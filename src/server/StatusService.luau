-- @file V4 status: earned titles and the public player card
-- @domain progression
-- @status wip
-- @see [[Titles.luau]]
-- @see [[V4-STATUS]]
-- Titles are granted here and only here, from the player's own server-side records, just before
-- each player-state push (so every change that reaches the client has been checked). Clients can
-- only ask to show a title they own ("showTitle"); the shown title's name goes on the Player as
-- the "Title" attribute for nameplates.
-- The player card: any client may ask for another player's card (Inspect, rate-limited) and gets
-- only public facts: rank, band, shown title, lifetime earned, extraction records, the Salvage Log
-- count. Never the coin balance, never anything a client sent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bands = require(ReplicatedStorage.Shared.Bands)
local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SalvageLog = require(ReplicatedStorage.Shared.SalvageLog)
local Titles = require(ReplicatedStorage.Shared.Titles)
local PlayerService = require(script.Parent.PlayerService)
local SessionStats = require(script.Parent.SessionStats)

local StatusService = {}

local eventRemote: RemoteEvent
local cardRemote: RemoteEvent
local INSPECT_LIMIT, INSPECT_WINDOW = 4, 2 -- requests per window (seconds)
local inspectWindows: { [Player]: { Start: number, Count: number } } = {}

local function viewOf(data: any): Titles.View
	return {
		Records = if type(data.Records) == "table" then data.Records else {},
		Found = if type(data.Collection) == "table" and type(data.Collection.Found) == "table"
			then data.Collection.Found
			else {},
		TotalEarned = data.Stats and data.Stats.TotalEarned or 0,
		Licenses = if type(data.Licenses) == "table" then data.Licenses else {},
	}
end

local function publish(player: Player, data: any)
	local shown = data.Titles.Shown
	local def = shown and Titles.ById[shown]
	local name = if def then def.Name else ""
	if player:GetAttribute("Title") ~= name then
		player:SetAttribute("Title", name)
	end
end

-- Grants any newly earned titles. Runs before every state push (PlayerService.beforePush).
local function check(player: Player, session: any)
	local data = session.Data
	data.Titles = Titles.reconcile(data.Titles)
	for _, id in Titles.newlyEarned(viewOf(data), data.Titles.Owned) do
		data.Titles.Owned[id] = true
		local def = Titles.ById[id]
		eventRemote:FireClient(player, { Kind = "Title", Id = id, Name = def.Name, How = def.How })
		SessionStats.event(player, "Title_" .. id, 1)
	end
	publish(player, data)
end

local function onAction(player: Player, action: unknown, arg: unknown)
	if action ~= "showTitle" then
		return
	end
	local session = PlayerService.get(player)
	if not session then
		return
	end
	local data = session.Data
	data.Titles = Titles.reconcile(data.Titles)
	if arg ~= nil and type(arg) ~= "string" then
		return
	end
	if not Titles.canShow(arg, data.Titles.Owned) then
		return -- not owned (or not a title): ignored, never trusted
	end
	data.Titles.Shown = arg :: string?
	PlayerService.pushState(player)
end

-- The public card for `player`.
function StatusService.card(player: Player): { [string]: any }?
	local session = PlayerService.get(player)
	if not session then
		return nil
	end
	local data = session.Data
	local records = if type(data.Records) == "table" then data.Records else {}
	local collection = SalvageLog.reconcile(data.Collection)
	local found, total = SalvageLog.progress(collection, Config.Loot)
	local owned = 0
	for _ in data.Titles.Owned do
		owned += 1
	end
	local shown = data.Titles.Shown and Titles.ById[data.Titles.Shown]
	local band = Bands.bandOf(data.Licenses)
	return {
		UserId = player.UserId,
		DisplayName = player.DisplayName,
		Name = player.Name,
		Rank = Progression.rankFor(data.Rep.XP).Title,
		Band = band,
		BandName = Bands.Names[band],
		Title = if shown then shown.Name else nil,
		Titles = owned,
		TitlesTotal = #Titles.List,
		Plate = data.Cosmetics.Plate,
		LifetimeEarned = data.Stats.TotalEarned,
		Extractions = records.Extractions or 0,
		BestExtract = records.BestExtract or 0,
		BestStreak = records.BestStreak or 0,
		GoldenExtractions = records.GoldenExtractions or 0,
		Hardest = records.Hardest or 0,
		Found = found,
		FoundTotal = total,
	}
end

local function onInspect(player: Player, userId: unknown)
	if type(userId) ~= "number" or userId ~= userId then
		return
	end
	local now = os.clock()
	local w = inspectWindows[player]
	if not w or now - w.Start > INSPECT_WINDOW then
		w = { Start = now, Count = 0 }
		inspectWindows[player] = w
	end
	w.Count += 1
	if w.Count > INSPECT_LIMIT then
		return
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target then
		return
	end
	local card = StatusService.card(target)
	if card then
		cardRemote:FireClient(player, card)
	end
end

function StatusService.init()
	eventRemote = Remotes.get("ProgressEvent")
	cardRemote = Remotes.get("InspectCard")
	PlayerService.beforePush(check)
	Remotes.get("ProgressAction").OnServerEvent:Connect(onAction)
	Remotes.get("Inspect").OnServerEvent:Connect(onInspect)
	Players.PlayerRemoving:Connect(function(player)
		inspectWindows[player] = nil
	end)
end

return StatusService

-- Salvage Contracts, Salvager Reputation and nameplate finishes (rules: shared/Progression).
--
-- Authority: progress only comes from the server's own game events (a pickup the server granted,
-- a sale the server paid, a storm the server says you survived), each reported exactly once by
-- the code path that already guarantees it happens once (LootService's `taken` flag, the sale
-- emptying the bag, the survivor check). Clients can only pin a job, swap one (cooldown) or buy
-- and equip a cosmetic finish, all validated here. Completing a job changes coins, XP and the
-- job list in one synchronous step (no yields), inside the player's profile, so it is saved
-- (or not) together with everything else under the existing session-owned save.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)

local ContractService = {}

local rng = Random.new()
local eventRemote: RemoteEvent
local swapReadyAt: { [Player]: number } = {}
local actionWindows: { [Player]: { Start: number, Count: number } } = {}
local ACTION_LIMIT, ACTION_WINDOW = 6, 1

local function pick(n: number): number
	return rng:NextInteger(1, n)
end

local function rankIndex(data: any): number
	return Progression.rankFor(data.Rep.XP).Index
end

-- Overhead nameplate: what every client draws (Nameplates.luau).
local function publish(player: Player, data: any)
	local rank = Progression.rankFor(data.Rep.XP)
	player:SetAttribute("RankIndex", rank.Index)
	player:SetAttribute("RankTitle", rank.Title)
	player:SetAttribute("Plate", data.Cosmetics.Plate)
end

-- Keeps three valid jobs. Repairs anything malformed from an older or damaged profile.
local function fill(data: any)
	local c = data.Contracts
	local valid = {}
	for _, job in c.Active do
		if
			type(job) == "table"
			and Progression.Kinds[job.Kind]
			and type(job.Target) == "number"
			and type(job.Progress) == "number"
		then
			table.insert(valid, job)
		end
	end
	c.Active = valid
	while #c.Active < Progression.ACTIVE do
		c.Done += 1
		table.insert(
			c.Active,
			Progression.make(Progression.pickKind(c.Active, pick), rankIndex(data), c.Done, pick)
		)
	end
end

local function addXP(player: Player, data: any, amount: number)
	if amount <= 0 then
		return
	end
	local before = rankIndex(data)
	data.Rep.XP += amount
	local after = Progression.rankFor(data.Rep.XP)
	if after.Index > before then
		publish(player, data)
		local unlocked = {}
		for _, f in Progression.Finishes do
			if f.Rank == after.Index then
				table.insert(unlocked, f.Name)
			end
		end
		eventRemote:FireClient(player, { Kind = "RankUp", Title = after.Title, Unlocked = unlocked })
	end
end

-- Applies one game event to the player's jobs; completes and replaces any that finish.
local function apply(player: Player, event: Progression.Event)
	local session = PlayerService.get(player)
	if not session then
		return
	end
	local data = session.Data
	local c = data.Contracts
	local changed = false
	for i, job in c.Active do
		local step = Progression.advance(job, event)
		if step > 0 then
			changed = true
			job.Progress = math.min(job.Target, job.Progress + step)
			if job.Progress >= job.Target then
				-- Complete: reward, then a fresh job in the same slot, all before anything yields.
				data.Coins += job.Coins
				data.Stats.TotalEarned += job.Coins
				c.Done += 1
				local text = Progression.describe(job)
				local replacement = Progression.make(
					Progression.pickKind(
						(function()
							local others = {}
							for j, o in c.Active do
								if j ~= i then
									table.insert(others, o)
								end
							end
							table.insert(others, job) -- a different kind next, for variety
							return others
						end)(),
						pick
					),
					rankIndex(data),
					c.Done,
					pick
				)
				if c.Pinned == job.Id then
					c.Pinned = replacement.Id
				end
				c.Active[i] = replacement
				eventRemote:FireClient(player, { Kind = "Job", Text = text, Coins = job.Coins, XP = job.XP })
				addXP(player, data, job.XP)
			end
		end
	end
	if changed then
		PlayerService.pushState(player)
	end
end

---------------------------------------------------------------------------- Game events

-- A pickup the server just granted. `zone` is the district the item spawned in (nil for Storm
-- Cores); `fromBag` is a recovery of a dropped bag, which doesn't count again.
function ContractService.collected(player: Player, _lootId: string, zone: string?, fromBag: boolean)
	if fromBag then
		return
	end
	apply(player, { Type = "Collected", Items = 1, Zone = zone })
end

function ContractService.survived(player: Player)
	local session = PlayerService.get(player)
	if session then
		addXP(player, session.Data, Progression.XP_PER_STORM_SURVIVED)
	end
	apply(player, { Type = "Survived" })
end

local function sold(player: Player, items: number, coins: number, cores: number)
	local session = PlayerService.get(player)
	if session then
		addXP(player, session.Data, items * Progression.XP_PER_ITEM_SOLD)
	end
	apply(player, { Type = "Sold", Items = items, Coins = coins, Cores = cores })
end

---------------------------------------------------------------------------- Player actions

local function allowed(player: Player): boolean
	local now = os.clock()
	local w = actionWindows[player]
	if not w or now - w.Start >= ACTION_WINDOW then
		actionWindows[player] = { Start = now, Count = 1 }
		return true
	end
	w.Count += 1
	return w.Count <= ACTION_LIMIT
end

local function onAction(player: Player, action: unknown, arg: unknown)
	if type(action) ~= "string" or (arg ~= nil and (type(arg) ~= "string" or #arg > 32)) then
		return
	end
	if not allowed(player) then
		return
	end
	local session = PlayerService.get(player)
	if not session then
		return
	end
	local data = session.Data
	local c = data.Contracts
	if action == "pin" then
		for _, job in c.Active do
			if job.Id == arg then
				c.Pinned = if c.Pinned == arg then nil else arg
				PlayerService.pushState(player)
				return
			end
		end
	elseif action == "swap" then
		local now = os.clock()
		if now < (swapReadyAt[player] or 0) then
			PlayerService.notify(
				player,
				("You can swap a job again in %ds."):format(math.ceil(swapReadyAt[player] - now)),
				Color3.fromRGB(255, 200, 120)
			)
			return
		end
		for i, job in c.Active do
			if job.Id == arg then
				local others = {}
				for j, o in c.Active do
					if j ~= i then
						table.insert(others, o)
					end
				end
				table.insert(others, job) -- never deal the same kind straight back
				c.Done += 1
				local replacement =
					Progression.make(Progression.pickKind(others, pick), rankIndex(data), c.Done, pick)
				if c.Pinned == job.Id then
					c.Pinned = replacement.Id
				end
				c.Active[i] = replacement
				swapReadyAt[player] = now + Progression.SWAP_COOLDOWN
				PlayerService.pushState(player)
				return
			end
		end
	elseif action == "buyFinish" then
		local ok, why = Progression.canBuyFinish(arg, data.Coins, data.Rep.XP, data.Cosmetics.Owned)
		if not ok then
			local f = Progression.finish(arg)
			PlayerService.notify(
				player,
				if why == "short" and f
					then ("Need %d more coins."):format(f.Cost - data.Coins)
					elseif why == "rank" and f then ("Reach %s to unlock this finish."):format(
						Progression.Ranks[f.Rank].Title
					)
					else "You can't buy that.",
				Color3.fromRGB(255, 160, 120)
			)
			return
		end
		local f = Progression.finish(arg) :: Progression.Finish
		data.Coins -= f.Cost
		data.Cosmetics.Owned[f.Id] = true
		data.Cosmetics.Plate = f.Id
		publish(player, data)
		PlayerService.pushState(player)
		PlayerService.notify(player, ("%s nameplate unlocked!"):format(f.Name), Color3.fromRGB(255, 220, 90))
	elseif action == "equipFinish" then
		local f = Progression.finish(arg)
		if f and data.Cosmetics.Owned[f.Id] then
			data.Cosmetics.Plate = f.Id
			publish(player, data)
			PlayerService.pushState(player)
		end
	end
end

---------------------------------------------------------------------------- Board

-- A notice board beside the spawn aisle in the Scrapyard; its prompt opens the Jobs board.
local function buildBoard()
	local origin = Vector3.new(16, 60, -280)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Loot") or workspace.Terrain }
	local hit = workspace:Raycast(origin, Vector3.new(0, -80, 0), params)
	local ground = if hit then hit.Position.Y else 33
	local model = Instance.new("Model")
	model.Name = "ContractBoard"
	local face = CFrame.lookAt(Vector3.new(16, ground + 4.5, -280), Vector3.new(0, ground + 4.5, -280))
	local function block(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local wood = Color3.fromRGB(116, 76, 40)
	for _, x in { -3.6, 3.6 } do
		block("Post", Vector3.new(0.6, 9, 0.6), face * CFrame.new(x, -0.3, 0.3), wood, Enum.Material.Wood)
	end
	local panel = block(
		"Board",
		Vector3.new(7.6, 4.6, 0.4),
		face * CFrame.new(0, 0.6, 0),
		Color3.fromRGB(150, 106, 62),
		Enum.Material.WoodPlanks
	)
	block("Roof", Vector3.new(8.6, 0.4, 1.4), face * CFrame.new(0, 3.2, 0.1), wood, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- the side facing the spawn aisle
	gui.CanvasSize = Vector2.new(380, 230)
	gui.LightInfluence = 0.4
	gui.Parent = panel
	local title = Instance.new("TextLabel")
	title.BackgroundColor3 = Color3.fromRGB(240, 220, 170)
	title.BorderSizePixel = 0
	title.Position = UDim2.fromOffset(40, 18)
	title.Size = UDim2.fromOffset(300, 56)
	title.Font = Enum.Font.PermanentMarker
	title.TextSize = 40
	title.TextColor3 = Color3.fromRGB(34, 30, 28)
	title.Text = "JOBS"
	title.Parent = gui
	for i = 0, 2 do
		local note = Instance.new("Frame")
		note.BackgroundColor3 = if i == 1
			then Color3.fromRGB(255, 226, 110)
			else Color3.fromRGB(250, 248, 238)
		note.BorderSizePixel = 0
		note.Position = UDim2.fromOffset(34 + i * 110, 92)
		note.Size = UDim2.fromOffset(92, 110)
		note.Rotation = (i - 1) * 4
		note.Parent = gui
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "JobsPrompt"
	prompt.ActionText = "View Jobs"
	prompt.ObjectText = "Contract Board"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = panel
	model.Parent = workspace:FindFirstChild("Map") or workspace
end

-- Studio QA only (DebugService): add XP through the real rank-up path.
function ContractService.addXPForTest(player: Player, amount: number)
	assert(game:GetService("RunService"):IsStudio(), "Studio only")
	local session = PlayerService.get(player)
	if session then
		addXP(player, session.Data, amount)
		PlayerService.pushState(player)
	end
end

---------------------------------------------------------------------------- Init

function ContractService.init()
	eventRemote = Remotes.get("ProgressEvent")
	Remotes.get("ProgressAction").OnServerEvent:Connect(onAction)
	PlayerService.onSold(sold)
	PlayerService.onLoaded(function(player, session)
		fill(session.Data)
		if
			not Progression.finish(session.Data.Cosmetics.Plate)
			or not session.Data.Cosmetics.Owned[session.Data.Cosmetics.Plate]
		then
			session.Data.Cosmetics.Plate = "Cardboard"
		end
		session.Data.Cosmetics.Owned.Cardboard = true
		publish(player, session.Data)
		PlayerService.pushState(player)
	end)
	-- The nameplate replaces Roblox's default overhead name.
	local function hideDefaultName(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(hideDefaultName)
		if player.Character then
			task.spawn(hideDefaultName, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		swapReadyAt[player] = nil
		actionWindows[player] = nil
	end)
	buildBoard()
end

return ContractService

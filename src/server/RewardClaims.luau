-- @file Cooperative shares for players who weren't there: stored, then paid once on their next join
-- @domain progression
-- @status wip
-- @see [[PendingRewards.luau]]
-- @see [[V4-COOP]]
-- Two ways a share ends up pending (never with anyone else):
--   * the event decides a share for a contributor who has left (Armored Wreck vault);
--   * a player leaves with owner-only shares still lying on the ground (Wreck, Titan core).
-- Either way it's written under the owner's own user id (DataService.addPending, bounded and
-- expiring). On their next join it's paid as coins at their own Salvage Press, through
-- DataService.grantClaim (coins and the claim id in one profile write, so never twice), then
-- the live session gets the same change, the session is saved, and the pending entry is removed.
-- A crash between those steps is safe: the profile already records the claim, so the next join
-- just removes the leftover entry.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigMoney = require(ReplicatedStorage.Shared.BigMoney)
local Config = require(ReplicatedStorage.Shared.Config)
local PendingRewards = require(ReplicatedStorage.Shared.PendingRewards)
local Wallet = require(ReplicatedStorage.Shared.Wallet)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local SessionStats = require(script.Parent.SessionStats)

local RewardClaims = {}

RewardClaims.ServerId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

local VALUES: { [string]: number } = {}
for id, def in Config.Loot do
	VALUES[id] = def.Value
end

-- The owner's own sale factor from their profile: the Salvage Press (needs the Pro licence).
local function pressFactor(data: any): number
	local level = type(data.Upgrades) == "table" and data.Upgrades.Press or 0
	local pro = type(data.Licenses) == "table" and data.Licenses.Pro == true
	if pro and type(level) == "number" and level > 0 then
		return Config.Upgrades.Press.Values[level + 1] or 1
	end
	return 1
end

-- Store `items` for `userId` (who isn't here). `id` names this exact share (event + share).
function RewardClaims.hold(userId: number, id: string, items: { string }, source: string): boolean
	if #items == 0 then
		return true
	end
	local ok = DataService.addPending(userId, { Id = id, Items = items, Source = source, At = os.time() })
	print(("[RewardClaims] held %s for %d: %s"):format(id, userId, table.concat(items, ",")))
	return ok
end

local function payOne(player: Player, entry: PendingRewards.Entry): boolean
	local session = PlayerService.get(player)
	if not session or not session.CanSave then
		return false -- can't persist the payment here: leave it pending for a later join
	end
	if PendingRewards.claimed(session.Data.ClaimedRewards, entry.Id) then
		return true -- already paid (and saved): just clear the entry
	end
	local paid = "0"
	local function apply(data: any)
		paid = PendingRewards.value(entry.Items, VALUES, pressFactor(data))
		Wallet.earn(data, paid)
	end
	local ok, already, lostLock = DataService.grantClaim(player, entry.Id, apply)
	if lostLock then
		session.CanSave = false
		return false
	end
	if not ok then
		return false
	end
	if not already then
		-- The stored profile has it; give the live session the same, once.
		apply(session.Data)
		session.Data.ClaimedRewards =
			PendingRewards.remember(session.Data.ClaimedRewards, entry.Id, os.time())
		SessionStats.event(player, "PendingClaimed", 1)
		PlayerService.notify(
			player,
			("While you were away: your %s share paid %s coins."):format(
				string.lower(entry.Source),
				BigMoney.full(paid)
			),
			Color3.fromRGB(255, 220, 90)
		)
	end
	return true
end

-- Pays every live pending share for `player` (on join).
function RewardClaims.claim(player: Player)
	local entries = DataService.readPending(player.UserId)
	if not entries or #entries == 0 then
		return
	end
	local done: { [string]: boolean } = {}
	for _, entry in entries do
		if payOne(player, entry) then
			done[entry.Id] = true
		end
	end
	if next(done) then
		-- The session now holds the coins: save it before clearing the entries.
		if PlayerService.save(player, false) then
			DataService.removePending(player.UserId, done)
		end
		PlayerService.pushState(player)
	end
end

function RewardClaims.init()
	PlayerService.onLoaded(function(player)
		task.delay(2, RewardClaims.claim, player)
	end)
end

return RewardClaims

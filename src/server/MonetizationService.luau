-- @file Game passes and developer products (Supply Counter)
-- @domain salvage-economy
-- @status stable
-- @see [[V3-MONETIZATION]]
-- Game passes and developer products (the Supply Counter). IDs live in Config; an Id of 0
-- disables that item. Coins are granted only here, from Roblox's receipt callback, never from a
-- client message; the client is told after the reward is saved (PurchaseDelivered).
--
-- Developer-product receipts. Correctness rests on one invariant: **a PurchaseId is in the
-- stored profile if and only if its reward is in the stored profile.** Both are written in a
-- single UpdateAsync (DataService.grantReceipt), the transform checks the PurchaseId first and
-- has no side effects, and the profile's PurchaseId list is never pruned. So:
--   - a retry, a duplicate callback or a delivery after rejoining finds the PurchaseId and
--     grants nothing;
--   - only the server holding the profile's session lock can write it (grantReceipt refuses
--     otherwise and the receipt stays unprocessed until that server's session ends);
--   - live-session saves write the whole profile, so a save that predates the grant overwrites
--     both the reward and the PurchaseId together, and the receipt is granted again, once.
-- The live session only receives the reward after the durable write, so nothing spendable
-- exists that a failed write could take back. PurchaseGranted is returned only after the
-- session has been saved with the grant. The purchase-history store is an audit log, written
-- after that save and **never read to decide anything**: a racing whole-profile save (e.g. the
-- shutdown save) can legitimately drop a just-made grant together with its PurchaseId, and a
-- history record must then not stop the redelivery from granting it (RC3 fix; in RC2 a history
-- hit returned PurchaseGranted without the reward).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Wallet = require(ReplicatedStorage.Shared.Wallet)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local SessionStats = require(script.Parent.SessionStats)

local MonetizationService = {}

local deliveredRemote = Remotes.get("PurchaseDelivered")

---------------------------------------------------------------------------- Game pass

-- Heavy-Duty Pack: a yes/no entitlement on the session (so it can never stack), checked with
-- Roblox on join and set when Roblox reports a completed purchase. Not saved: Roblox is the
-- record of ownership. If the ownership check errors, it retries instead of silently denying a
-- paying player.
local function grantHeavyDuty(player: Player, announce: boolean)
	local session = PlayerService.get(player)
	if not session or session.OwnsHeavyDuty then
		return
	end
	session.OwnsHeavyDuty = true
	PlayerService.pushState(player)
	if announce then
		PlayerService.notify(
			player,
			("Heavy-Duty Pack unlocked: +%d bag slots!"):format(Config.GamePasses.HeavyDuty.BonusCapacity),
			Color3.fromRGB(255, 220, 90)
		)
		deliveredRemote:FireClient(player, { Kind = "Pass", Key = "HeavyDuty" })
		SessionStats.purchased(player, "HeavyDuty")
	end
end

local function refreshPasses(player: Player, attempt: number?)
	local pass = Config.GamePasses.HeavyDuty
	if pass.Id == 0 or not player.Parent then
		return
	end
	local ok, owns =
		pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
	if ok and owns == true then
		grantHeavyDuty(player, false)
	elseif not ok and (attempt or 1) < 10 then
		task.delay(30, refreshPasses, player, (attempt or 1) + 1)
	end
end

---------------------------------------------------------------------------- Developer products

-- Each product: `apply` adds the reward to a profile table (used on the stored profile first,
-- then on the live session), `message` is shown once the grant is durable.
type Product = { Key: string, Coins: number, apply: (data: any) -> (), message: string }
local products: { [number]: Product } = {}

local function coinPack(key: string, coins: number): Product
	return {
		Key = key,
		Coins = coins,
		apply = function(data)
			-- A fixed amount, decided by the product (never by the player's state at delivery
			-- time), applied in the same write as the PurchaseId. Bought coins are cash, not
			-- earnings, so they never count toward wealth titles.
			Wallet.deposit(data, coins)
		end,
		message = ("+%s coins delivered. Thanks for the support!"):format(tostring(coins)),
	}
end

local function registerProducts()
	for key, def in Config.DevProducts do
		if def.Id ~= 0 then
			products[def.Id] = coinPack(key, def.Coins)
		end
	end
	-- Studio QA (DebugService): stand-in ids for the real catalog, so the full receipt path can be
	-- exercised before the products exist. Negative ids are never real Roblox products.
	if RunService:IsStudio() then
		for key, def in Config.DevProducts do
			products[-100 - def.Order] = coinPack(key, def.Coins)
		end
	end
end

local inFlight: { [string]: boolean } = {}

local function rememberReceipt(receipts: { string }, purchaseId: string)
	table.insert(receipts, purchaseId)
end

local function processReceiptUnguarded(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local session = player and PlayerService.get(player)
	if not player or not session then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Never grant what we can't persist: with DataStores unavailable the reward would vanish on
	-- leave. Leaving it unprocessed lets Roblox retry on a later join.
	if not session.CanSave then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)

	-- 1. Durable grant first, live session second. The profile is the only record consulted:
	-- it's written atomically with the reward, so it can't say "granted" without the reward.
	local grantedNow = false
	if not table.find(session.Data.ProcessedReceipts, purchaseId) then
		local product = products[receipt.ProductId]
		if not product then
			warn("[Monetization] no handler for product", receipt.ProductId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, _already, lostLock = DataService.grantReceipt(player, purchaseId, product.apply)
		if lostLock then
			session.CanSave = false
			PlayerService.pushState(player)
		end
		if not ok then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- The stored profile now has the grant (just written, or written by an earlier attempt
		-- whose session never got it); the session doesn't yet, so apply it once here.
		product.apply(session.Data)
		rememberReceipt(session.Data.ProcessedReceipts, purchaseId)
		grantedNow = true
		PlayerService.pushState(player)
		PlayerService.notify(player, product.message, Color3.fromRGB(255, 220, 90))
	end

	-- 2. A full save of the session (which now holds the reward), so a save that started before
	-- the grant can't leave the profile without it.
	if not PlayerService.save(player, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- 3. Audit record, only now that the reward is in the saved profile. Never read for
	-- decisions (see the header).
	if not DataService.recordPurchase(purchaseId, receipt.PlayerId, receipt.ProductId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = products[receipt.ProductId]
	if product and grantedNow then
		deliveredRemote:FireClient(player, { Kind = "Product", Key = product.Key, Coins = product.Coins })
		SessionStats.purchased(player, product.Key)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local id = tostring(receipt.PurchaseId)
	if inFlight[id] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	inFlight[id] = true
	local ok, result = pcall(processReceiptUnguarded, receipt)
	inFlight[id] = nil
	if not ok then
		warn("[Monetization] receipt error", id, result)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return result
end

-- Studio QA only (DebugService): run a simulated receipt through the real handler. `key` picks a
-- catalog product (its Studio stand-in id); without it, a 1000-coin test product.
MonetizationService.TEST_PRODUCT_ID = -1
MonetizationService.TEST_PRODUCT_COINS = 1000
function MonetizationService.simulateReceipt(
	player: Player,
	purchaseId: string,
	key: string?
): Enum.ProductPurchaseDecision
	assert(RunService:IsStudio(), "Studio only")
	products[MonetizationService.TEST_PRODUCT_ID] = coinPack("Test", MonetizationService.TEST_PRODUCT_COINS)
	local productId = MonetizationService.TEST_PRODUCT_ID
	if key then
		local def = Config.DevProducts[key]
		assert(def, "unknown product " .. key)
		productId = -100 - def.Order
	end
	return processReceipt({
		PlayerId = player.UserId,
		ProductId = productId,
		PurchaseId = purchaseId,
		CurrencySpent = 0,
		CurrencyType = Enum.CurrencyType.Robux,
		PlaceIdWherePurchased = game.PlaceId,
	})
end

-- Studio QA only: what Roblox's PromptGamePassPurchaseFinished(purchased = true) does.
function MonetizationService.simulatePassPurchase(player: Player)
	assert(RunService:IsStudio(), "Studio only")
	grantHeavyDuty(player, true)
end

function MonetizationService.init()
	registerProducts()
	MarketplaceService.ProcessReceipt = processReceipt

	PlayerService.onLoaded(function(player)
		refreshPasses(player)
	end)

	-- Fired on the server by Roblox (not by the client) when a pass purchase completes.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Config.GamePasses.HeavyDuty
		if purchased and pass.Id ~= 0 and passId == pass.Id then
			grantHeavyDuty(player, true)
		end
	end)

	-- Keep the boost countdown on clients accurate.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				local session = PlayerService.get(player)
				if session and session.Data.BoostUntil > os.time() - 31 then
					PlayerService.pushState(player)
				end
			end
		end
	end)
end

return MonetizationService

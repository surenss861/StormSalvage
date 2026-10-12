-- Game passes and developer products. IDs live in Config; an Id of 0 disables that item.
--
-- Developer-product receipts are processed so a reward can never be granted twice or spent
-- before it is durable:
--   1. A PurchaseId already in the lifetime purchase history is acknowledged without granting.
--   2. The grant and its PurchaseId are written to the stored profile in one UpdateAsync
--      (DataService.grantReceipt). Only after that succeeds does the live session get the
--      reward, so nothing spendable exists that a failed save could take back.
--   3. The PurchaseId goes into the lifetime history store, the session is saved, and only
--      then is PurchaseGranted returned. Any failure returns NotProcessedYet; Roblox re-delivers
--      the receipt and steps 1-2 make the retry a no-op apart from finishing the bookkeeping.
-- A receipt already being processed in this server is never processed concurrently.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local MonetizationService = {}

local MAX_RECEIPT_HISTORY = 100

local function ownsPass(player: Player, passId: number): boolean
	if passId == 0 then
		return false
	end
	local ok, owns =
		pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and owns == true
end

local function refreshPasses(player: Player)
	local session = PlayerService.get(player)
	if not session then
		return
	end
	session.OwnsBigBag = ownsPass(player, Config.GamePasses.BigBag.Id)
	session.OwnsVIP = ownsPass(player, Config.GamePasses.VIP.Id)
	PlayerService.pushState(player)
end

-- Each product: `apply` adds the reward to a profile table (used on the stored profile first,
-- then on the live session), `message` is shown once the grant is durable.
type Product = { apply: (data: any) -> (), message: string }
local products: { [number]: Product } = {}

local function registerProducts()
	local boost = Config.DevProducts.SalvageBoost
	if boost.Id ~= 0 then
		products[boost.Id] = {
			apply = function(data)
				data.BoostUntil = math.max(data.BoostUntil, os.time()) + boost.BoostSeconds
			end,
			message = "2x Salvage active!",
		}
	end
	local coins = Config.DevProducts.CoinPackSmall
	if coins.Id ~= 0 then
		products[coins.Id] = {
			apply = function(data)
				data.Coins += coins.Coins
			end,
			message = ("+%d coins. Thanks for the support!"):format(coins.Coins),
		}
	end
end

local inFlight: { [string]: boolean } = {}

local function rememberReceipt(receipts: { string }, purchaseId: string)
	table.insert(receipts, purchaseId)
	while #receipts > MAX_RECEIPT_HISTORY do
		table.remove(receipts, 1)
	end
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

	-- 1. Lifetime history: granted in some earlier session or server.
	local readOk, recorded = DataService.purchaseRecorded(purchaseId)
	if not readOk then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if recorded then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 2. Durable grant first, live session second.
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
		PlayerService.pushState(player)
		PlayerService.notify(player, product.message, Color3.fromRGB(255, 220, 90))
	end

	-- 3. Lifetime record, then a full save so later progress doesn't overwrite the grant.
	if not DataService.recordPurchase(purchaseId, receipt.PlayerId, receipt.ProductId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not PlayerService.save(player, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
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

-- Studio QA only (DebugService): run a simulated receipt through the real handler. Product
-- ids are 0 until real products exist, so tests use a test-only product id.
MonetizationService.TEST_PRODUCT_ID = -1
MonetizationService.TEST_PRODUCT_COINS = 1000
function MonetizationService.simulateReceipt(player: Player, purchaseId: string): Enum.ProductPurchaseDecision
	products[MonetizationService.TEST_PRODUCT_ID] = {
		apply = function(data)
			data.Coins += MonetizationService.TEST_PRODUCT_COINS
		end,
		message = "Test purchase granted.",
	}
	return processReceipt({
		PlayerId = player.UserId,
		ProductId = MonetizationService.TEST_PRODUCT_ID,
		PurchaseId = purchaseId,
		CurrencySpent = 0,
		CurrencyType = Enum.CurrencyType.Robux,
		PlaceIdWherePurchased = game.PlaceId,
	})
end

function MonetizationService.init()
	registerProducts()
	MarketplaceService.ProcessReceipt = processReceipt

	PlayerService.onLoaded(function(player)
		refreshPasses(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, purchased)
		if purchased then
			refreshPasses(player)
			PlayerService.notify(player, "Pass unlocked. Thank you!", Color3.fromRGB(255, 220, 90))
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

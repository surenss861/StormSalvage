-- Game passes and developer products. IDs live in Config; an Id of 0 disables that item.
-- ProcessReceipt is idempotent: receipts are recorded in the saved profile so a
-- retried callback never grants twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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

local productHandlers: { [number]: (Player, any) -> () } = {}

local function registerProducts()
	local boost = Config.DevProducts.SalvageBoost
	if boost.Id ~= 0 then
		productHandlers[boost.Id] = function(player, session)
			local now = os.time()
			session.Data.BoostUntil = math.max(session.Data.BoostUntil, now) + boost.BoostSeconds
			PlayerService.notify(player, "2x Salvage active!", Color3.fromRGB(255, 220, 90))
		end
	end
	local coins = Config.DevProducts.CoinPackSmall
	if coins.Id ~= 0 then
		productHandlers[coins.Id] = function(player, session)
			session.Data.Coins += coins.Coins
			PlayerService.notify(
				player,
				("+%d coins. Thanks for the support!"):format(coins.Coins),
				Color3.fromRGB(255, 220, 90)
			)
		end
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local session = player and PlayerService.get(player)
	if not player or not session then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receipts = session.Data.ProcessedReceipts
	if not table.find(receipts, receipt.PurchaseId) then
		local handler = productHandlers[receipt.ProductId]
		if not handler then
			warn("[Monetization] no handler for product", receipt.ProductId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		handler(player, session)
		table.insert(receipts, receipt.PurchaseId)
		while #receipts > MAX_RECEIPT_HISTORY do
			table.remove(receipts, 1)
		end
		PlayerService.pushState(player)
	end

	-- Only confirm once the grant is safely persisted (or saving is impossible in this session).
	if session.CanSave and not PlayerService.save(player, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
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

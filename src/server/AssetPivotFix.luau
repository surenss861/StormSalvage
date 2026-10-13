-- @file Restores authored asset pivots before placement
-- @domain world
-- @status stable
-- @see [[AssetPivots.luau]]
-- @see [[pivots.luau]]
-- @see [[RC5-DEPLOYMENT]]
-- Restores the authored pivots of the asset templates in ServerStorage.Assets before anything is
-- placed.
--
-- Placement code moves each asset by its pivot: base centre, plus deliberate offsets such as the
-- crane arm and the shop counters. Studio resets those pivots to the bounding-box centre when it
-- opens the Rojo-built place file, although the file holds them. Published from that file, every
-- building and prop sat half underground (RC5 on the live place). AssetPivots.luau records the
-- authored pivots from the asset files; CI checks it against them. In a place where the pivots
-- survived (the dev place), applying them changes nothing.

local ServerStorage = game:GetService("ServerStorage")

local AssetPivots = require(script.Parent.AssetPivots)

local AssetPivotFix = {}

function AssetPivotFix.apply(): (number, number)
	local assets = ServerStorage:FindFirstChild("Assets")
	if not assets then
		warn("[AssetPivotFix] no ServerStorage.Assets")
		return 0, 0
	end
	local corrected, missing = 0, 0
	for key, c in AssetPivots do
		local setName, name = string.match(key, "^([^/]+)/(.+)$")
		local set = setName and assets:FindFirstChild(setName)
		local model = set and set:FindFirstChild(name)
		if model and model:IsA("Model") then
			local authored = CFrame.new(table.unpack(c))
			if not model:GetPivot():FuzzyEq(authored, 1e-3) then
				model.WorldPivot = authored
				corrected += 1
			end
		else
			missing += 1
		end
	end
	print(string.format("[AssetPivotFix] %d asset pivots restored, %d missing", corrected, missing))
	return corrected, missing
end

return AssetPivotFix

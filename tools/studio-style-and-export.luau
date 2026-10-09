-- Studio command-bar tool (Edit mode). After importing an FBX batch with the 3D Importer:
--   1. Move the imported models into ServerStorage.ImportedAssets.<set> (e.g. "salvage").
--   2. Run tools/asset_server.py from the repo root.
--   3. Run this script (loadstring via HTTP, like studio-sync). It styles every MeshPart from its
--      "Piece__Material__Swatch" name using src/shared/Palette.luau, then writes each model to
--      assets/roblox/<set>/<Model>.rbxm, which Rojo syncs into ServerStorage.Assets.<set>.

local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local ServerStorage = game:GetService("ServerStorage")

-- Require a fresh copy: the command bar caches modules, which would hide palette edits.
local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette:Clone())

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(buf: buffer): string
	local out = table.create(math.ceil(buffer.len(buf) / 3))
	local n = buffer.len(buf)
	for i = 0, n - 1, 3 do
		local a = buffer.readu8(buf, i)
		local b = if i + 1 < n then buffer.readu8(buf, i + 1) else 0
		local c = if i + 2 < n then buffer.readu8(buf, i + 2) else 0
		local v = bit32.bor(bit32.lshift(a, 16), bit32.lshift(b, 8), c)
		local s = {}
		for k = 3, 0, -1 do
			local idx = bit32.band(bit32.rshift(v, k * 6), 63)
			s[4 - k] = string.sub(B64, idx + 1, idx + 1)
		end
		if i + 1 >= n then
			s[3], s[4] = "=", "="
		elseif i + 2 >= n then
			s[4] = "="
		end
		table.insert(out, table.concat(s))
	end
	return table.concat(out)
end

-- Assets with open interiors or gaps (doorways, the gate) need real collision shapes; a box
-- around their joined walls would block them. Everything else uses a cheap box. Salvage never
-- collides (LootService turns collisions off).
local PRECISE = { SellShack = true, GearShack = true, GateArch = true, Crane = true, Crusher = true, Workbench = true }

-- Applies palette material/color to one model; returns how many MeshParts were styled.
local function style(model: Instance): (number, { string })
	local styled, unknown = 0, {}
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			d:Destroy() -- we color from the palette, not imported textures
		elseif d:IsA("MeshPart") then
			local material, color = Palette.parseName(d.Name)
			if material and color then
				d.Material = material
				d.Color = color
				styled += 1
			else
				table.insert(unknown, d.Name)
			end
			d.Anchored = true
			d.CastShadow = d.Size.Magnitude > 4
			d.CollisionFidelity = if PRECISE[model.Name]
				then Enum.CollisionFidelity.PreciseConvexDecomposition
				else Enum.CollisionFidelity.Box
			if material == Enum.Material.Glass then
				d.Transparency = 0.3
			end
		end
	end
	return styled, unknown
end

local root = ServerStorage:FindFirstChild("ImportedAssets") or ServerStorage:FindFirstChild("Assets")
assert(root, "Put imported models in ServerStorage.ImportedAssets.<set> first")

local log = {}
local was = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, err = pcall(function()
	for _, set in root:GetChildren() do
		for _, model in set:GetChildren() do
			local styled, unknown = style(model)
			local data = SerializationService:SerializeInstancesAsync({ model })
			local path = ("assets/roblox/%s/%s.rbxm"):format(set.Name, model.Name)
			local reply = HttpService:PostAsync(
				"http://127.0.0.1:34872/save?path=" .. HttpService:UrlEncode(path),
				base64(data),
				Enum.HttpContentType.TextPlain
			)
			table.insert(
				log,
				("%s: styled %d meshes%s -> %s"):format(
					model.Name,
					styled,
					#unknown > 0 and (" (unstyled: " .. table.concat(unknown, ", ") .. ")") or "",
					reply
				)
			)
		end
	end
end)
HttpService.HttpEnabled = was
return (ok and "ok" or ("ERROR " .. tostring(err))) .. "\n" .. table.concat(log, "\n")

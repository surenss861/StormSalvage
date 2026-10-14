-- @file CI: the built place contains every model and world builder the game needs
-- @domain world
-- @status stable
-- @see [[Bands.luau]]
-- @see [[MapBuilder.luau]]
-- A map or model that exists only in someone's open Studio window isn't a shipped asset. This
-- reads the Rojo-built place and fails if anything the code spawns is missing from it:
--   * a model for every loot item that names its own (band salvage from Bands.luau: artifacts,
--     the Storm Heart, industrial, vault, mythic; the Golden Core), and the Armored Wreck;
--   * every district builder module, and MapBuilder calling it;
--   * the event services and their client halves.
--   lune run tools/assets/manifest <place.rbxl>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Bands = (require :: any)("../../src/shared/Bands")

local placePath = process.args[1]
assert(placePath, "usage: lune run tools/assets/manifest <place.rbxl>")
local game = roblox.deserializePlace(fs.readFile(placePath))
local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
assert(assets, "no ServerStorage.Assets")

local missing = {}
local checked = 0
local function need(ok: boolean, what: string)
	checked += 1
	if not ok then
		table.insert(missing, what)
	end
end

local function model(set: string, name: string)
	local folder = assets:FindFirstChild(set)
	local m = folder and folder:FindFirstChild(name)
	local parts = 0
	if m then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
	end
	need(m ~= nil and parts > 0, ("model %s/%s"):format(set, name))
end

model("salvage", "GoldenCore")
model("salvage", Bands.StormHeart.Id)
for _, list in { Bands.Industrial, Bands.Artifacts, Bands.Mythic } do
	for _, item in list do
		model("salvage", item.Id)
	end
end
for _, id in Bands.VaultOrder do
	model("salvage", id)
end
model("events", "ArmoredWreck")

local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
local client = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Client")
assert(server and client, "no Server/Client script folders")
local mapBuilder = server:FindFirstChild("MapBuilder")
need(mapBuilder ~= nil, "server MapBuilder")
local source = if mapBuilder then (mapBuilder :: any).Source else ""
for _, district in
	{ "Houses", "Supermarket", "Fuel", "Warehouse", "Motel", "RailYard", "FloodWorks", "South" }
do
	local name = "District" .. district
	need(server:FindFirstChild(name) ~= nil, "server " .. name)
	need(string.find(source, name .. ".build(", 1, true) ~= nil, "MapBuilder calls " .. name .. ".build")
end
for _, name in { "StormEyeService", "WreckService", "TitanService", "EventService", "PursuitService" } do
	need(server:FindFirstChild(name) ~= nil, "server " .. name)
end
for _, name in { "StormEyeHud", "WreckHud", "TitanHud", "PursuitHud", "WorldMotion" } do
	need(client:FindFirstChild(name) ~= nil, "client " .. name)
end

if #missing > 0 then
	print("MISSING from " .. placePath .. ":\n  " .. table.concat(missing, "\n  "))
	process.exit(1)
end
print(("%s has everything (%d checks)"):format(placePath, checked))

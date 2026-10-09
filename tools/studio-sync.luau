-- Rojo-free sync for when the rojo binary is unavailable: run `python3 -m http.server 34872 --bind 127.0.0.1`
-- from the repo root, then paste tools/studio-sync-bootstrap.luau into the Studio command bar (Edit mode).
-- Pulls src/ from the local http server into the place (Rojo-equivalent mapping).
local Http = game:GetService("HttpService")
local BASE = "http://127.0.0.1:34872/src/"
local roots = {
	shared = game.ReplicatedStorage:FindFirstChild("Shared"),
	server = game.ServerScriptService:FindFirstChild("Server"),
	client = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client"),
}
local was = Http.HttpEnabled
Http.HttpEnabled = true
local log = {}
local ok, err = pcall(function()
	for dir, folder in roots do
		local listing = Http:GetAsync(BASE .. dir .. "/")
		local seen = {}
		for file in listing:gmatch('href="([%w_]+[%.%w]*%.luau)"') do
			local name, kind = file:match("^([%w_]+)%.(%a+)%.luau$")
			local class = "ModuleScript"
			if kind == "server" then class = "Script" elseif kind == "client" then class = "LocalScript" else name = file:match("^([%w_]+)%.luau$") end
			local src = Http:GetAsync(BASE .. dir .. "/" .. file)
			local inst = folder:FindFirstChild(name)
			if inst and inst.ClassName ~= class then inst:Destroy() inst = nil end
			if not inst then inst = Instance.new(class) inst.Name = name inst.Parent = folder table.insert(log, "created " .. name) end
			if inst.Source ~= src then inst.Source = src table.insert(log, "updated " .. dir .. "/" .. name) end
			seen[name] = true
		end
		for _, c in folder:GetChildren() do
			if c:IsA("LuaSourceContainer") and not seen[c.Name] then table.insert(log, "removed " .. c.Name) c:Destroy() end
		end
	end
end)
Http.HttpEnabled = was
return (ok and "ok" or ("ERR " .. tostring(err))) .. "\n" .. table.concat(log, "\n")

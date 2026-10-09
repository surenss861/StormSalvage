-- Paste into the Studio command bar (Edit mode) while the repo is served on port 34872.
local Http = game:GetService("HttpService")
local was = Http.HttpEnabled
Http.HttpEnabled = true
local ok, code = pcall(Http.GetAsync, Http, "http://127.0.0.1:34872/tools/studio-sync.luau")
Http.HttpEnabled = was
assert(ok, code)
return loadstring(code)()

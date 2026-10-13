local Environment = require("../src/shared/Environment")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local PROD = { 99653875913460 }
local STAGING = { 1234567890 }

return {
	["env: Studio always uses _STUDIO, even on the live place id"] = function()
		local r = Environment.resolve(true, 99653875913460, PROD, STAGING)
		eq(r.Name, "Studio", "name")
		eq(r.DataStoreName, "StormSalvage_v1_STUDIO", "store")
	end,
	["env: Studio on a staging or unknown place still _STUDIO"] = function()
		eq(
			Environment.resolve(true, 1234567890, PROD, STAGING).DataStoreName,
			"StormSalvage_v1_STUDIO",
			"staging"
		)
		eq(Environment.resolve(true, 42, PROD, STAGING).DataStoreName, "StormSalvage_v1_STUDIO", "unknown")
		eq(Environment.resolve(true, 0, PROD, STAGING).DataStoreName, "StormSalvage_v1_STUDIO", "unpublished")
	end,
	["env: listed live place uses the real store"] = function()
		local r = Environment.resolve(false, 99653875913460, PROD, STAGING)
		eq(r.Name, "Production", "name")
		eq(r.DataStoreName, "StormSalvage_v1", "store")
	end,
	["env: listed staging place uses _STAGING"] = function()
		local r = Environment.resolve(false, 1234567890, PROD, STAGING)
		eq(r.Name, "Staging", "name")
		eq(r.DataStoreName, "StormSalvage_v1_STAGING", "store")
	end,
	["env: unlisted place fails closed (no store)"] = function()
		local r = Environment.resolve(false, 555, PROD, STAGING)
		eq(r.Name, "Unknown", "name")
		eq(r.DataStoreName, nil, "store")
	end,
	["env: no staging configured yet -> other places fail closed"] = function()
		eq(Environment.resolve(false, 1234567890, PROD, {}).DataStoreName, nil, "store")
	end,
	["env: place in both lists fails closed"] = function()
		local r = Environment.resolve(false, 7, { 7 }, { 7 })
		eq(r.Name, "Unknown", "name")
		eq(r.DataStoreName, nil, "store")
	end,
	["env: missing or invalid place id fails closed"] = function()
		eq(Environment.resolve(false, 0, PROD, STAGING).DataStoreName, nil, "zero")
		eq(Environment.resolve(false, -1, PROD, STAGING).DataStoreName, nil, "negative")
		eq(Environment.resolve(false, 1.5, PROD, STAGING).DataStoreName, nil, "fraction")
	end,
	["live test: live place uses _LIVETEST, never the real store"] = function()
		local r = Environment.resolve(false, 99653875913460, PROD, {}, true)
		eq(r.Name, "Production", "name")
		eq(r.DataStoreName, "StormSalvage_v1_LIVETEST", "store")
		eq(r.LiveTest, true, "flag")
	end,
	["live test off: live place uses the real store"] = function()
		local r = Environment.resolve(false, 99653875913460, PROD, {}, false)
		eq(r.DataStoreName, "StormSalvage_v1", "store")
		eq(r.LiveTest, false, "flag")
	end,
	["live test: Studio still _STUDIO; unknown places still fail closed"] = function()
		eq(
			Environment.resolve(true, 99653875913460, PROD, {}, true).DataStoreName,
			"StormSalvage_v1_STUDIO",
			"studio"
		)
		eq(Environment.resolve(false, 555, PROD, {}, true).DataStoreName, nil, "unknown")
	end,
}

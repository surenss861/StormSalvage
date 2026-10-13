--!strict
-- Which data environment a server is in, as a pure function so it can be unit-tested
-- (tests/environment.spec.luau) without Roblox. Config calls it once at startup.
--
--   Studio      every Studio session, whatever the place id: "_STUDIO" DataStores, so tests and
--               fault injection never touch real profiles.
--   Production  a listed live place: the real DataStores.
--   Staging     a listed private test place: "_STAGING" DataStores.
--   Unknown     anything else, and any place listed as both production and staging (a
--               configuration mistake): no DataStores at all. Fails closed.

local Environment = {}

export type Result = {
	Name: "Studio" | "Production" | "Staging" | "Unknown",
	DataStoreName: string?,
	Reason: string,
}

Environment.BASE = "StormSalvage_v1"

local function listed(ids: { number }, placeId: number): boolean
	for _, id in ids do
		if id == placeId then
			return true
		end
	end
	return false
end

function Environment.resolve(
	isStudio: boolean,
	placeId: number,
	production: { number },
	staging: { number }
): Result
	if isStudio then
		return { Name = "Studio", DataStoreName = Environment.BASE .. "_STUDIO", Reason = "studio" }
	end
	if type(placeId) ~= "number" or placeId <= 0 or placeId % 1 ~= 0 then
		return { Name = "Unknown", DataStoreName = nil, Reason = "no place id" }
	end
	local isProduction = listed(production, placeId)
	local isStaging = listed(staging, placeId)
	if isProduction and isStaging then
		return { Name = "Unknown", DataStoreName = nil, Reason = "place listed as production and staging" }
	elseif isProduction then
		return { Name = "Production", DataStoreName = Environment.BASE, Reason = "listed production place" }
	elseif isStaging then
		return {
			Name = "Staging",
			DataStoreName = Environment.BASE .. "_STAGING",
			Reason = "listed staging place",
		}
	end
	return { Name = "Unknown", DataStoreName = nil, Reason = "unlisted place" }
end

return Environment

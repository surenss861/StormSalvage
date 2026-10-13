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
--
-- Live-test mode (no separate staging experience): with `liveTest` on, the listed live place
-- uses "_LIVETEST" DataStores instead of the real ones, so pre-launch testing in the private
-- live experience never opens, reads or writes real player saves. Name stays "Production"
-- (it is the live place) and `LiveTest` is true. Release tags fail CI while it's on.

local Environment = {}

export type Result = {
	Name: "Studio" | "Production" | "Staging" | "Unknown",
	DataStoreName: string?,
	Reason: string,
	LiveTest: boolean,
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
	staging: { number },
	liveTest: boolean?
): Result
	if isStudio then
		return {
			Name = "Studio",
			DataStoreName = Environment.BASE .. "_STUDIO",
			Reason = "studio",
			LiveTest = false,
		}
	end
	if type(placeId) ~= "number" or placeId <= 0 or placeId % 1 ~= 0 then
		return { Name = "Unknown", DataStoreName = nil, Reason = "no place id", LiveTest = false }
	end
	local isProduction = listed(production, placeId)
	local isStaging = listed(staging, placeId)
	if isProduction and isStaging then
		return {
			Name = "Unknown",
			DataStoreName = nil,
			Reason = "place listed as production and staging",
			LiveTest = false,
		}
	elseif isProduction and liveTest == true then
		return {
			Name = "Production",
			DataStoreName = Environment.BASE .. "_LIVETEST",
			Reason = "listed production place, LIVE TEST namespace (real saves untouched)",
			LiveTest = true,
		}
	elseif isProduction then
		return {
			Name = "Production",
			DataStoreName = Environment.BASE,
			Reason = "listed production place",
			LiveTest = false,
		}
	elseif isStaging then
		return {
			Name = "Staging",
			DataStoreName = Environment.BASE .. "_STAGING",
			Reason = "listed staging place",
			LiveTest = false,
		}
	end
	return { Name = "Unknown", DataStoreName = nil, Reason = "unlisted place", LiveTest = false }
end

return Environment

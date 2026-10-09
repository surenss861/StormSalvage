-- "Is this position under a roof?" Used by the server (lightning/debris damage)
-- and the client (wind push) so both agree on what counts as shelter.

local Shelter = {}

local params: RaycastParams? = nil

local function getParams(): RaycastParams?
	if params then
		return params
	end
	local map = workspace:FindFirstChild("Map")
	local roofs = map and map:FindFirstChild("Roofs")
	if not roofs then
		return nil
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = { roofs }
	params = p
	return p
end

function Shelter.isSheltered(position: Vector3): boolean
	local p = getParams()
	if not p then
		return false
	end
	return workspace:Raycast(position, Vector3.new(0, 60, 0), p) ~= nil
end

return Shelter

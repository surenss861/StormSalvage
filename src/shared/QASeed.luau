--!strict
-- @file Deterministic RNG for Studio QA runs
-- @domain qa
-- @status stable
-- Random number generators for gameplay. Normally unseeded. In Studio only, the ReplicatedStorage
-- attribute QA_Seed (set in Edit mode before Play) makes every run with the same seed produce the
-- same loot spawns, storm order, strike spots and contract deals, so economy comparisons (free vs
-- Heavy-Duty) get identical opportunities (docs/production/V3-PROGRESSION.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local QASeed = {}

function QASeed.random(stream: number): Random
	local seed = if RunService:IsStudio() then ReplicatedStorage:GetAttribute("QA_Seed") else nil
	if type(seed) == "number" then
		return Random.new(seed * 1000 + stream)
	end
	return Random.new()
end

return QASeed

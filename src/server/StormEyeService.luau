-- @file The Storm's Eye: band 3's signature event
-- @domain world
-- @status wip
-- @see [[Bands.luau]]
-- @see [[StormEyeHud.luau]]
-- While a storm rages, a pocket of calm drifts across Gale Hollow. Inside it there's no wind,
-- debris or lightning (a flood's water stays: the Eye can't hold back the sea). A Storm Heart
-- forms at the Eye's centre and stays where it formed, so the Eye drifts on and leaves it in the
-- open storm: grab it while you're still sheltered, or go out after it. Only Storm Hunter licence
-- holders can take the Heart (LootService's licence gate); everyone can shelter in the Eye.
-- It appears when at least one player in the server is in band 3 or higher, once per storm.
-- Server-authoritative: the Eye's position is the server's; the client only draws it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bands = require(ReplicatedStorage.Shared.Bands)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LootService = require(script.Parent.LootService)
local PlayerService = require(script.Parent.PlayerService)
local SessionStats = require(script.Parent.SessionStats)
local StormService = require(script.Parent.StormService)

local StormEyeService = {}

local E = Bands.Eye
local remote: RemoteEvent
type Eye = { Center: Vector3, Radius: number, Token: number, Heart: Vector3?, HeartTaken: boolean }
local current: Eye? = nil
local token = 0

local function broadcast()
	local eye = current
	if not eye then
		remote:FireAllClients({ Active = false })
		return
	end
	remote:FireAllClients({
		Active = true,
		Center = eye.Center,
		Radius = eye.Radius,
		Heart = if eye.HeartTaken then nil else eye.Heart,
		Speed = E.Speed,
	})
end

-- Is `pos` inside the Eye (horizontally)? StormService treats it as shelter.
function StormEyeService.protects(pos: Vector3): boolean
	local eye = current
	if not eye then
		return false
	end
	local d = (pos - eye.Center) * Vector3.new(1, 0, 1)
	return d.Magnitude <= eye.Radius
end

function StormEyeService.state(): { [string]: any }?
	local eye = current
	return if eye
		then { Center = eye.Center, Radius = eye.Radius, Heart = eye.Heart, HeartTaken = eye.HeartTaken }
		else nil
end

local function anyHunter(): boolean
	for _, player in Players:GetPlayers() do
		if PlayerService.bandOf(player) >= E.MinBand then
			return true
		end
	end
	return false
end

-- Runs one Eye for a storm of `duration` seconds. `force` skips the band check (Studio QA).
function StormEyeService.run(duration: number, force: boolean?)
	if current or (not force and not anyHunter()) then
		return
	end
	local start = LootService.randomExposedPoint()
	if not start then
		return
	end
	token += 1
	local my = token
	local eye: Eye = { Center = start, Radius = E.Radius, Token = my, HeartTaken = false }
	current = eye
	broadcast()
	PlayerService.notifyAll(
		"THE STORM'S EYE has opened: calm inside. A Storm Heart is forming!",
		Color3.fromRGB(200, 150, 255)
	)
	local endsAt = os.clock() + duration
	task.delay(E.FormSeconds, function()
		if current ~= eye then
			return
		end
		eye.Heart = eye.Center
		LootService.spawnSpecial(
			"StormHeart",
			eye.Center,
			math.max(5, endsAt - os.clock()) + Config.Cycle.Aftermath,
			function(player)
				eye.HeartTaken = true
				if player then
					PlayerService.notifyAll(
						("%s took the Storm Heart! Get it to the Scrap Buyer."):format(player.DisplayName),
						Color3.fromRGB(200, 150, 255)
					)
					SessionStats.event(player, "StormHeartTaken", 1)
				end
				if current == eye then
					broadcast()
				end
			end
		)
		broadcast()
	end)
	-- Drift: straight legs between open-ground points.
	local legs = {}
	for _ = 1, E.Legs do
		local p = LootService.randomExposedPoint()
		if p then
			table.insert(legs, p)
		end
	end
	local leg = 1
	local lastSend = 0
	while current == eye and os.clock() < endsAt and StormService.getState().Phase == "Storm" do
		local dt = task.wait(0.1)
		local target = legs[leg]
		if target then
			local flat = (target - eye.Center) * Vector3.new(1, 0, 1)
			local step = E.Speed * dt
			if flat.Magnitude <= step then
				eye.Center = Vector3.new(target.X, eye.Center.Y, target.Z)
				leg += 1
			else
				eye.Center += flat.Unit * step
			end
		end
		if os.clock() - lastSend > 0.25 then
			lastSend = os.clock()
			broadcast()
		end
	end
	if current == eye then
		current = nil
		broadcast()
	end
end

function StormEyeService.init()
	remote = Remotes.get("StormEye")
	StormService.addShelter(StormEyeService.protects)
	StormService.onPhase(function(phase, duration)
		if phase == "Storm" then
			task.delay(3, StormEyeService.run, duration - 3)
		end
	end)
end

return StormEyeService

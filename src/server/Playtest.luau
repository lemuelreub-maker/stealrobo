--!strict
-- Logs what the playtest plan in the design doc measures: run times, catches
-- per layer, the closest the Warden got, and Tag Net hit rate. Everything is
-- printed to the Output window with a [Playtest] prefix. Type /stats in chat
-- for a summary.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Playtest = {}

type LayerStats = {
	Attempts: number,
	Caught: number,
	Escaped: number,
	EscapeTimeTotal: number,
	ClosestTotal: number,
}

local layers: { LayerStats } = {}
for i = 1, #Config.Layers do
	layers[i] = { Attempts = 0, Caught = 0, Escaped = 0, EscapeTimeTotal = 0, ClosestTotal = 0 }
end

local runTimes: { number } = {}
local netsFired = 0
local netsHit = 0

local function log(text: string)
	print("[Playtest] " .. text)
end

function Playtest.HeistStarted(player: Player, robotName: string, layer: number)
	layers[layer].Attempts += 1
	log(("%s unplugged %s in layer %d"):format(player.Name, robotName, layer))
end

function Playtest.Escaped(player: Player, layer: number, seconds: number, closest: number)
	local s = layers[layer]
	s.Escaped += 1
	s.EscapeTimeTotal += seconds
	s.ClosestTotal += closest
	log(("%s escaped layer %d in %.1f s; closest the Warden got: %.0f studs"):format(player.Name, layer, seconds, closest))
end

function Playtest.Caught(player: Player?, layer: number)
	layers[layer].Caught += 1
	log(("%s was caught by the layer %d Warden"):format(if player then player.Name else "(dropped robot)", layer))
end

function Playtest.Secured(player: Player, robotName: string, seconds: number)
	table.insert(runTimes, seconds)
	log(("%s secured %s, total run %.1f s"):format(player.Name, robotName, seconds))
end

function Playtest.Returned(robotName: string, reason: string)
	log(("%s went back to its dock (%s)"):format(robotName, reason))
end

function Playtest.NetFired(shooter: Player)
	netsFired += 1
	log(shooter.Name .. " fired a Tag Net")
end

function Playtest.NetHit(shooter: Player, victim: Player)
	netsHit += 1
	log(("%s netted %s"):format(shooter.Name, victim.Name))
end

local function median(list: { number }): number
	if #list == 0 then
		return 0
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.ceil(#sorted / 2)]
end

local function quartile(list: { number }): number
	if #list == 0 then
		return 0
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.max(1, math.ceil(#sorted / 4))]
end

function Playtest.Summary()
	log("===== Summary =====")
	for i, s in layers do
		local caughtPct = if s.Attempts > 0 then s.Caught / s.Attempts * 100 else 0
		local avgEscape = if s.Escaped > 0 then s.EscapeTimeTotal / s.Escaped else 0
		local avgClosest = if s.Escaped > 0 then s.ClosestTotal / s.Escaped else 0
		log(("Layer %d %-20s attempts %3d  caught %5.1f%%  avg escape %5.1f s  avg closest %4.0f studs"):format(i, Config.Layers[i].Name, s.Attempts, caughtPct, avgEscape, avgClosest))
	end
	local med = median(runTimes)
	local top = quartile(runTimes)
	log(("Secured runs %d  median %.1f s  top quartile %.1f s  (%.0f%% of median; target 60%% or less)"):format(#runTimes, med, top, if med > 0 then top / med * 100 else 0))
	local hitRate = if netsFired > 0 then netsHit / netsFired * 100 else 0
	log(("Tag Nets fired %d  hit %d  hit rate %.0f%% (target 25-45%%)"):format(netsFired, netsHit, hitRate))
end

function Playtest.Init()
	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			if message:lower() == "/stats" then
				Playtest.Summary()
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	game:BindToClose(Playtest.Summary)
end

return Playtest

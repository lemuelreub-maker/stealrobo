--!strict
-- Steal a Bot: greybox prototype (playtest round 1).
-- Builds the map, then starts the rules. See README.md for how to test.

local RunService = game:GetService("RunService")

local Map = require(script.Map)
local Plots = require(script.Plots)
local Wardens = require(script.Wardens)
local Hazards = require(script.Hazards)
local NetService = require(script.NetService)
local RobotService = require(script.RobotService)
local Playtest = require(script.Playtest)

Map.Build()
Plots.Init()
Wardens.Init()
Playtest.Init()

NetService.Init({
	IsCarrying = RobotService.IsCarrying,
	NetDrop = RobotService.NetDrop,
})
RobotService.Init({
	OnHaulTaken = NetService.RecordTake,
})

RunService.Heartbeat:Connect(function(dt)
	Wardens.Step(dt)
	Hazards.Step()
	NetService.Step(dt)
end)

print("[StealABot] Greybox ready. Type /stats in chat for playtest numbers.")

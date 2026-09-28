--!strict
-- Steal a Bot client: controls, HUD and robot behaviours.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controls = require(script.Controls)
local Effects = require(script.Effects)
local Hud = require(script.Hud)
local Treadmill = require(script.Treadmill)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = remotes:WaitForChild("Notify") :: RemoteEvent
local NetIncoming = remotes:WaitForChild("NetIncoming") :: RemoteEvent

Controls.Init()
Effects.Init()
Hud.Init()
Treadmill.Init()

Notify.OnClientEvent:Connect(function(text: string, tone: string?)
	Hud.Toast(text, tone)
end)

NetIncoming.OnClientEvent:Connect(function(from: Vector3, shooterName: string)
	Hud.NetWarning(from, shooterName)
end)

--!strict
-- Runs the moving hazards: the Assembly Hall sweep light and the Press Floor
-- presses. Treadmills are handled on each player's own client (Treadmill.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)
local Remotes = require(script.Parent.Remotes)

local Hazards = {}

local H = Config.Hazards
local O = Config.Origin
local HALF_TRACK = Config.TrackWidth / 2

local IDLE = Color3.fromRGB(60, 60, 65)
local WARN = Color3.fromRGB(255, 255, 255)

local lastSlam: { [number]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Triangle wave: the beam slides from one wall to the other and back.
local function sweepX(t: number): number
	local sweep = Map.Sweep
	if not sweep then
		return 0
	end
	local phase = (t % H.SweepPeriod) / H.SweepPeriod
	local tri = if phase < 0.5 then phase * 4 - 1 else 3 - phase * 4
	return O.X + tri * sweep.Travel
end

function Hazards.InSweepLight(position: Vector3): boolean
	local sweep = Map.Sweep
	if not sweep then
		return false
	end
	return position.Z >= sweep.MinZ
		and position.Z <= sweep.MaxZ
		and math.abs(position.X - sweepX(now())) <= H.SweepWidth / 2
		and position.Y - Map.FloorY < 15
end

local function pushPlayers(row: Map.PressRow)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			local p = root.Position
			if p.Z >= row.MinZ and p.Z <= row.MaxZ and math.abs(p.X - O.X) <= HALF_TRACK and p.Y - Map.FloorY < 10 then
				character:PivotTo(character:GetPivot() + Vector3.new(0, 0, H.PressPush))
				Remotes.Tell(player, "Press! Pushed back " .. H.PressPush .. " studs", "bad")
			end
		end
	end
end

function Hazards.Step()
	local t = now()

	local sweep = Map.Sweep
	if sweep then
		local beam = sweep.Beam
		beam.Position = Vector3.new(sweepX(t), beam.Position.Y, beam.Position.Z)
	end

	for i, row in Map.PressRows do
		local local_t = t - row.Offset
		local cycle = math.floor(local_t / H.PressBeat)
		local phase = local_t - cycle * H.PressBeat
		local down = phase < H.PressDownTime
		local warning = phase >= H.PressBeat - H.PressWarning
		row.Head.Position = Vector3.new(row.Head.Position.X, if down then row.DownY else row.UpY, row.Head.Position.Z)
		row.Warning.Color = if warning or down then WARN else IDLE
		row.Warning.Material = if warning or down then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if lastSlam[i] ~= cycle then
			lastSlam[i] = cycle
			pushPlayers(row)
		end
	end
end

return Hazards

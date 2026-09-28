--!strict
-- The Warden wakes when a robot is unplugged, boots for 2.5 s, then follows
-- the robot's exact path at the speed of whatever layer it is in. It stops
-- dead at the safe line. If it gets within 3.5 studs, the robot goes home.
-- One Warden is spawned per heist so several players can run the same layer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)

export type Warden = {
	Model: Model,
	Beacon: BasePart,
	Visor: BasePart,
	Pos: Vector3,
	Facing: Vector3,
	Trail: { Vector3 },
	Cum: { number }, -- path length from the first crumb to crumb i
	Index: number,
	BootEndsAt: number,
	SurgeUntil: number,
	State: "Booting" | "Chasing" | "Held",
	PathDistance: number,
	Target: BasePart,
	OnCatch: () -> (),
}

local Wardens = {}

local W = Config.Warden
local HOVER = Vector3.new(0, W.HoverHeight, 0)
local RED = Color3.fromRGB(255, 40, 40)
local SURGE = Color3.fromRGB(255, 140, 0)

local active: { [Warden]: boolean } = {}
local folder: Folder

local function now(): number
	return workspace:GetServerTimeNow()
end

local function buildModel(layer: number): (Model, BasePart, BasePart)
	local model = Instance.new("Model")
	model.Name = "Warden"
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = offset
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local body = part("Body", Vector3.new(4, 4, 4), CFrame.new(), Color3.fromRGB(45, 45, 52), Enum.Material.Metal, Enum.PartType.Ball)
	local visor = part("Visor", Vector3.new(3, 0.8, 0.6), CFrame.new(0, 0.4, -1.75), RED, Enum.Material.Neon)
	part("Trim", Vector3.new(0.5, 4.4, 4.4), CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Config.Layers[layer].ArchColor, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local beacon = part("Beacon", Vector3.new(1, 1, 1.4), CFrame.new(0, 2.3, 0), RED, Enum.Material.Neon)
	model.PrimaryPart = body
	return model, beacon, visor
end

function Wardens.Init()
	folder = Instance.new("Folder")
	folder.Name = "StealABotWardens"
	folder.Parent = workspace
end

-- target is the robot's body; the Warden chases the robot, not a player, so
-- drops and interceptions need no special handling.
function Wardens.Spawn(target: BasePart, layer: number, headStart: number, onCatch: () -> ()): Warden
	local model, beacon, visor = buildModel(layer)
	local start = target.Position + HOVER + Vector3.new(0, 2, 0)
	model:PivotTo(CFrame.new(start))
	model.Parent = folder
	local w: Warden = {
		Model = model,
		Beacon = beacon,
		Visor = visor,
		Pos = start,
		Facing = Vector3.new(0, 0, -1),
		Trail = {},
		Cum = {},
		Index = 1,
		BootEndsAt = now() + headStart,
		SurgeUntil = 0,
		State = "Booting",
		PathDistance = 0,
		Target = target,
		OnCatch = onCatch,
	}
	active[w] = true
	return w
end

function Wardens.Remove(w: Warden)
	active[w] = nil
	w.Model:Destroy()
end

function Wardens.Surge(w: Warden)
	w.SurgeUntil = now() + W.SurgeTime
end

local function record(w: Warden, pos: Vector3)
	local n = #w.Trail
	if n == 0 then
		w.Trail[1] = pos
		w.Cum[1] = 0
	elseif (pos - w.Trail[n]).Magnitude >= 1 then
		w.Trail[n + 1] = pos
		w.Cum[n + 1] = w.Cum[n] + (pos - w.Trail[n]).Magnitude
	end
end

local function factoryCrumbAfter(w: Warden, index: number): boolean
	for i = index + 1, #w.Trail do
		if w.Trail[i].Z >= Map.SafeLineZ then
			return true
		end
	end
	return false
end

-- The next point on the robot's path that lies inside the factory, or nil if
-- the path currently ends in the safe zone.
local function nextTarget(w: Warden, robotPos: Vector3): Vector3?
	local robotInFactory = robotPos.Z >= Map.SafeLineZ
	while w.Index <= #w.Trail do
		local crumb = w.Trail[w.Index]
		if crumb.Z >= Map.SafeLineZ then
			return crumb
		end
		if robotInFactory or factoryCrumbAfter(w, w.Index) then
			w.Index += 1
		else
			return nil
		end
	end
	return if robotInFactory then robotPos else nil
end

local function speedAt(w: Warden, pos: Vector3, t: number): number
	local layer = Map.LayerIndexAt(pos)
	if layer == 0 then
		return 0
	end
	local speed = Config.Layers[layer].WardenSpeed
	if t < w.SurgeUntil then
		speed += W.SurgeSpeed
	end
	return speed
end

local function pathDistance(w: Warden, robotPos: Vector3): number
	local n = #w.Trail
	local here = w.Pos - HOVER
	if w.Index > n then
		return (here - robotPos).Magnitude
	end
	return (here - w.Trail[w.Index]).Magnitude + (w.Cum[n] - w.Cum[w.Index]) + (w.Trail[n] - robotPos).Magnitude
end

local function step(w: Warden, dt: number, t: number)
	local robotPos = w.Target.Position
	record(w, robotPos)

	if t < w.BootEndsAt then
		w.State = "Booting"
		w.Model:PivotTo(CFrame.new(w.Pos) * CFrame.Angles(0, t * 8, 0))
		w.PathDistance = pathDistance(w, robotPos)
		return
	end

	local budget = speedAt(w, w.Pos, t) * dt
	local held = false
	local guard = 0
	while budget > 1e-3 and guard < 64 do
		guard += 1
		local target = nextTarget(w, robotPos)
		if not target then
			held = true
			break
		end
		local goal = target + HOVER
		local delta = goal - w.Pos
		local d = delta.Magnitude
		if d <= budget then
			w.Pos = goal
			budget -= d
			if w.Index <= #w.Trail then
				w.Index += 1
			else
				break -- reached the robot itself
			end
		else
			w.Pos += delta.Unit * budget
			budget = 0
		end
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat.Magnitude > 0.05 then
			w.Facing = flat.Unit
		end
	end

	w.State = if held then "Held" else "Chasing"
	w.Beacon.Color = if t < w.SurgeUntil then SURGE else RED
	w.Model:PivotTo(CFrame.lookAt(w.Pos, w.Pos + w.Facing))
	w.PathDistance = pathDistance(w, robotPos)

	-- Nothing is ever caught inside the safe zone.
	if robotPos.Z >= Map.SafeLineZ and ((w.Pos - HOVER) - robotPos).Magnitude <= W.CatchDistance then
		w.OnCatch()
	end
end

function Wardens.Step(dt: number)
	local t = now()
	for w in active do
		step(w, dt, t)
	end
end

return Wardens

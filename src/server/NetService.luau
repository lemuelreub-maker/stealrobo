--!strict
-- The Tag Net: the only way to take a robot from another player, and only
-- while they carry it out of the factory. A visible, dodgeable projectile
-- with no stun and no damage. A netted carrier drops the robot and keeps
-- moving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)
local Remotes = require(script.Parent.Remotes)
local Playtest = require(script.Parent.Playtest)

local N = Config.Net

type Net = {
	Shooter: Player,
	Part: BasePart,
	Origin: Vector3,
	Direction: Vector3,
	Travelled: number,
	LastPos: Vector3,
	Warned: { [Player]: boolean },
}

export type Deps = {
	IsCarrying: (Player) -> boolean,
	NetDrop: (victim: Player, shooter: Player) -> (),
}

local NetService = {}

local deps: Deps
local nets: { Net } = {}
local folder: Folder
local takes: { [Player]: { [Player]: number } } = {}
local losses: { [Player]: { number } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

-- Why a net can't lock on to this carrier right now, or nil if it can.
local function protection(shooter: Player, victim: Player): string?
	local t = now()
	if (tonumber(victim:GetAttribute("NetImmuneUntil")) or 0) > t then
		return "they were just netted"
	end
	local lastTake = takes[shooter] and takes[shooter][victim]
	if lastTake and t - lastTake < N.PairCooldown then
		return "you already took a haul from them recently"
	end
	local recent = 0
	local list = losses[victim]
	if list then
		for _, at in list do
			if t - at < 3600 then
				recent += 1
			end
		end
	end
	if recent >= N.HourlyLossCap then
		return "they have lost enough hauls this hour"
	end
	return nil
end

-- Called when a carrier secures a robot that was netted from someone else.
function NetService.RecordTake(taker: Player, victim: Player)
	takes[taker] = takes[taker] or {}
	takes[taker][victim] = now()
	losses[victim] = losses[victim] or {}
	table.insert(losses[victim], now())
end

local function makeNetPart(origin: Vector3): BasePart
	local p = Instance.new("Part")
	p.Name = "TagNet"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.6, 1.6, 1.6)
	p.Color = Color3.fromRGB(120, 230, 255)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Position = origin
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.5, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.5, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.Color = ColorSequence.new(p.Color)
	trail.LightEmission = 1
	trail.Parent = p
	p.Parent = folder
	return p
end

local function onFire(shooter: Player, aim: unknown)
	if typeof(aim) ~= "Vector3" then
		return
	end
	local direction = aim :: Vector3
	if direction.Magnitude < 0.1 or direction.Magnitude ~= direction.Magnitude then
		return
	end
	local root = rootOf(shooter)
	if not root then
		return
	end
	local t = now()
	if deps.IsCarrying(shooter) then
		return
	end
	if Map.ZoneAt(root.Position) == "Safe" then
		Remotes.Tell(shooter, "Tag Nets only work inside the factory")
		return
	end
	if (tonumber(shooter:GetAttribute("NetReadyAt")) or 0) > t + 0.1 then
		return
	end
	shooter:SetAttribute("NetReadyAt", t + N.Reload)

	direction = direction.Unit
	local origin = root.Position + Vector3.new(0, 1.5, 0) + direction * 2.5
	table.insert(nets, {
		Shooter = shooter,
		Part = makeNetPart(origin),
		Origin = origin,
		Direction = direction,
		Travelled = 0,
		LastPos = origin,
		Warned = {},
	})
	Playtest.NetFired(shooter)

	-- Warn carriers in range so a player who is watching can sidestep.
	for _, other in Players:GetPlayers() do
		local otherRoot = if other ~= shooter and deps.IsCarrying(other) then rootOf(other) else nil
		if otherRoot and (otherRoot.Position - root.Position).Magnitude <= N.WarnRange then
			Remotes.NetIncoming:FireClient(other, root.Position, shooter.DisplayName)
		end
	end
end

local function closestOnSegment(a: Vector3, b: Vector3, p: Vector3): Vector3
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 1e-6 then
		return a
	end
	local s = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	return a + ab * s
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.RespectCanCollide = true

-- Returns true when the net is used up.
local function stepNet(net: Net, dt: number): boolean
	local travelled = math.min(net.Travelled + N.Speed * dt, N.Range)
	local s = travelled / N.Range
	local arc = Vector3.new(0, 4 * N.ArcHeight * s * (1 - s), 0)
	local pos = net.Origin + net.Direction * travelled + arc

	if Map.Folder then
		rayParams.FilterDescendantsInstances = { Map.Folder }
		if workspace:Raycast(net.LastPos, pos - net.LastPos, rayParams) then
			return true -- hit a wall
		end
	end

	for _, victim in Players:GetPlayers() do
		if victim ~= net.Shooter and deps.IsCarrying(victim) and not net.Warned[victim] then
			local root = rootOf(victim)
			if root and (closestOnSegment(net.LastPos, pos, root.Position) - root.Position).Magnitude <= N.HitRadius then
				if Map.ZoneAt(root.Position) ~= "Safe" then
					local reason = protection(net.Shooter, victim)
					if reason then
						-- The net passes through; tell the shooter once.
						net.Warned[victim] = true
						Remotes.Tell(net.Shooter, ("Your net can't lock on to %s: %s"):format(victim.DisplayName, reason))
					else
						victim:SetAttribute("NetImmuneUntil", now() + N.ImmunityTime)
						deps.NetDrop(victim, net.Shooter)
						Playtest.NetHit(net.Shooter, victim)
						Remotes.Tell(net.Shooter, ("You netted %s! Grab the robot"):format(victim.DisplayName), "good")
						Remotes.Tell(victim, ("Netted by %s! Grab it back within %d s"):format(net.Shooter.DisplayName, Config.DropClaimTime), "bad")
						return true
					end
				end
			end
		end
	end

	net.Part.Position = pos
	net.LastPos = pos
	net.Travelled = travelled
	return travelled >= N.Range
end

function NetService.Step(dt: number)
	for i = #nets, 1, -1 do
		local net = nets[i]
		if stepNet(net, dt) then
			net.Part:Destroy()
			table.remove(nets, i)
		end
	end
end

function NetService.Init(d: Deps)
	deps = d
	folder = Instance.new("Folder")
	folder.Name = "StealABotNets"
	folder.Parent = workspace
	Remotes.FireNet.OnServerEvent:Connect(onFire)
	Players.PlayerRemoving:Connect(function(player)
		takes[player] = nil
		losses[player] = nil
		for _, byVictim in takes do
			byVictim[player] = nil
		end
	end)
end

return NetService

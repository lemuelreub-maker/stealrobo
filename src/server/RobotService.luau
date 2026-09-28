--!strict
-- Unplug, carry, drop, secure and return. The server owns every rule.
-- Ownership changes at exactly one moment: when a carrier brings a robot
-- across their own loading-bay line.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RobotDefs = require(ReplicatedStorage.Shared.RobotDefs)
local Map = require(script.Parent.Map)
local Plots = require(script.Parent.Plots)
local Remotes = require(script.Parent.Remotes)
local RobotModels = require(script.Parent.RobotModels)
local Wardens = require(script.Parent.Wardens)
local Hazards = require(script.Parent.Hazards)
local Playtest = require(script.Parent.Playtest)

type RobotDef = RobotDefs.RobotDef

type Robot = {
	Id: string,
	Def: RobotDef,
	Model: Model,
	Body: BasePart,
	Prompt: ProximityPrompt,
	Card: BillboardGui,
	Dock: Map.Dock,
	State: "Docked" | "Carried" | "Dropped" | "Secured",
	Carrier: Player?,
	Weld: WeldConstraint?,
	Claimant: Player?,
	ClaimUntil: number,
	DropExpiresAt: number,
	NettedFrom: Player?,
	Warden: Wardens.Warden?,
	HeistStart: number,
	CarryEndsAt: number,
	BatteryWarned: boolean,
	EscapedAt: number?,
	Closest: number,
	Spotted: number,
}

export type Deps = {
	OnHaulTaken: (taker: Player, victim: Player) -> (),
}

local RobotService = {}

local M = Config.Movement
local TICK = 0.1

local deps: Deps
local robots: { [Robot]: boolean } = {}
local carriedBy: { [Player]: Robot } = {}
local sprinting: { [Player]: boolean } = {}
local secured: { [Player]: { Model } } = {}
local robotFolder: Folder
local nextId = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function characterParts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function applyMovement(player: Player)
	local _, humanoid = characterParts(player)
	if not humanoid then
		return
	end
	local carrying = carriedBy[player] ~= nil
	local sprint = sprinting[player] == true
	if carrying then
		humanoid.WalkSpeed = if sprint then M.CarrySprint else M.CarryWalk
	else
		humanoid.WalkSpeed = if sprint then M.Sprint else M.Walk
	end
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = if carrying then M.JumpHeight * M.CarryJumpScale else M.JumpHeight
end

local CARRY_ATTRIBUTES = { "Carrying", "Behaviour", "RhythmStart", "RhythmPeriod", "BounceHeight", "CarryEndsAt", "WardenState", "WardenBootEndsAt", "WardenDistance", "Spotted" }

local function clearCarryAttributes(player: Player)
	for _, name in CARRY_ATTRIBUTES do
		player:SetAttribute(name, nil)
	end
end

---------------------------------------------------------------------------
-- Info card and prompt

local function makeCard(def: RobotDef, parent: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "InfoCard"
	gui.Size = UDim2.fromOffset(260, 118)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.MaxDistance = Config.InfoCardDistance
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = def.Accent
	stroke.Thickness = 2
	stroke.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 6)
	pad.Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.Parent = frame

	local padNames = { S = "Small", M = "Medium", L = "Large" }
	local lines: { { Text: string, Size: number, Font: Enum.Font, Color: Color3 } } = {
		{ Text = ("%s · Tier %d"):format(def.Name, def.Tier), Size = 20, Font = Enum.Font.GothamBlack, Color = def.Accent },
		{ Text = "Job: " .. def.Job, Size = 14, Font = Enum.Font.Gotham, Color = Color3.new(1, 1, 1) },
		{ Text = ("%s · %s"):format(def.Transport, def.BehaviourText), Size = 14, Font = Enum.Font.Gotham, Color = Color3.new(1, 1, 1) },
		{ Text = ("Base value %d C · Needs a %s pad"):format(def.BaseValue, padNames[def.Pad]), Size = 14, Font = Enum.Font.GothamBold, Color = Color3.fromRGB(255, 220, 120) },
	}
	for i, line in lines do
		local t = Instance.new("TextLabel")
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, if i == 3 then 34 else line.Size + 6)
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = line.Text
		t.TextSize = line.Size
		t.Font = line.Font
		t.TextColor3 = line.Color
		t.Parent = frame
	end
	return gui
end

local function setPrompt(robot: Robot, mode: "Unplug" | "PickUp" | "Off")
	local prompt = robot.Prompt
	if mode == "Off" then
		prompt.Enabled = false
		robot.Card.Enabled = false
		return
	end
	prompt.Enabled = true
	robot.Card.Enabled = true
	if mode == "Unplug" then
		prompt.ActionText = "Unplug"
		prompt.HoldDuration = Config.UnplugTime[robot.Def.Tier]
	else
		prompt.ActionText = "Pick up"
		prompt.HoldDuration = Config.RegrabHoldTime
	end
end

---------------------------------------------------------------------------
-- Moving robots around

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.RespectCanCollide = true

local function detach(robot: Robot)
	if robot.Weld then
		robot.Weld:Destroy()
		robot.Weld = nil
	end
	robot.Body.Anchored = true
end

local function attach(robot: Robot, root: BasePart)
	detach(robot)
	robot.Model:PivotTo(root.CFrame * CFrame.new(0, -1.3, 1.3))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = robot.Body
	weld.Parent = robot.Body
	robot.Weld = weld
	robot.Body.Anchored = false
end

-- Sets the robot down on the floor below it. Returns false if there is no floor.
local function placeOnGround(robot: Robot): boolean
	local from = robot.Body.Position + Vector3.new(0, 2, 0)
	local mapFolder = Map.Folder
	if not mapFolder then
		return false
	end
	groundParams.FilterDescendantsInstances = { mapFolder }
	local hit = workspace:Raycast(from, Vector3.new(0, -40, 0), groundParams)
	if not hit then
		return false
	end
	local _, yaw = robot.Body.CFrame:ToEulerAnglesYXZ()
	robot.Model:PivotTo(CFrame.new(hit.Position) * CFrame.Angles(0, yaw, 0))
	return true
end

local function endCarry(robot: Robot)
	local player = robot.Carrier
	robot.Carrier = nil
	if player then
		if carriedBy[player] == robot then
			carriedBy[player] = nil
		end
		clearCarryAttributes(player)
		applyMovement(player)
	end
end

local returnToDock: (Robot, string, string?) -> ()

local function startCarry(robot: Robot, player: Player, root: BasePart, fromDock: boolean)
	local t = now()
	if fromDock then
		robot.HeistStart = t
		robot.CarryEndsAt = t + Config.CarryTimeLimit
		robot.BatteryWarned = false
		robot.EscapedAt = nil
		robot.Closest = math.huge
		robot.Spotted = 0
		robot.NettedFrom = nil
		robot.Warden = Wardens.Spawn(robot.Body, robot.Dock.Layer, Config.Warden.BootTime, function()
			returnToDock(robot, "Caught", "The Warden caught you! The robot went back to its dock.")
		end)
		Playtest.HeistStarted(player, robot.Def.Name, robot.Dock.Layer)
	end

	robot.State = "Carried"
	robot.Carrier = player
	robot.Claimant = nil
	carriedBy[player] = robot
	attach(robot, root)
	setPrompt(robot, "Off")

	player:SetAttribute("Carrying", robot.Def.Name)
	player:SetAttribute("Behaviour", robot.Def.Behaviour)
	player:SetAttribute("RhythmStart", t)
	player:SetAttribute("RhythmPeriod", robot.Def.BouncePeriod)
	player:SetAttribute("BounceHeight", robot.Def.BounceHeight)
	player:SetAttribute("CarryEndsAt", robot.CarryEndsAt)
	if robot.Warden then
		player:SetAttribute("WardenBootEndsAt", robot.Warden.BootEndsAt)
	end
	applyMovement(player)
	Remotes.Tell(player, if fromDock then "Take it home!" else "Got it! Take it home!", "good")
end

function returnToDock(robot: Robot, reason: string, message: string?)
	local carrier = robot.Carrier
	if robot.State == "Carried" then
		endCarry(robot)
	end
	if reason == "Caught" then
		Playtest.Caught(carrier, robot.Dock.Layer)
	end
	detach(robot)
	if robot.Warden then
		Wardens.Remove(robot.Warden)
		robot.Warden = nil
	end
	robot.Model:PivotTo(robot.Dock.CFrame)
	robot.State = "Docked"
	robot.Claimant = nil
	robot.NettedFrom = nil
	setPrompt(robot, "Unplug")
	Playtest.Returned(robot.Def.Name, reason)
	if carrier and message then
		Remotes.Tell(carrier, message, "bad")
	end
end

local function drop(robot: Robot, netter: Player?)
	local player = robot.Carrier
	if not player then
		return
	end
	endCarry(robot)
	detach(robot)
	if not placeOnGround(robot) then
		returnToDock(robot, "NoFloor")
		return
	end
	local t = now()
	robot.State = "Dropped"
	robot.Claimant = player
	-- In the safe zone only the dropper can ever pick it back up.
	robot.ClaimUntil = if Map.ZoneAt(robot.Body.Position) == "Safe" then math.huge else t + Config.DropClaimTime
	robot.DropExpiresAt = t + Config.DropLifetime
	if netter then
		robot.NettedFrom = player
	end
	setPrompt(robot, "PickUp")
end

local function secure(robot: Robot, player: Player, plot: Map.Plot)
	local t = now()
	endCarry(robot)
	detach(robot)
	if robot.Warden then
		Wardens.Remove(robot.Warden)
		robot.Warden = nil
	end
	robot.State = "Secured"
	robots[robot] = nil
	robot.Prompt:Destroy()
	robot.Card:Destroy()
	robot.Model.Name = robot.Def.Name .. " (" .. player.Name .. ")"
	robot.Model:PivotTo(Plots.NextDisplay(plot))
	secured[player] = secured[player] or {}
	table.insert(secured[player], robot.Model)

	local dock = robot.Dock
	dock.Robot = nil
	dock.RespawnAt = t + Config.DockRespawnTime

	if robot.NettedFrom and robot.NettedFrom ~= player then
		deps.OnHaulTaken(player, robot.NettedFrom)
	end

	local runTime = t - robot.HeistStart
	local count = (tonumber(player:GetAttribute("SecuredCount")) or 0) + 1
	player:SetAttribute("SecuredCount", count)
	local best = player:GetAttribute("BestRun")
	if typeof(best) ~= "number" or runTime < best then
		player:SetAttribute("BestRun", runTime)
	end
	Playtest.Secured(player, robot.Def.Name, runTime)
	Remotes.Tell(player, ("Secured! %s is yours. Run time %.1f s"):format(robot.Def.Name, runTime), "good")
end

local function spawnAtDock(dock: Map.Dock)
	local def = RobotDefs[dock.RobotKey]
	local built = RobotModels.Build(def)
	nextId += 1
	local robot: Robot = {
		Id = ("%d-%s"):format(nextId, HttpService:GenerateGUID(false)),
		Def = def,
		Model = built.Model,
		Body = built.Body,
		Prompt = Instance.new("ProximityPrompt"),
		Card = makeCard(def, built.Body),
		Dock = dock,
		State = "Docked",
		Carrier = nil,
		Weld = nil,
		Claimant = nil,
		ClaimUntil = 0,
		DropExpiresAt = 0,
		NettedFrom = nil,
		Warden = nil,
		HeistStart = 0,
		CarryEndsAt = 0,
		BatteryWarned = false,
		EscapedAt = nil,
		Closest = math.huge,
		Spotted = 0,
	}
	robot.Model:SetAttribute("RobotId", robot.Id)
	local prompt = robot.Prompt
	prompt.ObjectText = def.Name
	prompt.MaxActivationDistance = Config.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = robot.Body
	setPrompt(robot, "Unplug")

	prompt.Triggered:Connect(function(player)
		local _, _, root = characterParts(player)
		if not root or carriedBy[player] then
			return
		end
		if (root.Position - robot.Body.Position).Magnitude > Config.InfoCardDistance then
			return
		end
		if robot.State == "Docked" then
			startCarry(robot, player, root, true)
		elseif robot.State == "Dropped" then
			local claimant = robot.Claimant
			if claimant and claimant ~= player and now() < robot.ClaimUntil then
				Remotes.Tell(player, ("Only %s can grab this for a moment"):format(claimant.DisplayName))
				return
			end
			if player == robot.NettedFrom then
				robot.NettedFrom = nil -- they got it back
			end
			startCarry(robot, player, root, false)
		end
	end)

	robot.Model:PivotTo(dock.CFrame)
	robot.Model.Parent = robotFolder
	dock.Robot = robot
	robots[robot] = true
end

---------------------------------------------------------------------------
-- The 10 Hz rules loop

local function tickCarried(robot: Robot, player: Player, t: number)
	local _, humanoid, root = characterParts(player)
	if not humanoid or not root then
		returnToDock(robot, "CarrierLost")
		return
	end
	local pos = robot.Body.Position
	if pos.Y < Map.FloorY - 30 then
		returnToDock(robot, "FellOff", "The robot fell and went back to the factory.")
		return
	end
	if t >= robot.CarryEndsAt then
		returnToDock(robot, "Battery", "The robot's battery ran out and it went back to the factory.")
		return
	end
	if not robot.BatteryWarned and robot.CarryEndsAt - t <= Config.CarryWarnAt then
		robot.BatteryWarned = true
		Remotes.Tell(player, ("Battery low! %d s to get it home"):format(Config.CarryWarnAt), "bad")
	end

	local warden = robot.Warden
	if warden then
		player:SetAttribute("WardenState", warden.State)
		player:SetAttribute("WardenDistance", math.floor(warden.PathDistance + 0.5))
		if warden.State == "Chasing" then
			robot.Closest = math.min(robot.Closest, warden.PathDistance)
		end
	end

	if not robot.EscapedAt and Map.LayerIndexAt(pos) == 0 then
		robot.EscapedAt = t
		local closest = if robot.Closest < math.huge then robot.Closest elseif warden then warden.PathDistance else 0
		Playtest.Escaped(player, robot.Dock.Layer, t - robot.HeistStart, closest)
	end

	-- Sweep light: 1.5 s in the beam makes the Warden surge.
	if Hazards.InSweepLight(root.Position) then
		robot.Spotted += TICK / Config.Warden.SpotTime
	else
		robot.Spotted = math.max(0, robot.Spotted - TICK / Config.Warden.SpotTime)
	end
	if robot.Spotted >= 1 then
		robot.Spotted = 0
		if warden then
			Wardens.Surge(warden)
		end
		Remotes.Tell(player, "Spotted! The Warden surges", "bad")
	end
	player:SetAttribute("Spotted", robot.Spotted)

	local plot = Plots.Of(player)
	if plot and Map.InPlot(plot, root.Position) then
		secure(robot, player, plot)
	end
end

local function tick()
	local t = now()
	for robot in robots do
		if robot.State == "Carried" then
			local carrier = robot.Carrier
			if carrier then
				tickCarried(robot, carrier, t)
			end
		elseif robot.State == "Dropped" then
			if t >= robot.DropExpiresAt then
				returnToDock(robot, "DropExpired")
			end
		end
	end
	for _, dock in Map.Docks do
		if not dock.Robot and t >= dock.RespawnAt then
			spawnAtDock(dock)
		end
	end
	for _, player in Players:GetPlayers() do
		local _, _, root = characterParts(player)
		if root then
			player:SetAttribute("Zone", Map.ZoneAt(root.Position))
		end
	end
end

---------------------------------------------------------------------------
-- Public API

function RobotService.IsCarrying(player: Player): boolean
	return carriedBy[player] ~= nil
end

function RobotService.NetDrop(victim: Player, netter: Player)
	local robot = carriedBy[victim]
	if robot then
		drop(robot, netter)
	end
end

local function onPlayerRemoving(player: Player)
	local robot = carriedBy[player]
	if robot then
		returnToDock(robot, "CarrierLeft")
	end
	-- A netted robot they dropped stays for anyone to grab until it times out.
	for r in robots do
		if r.Claimant == player then
			r.Claimant = nil
			r.ClaimUntil = 0
		end
		if r.NettedFrom == player then
			r.NettedFrom = nil
		end
	end
	local models = secured[player]
	if models then
		for _, model in models do
			model:Destroy()
		end
	end
	secured[player] = nil
	sprinting[player] = nil
end

function RobotService.Init(d: Deps)
	deps = d
	robotFolder = Instance.new("Folder")
	robotFolder.Name = "StealABotRobots"
	robotFolder.Parent = workspace

	Remotes.SetSprint.OnServerEvent:Connect(function(player, on)
		sprinting[player] = on == true
		applyMovement(player)
	end)
	Remotes.DropRobot.OnServerEvent:Connect(function(player)
		local robot = carriedBy[player]
		if robot then
			drop(robot, nil)
			Remotes.Tell(player, ("Dropped. It goes back to the factory in %d s"):format(Config.DropLifetime))
		end
	end)

	local function onCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			applyMovement(player)
			humanoid.Died:Connect(function()
				local robot = carriedBy[player]
				if robot then
					returnToDock(robot, "CarrierDied")
				end
			end)
		end
	end
	local function onPlayer(player: Player)
		player:SetAttribute("SecuredCount", 0)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	for _, dock in Map.Docks do
		spawnAtDock(dock)
	end

	task.spawn(function()
		while true do
			task.wait(TICK)
			tick()
		end
	end)
end

return RobotService

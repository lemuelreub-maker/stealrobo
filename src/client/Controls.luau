--!strict
-- One control scheme for PC, mobile and console. Interact (hold) is the
-- ProximityPrompt; this file adds Drop, Sprint and the Tag Net.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetSprint = remotes:WaitForChild("SetSprint") :: RemoteEvent
local DropRobot = remotes:WaitForChild("DropRobot") :: RemoteEvent
local FireNet = remotes:WaitForChild("FireNet") :: RemoteEvent

local Controls = {}

local sprinting = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function isCarrying(p: Player): boolean
	local c = p:GetAttribute("Carrying")
	return typeof(c) == "string" and c ~= ""
end

function Controls.CanNet(): (boolean, string)
	if isCarrying(player) then
		return false, "Can't net while carrying"
	end
	if player:GetAttribute("Zone") ~= "Amber" and player:GetAttribute("Zone") ~= "Red" then
		return false, "Tag Net: factory only"
	end
	local readyAt = player:GetAttribute("NetReadyAt")
	if typeof(readyAt) == "number" and readyAt > now() then
		return false, ("Tag Net: reloading %.1f s"):format(readyAt - now())
	end
	return true, "Tag Net: ready"
end

local function rootPart(p: Player): BasePart?
	local character = p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function aimDirection(from: Vector3, useMouse: boolean): Vector3
	local camera = workspace.CurrentCamera
	local dir = camera.CFrame.LookVector
	if useMouse then
		local m = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(m.X, m.Y)
		aimParams.FilterDescendantsInstances = { player.Character :: Instance }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, aimParams)
		local point = if hit then hit.Position else ray.Origin + ray.Direction * 300
		dir = point - from
	end
	dir = Vector3.new(dir.X, math.clamp(dir.Y, -0.3 * dir.Magnitude, 0.3 * dir.Magnitude), dir.Z)

	-- Auto-aim: snap to a carrier within a few degrees of where you aim.
	local best: Vector3? = nil
	local bestAngle = math.rad(Config.Net.AutoAimDegrees)
	for _, other in Players:GetPlayers() do
		local root = if other ~= player and isCarrying(other) then rootPart(other) else nil
		if root then
			local to = root.Position - from
			if to.Magnitude <= Config.Net.Range then
				local angle = math.acos(math.clamp(dir.Unit:Dot(to.Unit), -1, 1))
				if angle <= bestAngle then
					bestAngle = angle
					best = to
				end
			end
		end
	end
	return (best or dir).Unit
end

local function onSprint(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if state == Enum.UserInputState.Begin then
			sprinting = true
		elseif state == Enum.UserInputState.End then
			sprinting = false
		else
			return Enum.ContextActionResult.Pass
		end
	elseif state == Enum.UserInputState.Begin then
		sprinting = not sprinting -- L3 and the touch button toggle
	else
		return Enum.ContextActionResult.Pass
	end
	SetSprint:FireServer(sprinting)
	ContextActionService:SetTitle("Sprint", if sprinting then "Sprint ON" else "Sprint")
	return Enum.ContextActionResult.Sink
end

local function onDrop(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and isCarrying(player) then
		DropRobot:FireServer()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function onNet(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local ok = Controls.CanNet()
	local root = rootPart(player)
	if not ok or not root then
		return Enum.ContextActionResult.Pass
	end
	local useMouse = input.UserInputType == Enum.UserInputType.MouseButton1
	FireNet:FireServer(aimDirection(root.Position + Vector3.new(0, 1.5, 0), useMouse))
	return Enum.ContextActionResult.Sink
end

local function onCarryingChanged()
	local carrying = isCarrying(player)
	-- Hide Unplug prompts while carrying so E means Drop.
	pcall(function()
		ProximityPromptService.Enabled = not carrying
	end)
	if carrying then
		ContextActionService:BindAction("Drop", onDrop, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle("Drop", "Drop")
	else
		ContextActionService:UnbindAction("Drop")
	end
end

function Controls.Init()
	ContextActionService:BindAction("Sprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Sprint")

	ContextActionService:BindAction("TagNet", onNet, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("TagNet", "Net")

	player:GetAttributeChangedSignal("Carrying"):Connect(onCarryingChanged)
	onCarryingChanged()

	player.CharacterAdded:Connect(function()
		sprinting = false
		ContextActionService:SetTitle("Sprint", "Sprint")
	end)
end

return Controls

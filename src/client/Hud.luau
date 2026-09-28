--!strict
-- The on-screen HUD. Everything it shows comes from attributes the server
-- sets on the player, so the HUD can never disagree with the rules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Controls = require(script.Parent.Controls)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer

local Hud = {}

local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(20, 22, 28)
local GOOD = Color3.fromRGB(90, 220, 110)
local WARN = Color3.fromRGB(255, 160, 40)
local BAD = Color3.fromRGB(255, 70, 60)
local TONES = { good = GOOD, bad = BAD, info = WHITE }

local gui: ScreenGui
local zoneChip: TextLabel
local statsLabel: TextLabel
local wardenLabel: TextLabel
local spottedBar: Frame
local spottedFill: Frame
local carryPanel: Frame
local carryName: TextLabel
local rhythmBar: Frame
local rhythmFill: Frame
local behaviourLabel: TextLabel
local batteryLabel: TextLabel
local netLabel: TextLabel
local speedNeedle: Frame
local speedNumber: TextLabel
local shownSpeed = 0
local toastList: Frame
local netArrow: TextLabel
local netWarnUntil = 0
local netFrom = Vector3.zero

local function now(): number
	return workspace:GetServerTimeNow()
end

local function label(parent: Instance, size: UDim2, position: UDim2, textSize: number, font: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = size
	t.Position = position
	t.BackgroundTransparency = 1
	t.TextColor3 = WHITE
	t.TextSize = textSize
	t.Font = font or Enum.Font.GothamBold
	t.TextStrokeTransparency = 0.5
	t.Text = ""
	t.Parent = parent
	return t
end

local function panel(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.25
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = f
	return f
end

local function bar(parent: Instance, position: UDim2, width: number): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Size = UDim2.fromOffset(width, 10)
	back.Position = position
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = WHITE
	fill.BorderSizePixel = 0
	fill.Parent = back
	return back, fill
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "StealABotHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Top left: zone and progress.
	local status = panel(gui, UDim2.fromOffset(250, 62), UDim2.fromOffset(12, 12), Vector2.zero)
	zoneChip = label(status, UDim2.new(1, -12, 0, 24), UDim2.fromOffset(6, 6), 16, Enum.Font.GothamBlack)
	zoneChip.BackgroundTransparency = 0
	zoneChip.TextStrokeTransparency = 1
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, 6)
	chipCorner.Parent = zoneChip
	statsLabel = label(status, UDim2.new(1, -12, 0, 22), UDim2.fromOffset(6, 34), 14, Enum.Font.Gotham)
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Under that: a speedometer showing how fast you're moving.
	local speed = panel(gui, UDim2.fromOffset(150, 64), UDim2.fromOffset(12, 82), Vector2.zero)
	local dial = Instance.new("Frame")
	dial.Size = UDim2.fromOffset(52, 52)
	dial.Position = UDim2.fromOffset(6, 6)
	dial.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
	dial.Parent = speed
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = dial
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.fromRGB(120, 200, 255)
	ring.Thickness = 2
	ring.Parent = dial
	speedNeedle = Instance.new("Frame")
	speedNeedle.Size = UDim2.fromOffset(3, 22)
	speedNeedle.AnchorPoint = Vector2.new(0.5, 1)
	speedNeedle.Position = UDim2.fromScale(0.5, 0.5)
	speedNeedle.BackgroundColor3 = WHITE
	speedNeedle.BorderSizePixel = 0
	speedNeedle.Parent = dial
	local hub = Instance.new("Frame")
	hub.Size = UDim2.fromOffset(8, 8)
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.BackgroundColor3 = WHITE
	hub.Parent = dial
	local hubRound = Instance.new("UICorner")
	hubRound.CornerRadius = UDim.new(0.5, 0)
	hubRound.Parent = hub
	speedNumber = label(speed, UDim2.fromOffset(80, 32), UDim2.fromOffset(64, 6), 28, Enum.Font.GothamBlack)
	local unit = label(speed, UDim2.fromOffset(80, 18), UDim2.fromOffset(64, 38), 14, Enum.Font.Gotham)
	unit.Text = "studs/s"

	-- Top centre: the Warden.
	wardenLabel = label(gui, UDim2.fromOffset(420, 34), UDim2.new(0.5, 0, 0, 12), 24, Enum.Font.GothamBlack)
	wardenLabel.AnchorPoint = Vector2.new(0.5, 0)
	spottedBar, spottedFill = bar(gui, UDim2.new(0.5, 0, 0, 52), 180)
	spottedFill.BackgroundColor3 = WARN
	local spottedText = label(spottedBar, UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 12), 14)
	spottedText.Text = "Spotted"

	-- Bottom centre: what you carry.
	carryPanel = panel(gui, UDim2.fromOffset(320, 96), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1))
	carryName = label(carryPanel, UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, 4), 20, Enum.Font.GothamBlack)
	rhythmBar, rhythmFill = bar(carryPanel, UDim2.new(0.5, 0, 0, 34), 280)
	behaviourLabel = label(carryPanel, UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, 48), 14, Enum.Font.Gotham)
	batteryLabel = label(carryPanel, UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, 70), 14)

	-- Bottom left: controls reminder. Bottom right: Tag Net state.
	local help = label(gui, UDim2.fromOffset(420, 20), UDim2.new(0, 12, 1, -12), 14, Enum.Font.Gotham)
	help.AnchorPoint = Vector2.new(0, 1)
	help.TextXAlignment = Enum.TextXAlignment.Left
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		help.Text = "Hold the prompt: unplug · Drop · Sprint · Net buttons"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		help.Text = "X hold: unplug · X: drop · L3: sprint · R2: Tag Net"
	else
		help.Text = "Hold E: unplug / pick up · E: drop · Shift: sprint · Click: Tag Net"
	end
	netLabel = label(gui, UDim2.fromOffset(240, 22), UDim2.new(1, -12, 0, 12), 16)
	netLabel.AnchorPoint = Vector2.new(1, 0)
	netLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- Middle: short messages.
	toastList = Instance.new("Frame")
	toastList.BackgroundTransparency = 1
	toastList.Size = UDim2.fromOffset(520, 120)
	toastList.Position = UDim2.fromScale(0.5, 0.22)
	toastList.AnchorPoint = Vector2.new(0.5, 0)
	toastList.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = toastList

	-- Net warning arrow that points at whoever fired.
	netArrow = label(gui, UDim2.fromOffset(200, 40), UDim2.fromScale(0.5, 0.5), 22, Enum.Font.GothamBlack)
	netArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	netArrow.TextColor3 = BAD
end

function Hud.Toast(text: string, tone: string?)
	local t = label(toastList, UDim2.fromOffset(520, 30), UDim2.new(), 20, Enum.Font.GothamBlack)
	t.Text = text
	t.TextColor3 = TONES[tone or "info"] or WHITE
	t.TextStrokeTransparency = 0.2
	if #toastList:GetChildren() > 4 then
		for _, child in toastList:GetChildren() do
			if child:IsA("TextLabel") and child ~= t then
				child:Destroy()
				break
			end
		end
	end
	task.delay(2.5, function()
		local fade = TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		t:Destroy()
	end)
end

function Hud.NetWarning(from: Vector3, shooterName: string)
	netWarnUntil = os.clock() + 1.2
	netFrom = from
	netArrow.Text = "▲ Net from " .. shooterName
end

local function number(name: string): number?
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else nil
end

local function update()
	local t = now()

	local zone = player:GetAttribute("Zone")
	if zone == "Amber" or zone == "Red" then
		zoneChip.Text = "FACTORY · " .. (zone :: string):upper()
		zoneChip.BackgroundColor3 = Config.ZoneColors[zone]
	else
		zoneChip.Text = "SAFE ZONE"
		zoneChip.BackgroundColor3 = Config.ZoneColors.Safe
	end
	local best = number("BestRun")
	statsLabel.Text = ("Secured: %d · Best run: %s"):format(number("SecuredCount") or 0, if best then ("%.1f s"):format(best) else "—")

	local carrying = player:GetAttribute("Carrying")
	carryPanel.Visible = typeof(carrying) == "string" and carrying ~= ""
	if carryPanel.Visible then
		carryName.Text = carrying :: string

		local phase = Effects.RhythmPhase()
		rhythmBar.Visible = phase ~= nil
		if phase then
			local period = number("RhythmPeriod") or 1
			local windUp = phase >= 1 - 0.5 / period
			rhythmFill.Size = UDim2.fromScale(phase, 1)
			rhythmFill.BackgroundColor3 = if windUp then Color3.fromRGB(255, 230, 60) else WHITE
			behaviourLabel.Text = if windUp then "BOUNCE!" else ("Bounces every %.1f s"):format(period)
		else
			behaviourLabel.Text = ""
		end

		local ends = number("CarryEndsAt")
		if ends then
			local left = math.max(0, ends - t)
			batteryLabel.Text = ("Battery %d s"):format(math.ceil(left))
			batteryLabel.TextColor3 = if left <= Config.CarryWarnAt then BAD else WHITE
		end

		local state = player:GetAttribute("WardenState")
		local distance = number("WardenDistance") or 0
		if state == "Booting" then
			local boot = number("WardenBootEndsAt") or t
			wardenLabel.Text = ("Warden waking… %.1f"):format(math.max(0, boot - t))
			wardenLabel.TextColor3 = WARN
		elseif state == "Held" then
			wardenLabel.Text = "Warden stopped at the safe line"
			wardenLabel.TextColor3 = GOOD
		elseif state == "Chasing" then
			wardenLabel.Text = ("Warden: %d studs behind you"):format(distance)
			wardenLabel.TextColor3 = if distance >= 25 then GOOD elseif distance >= 10 then WARN else BAD
		else
			wardenLabel.Text = ""
		end

		local spotted = number("Spotted") or 0
		spottedBar.Visible = spotted > 0.01
		spottedFill.Size = UDim2.fromScale(spotted, 1)
	else
		wardenLabel.Text = ""
		spottedBar.Visible = false
	end

	-- Speedometer: horizontal speed, smoothed so the needle doesn't jitter.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local speed = 0
	if root and root:IsA("BasePart") then
		local v = root.AssemblyLinearVelocity
		speed = Vector3.new(v.X, 0, v.Z).Magnitude
	end
	shownSpeed += (speed - shownSpeed) * 0.25
	local top = Config.Movement.Sprint
	speedNeedle.Rotation = -120 + 240 * math.clamp(shownSpeed / top, 0, 1)
	speedNeedle.BackgroundColor3 = if shownSpeed >= Config.Movement.CarrySprint - 0.5 then Color3.fromRGB(120, 200, 255) else WHITE
	speedNumber.Text = tostring(math.floor(shownSpeed + 0.5))

	local ok, text = Controls.CanNet()
	netLabel.Text = text
	netLabel.TextColor3 = if ok then GOOD else Color3.fromRGB(150, 150, 155)

	-- Point the warning arrow toward the shooter, relative to the camera.
	if os.clock() < netWarnUntil then
		local camera = workspace.CurrentCamera
		local rel = camera.CFrame:PointToObjectSpace(netFrom)
		local angle = math.atan2(rel.X, -rel.Z)
		netArrow.Visible = true
		netArrow.Rotation = math.deg(angle)
		netArrow.Position = UDim2.new(0.5, math.sin(angle) * 180, 0.5, -math.cos(angle) * 140)
	else
		netArrow.Visible = false
	end
end

function Hud.Init()
	build()
	RunService.RenderStepped:Connect(update)
end

return Hud

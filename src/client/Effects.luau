--!strict
-- Robot behaviours that must run on the carrier's own machine (the character
-- is physically simulated there), plus outlines everyone sees:
--   * Spring Bot bounces on a fixed beat
--   * recently netted players get a blue outline (net immunity)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Effects = {}

local IMMUNE = Color3.fromRGB(70, 150, 255)

local lastPhase = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function bounce(height: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	local normal = humanoid.JumpHeight
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = height
	humanoid.Jump = true
	task.delay(0.2, function()
		-- The server may have changed it meanwhile (for example, a drop).
		if humanoid.JumpHeight == height then
			humanoid.JumpHeight = normal
		end
	end)
end

local function stepBounce()
	if player:GetAttribute("Behaviour") ~= "Bounce" then
		lastPhase = 0
		return
	end
	local start = player:GetAttribute("RhythmStart")
	local period = player:GetAttribute("RhythmPeriod")
	local height = player:GetAttribute("BounceHeight")
	if typeof(start) ~= "number" or typeof(period) ~= "number" or typeof(height) ~= "number" then
		return
	end
	local phase = ((now() - start) % period) / period
	if phase < lastPhase then
		bounce(height)
	end
	lastPhase = phase
end

-- Called every frame by the HUD for the rhythm ring: 0..1 through the beat.
function Effects.RhythmPhase(): number?
	if player:GetAttribute("Behaviour") ~= "Bounce" then
		return nil
	end
	local start = player:GetAttribute("RhythmStart")
	local period = player:GetAttribute("RhythmPeriod")
	if typeof(start) ~= "number" or typeof(period) ~= "number" then
		return nil
	end
	return ((now() - start) % period) / period
end

local function updateOutline(other: Player, t: number)
	local character = other.Character
	if not character then
		return
	end
	local immune = (tonumber(other:GetAttribute("NetImmuneUntil")) or 0) > t
	local highlight = character:FindFirstChild("StealABotOutline")
	if not immune then
		if highlight then
			highlight:Destroy()
		end
		return
	end
	if not highlight then
		local h = Instance.new("Highlight")
		h.Name = "StealABotOutline"
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.OutlineColor = IMMUNE
		h.FillTransparency = 1
		h.Parent = character
	end
end

function Effects.Init()
	RunService.Heartbeat:Connect(stepBounce)
	task.spawn(function()
		while true do
			local t = now()
			for _, other in Players:GetPlayers() do
				updateOutline(other, t)
			end
			task.wait(0.2)
		end
	end)
end

return Effects

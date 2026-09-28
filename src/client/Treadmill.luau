--!strict
-- Treadmills in the Loading Yard hold you in place: walking, sprinting or
-- bouncing along the belt gets you nowhere. Step off sideways to get past.
-- Runs on the player's own client because that's where their character moves.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Treadmill = {}

local TAG = "Treadmill"
local REACH = 12 -- studs below you that still count as "on the belt", so jumps don't escape it

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local lockZ: number? = nil

local function refresh()
	params.FilterDescendantsInstances = CollectionService:GetTagged(TAG)
end

local function step()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		lockZ = nil
		return
	end
	local pos = root.Position
	if not workspace:Raycast(pos, Vector3.new(0, -REACH, 0), params) then
		lockZ = nil
		return
	end
	-- Pin your position along the belt; sideways movement still works.
	local z = lockZ or pos.Z
	lockZ = z
	if math.abs(pos.Z - z) > 0.01 then
		root.CFrame += Vector3.new(0, 0, z - pos.Z)
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0)
end

function Treadmill.Init()
	-- Parts stream in and out, so keep the list current.
	CollectionService:GetInstanceAddedSignal(TAG):Connect(refresh)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(refresh)
	refresh()
	RunService.Heartbeat:Connect(step)
end

return Treadmill

--!strict
-- Greybox robot shapes: a body, a head with screen eyes, and one signature
-- part per robot. Models face -Z and pivot at their feet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobotDefs = require(ReplicatedStorage.Shared.RobotDefs)

type RobotDef = RobotDefs.RobotDef

local RobotModels = {}

local METAL = Color3.fromRGB(160, 165, 175)
local DARK = Color3.fromRGB(40, 40, 48)

local function part(model: Model, body: BasePart?, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Parent = model
	if body then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
	end
	return p
end

local function head(model: Model, body: BasePart, y: number, size: Vector3, accent: Color3)
	local h = part(model, body, "Head", size, CFrame.new(0, y, 0), METAL, Enum.Material.Metal)
	local screen = part(model, body, "Screen", Vector3.new(size.X * 0.8, size.Y * 0.7, 0.05), CFrame.new(0, y, -size.Z / 2 - 0.03), DARK)
	for _, x in { -0.25, 0.25 } do
		part(model, body, "Eye", Vector3.new(0.2, 0.25, 0.05), CFrame.new(x * size.X, y + 0.05, -size.Z / 2 - 0.07), accent, Enum.Material.Neon)
	end
	return h, screen
end

local shapes: { [string]: (Model, RobotDef) -> (BasePart, number) } = {}

-- Spring Bot: a boxy body on two coiled spring legs.
shapes.SpringBot = function(model, def)
	local body = part(model, nil, "Body", Vector3.new(1.8, 1.2, 1.2), CFrame.new(0, 1.5, 0), METAL, Enum.Material.Metal)
	part(model, body, "Stripe", Vector3.new(1.82, 0.25, 1.22), CFrame.new(0, 1.5, 0), def.Accent, Enum.Material.Neon)
	head(model, body, 2.55, Vector3.new(1.4, 0.9, 1.1), def.Accent)
	for _, x in { -0.5, 0.5 } do
		local spring = part(model, body, "SpringLeg", Vector3.new(0.9, 0.55, 0.55), CFrame.new(x, 0.45, 0) * CFrame.Angles(0, 0, math.pi / 2), def.Accent, Enum.Material.Metal)
		spring.Shape = Enum.PartType.Cylinder
		part(model, body, "Coil", Vector3.new(0.6, 0.12, 0.6), CFrame.new(x, 0.3, 0), DARK)
		part(model, body, "Coil", Vector3.new(0.6, 0.12, 0.6), CFrame.new(x, 0.6, 0), DARK)
	end
	return body, 3
end

export type Built = {
	Model: Model,
	Body: BasePart,
	Height: number,
}

function RobotModels.Build(def: RobotDef): Built
	local model = Instance.new("Model")
	model.Name = def.Name
	local build = shapes[def.Key] or shapes.SpringBot
	local body, height = build(model, def)
	body.Anchored = true
	model.PrimaryPart = body
	-- Pivot at the feet so PivotTo places the robot standing on a surface.
	body.PivotOffset = CFrame.new(0, -body.Position.Y, 0)
	return { Model = model, Body = body, Height = height }
end

return RobotModels

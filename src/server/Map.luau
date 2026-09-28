--!strict
-- Builds the greybox: a safe zone with eight workshops, then five factory
-- layers in a straight line along +Z. Everything is plain blocks so the
-- layout can be judged before any art exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Plot = {
	Index: number,
	Side: number, -- -1 = left of the street, 1 = right
	CenterZ: number,
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
	SpawnCFrame: CFrame,
	Beacon: BasePart,
	BayLine: BasePart,
	Sign: TextLabel,
	Owner: Player?,
	DisplayCount: number,
}

export type Dock = {
	CFrame: CFrame,
	Layer: number,
	RobotKey: string,
	Robot: any?,
	RespawnAt: number,
}

export type PressRow = {
	Head: BasePart,
	Warning: BasePart,
	MinZ: number,
	MaxZ: number,
	UpY: number,
	DownY: number,
	Offset: number,
}

local Map = {}

Map.Folder = nil :: Folder?
Map.SafeLineZ = 0
Map.EndZ = 0
Map.FloorY = 0
Map.Plots = {} :: { Plot }
Map.Docks = {} :: { Dock }
Map.LayerStartZ = {} :: { number }
Map.Sweep = nil :: { Beam: BasePart, MinZ: number, MaxZ: number, Travel: number }?
Map.PressRows = {} :: { PressRow }

local O = Config.Origin
local LAYER = Config.LayerLength
local HALF_TRACK = Config.TrackWidth / 2

local function block(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = O + position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = text
	t.Parent = gui
end

local function buildSafeZone(folder: Folder)
	local sz = Config.SafeZone
	local halfW = sz.Width / 2
	local grey = Color3.fromRGB(120, 120, 125)

	block(folder, "SafeFloor", Vector3.new(sz.Width, 2, sz.Length), Vector3.new(0, -1, sz.Length / 2), Config.ZoneColors.Safe, Enum.Material.Grass)
	block(folder, "Street", Vector3.new(sz.StreetWidth, 0.2, sz.Length), Vector3.new(0, 0.1, sz.Length / 2), Color3.fromRGB(60, 60, 65), Enum.Material.Asphalt)

	-- Outer walls, leaving the factory entrance open.
	block(folder, "WallLeft", Vector3.new(2, 12, sz.Length), Vector3.new(-halfW - 1, 6, sz.Length / 2), grey)
	block(folder, "WallRight", Vector3.new(2, 12, sz.Length), Vector3.new(halfW + 1, 6, sz.Length / 2), grey)
	block(folder, "WallBack", Vector3.new(sz.Width + 4, 12, 2), Vector3.new(0, 6, -1), grey)
	local frontW = halfW - HALF_TRACK
	block(folder, "WallFrontLeft", Vector3.new(frontW, 12, 2), Vector3.new(-(HALF_TRACK + frontW / 2), 6, sz.Length + 1), grey)
	block(folder, "WallFrontRight", Vector3.new(frontW, 12, 2), Vector3.new(HALF_TRACK + frontW / 2, 6, sz.Length + 1), grey)

	local safeLine = block(folder, "SafeLine", Vector3.new(Config.TrackWidth, 0.4, 2), Vector3.new(0, 0.2, sz.Length), Config.ZoneColors.Safe, Enum.Material.Neon)
	safeLine.CanCollide = false

	local sign = block(folder, "SafeLineSign", Vector3.new(Config.TrackWidth, 4, 1), Vector3.new(0, 16, sz.Length), Color3.fromRGB(30, 30, 35))
	label(sign, Enum.NormalId.Back, "SAFE ZONE — the Warden stops here", Config.ZoneColors.Safe)
	label(sign, Enum.NormalId.Front, "SAFE ZONE — the Warden stops here", Config.ZoneColors.Safe)

	Map.SafeLineZ = O.Z + sz.Length
end

local function buildPlots(folder: Folder)
	local sz = Config.SafeZone
	local plotSize = sz.PlotSize
	local street = sz.StreetWidth / 2
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Workshops"
	plotsFolder.Parent = folder

	for i = 1, 8 do
		-- Workshops 1 and 8 sit nearest the factory.
		local side = if i <= 4 then -1 else 1
		local row = if i <= 4 then i - 1 else 8 - i
		local cz = sz.Length - 5 - plotSize / 2 - plotSize * row
		local cx = side * (street + plotSize / 2)

		local model = Instance.new("Model")
		model.Name = "Workshop" .. i
		model.Parent = plotsFolder

		block(model, "Floor", Vector3.new(plotSize - 2, 0.4, plotSize - 2), Vector3.new(cx, 0.2, cz), Color3.fromRGB(150, 145, 140), Enum.Material.Concrete)
		local wallColor = Color3.fromRGB(110, 100, 95)
		block(model, "DividerA", Vector3.new(plotSize, 5, 1), Vector3.new(cx, 2.5, cz - plotSize / 2 + 0.5), wallColor)
		block(model, "DividerB", Vector3.new(plotSize, 5, 1), Vector3.new(cx, 2.5, cz + plotSize / 2 - 0.5), wallColor)

		local bay = block(model, "LoadingBayLine", Vector3.new(1, 0.3, plotSize - 2), Vector3.new(side * (street + 1), 0.45, cz), Color3.fromRGB(200, 200, 200), Enum.Material.Neon)
		bay.CanCollide = false

		local beacon = block(model, "Beacon", Vector3.new(2, 40, 2), Vector3.new(side * (street + plotSize - 5), 20, cz + plotSize / 2 - 5), Color3.fromRGB(90, 90, 90), Enum.Material.Neon)

		local signPart = block(model, "SignPost", Vector3.new(1, 1, 1), Vector3.new(side * (street + 2), 9, cz), Color3.new(), Enum.Material.SmoothPlastic)
		signPart.Transparency = 1
		signPart.CanCollide = false
		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromOffset(260, 50)
		board.MaxDistance = 150
		board.Parent = signPart
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 0.3
		text.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.Text = ("Workshop %d · free"):format(i)
		text.Parent = board

		local spawnPos = O + Vector3.new(side * (street + 25), 3, cz)
		table.insert(Map.Plots, {
			Index = i,
			Side = side,
			CenterZ = O.Z + cz,
			MinX = O.X + math.min(side * street, side * (street + plotSize)),
			MaxX = O.X + math.max(side * street, side * (street + plotSize)),
			MinZ = O.Z + cz - plotSize / 2,
			MaxZ = O.Z + cz + plotSize / 2,
			SpawnCFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(-side, 0, 0)),
			Beacon = beacon,
			BayLine = bay,
			Sign = text,
			Owner = nil,
			DisplayCount = 0,
		})
	end
end

local function buildLayerShell(folder: Instance, index: number, startZ: number)
	local def = Config.Layers[index]
	local zoneColor = Config.ZoneColors[def.Zone]
	local wallColor = Color3.fromRGB(85, 85, 95)

	block(folder, "Floor", Vector3.new(Config.TrackWidth, 2, LAYER), Vector3.new(0, -1, startZ + LAYER / 2), zoneColor, Enum.Material.Concrete)
	for _, side in { -1, 1 } do
		block(folder, "SideWall", Vector3.new(2, 20, LAYER), Vector3.new(side * (HALF_TRACK + 1), 10, startZ + LAYER / 2), wallColor)
		block(folder, "ArchPillar", Vector3.new(3, 24, 3), Vector3.new(side * (HALF_TRACK - 0.5), 12, startZ), def.ArchColor)
	end
	-- Edge stripes repeat the zone colour so it reads from any angle.
	for _, side in { -1, 1 } do
		local stripe = block(folder, "EdgeStripe", Vector3.new(1, 0.3, LAYER), Vector3.new(side * (HALF_TRACK - 0.5), 0.15, startZ + LAYER / 2), zoneColor, Enum.Material.Neon)
		stripe.CanCollide = false
	end

	local arch = block(folder, "Arch", Vector3.new(Config.TrackWidth + 2, 4, 2), Vector3.new(0, 22, startZ), def.ArchColor)
	local text = ("%d · %s — Warden speed %s"):format(index, def.Name:upper(), tostring(def.WardenSpeed))
	label(arch, Enum.NormalId.Back, text, Color3.fromRGB(20, 20, 25))
	label(arch, Enum.NormalId.Front, text, Color3.fromRGB(20, 20, 25))
end

local function buildDocks(folder: Instance, index: number, startZ: number)
	local def = Config.Layers[index]
	local spacing = 18
	local count = Config.DocksPerLayer
	for d = 1, count do
		local x = (d - (count + 1) / 2) * spacing
		local z = startZ + Config.DockDepth
		local pad = block(folder, "Dock", Vector3.new(6, 0.6, 6), Vector3.new(x, 0.3, z), def.ArchColor, Enum.Material.Metal)
		pad.CanCollide = true
		table.insert(Map.Docks, {
			CFrame = CFrame.new(O + Vector3.new(x, 0.6, z)), -- robots face -Z, toward players walking in
			Layer = index,
			RobotKey = def.Robot,
			Robot = nil,
			RespawnAt = 0,
		})
	end
end

local SCRAP = Color3.fromRGB(120, 95, 70)
local PILLAR = Color3.fromRGB(100, 100, 110)
local WALL = Color3.fromRGB(80, 80, 90)
local SPRING_GAP = Color3.fromRGB(255, 230, 0)

-- Layer 1: a few scrap piles to step around.
local function buildScrapyard(folder: Instance, a: number)
	for _, spot in { Vector3.new(-14, 1.5, 25), Vector3.new(12, 1.5, 35), Vector3.new(-4, 1.5, 55), Vector3.new(18, 1.5, 62) } do
		block(folder, "ScrapPile", Vector3.new(7, 3, 6), spot + Vector3.new(0, 0, a), SCRAP, Enum.Material.CorrodedMetal)
	end
end

-- Layer 2: pillars and a sweeping light. 1.5 s in the beam surges the Warden.
local function buildAssemblyHall(folder: Instance, a: number)
	for _, spot in { Vector3.new(-16, 10, 18), Vector3.new(16, 10, 18), Vector3.new(0, 10, 65), Vector3.new(-22, 10, 68), Vector3.new(22, 10, 68) } do
		block(folder, "Pillar", Vector3.new(4, 20, 4), spot + Vector3.new(0, 0, a), PILLAR)
	end
	local h = Config.Hazards
	local minZ, maxZ = a + 30, a + 30 + h.SweepDepth
	local beam = block(folder, "SweepLight", Vector3.new(h.SweepWidth, 0.3, h.SweepDepth), Vector3.new(0, 0.3, (minZ + maxZ) / 2), Color3.fromRGB(190, 225, 255), Enum.Material.Neon)
	beam.Transparency = 0.35
	beam.CanCollide = false
	beam.CanQuery = false
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Top
	light.Range = 20
	light.Brightness = 3
	light.Parent = beam
	Map.Sweep = {
		Beam = beam,
		MinZ = O.Z + minZ,
		MaxZ = O.Z + maxZ,
		Travel = HALF_TRACK - h.SweepWidth / 2,
	}
end

-- Layer 3: three cross walls in a zigzag, each with a narrow side gap and a
-- yellow Spring gap in the middle that only a bounce clears.
local function buildTunnels(folder: Instance, a: number)
	local height = 14
	local gapSide = { 1, -1, 1 }
	for w, z in { 20, 45, 70 } do
		local side = gapSide[w]
		-- Solid wall from the far side wall to the spring gap.
		local farEdge = -side * HALF_TRACK
		local solidA = { farEdge, -side * 4 }
		-- Wall from the spring gap to the narrow 4-stud side gap.
		local solidB = { side * 4, side * (HALF_TRACK - 4) }
		for _, seg in { solidA, solidB } do
			local x0, x1 = math.min(seg[1], seg[2]), math.max(seg[1], seg[2])
			block(folder, "CrossWall", Vector3.new(x1 - x0, height, 2), Vector3.new((x0 + x1) / 2, height / 2, a + z), WALL)
		end
		local fence = Config.Hazards.SpringFenceHeight
		local gap = block(folder, "SpringGap", Vector3.new(8, fence, 2), Vector3.new(0, fence / 2, a + z), SPRING_GAP)
		gap.Material = Enum.Material.DiamondPlate
	end
end

-- Layer 4: conveyors on both sides push you deeper; crates slalom down the middle.
local function buildLoadingYard(folder: Instance, a: number)
	for _, side in { -1, 1 } do
		local belt = block(folder, "Conveyor", Vector3.new(20, 0.4, 70), Vector3.new(side * 20, 0.2, a + 45), Color3.fromRGB(45, 45, 50), Enum.Material.DiamondPlate)
		belt.AssemblyLinearVelocity = Vector3.new(0, 0, Config.Hazards.ConveyorSpeed)
		for k = 0, 6 do
			local arrow = block(folder, "ConveyorArrow", Vector3.new(4, 0.1, 1), Vector3.new(side * 20, 0.45, a + 15 + k * 10), Color3.fromRGB(200, 200, 210), Enum.Material.Neon)
			arrow.CanCollide = false
		end
	end
	for k, z in { 15, 27, 39, 51, 63, 75 } do
		local x = if k % 2 == 0 then 4 else -4
		block(folder, "Crate", Vector3.new(5, 5, 5), Vector3.new(x, 2.5, a + z), SCRAP, Enum.Material.WoodPlanks)
	end
end

-- Layer 5: two rows of presses on a staggered beat. A slam pushes you back.
local function buildPressFloor(folder: Instance, a: number)
	local h = Config.Hazards
	for r, z in { 30, 60 } do
		for _, side in { -1, 1 } do
			block(folder, "PressFrame", Vector3.new(2, 16, 12), Vector3.new(side * (HALF_TRACK - 1), 8, a + z), PILLAR)
		end
		local upY, downY = 12, 2
		local head = block(folder, "PressHead", Vector3.new(Config.TrackWidth - 4, 3, 10), Vector3.new(0, upY, a + z), Color3.fromRGB(70, 70, 80), Enum.Material.Metal)
		head.CanCollide = false
		local warning = block(folder, "PressWarning", Vector3.new(Config.TrackWidth - 4, 0.2, 10), Vector3.new(0, 0.1, a + z), Color3.fromRGB(60, 60, 65), Enum.Material.SmoothPlastic)
		warning.CanCollide = false
		table.insert(Map.PressRows, {
			Head = head,
			Warning = warning,
			MinZ = O.Z + a + z - 5,
			MaxZ = O.Z + a + z + 5,
			UpY = O.Y + upY,
			DownY = O.Y + downY,
			Offset = (r - 1) * h.PressBeat / 2,
		})
	end
end

local HAZARDS = { buildScrapyard, buildAssemblyHall, buildTunnels, buildLoadingYard, buildPressFloor }

function Map.Build()
	local existing = workspace:FindFirstChild("StealABotGreybox")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "StealABotGreybox"
	Map.Folder = folder
	Map.FloorY = O.Y

	buildSafeZone(folder)
	buildPlots(folder)

	local factory = Instance.new("Folder")
	factory.Name = "Factory"
	factory.Parent = folder
	local startZ = Config.SafeZone.Length
	for i = 1, #Config.Layers do
		local layerFolder = Instance.new("Model")
		layerFolder.Name = ("Layer%d_%s"):format(i, (Config.Layers[i].Name:gsub(" ", "")))
		layerFolder.Parent = factory
		buildLayerShell(layerFolder, i, startZ)
		buildDocks(layerFolder, i, startZ)
		local hazard = HAZARDS[i]
		if hazard then
			hazard(layerFolder, startZ)
		end
		Map.LayerStartZ[i] = O.Z + startZ
		startZ += LAYER
	end
	block(factory, "EndWall", Vector3.new(Config.TrackWidth + 4, 20, 2), Vector3.new(0, 10, startZ + 1), Color3.fromRGB(85, 85, 95))
	Map.EndZ = O.Z + startZ

	folder.Parent = workspace
end

-- 0 means the safe zone.
function Map.LayerIndexAt(position: Vector3): number
	if position.Z < Map.SafeLineZ then
		return 0
	end
	local index = math.floor((position.Z - Map.SafeLineZ) / LAYER) + 1
	return math.clamp(index, 1, #Config.Layers)
end

function Map.ZoneAt(position: Vector3): "Safe" | "Amber" | "Red"
	local index = Map.LayerIndexAt(position)
	if index == 0 then
		return "Safe"
	end
	return Config.Layers[index].Zone
end

-- True once a position is past the plot's loading-bay line.
function Map.InPlot(plot: Plot, position: Vector3): boolean
	return position.X >= plot.MinX + (if plot.Side == 1 then 1 else 0)
		and position.X <= plot.MaxX - (if plot.Side == -1 then 1 else 0)
		and position.Z >= plot.MinZ
		and position.Z <= plot.MaxZ
		and math.abs(position.Y - Map.FloorY) < 30
end

-- Where the Nth secured robot is shown inside a workshop.
function Map.DisplayCFrame(plot: Plot, n: number): CFrame
	local col = (n - 1) % 5
	local row = math.floor((n - 1) / 5) % 7
	local x = plot.Side * (Config.SafeZone.StreetWidth / 2 + 38 + col * 9)
	local z = plot.CenterZ - O.Z - 30 + row * 10
	return CFrame.new(O + Vector3.new(x, 0.4, z)) * CFrame.Angles(0, if plot.Side == 1 then -math.pi / 2 else math.pi / 2, 0)
end

return Map

--!strict
-- Every number here comes from the Steal a Bot design doc and is a prototype
-- assumption to tune during playtests.

local Config = {}

-- Where the greybox map is built. It is far from the middle of the place so it
-- never overlaps anything already built in Studio.
Config.Origin = Vector3.new(3000, 50, 0)

Config.SafeZone = {
	Width = 220,
	Length = 330,
	StreetWidth = 60,
	PlotSize = 80,
}

Config.TrackWidth = 60
Config.LayerLength = 100

export type LayerDef = {
	Name: string,
	Zone: "Amber" | "Red",
	WardenSpeed: number,
	Robot: string,
	ArchColor: Color3,
}

-- One straight line of layers. Deeper means a faster Warden and better robots.
Config.Layers = {
	{ Name = "Scrapyard", Zone = "Amber", WardenSpeed = 9, Robot = "BoltBot", ArchColor = Color3.fromRGB(90, 140, 220) },
	{ Name = "Assembly Hall", Zone = "Amber", WardenSpeed = 11, Robot = "SpringBot", ArchColor = Color3.fromRGB(150, 100, 220) },
	{ Name = "Maintenance Tunnels", Zone = "Red", WardenSpeed = 12.5, Robot = "SpringBot", ArchColor = Color3.fromRGB(60, 190, 200) },
	{ Name = "Loading Yard", Zone = "Red", WardenSpeed = 14.5, Robot = "SpringBot", ArchColor = Color3.fromRGB(220, 110, 180) },
	{ Name = "Press Floor", Zone = "Red", WardenSpeed = 16, Robot = "SpringBot", ArchColor = Color3.fromRGB(230, 230, 235) },
} :: { LayerDef }

Config.DocksPerLayer = 3
Config.DockDepth = 85 -- studs into a layer, measured from its entrance
Config.DockRespawnTime = 6

Config.Movement = {
	Walk = 16,
	Sprint = 22,
	CarryWalk = 14,
	CarrySprint = 19,
	JumpHeight = 7.2,
	CarryJumpScale = 0.8,
}

-- Seconds to hold Interact, by robot tier.
Config.UnplugTime = { 1.5, 2, 2.5, 3, 4 }

Config.InfoCardDistance = 12
Config.PromptDistance = 8

Config.CarryTimeLimit = 180
Config.CarryWarnAt = 30 -- seconds left when the battery warning shows
Config.DropLifetime = 20
Config.DropClaimTime = 3
Config.RegrabHoldTime = 0.5

Config.Warden = {
	BootTime = 2.5,
	CatchDistance = 3.5,
	SurgeSpeed = 3,
	SurgeTime = 4,
	SpotTime = 1.5, -- seconds in the sweep light before the Warden surges
	HoverHeight = 1.5,
}

Config.Net = {
	Speed = 60,
	Range = 60,
	Reload = 4,
	HitRadius = 3.5,
	ArcHeight = 2,
	ImmunityTime = 20,
	AutoAimDegrees = 6,
	WarnRange = 60,
	PairCooldown = 600, -- one player can take a haul from the same player once per 10 minutes
	HourlyLossCap = 3, -- hauls a player can lose to nets in a rolling hour
}

Config.RevealTime = 3

Config.Hazards = {
	SweepPeriod = 12,
	SweepWidth = 14,
	SweepDepth = 25,
	ConveyorSpeed = 6,
	PressBeat = 4,
	PressWarning = 0.8,
	PressDownTime = 0.6,
	PressPush = 6,
	SpringFenceHeight = 7,
}

-- Zone colours are a rule, not decoration: never reuse them for props.
Config.ZoneColors = {
	Safe = Color3.fromRGB(70, 170, 80),
	Amber = Color3.fromRGB(215, 150, 40),
	Red = Color3.fromRGB(175, 55, 50),
}

Config.PlotColors = {
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(80, 230, 230),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 170, 120),
	Color3.fromRGB(140, 150, 255),
	Color3.fromRGB(200, 255, 120),
}

return Config

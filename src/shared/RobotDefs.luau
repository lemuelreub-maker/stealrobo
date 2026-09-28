--!strict
-- Robot data. Each robot is one row here plus a shape in RobotModels.
-- The greybox only needs two robots; the rest of the catalogue slots in as rows.

export type RobotDef = {
	Key: string,
	Name: string,
	Tier: number,
	Pad: "S" | "M" | "L",
	Transport: string,
	Behaviour: "Bounce" | "RattleOnSprint",
	BehaviourText: string,
	Job: string,
	BaseValue: number,
	Accent: Color3,
	BouncePeriod: number?,
	BounceHeight: number?,
}

local RobotDefs: { [string]: RobotDef } = {
	BoltBot = {
		Key = "BoltBot",
		Name = "Bolt Bot",
		Tier = 1,
		Pad = "S",
		Transport = "Carry",
		Behaviour = "RattleOnSprint",
		BehaviourText = "Rattles whenever you sprint, showing you to everyone",
		Job = "Scrap Line: Sort",
		BaseValue = 70,
		Accent = Color3.fromRGB(255, 190, 60),
	},
	SpringBot = {
		Key = "SpringBot",
		Name = "Spring Bot",
		Tier = 2,
		Pad = "S",
		Transport = "Carry",
		Behaviour = "Bounce",
		BehaviourText = "Bounces 9 studs every 2.5 s. Clears yellow Spring gaps",
		Job = "Scrap Line: Compressor",
		BaseValue = 180,
		Accent = Color3.fromRGB(120, 220, 255),
		BouncePeriod = 2.5,
		BounceHeight = 9,
	},
}

return RobotDefs

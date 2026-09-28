--!strict
-- Gives each player one of the eight workshops and spawns them in it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)

local Plots = {}

local byPlayer: { [Player]: Map.Plot } = {}

local FREE = Color3.fromRGB(90, 90, 90)
local BAY = Color3.fromRGB(200, 200, 200)

function Plots.Of(player: Player): Map.Plot?
	return byPlayer[player]
end

-- Returns where the next secured robot should stand in this workshop.
function Plots.NextDisplay(plot: Map.Plot): CFrame
	plot.DisplayCount += 1
	return Map.DisplayCFrame(plot, plot.DisplayCount)
end

local function assign(player: Player)
	for _, plot in Map.Plots do
		if not plot.Owner then
			plot.Owner = player
			plot.DisplayCount = 0
			local color = Config.PlotColors[plot.Index]
			plot.Beacon.Color = color
			plot.BayLine.Color = color
			plot.Sign.Text = ("Workshop %d · %s"):format(plot.Index, player.DisplayName)
			plot.Sign.TextColor3 = color
			byPlayer[player] = plot
			player:SetAttribute("Workshop", plot.Index)
			return
		end
	end
	warn("[StealABot] No free workshop for " .. player.Name)
end

local function release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.Owner = nil
	plot.DisplayCount = 0
	plot.Beacon.Color = FREE
	plot.BayLine.Color = BAY
	plot.Sign.Text = ("Workshop %d · free"):format(plot.Index)
	plot.Sign.TextColor3 = Color3.new(1, 1, 1)
end

local function spawnAtWorkshop(player: Player, character: Model)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	-- Wait a frame so the default spawn has finished placing the character,
	-- and load the area first so the player never lands before the floor does.
	task.defer(function()
		pcall(function()
			player:RequestStreamAroundAsync(plot.SpawnCFrame.Position, 10)
		end)
		if character.Parent then
			character:PivotTo(plot.SpawnCFrame)
		end
	end)
end

function Plots.Init()
	local function onPlayer(player: Player)
		assign(player)
		player.CharacterAdded:Connect(function(character)
			spawnAtWorkshop(player, character)
		end)
		if player.Character then
			spawnAtWorkshop(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return Plots

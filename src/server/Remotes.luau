--!strict
-- Creates the RemoteEvents the client uses. The server owns every rule; the
-- client only asks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
folder.Name = "Remotes"
folder.Parent = ReplicatedStorage

local function remote(name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end

local Remotes = {
	SetSprint = remote("SetSprint"), -- client -> server: boolean
	DropRobot = remote("DropRobot"), -- client -> server
	FireNet = remote("FireNet"), -- client -> server: aim direction
	Notify = remote("Notify"), -- server -> client: text, tone
	NetIncoming = remote("NetIncoming"), -- server -> client: shooter position, shooter name
}

function Remotes.Tell(player: Player, text: string, tone: ("good" | "bad" | "info")?)
	Remotes.Notify:FireClient(player, text, tone or "info")
end

return Remotes

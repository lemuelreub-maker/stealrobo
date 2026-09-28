local ReplicatedStorage = game:GetService("ReplicatedStorage")

local hello = require(ReplicatedStorage.Shared.Hello)

print("Server script synced from Rojo")
hello()

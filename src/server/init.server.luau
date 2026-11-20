-- init: server bootstrap for Steal a Snackrot.
-- Builds the arena, starts the spawner and the income tick, wires
-- the steal/carry/slap systems and the shop, then looks after
-- players as they join (leaderstats, plot, slap tool) and leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Server = script
-- NOTE: Rojo turns a directory holding init.server.luau into the
-- Script itself, so the modules below are children of this script
-- (script.MapBuilder, script.Steal, ...) and not of its parent.
local MapBuilder = require(Server:WaitForChild("MapBuilder"))
local BaseManager = require(Server:WaitForChild("BaseManager"))
local Spawner = require(Server:WaitForChild("Spawner"))
local Income = require(Server:WaitForChild("Income"))
local Steal = require(Server:WaitForChild("Steal"))
local Shop = require(Server:WaitForChild("Shop"))

-- RemoteEvents, created once here so every module uses the same ones.
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local remotes = {
	ClaimResult = makeRemote("ClaimResult"),
	BaseUpdate = makeRemote("BaseUpdate"),
	ShopBuy = makeRemote("ShopBuy"),
	DropCarried = makeRemote("DropCarried"),
}

-- Clear any leftover arena from a previous load (Studio hot reload).
do
	local workspace = game:GetService("Workspace")
	local oldMap = workspace:FindFirstChild("SnackMap")
	if oldMap then
		oldMap:Destroy()
	end
	local oldCharacters = workspace:FindFirstChild("Characters")
	if oldCharacters then
		oldCharacters:Destroy()
	end
end

-- Build the arena first; every system below works on it.
local map = MapBuilder.Build()
BaseManager.Init(map)

local deps = {
	Map = map,
	Spawner = Spawner,
	BaseManager = BaseManager,
	Income = Income,
	Config = Config,
	Remotes = remotes,
}

Spawner.Start(map)
Income.Start(BaseManager, Config)
Steal.Init(deps)
Shop.Init(deps)

-- Seed the conveyor so the first players see characters right away.
for _ = 1, 3 do
	Spawner.Spawn()
end

-- New player: leaderstats Cash, a plot, and the slap tool on spawn.
local function onCharacterAdded(player, character)
	Steal.GiveSlapTool(player)
	Shop.ApplyCoilIfActive(player)
end

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = Config.StartCash
	cash.Parent = leaderstats

	local plot = BaseManager.AssignPlot(player)
	if plot then
		remotes.ClaimResult:FireClient(player, "Welcome! Your base is Base " .. plot.Number .. ". Claim snacks from the conveyor!")
	else
		remotes.ClaimResult:FireClient(player, "Welcome! All bases are taken — steal from others to earn.")
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player)
	BaseManager.ReleasePlot(player.UserId)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

print("Steal a Snackrot server ready: " .. Config.PlotCount .. " plots, conveyor running.")

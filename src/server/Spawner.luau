-- Spawner: creates snack-brainrot characters and walks them along
-- the central conveyor loop. Characters are picked by rarity weight
-- (CharacterData.PickWeighted), spawn at the first waypoint, and
-- despawn after one full lap or after their lifetime runs out.
-- The shop's Spawn Boost forces the next spawn to be Epic or better.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local Config = require(Shared:WaitForChild("Config"))

local Spawner = {}

local map = nil
local active = {} -- models currently walking the conveyor
local boostNext = false
local spawnTimer = 0
local heartbeatConnection = nil

-- Build one character model from a roster entry. All parts are
-- anchored; the model is moved with PivotTo, never by physics.
local function buildCharacter(entry)
	local scale = entry.Scale
	local bodySize = 3 * scale

	local model = Instance.new("Model")
	model.Name = entry.Name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(bodySize, bodySize, bodySize)
	body.Color = entry.Color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2 * scale, 2 * scale, 2 * scale)
	head.Color = entry.Accent
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.CFrame = body.CFrame * CFrame.new(0, 2.5 * scale, 0)
	head.Parent = model

	-- Eyes, so the snack reads as a character, not a box.
	for _, xOffset in ipairs({ -0.5 * scale, 0.5 * scale }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.45 * scale, 0.7 * scale, 0.2)
		eye.Color = Color3.fromRGB(20, 20, 20)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Anchored = true
		eye.CanCollide = false
		eye.CFrame = body.CFrame * CFrame.new(xOffset, 0.5 * scale, bodySize / 2 + 0.05)
		eye.Parent = model
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(140, 44)
	tag.StudsOffset = Vector3.new(0, 3.6 * scale, 0)
	tag.AlwaysOnTop = true
	tag.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = entry.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.Parent = tag

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "Income"
	incomeLabel.Position = UDim2.fromScale(0, 0.55)
	incomeLabel.Size = UDim2.fromScale(1, 0.45)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = entry.Rarity .. "  $" .. entry.Income .. "/s"
	incomeLabel.TextColor3 = CharacterData.RarityColors[entry.Rarity]
	incomeLabel.TextScaled = true
	incomeLabel.Font = Enum.Font.SourceSansBold
	incomeLabel.Parent = tag

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 32
	click.Parent = body
	CollectionService:AddTag(click, "SnackCharacter")

	model.PrimaryPart = body
	model:SetAttribute("CharName", entry.Name)
	model:SetAttribute("Rarity", entry.Rarity)
	model:SetAttribute("Cost", entry.Cost)
	model:SetAttribute("Income", entry.Income)
	model:SetAttribute("Scale", scale)
	model:SetAttribute("State", "conveyor")
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("HomePlot", 0)
	model:SetAttribute("SlotIndex", 0)
	model:SetAttribute("SpawnTime", os.clock())

	return model
end

-- Spawn one character at the start of the conveyor loop.
function Spawner.Spawn()
	if not map then
		return nil
	end
	local entry = CharacterData.PickWeighted(boostNext)
	boostNext = false

	if entry.Rarity == "Legendary" or entry.Rarity == "Mythic" then
		print("[Spawner] A " .. entry.Rarity .. " " .. entry.Name .. " joined the conveyor!")
	end

	local model = buildCharacter(entry)
	local waypoints = map.Waypoints
	local start = waypoints[1]
	local bodyHalf = 1.5 * entry.Scale
	model:PivotTo(CFrame.new(start.X, map.TrackTopY + bodyHalf, start.Z))
	model.Parent = map.CharactersFolder

	table.insert(active, {
		Model = model,
		WaypointIndex = 2, -- the next corner to walk to
		BornAt = os.clock(),
	})
	return model
end

-- The shop calls this: the next spawn is Epic or better.
function Spawner.BoostNext()
	boostNext = true
end

-- True while the model is still walking the conveyor.
function Spawner.IsOnConveyor(model)
	for _, record in ipairs(active) do
		if record.Model == model then
			return true
		end
	end
	return false
end

-- Take a model off the conveyor list (it was claimed or stolen).
-- The caller moves the model itself afterwards.
function Spawner.RemoveFromConveyor(model)
	for i = #active, 1, -1 do
		if active[i].Model == model then
			table.remove(active, i)
			return true
		end
	end
	return false
end

function Spawner.ConveyorCount()
	return #active
end

-- The models currently walking the conveyor, for debugging and UI.
function Spawner.GetActive()
	local out = {}
	for _, record in ipairs(active) do
		table.insert(out, record.Model)
	end
	return out
end

-- Advance every conveyor character one step toward its next waypoint.
local function stepCharacters(dt, now)
	for i = #active, 1, -1 do
		local record = active[i]
		local model = record.Model
		if not model.Parent then
			table.remove(active, i)
		elseif now - record.BornAt > Config.ConveyorLifetime then
			model:Destroy()
			table.remove(active, i)
		else
			local waypoints = map.Waypoints
			local target = waypoints[record.WaypointIndex]
			local body = model.PrimaryPart
			local pos = body.Position
			local toTarget = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
			local distance = toTarget.Magnitude
			if distance < 0.6 then
				record.WaypointIndex = record.WaypointIndex + 1
				if record.WaypointIndex > #waypoints then
					-- One full lap done: the character leaves.
					model:Destroy()
					table.remove(active, i)
				end
			else
				local step = math.min(distance, Config.ConveyorSpeed * dt)
				local move = toTarget.Unit * step
				local newPos = Vector3.new(pos.X + move.X, pos.Y, pos.Z + move.Z)
				-- Face the walk direction with a slight waddle.
				local yaw = math.atan(-toTarget.X, -toTarget.Z)
				local waddle = math.sin(now * 6 + i) * 0.12
				model:PivotTo(CFrame.new(newPos) * CFrame.Angles(0, yaw + waddle, 0))
			end
		end
	end
end

function Spawner.Start(builtMap)
	map = builtMap
	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		-- Spawn on a timer.
		spawnTimer = spawnTimer + dt
		if spawnTimer >= Config.SpawnInterval then
			spawnTimer = 0
			Spawner.Spawn()
		end
		stepCharacters(dt, now)
	end)
end

function Spawner.Stop()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

return Spawner

-- MapBuilder: constructs the whole Steal a Snackrot arena at runtime.
-- A central conveyor loop, a spawn platform in the middle, and six
-- player plots arranged in a circle around it. Each plot has eight
-- character slots, a lock button, a barrier that closes while the
-- base is locked, a spawn pad and a cash board.
--
-- Everything is built from code (no pre-made models), so the arena
-- is exactly the same every server start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local MapBuilder = {}

local function newPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Build one player plot. plotNumber is 1..6, angle is its position
-- around the circle, center is the map center (Vector3).
local function buildPlot(parent, plotNumber, angle, center)
	local radius = Config.PlotRadius
	local px = center.X + math.cos(angle) * radius
	local pz = center.Z + math.sin(angle) * radius
	local plotPos = Vector3.new(px, 0, pz)
	-- The plot faces the map center: its -Z axis points inward.
	local plotCFrame = CFrame.lookAt(plotPos, center)

	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. plotNumber
	folder.Parent = parent

	-- The base platform.
	local platform = newPart(
		folder,
		"Platform",
		Config.PlotSize,
		plotCFrame * CFrame.new(0, 0.5, 0),
		Color3.fromRGB(90, 120, 200),
		Enum.Material.SmoothPlastic
	)
	platform.CanCollide = true

	-- A colored trim around the platform edge.
	newPart(
		folder,
		"Trim",
		Vector3.new(Config.PlotSize.X + 0.6, 0.3, Config.PlotSize.Z + 0.6),
		plotCFrame * CFrame.new(0, 0.15, 0),
		Color3.fromRGB(255, 210, 60),
		Enum.Material.Neon
	)

	-- Eight character slots in two rows of four.
	local slots = {}
	local slotUsed = {}
	local colOffsets = { -7.5, -2.5, 2.5, 7.5 }
	local rowOffsets = { -4, 4 }
	local slotIndex = 0
	for _, rowZ in ipairs(rowOffsets) do
		for _, colX in ipairs(colOffsets) do
			slotIndex = slotIndex + 1
			local pad = newPart(
				folder,
				"Slot" .. slotIndex,
				Vector3.new(3.4, 0.4, 3.4),
				plotCFrame * CFrame.new(colX, 1.2, rowZ),
				Color3.fromRGB(60, 80, 150),
				Enum.Material.SmoothPlastic
			)
			pad.CanCollide = false
			pad:SetAttribute("PlotNumber", plotNumber)
			pad:SetAttribute("SlotIndex", slotIndex)
			local click = Instance.new("ClickDetector")
			click.MaxActivationDistance = 32
			click.Parent = pad
			CollectionService:AddTag(click, "SnackSlot")
			table.insert(slots, pad)
			slotUsed[slotIndex] = false
		end
	end

	-- Spawn pad: a glowing marker where the owner stands at home.
	local spawnPad = newPart(
		folder,
		"SpawnPad",
		Vector3.new(6, 0.4, 6),
		plotCFrame * CFrame.new(0, 1.2, 7),
		Color3.fromRGB(80, 220, 120),
		Enum.Material.Neon
	)
	spawnPad.CanCollide = false
	local spawnLabel = Instance.new("BillboardGui")
	spawnLabel.Name = "SpawnLabel"
	spawnLabel.Size = UDim2.fromOffset(120, 30)
	spawnLabel.StudsOffset = Vector3.new(0, 2.5, 0)
	spawnLabel.AlwaysOnTop = true
	spawnLabel.Parent = spawnPad
	local spawnText = Instance.new("TextLabel")
	spawnText.Size = UDim2.fromScale(1, 1)
	spawnText.BackgroundTransparency = 1
	spawnText.Text = "BASE " .. plotNumber
	spawnText.TextColor3 = Color3.fromRGB(255, 255, 255)
	spawnText.TextScaled = true
	spawnText.Font = Enum.Font.SourceSansBold
	spawnText.Parent = spawnLabel

	-- Lock button: a red post near the entrance.
	local lockButton = newPart(
		folder,
		"LockButton",
		Vector3.new(2, 3, 2),
		plotCFrame * CFrame.new(9, 2.5, -7),
		Color3.fromRGB(220, 60, 60),
		Enum.Material.Neon
	)
	lockButton:SetAttribute("PlotNumber", plotNumber)
	local lockClick = Instance.new("ClickDetector")
	lockClick.MaxActivationDistance = 32
	lockClick.Parent = lockButton
	CollectionService:AddTag(lockClick, "SnackLock")
	local lockLabel = Instance.new("BillboardGui")
	lockLabel.Name = "LockLabel"
	lockLabel.Size = UDim2.fromOffset(140, 30)
	lockLabel.StudsOffset = Vector3.new(0, 3, 0)
	lockLabel.AlwaysOnTop = true
	lockLabel.Parent = lockButton
	local lockText = Instance.new("TextLabel")
	lockText.Size = UDim2.fromScale(1, 1)
	lockText.BackgroundTransparency = 1
	lockText.Text = "LOCK"
	lockText.TextColor3 = Color3.fromRGB(255, 255, 255)
	lockText.TextScaled = true
	lockText.Font = Enum.Font.SourceSansBold
	lockText.Parent = lockLabel

	-- Barrier across the entrance. Transparent and walk-through
	-- while unlocked; solid while the base is locked.
	local barrier = newPart(
		folder,
		"Barrier",
		Vector3.new(Config.PlotSize.X, 5, 0.6),
		plotCFrame * CFrame.new(0, 3.5, -9),
		Color3.fromRGB(255, 60, 60),
		Enum.Material.ForceField
	)
	barrier.CanCollide = false
	barrier.Transparency = 0.75

	-- Cash board at the back of the plot.
	local board = newPart(
		folder,
		"CashBoard",
		Vector3.new(12, 6, 0.6),
		plotCFrame * CFrame.new(0, 4.5, 8.5),
		Color3.fromRGB(30, 30, 40),
		Enum.Material.SmoothPlastic
	)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "CashGui"
	surface.Face = Enum.NormalId.Front
	surface.AlwaysOnTop = false
	surface.Parent = board
	local boardLabel = Instance.new("TextLabel")
	boardLabel.Name = "CashText"
	boardLabel.Size = UDim2.fromScale(1, 1)
	boardLabel.BackgroundTransparency = 1
	boardLabel.Text = "BASE " .. plotNumber .. "\n(unclaimed)"
	boardLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	boardLabel.TextScaled = true
	boardLabel.Font = Enum.Font.SourceSansBold
	boardLabel.Parent = surface

	return {
		Number = plotNumber,
		OwnerUserId = 0,
		OwnerName = "",
		CFrame = plotCFrame,
		Platform = platform,
		Slots = slots,
		SlotUsed = slotUsed,
		SpawnPad = spawnPad,
		LockButton = lockButton,
		LockLabel = lockText,
		Barrier = barrier,
		BoardLabel = boardLabel,
		LockedUntil = 0,
		LockReadyAt = 0,
	}
end

-- Build the conveyor track: four edge parts forming a rectangular
-- loop, plus yellow corner posts. Returns the walk waypoints.
local function buildConveyor(parent, center)
	local half = Config.ConveyorHalf
	local topY = Config.ConveyorHeight
	local trackColor = Color3.fromRGB(45, 45, 55)
	local edge = 40 -- edge length, covering the corners

	newPart(parent, "TrackNorth", Vector3.new(edge, 1, 4),
		CFrame.new(center.X, topY - 0.5, center.Z - half), trackColor, Enum.Material.SmoothPlastic)
	newPart(parent, "TrackSouth", Vector3.new(edge, 1, 4),
		CFrame.new(center.X, topY - 0.5, center.Z + half), trackColor, Enum.Material.SmoothPlastic)
	newPart(parent, "TrackWest", Vector3.new(4, 1, edge),
		CFrame.new(center.X - half, topY - 0.5, center.Z), trackColor, Enum.Material.SmoothPlastic)
	newPart(parent, "TrackEast", Vector3.new(4, 1, edge),
		CFrame.new(center.X + half, topY - 0.5, center.Z), trackColor, Enum.Material.SmoothPlastic)

	for _, corner in ipairs({
		Vector3.new(center.X - half, topY, center.Z - half),
		Vector3.new(center.X + half, topY, center.Z - half),
		Vector3.new(center.X + half, topY, center.Z + half),
		Vector3.new(center.X - half, topY, center.Z + half),
	}) do
		newPart(parent, "CornerPost", Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(corner), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
	end

	return {
		Vector3.new(center.X - half, topY, center.Z - half),
		Vector3.new(center.X + half, topY, center.Z - half),
		Vector3.new(center.X + half, topY, center.Z + half),
		Vector3.new(center.X - half, topY, center.Z + half),
	}
end

-- Decor: four glowing pillars at the map corners and a floating
-- title sign over the center spawn, so the arena reads as a place
-- and not just a grey floor.
local function buildDecor(parent, center)
	local pillarColor = Color3.fromRGB(255, 180, 40)
	for _, offset in ipairs({
		Vector3.new(-55, 0, -55),
		Vector3.new(55, 0, -55),
		Vector3.new(55, 0, 55),
		Vector3.new(-55, 0, 55),
	}) do
		newPart(parent, "Pillar", Vector3.new(3, 14, 3),
			CFrame.new(center.X + offset.X, 7, center.Z + offset.Z),
			pillarColor, Enum.Material.Neon)
	end

	local sign = newPart(parent, "TitleSign", Vector3.new(22, 4, 0.6),
		CFrame.new(center.X, 12, center.Z), Color3.fromRGB(30, 30, 40), Enum.Material.SmoothPlastic)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local signGui = Instance.new("SurfaceGui")
		signGui.Face = face
		signGui.Parent = sign
		local signText = Instance.new("TextLabel")
		signText.Size = UDim2.fromScale(1, 1)
		signText.BackgroundTransparency = 1
		signText.Text = "STEAL A SNACKROT"
		signText.TextColor3 = Color3.fromRGB(255, 210, 60)
		signText.TextScaled = true
		signText.Font = Enum.Font.SourceSansBold
		signText.Parent = signGui
	end
end

function MapBuilder.Build()
	local workspace = game:GetService("Workspace")
	local center = Vector3.new(0, 0, 0)

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "SnackMap"
	mapFolder.Parent = workspace

	-- Center spawn platform with the SpawnLocation.
	local spawnPlatform = newPart(mapFolder, "CenterPlatform", Vector3.new(14, 1, 14),
		CFrame.new(center.X, 0.5, center.Z), Color3.fromRGB(120, 120, 130), Enum.Material.SmoothPlastic)
	spawnPlatform.CanCollide = true
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.CFrame = CFrame.new(center.X, 1.5, center.Z)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = mapFolder

	local waypoints = buildConveyor(mapFolder, center)

	local plots = {}
	for i = 1, Config.PlotCount do
		local angle = (i - 1) * (math.pi * 2 / Config.PlotCount)
		plots[i] = buildPlot(mapFolder, i, angle, center)
	end

	buildDecor(mapFolder, center)

	-- Folder that will hold every snack character in the game.
	local characters = Instance.new("Folder")
	characters.Name = "Characters"
	characters.Parent = workspace

	return {
		Plots = plots,
		Waypoints = waypoints,
		TrackTopY = Config.ConveyorHeight,
		CharactersFolder = characters,
		SpawnLocation = spawnLocation,
	}
end

return MapBuilder

-- Steal: the heart of the game. It wires every ClickDetector the
-- map and the spawner tagged (SnackCharacter, SnackSlot, SnackLock)
-- and runs the claim / steal / carry / drop / slap loop:
--
-- * Click a conveyor character: claim it into your base (costs its
--   price, needs a free slot).
-- * Click a character in someone else's unlocked base: pick it up
--   and carry it home. Click a free slot in your own base to drop
--   it there; it becomes yours.
-- * Click a loose character (dropped by a slap): claim it for free.
-- * The slap tool knocks a nearby thief back and makes them drop
--   what they carry; the character goes home if its slot is free.
-- * Press E (DropCarried remote) to drop what you carry into your
--   own base, or loose at your feet when no slot is free.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Steal = {}

local deps = nil -- { Map, Spawner, BaseManager, Income, Remotes }
local carriedBy = {} -- [userId] = character model
local lastSlapAt = {} -- [userId] = os.clock of the last slap
local slapTemplate = nil
local carryWatcherStarted = false

-- Send a short hint to one player's screen.
local function tell(player, message)
	local remote = deps.Remotes.ClaimResult
	if remote then
		remote:FireClient(player, message)
	end
end

-- Send a player their current owned-character list for the base panel.
local function sendBaseUpdate(player)
	local remote = deps.Remotes.BaseUpdate
	if not remote then
		return
	end
	local list = {}
	local characters = Workspace:FindFirstChild("Characters")
	if characters then
		for _, model in ipairs(characters:GetChildren()) do
			if model:GetAttribute("State") == "owned"
				and model:GetAttribute("OwnerUserId") == player.UserId
			then
				table.insert(list, {
					Name = model:GetAttribute("CharName"),
					Rarity = model:GetAttribute("Rarity"),
					Income = model:GetAttribute("Income"),
				})
			end
		end
	end
	local plot = deps.BaseManager.GetPlotByOwner(player.UserId)
	local plotNumber = plot and plot.Number or 0
	remote:FireClient(player, list, plotNumber)
end

function Steal.SendBaseUpdate(player)
	sendBaseUpdate(player)
end

-- Put a character into a base slot and make it owned.
local function placeInBase(player, model, plot)
	local BaseManager = deps.BaseManager
	local slotIndex = BaseManager.FindFreeSlot(plot)
	if not slotIndex then
		return false, "Your base is full."
	end
	BaseManager.PlaceOnSlot(model, plot, slotIndex)
	sendBaseUpdate(player)
	return true, ""
end

-- Claim a conveyor character (costs its price) or a loose one (free).
local function claimCharacter(player, model)
	local state = model:GetAttribute("State")
	local cost = 0
	if state == "conveyor" then
		cost = model:GetAttribute("Cost") or 0
	elseif state == "loose" then
		cost = 0
	else
		return
	end

	local BaseManager = deps.BaseManager
	local plot = BaseManager.GetPlotByOwner(player.UserId)
	if not plot then
		tell(player, "You do not have a base yet.")
		return
	end
	if not BaseManager.FindFreeSlot(plot) then
		tell(player, "Your base is full.")
		return
	end
	if deps.Income.GetCash(player) < cost then
		tell(player, "Not enough Cash: " .. (model:GetAttribute("CharName") or "this") .. " costs $" .. cost .. ".")
		return
	end

	deps.Spawner.RemoveFromConveyor(model)
	if cost > 0 then
		deps.Income.AddCash(player, -cost)
	end
	local ok, err = placeInBase(player, model, plot)
	if ok then
		tell(player, "Claimed " .. (model:GetAttribute("CharName") or "a character") .. "!")
	else
		tell(player, err)
	end
end

-- Pick a character up off a base slot and carry it.
local function pickUp(player, model)
	if carriedBy[player.UserId] then
		tell(player, "You are already carrying something.")
		return
	end
	local homePlotNumber = model:GetAttribute("HomePlot") or 0
	local homeSlot = model:GetAttribute("SlotIndex") or 0
	local plot = deps.BaseManager.GetPlot(homePlotNumber)
	if plot then
		deps.BaseManager.FreeSlot(plot, homeSlot)
		-- The victim's base panel updates right away too.
		local victim = Players:GetPlayerByUserId(plot.OwnerUserId)
		if victim then
			sendBaseUpdate(victim)
		end
	end
	model:SetAttribute("State", "carried")
	model:SetAttribute("CarriedBy", player.UserId)
	carriedBy[player.UserId] = model
	tell(player, "Carrying " .. (model:GetAttribute("CharName") or "a character") .. " — bring it to your base!")
end

-- Drop what a player carries. If returnHome is true the character
-- goes back to its home slot when that slot is free, otherwise it
-- becomes loose where the player stands. A nil player (they left)
-- just leaves the character loose where it is.
local function dropCarried(player, returnHome)
	local model = player and carriedBy[player.UserId]
	if player then
		carriedBy[player.UserId] = nil
	end
	if not model or not model.Parent then
		return
	end
	model:SetAttribute("CarriedBy", 0)

	if returnHome and player then
		local homePlotNumber = model:GetAttribute("HomePlot") or 0
		local homeSlot = model:GetAttribute("SlotIndex") or 0
		local plot = deps.BaseManager.GetPlot(homePlotNumber)
		if plot and homeSlot > 0 and not plot.SlotUsed[homeSlot] then
			deps.BaseManager.PlaceOnSlot(model, plot, homeSlot)
			local owner = Players:GetPlayerByUserId(plot.OwnerUserId)
			if owner then
				sendBaseUpdate(owner)
			end
			return
		end
	end

	-- Loose on the ground at the player's feet, free for anyone.
	local scale = model:GetAttribute("Scale") or 1
	if player then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local pos = root.Position
			model:PivotTo(CFrame.new(pos.X, pos.Y, pos.Z + 2) * CFrame.Angles(0, 0, 0))
			model:SetAttribute("State", "loose")
			model:SetAttribute("OwnerUserId", 0)
			return
		end
	end
	-- No player to drop from: leave it where it floats, marked loose.
	model:SetAttribute("State", "loose")
	model:SetAttribute("OwnerUserId", 0)
end

-- A player clicked a character model.
local function onCharacterClicked(player, model)
	if not model or not model.Parent then
		return
	end
	local state = model:GetAttribute("State")
	if state == "carried" then
		return
	elseif state == "conveyor" or state == "loose" then
		claimCharacter(player, model)
	elseif state == "owned" then
		local ownerId = model:GetAttribute("OwnerUserId") or 0
		if ownerId == player.UserId then
			tell(player, "That one is already yours.")
			return
		end
		local plot = deps.BaseManager.GetPlot(model:GetAttribute("HomePlot") or 0)
		if plot and deps.BaseManager.IsLocked(plot) then
			tell(player, "That base is locked.")
			return
		end
		pickUp(player, model)
	end
end

-- A player clicked a slot pad while (maybe) carrying something.
local function onSlotClicked(player, pad)
	local model = carriedBy[player.UserId]
	if not model then
		return
	end
	local plotNumber = pad:GetAttribute("PlotNumber") or 0
	local slotIndex = pad:GetAttribute("SlotIndex") or 0
	local plot = deps.BaseManager.GetPlot(plotNumber)
	if not plot or plot.OwnerUserId ~= player.UserId then
		tell(player, "That is not your base.")
		return
	end
	if plot.SlotUsed[slotIndex] then
		tell(player, "That slot is taken.")
		return
	end
	carriedBy[player.UserId] = nil
	model:SetAttribute("CarriedBy", 0)
	deps.BaseManager.PlaceOnSlot(model, plot, slotIndex)
	sendBaseUpdate(player)
	tell(player, "Stolen! " .. (model:GetAttribute("CharName") or "A character") .. " is yours now.")
end

-- A player clicked a base lock button.
local function onLockClicked(player, button)
	local plotNumber = button:GetAttribute("PlotNumber") or 0
	local plot = deps.BaseManager.GetPlot(plotNumber)
	if not plot then
		return
	end
	local ok, message = deps.BaseManager.LockPlot(player, plot)
	tell(player, message)
end

-- Slap: knock the nearest other player in front of you back. If
-- they carry something, they drop it (it goes home when possible).
local function doSlap(player)
	local now = os.clock()
	local last = lastSlapAt[player.UserId] or 0
	if now - last < deps.Config.SlapCooldown then
		return
	end
	lastSlapAt[player.UserId] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local myPos = root.Position
	local look = root.CFrame.LookVector
	local best = nil
	local bestDistance = deps.Config.SlapRange
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local offset = otherRoot.Position - myPos
				local distance = offset.Magnitude
				if distance <= deps.Config.SlapRange and distance > 0.01 then
					local facing = look:Dot(offset.Unit)
					if facing > 0.2 and distance < bestDistance then
						best = other
						bestDistance = distance
					end
				end
			end
		end
	end
	if not best or not best.Character then
		return
	end
	local targetRoot = best.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		return
	end
	local direction = (targetRoot.Position - myPos).Unit
	local mass = targetRoot.AssemblyMass
	local impulse = direction * deps.Config.SlapImpulse * mass
	impulse = Vector3.new(impulse.X, 8 * mass, impulse.Z)
	targetRoot:ApplyImpulse(impulse)
	local humanoid = best.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local oldSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
		task.delay(0.5, function()
			if humanoid.Parent then
				humanoid.WalkSpeed = oldSpeed
			end
		end)
	end
	if carriedBy[best.UserId] then
		dropCarried(best, true)
		tell(best, "You were slapped and dropped what you carried!")
		tell(player, "Slapped " .. best.Name .. " — they dropped it!")
	else
		tell(best, player.Name .. " slapped you!")
		tell(player, "Slapped " .. best.Name .. "!")
	end
end

-- Build the slap tool template once; clones are handed out on spawn.
local function buildSlapTemplate()
	local tool = Instance.new("Tool")
	tool.Name = "Slap"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 3)
	handle.Color = Color3.fromRGB(255, 220, 120)
	handle.Material = Enum.Material.SmoothPlastic
	handle.Anchored = false
	handle.CanCollide = false
	handle.Parent = tool
	tool.Parent = nil
	return tool
end

function Steal.GiveSlapTool(player)
	if not slapTemplate then
		slapTemplate = buildSlapTemplate()
	end
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end
	-- Remove any older slap tool first so there is exactly one.
	for _, item in ipairs(backpack:GetChildren()) do
		if item.Name == "Slap" then
			item:Destroy()
		end
	end
	local tool = slapTemplate:Clone()
	tool.Activated:Connect(function()
		doSlap(player)
	end)
	tool.Parent = backpack
end

-- Keep carried characters floating above their carrier's head.
local function startCarryWatcher()
	if carryWatcherStarted then
		return
	end
	carryWatcherStarted = true
	RunService.Heartbeat:Connect(function()
		for userId, model in pairs(carriedBy) do
			local player = Players:GetPlayerByUserId(userId)
			local character = player and player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not model.Parent then
				carriedBy[userId] = nil
			elseif not player then
				-- The carrier left the game: the character goes
				-- loose exactly where it is.
				carriedBy[userId] = nil
				model:SetAttribute("CarriedBy", 0)
				model:SetAttribute("State", "loose")
				model:SetAttribute("OwnerUserId", 0)
			elseif not root then
				-- The carrier's character died or is respawning.
				dropCarried(player, false)
				carriedBy[userId] = nil
			else
				local pos = root.Position
				model:PivotTo(CFrame.new(pos.X, pos.Y + deps.Config.CarryHeight, pos.Z))
			end
		end
	end)
end

function Steal.Init(dependencies)
	deps = dependencies
	startCarryWatcher()

	-- Drop with the E key (the client fires DropCarried).
	deps.Remotes.DropCarried.OnServerEvent:Connect(function(player)
		local model = carriedBy[player.UserId]
		if not model then
			return
		end
		local plot = deps.BaseManager.GetPlotByOwner(player.UserId)
		if plot and deps.BaseManager.FindFreeSlot(plot) then
			carriedBy[player.UserId] = nil
			model:SetAttribute("CarriedBy", 0)
			deps.BaseManager.PlaceOnSlot(model, plot, deps.BaseManager.FindFreeSlot(plot))
			sendBaseUpdate(player)
			tell(player, "Dropped it in your base.")
		else
			dropCarried(player, false)
			tell(player, "No free slot — dropped it loose.")
		end
	end)

	local function wire(tag, handler)
		for _, click in ipairs(CollectionService:GetTagged(tag)) do
			if click:IsA("ClickDetector") then
				click.MouseClick:Connect(function(player)
					handler(player, click.Parent)
				end)
			end
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(click)
			if click:IsA("ClickDetector") then
				click.MouseClick:Connect(function(player)
					handler(player, click.Parent)
				end)
			end
		end)
	end

	-- For characters the clicked instance is the body part; the
	-- model is its parent.
	wire("SnackCharacter", function(player, bodyPart)
		local model = bodyPart and bodyPart.Parent
		if model and model:IsA("Model") then
			onCharacterClicked(player, model)
		end
	end)
	wire("SnackSlot", function(player, pad)
		onSlotClicked(player, pad)
	end)
	wire("SnackLock", function(player, button)
		onLockClicked(player, button)
	end)
end

return Steal

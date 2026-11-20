-- BaseManager: owns the six player plots. It assigns a plot when a
-- player joins, tracks which of the eight slots in each base are
-- taken, places and removes characters on slots, runs the base lock
-- (60 seconds locked, then a cooldown), and keeps each base's cash
-- board up to date. It also releases a plot when its owner leaves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local BaseManager = {}

local plots = {}
local lockWatcherStarted = false

function BaseManager.Init(builtMap)
	plots = builtMap.Plots
	if not lockWatcherStarted then
		lockWatcherStarted = true
		task.spawn(function()
			while true do
				task.wait(1)
				local now = os.clock()
				for _, plot in ipairs(plots) do
					if plot.LockedUntil > 0 and now >= plot.LockedUntil then
						BaseManager.UnlockPlot(plot)
					end
				end
			end
		end)
	end
end

function BaseManager.GetPlots()
	return plots
end

function BaseManager.GetPlot(number)
	return plots[number]
end

function BaseManager.GetPlotByOwner(userId)
	for _, plot in ipairs(plots) do
		if plot.OwnerUserId == userId then
			return plot
		end
	end
	return nil
end

-- Give the joining player the first unclaimed plot, if any.
function BaseManager.AssignPlot(player)
	for _, plot in ipairs(plots) do
		if plot.OwnerUserId == 0 then
			plot.OwnerUserId = player.UserId
			plot.OwnerName = player.Name
			BaseManager.UpdateBoard(plot)
			return plot
		end
	end
	return nil
end

-- Free the plot when its owner leaves: every character they owned
-- is removed and the base goes back to unclaimed.
function BaseManager.ReleasePlot(userId)
	local plot = BaseManager.GetPlotByOwner(userId)
	if not plot then
		return
	end
	local characters = game:GetService("Workspace"):FindFirstChild("Characters")
	if characters then
		for _, model in ipairs(characters:GetChildren()) do
			if model:GetAttribute("OwnerUserId") == userId then
				model:Destroy()
			end
		end
	end
	for i = 1, #plot.SlotUsed do
		plot.SlotUsed[i] = false
	end
	plot.OwnerUserId = 0
	plot.OwnerName = ""
	BaseManager.UnlockPlot(plot)
	plot.LockReadyAt = 0
	BaseManager.UpdateBoard(plot)
end

function BaseManager.FindFreeSlot(plot)
	for i = 1, #plot.Slots do
		if not plot.SlotUsed[i] then
			return i
		end
	end
	return nil
end

-- The combined income per second of every character in a plot.
function BaseManager.GetPlotIncome(plot)
	local total = 0
	local characters = game:GetService("Workspace"):FindFirstChild("Characters")
	if characters then
		for _, model in ipairs(characters:GetChildren()) do
			if model:GetAttribute("State") == "owned"
				and model:GetAttribute("HomePlot") == plot.Number
			then
				total = total + (model:GetAttribute("Income") or 0)
			end
		end
	end
	return total
end

-- Put a character model on a slot pad. The model is anchored and
-- posed on the pad, facing the same way as the base.
function BaseManager.PlaceOnSlot(model, plot, slotIndex)
	local pad = plot.Slots[slotIndex]
	if not pad then
		return false
	end
	plot.SlotUsed[slotIndex] = true
	local scale = model:GetAttribute("Scale") or 1
	local padCF = pad.CFrame
	local rotation = padCF - padCF.Position
	local topY = 1.4
	local newPos = Vector3.new(padCF.Position.X, topY + 1.5 * scale, padCF.Position.Z)
	model:PivotTo(CFrame.new(newPos) * rotation)
	model:SetAttribute("State", "owned")
	model:SetAttribute("HomePlot", plot.Number)
	model:SetAttribute("SlotIndex", slotIndex)
	model:SetAttribute("OwnerUserId", plot.OwnerUserId)
	return true
end

-- Mark a slot empty again. The caller decides what happens to the
-- character model itself.
function BaseManager.FreeSlot(plot, slotIndex)
	if plot and slotIndex and plot.SlotUsed[slotIndex] ~= nil then
		plot.SlotUsed[slotIndex] = false
	end
end

function BaseManager.IsLocked(plot)
	return plot.LockedUntil > 0 and os.clock() < plot.LockedUntil
end

-- The owner locks their base: thieves cannot steal from it and the
-- barrier across the entrance turns solid for LockDuration seconds.
function BaseManager.LockPlot(player, plot)
	if not plot or plot.OwnerUserId ~= player.UserId then
		return false, "That is not your base."
	end
	local now = os.clock()
	if BaseManager.IsLocked(plot) then
		return false, "Your base is already locked."
	end
	if now < plot.LockReadyAt then
		local wait = math.ceil(plot.LockReadyAt - now)
		return false, "Lock is recharging: " .. wait .. "s left."
	end
	plot.LockedUntil = now + Config.LockDuration
	plot.LockReadyAt = now + Config.LockDuration + Config.LockCooldown
	plot.Barrier.CanCollide = true
	plot.Barrier.Transparency = 0.3
	plot.LockButton.Color = Color3.fromRGB(80, 220, 120)
	plot.LockLabel.Text = "LOCKED"
	BaseManager.UpdateBoard(plot)
	return true, "Base locked for " .. Config.LockDuration .. " seconds."
end

function BaseManager.UnlockPlot(plot)
	plot.LockedUntil = 0
	plot.Barrier.CanCollide = false
	plot.Barrier.Transparency = 0.75
	plot.LockButton.Color = Color3.fromRGB(220, 60, 60)
	plot.LockLabel.Text = "LOCK"
	BaseManager.UpdateBoard(plot)
end

-- Refresh a base's cash board from its owner's leaderstats.
function BaseManager.UpdateBoard(plot)
	if not plot then
		return
	end
	if plot.OwnerUserId == 0 then
		plot.BoardLabel.Text = "BASE " .. plot.Number .. "\n(unclaimed)"
		return
	end
	local cashText = "$?"
	local player = Players:GetPlayerByUserId(plot.OwnerUserId)
	if player then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local cash = leaderstats:FindFirstChild("Cash")
			if cash then
				cashText = "$" .. tostring(cash.Value)
			end
		end
	end
	local line = "BASE " .. plot.Number .. "\n" .. plot.OwnerName .. "\n" .. cashText
		.. "\n$" .. BaseManager.GetPlotIncome(plot) .. "/s"
	if BaseManager.IsLocked(plot) then
		line = line .. "\nLOCKED"
	end
	plot.BoardLabel.Text = line
end

function BaseManager.UpdateAllBoards()
	for _, plot in ipairs(plots) do
		BaseManager.UpdateBoard(plot)
	end
end

return BaseManager

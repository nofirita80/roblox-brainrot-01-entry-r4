-- Income: pays every owned snack character's income to its owner
-- once per second. Characters only earn while they sit in a base
-- (State "owned"); conveyor, carried and loose characters earn
-- nothing. The base cash boards refresh on the same tick.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Income = {}

local BaseManager = nil
local Config = nil
local running = false

local function getCashValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end
	return leaderstats:FindFirstChild("Cash")
end

function Income.AddCash(player, amount)
	local cash = getCashValue(player)
	if cash then
		cash.Value = math.clamp(cash.Value + amount, 0, Config.MaxCash)
		return cash.Value
	end
	return nil
end

function Income.GetCash(player)
	local cash = getCashValue(player)
	if cash then
		return cash.Value
	end
	return 0
end

-- The combined income per second of everything a player owns.
function Income.GetTotalIncome(player)
	local total = 0
	local characters = Workspace:FindFirstChild("Characters")
	if characters then
		for _, model in ipairs(characters:GetChildren()) do
			if model:GetAttribute("State") == "owned"
				and model:GetAttribute("OwnerUserId") == player.UserId
			then
				total = total + (model:GetAttribute("Income") or 0)
			end
		end
	end
	return total
end

local function payTick()
	local characters = Workspace:FindFirstChild("Characters")
	if not characters then
		return
	end
	for _, model in ipairs(characters:GetChildren()) do
		if model:GetAttribute("State") == "owned" then
			local ownerId = model:GetAttribute("OwnerUserId") or 0
			if ownerId > 0 then
				local player = Players:GetPlayerByUserId(ownerId)
				if player then
					local income = model:GetAttribute("Income") or 0
					Income.AddCash(player, income)
				end
			end
		end
	end
	if BaseManager then
		BaseManager.UpdateAllBoards()
	end
end

function Income.Start(baseManagerModule, configModule)
	BaseManager = baseManagerModule
	Config = configModule
	if running then
		return
	end
	running = true
	task.spawn(function()
		while running do
			task.wait(Config.IncomeTick)
			payTick()
		end
	end)
end

function Income.Stop()
	running = false
end

return Income

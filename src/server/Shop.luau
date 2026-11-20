-- Shop: two real items bought with Cash. The Spawn Boost makes the
-- next conveyor character Epic or better; the Speed Coil raises the
-- buyer's walk speed for a minute. Purchases are validated on the
-- server (cash is checked and deducted here, never on the client).

local Players = game:GetService("Players")

local Shop = {}

local deps = nil -- { Spawner, Income, Config, Remotes }
local coilExpiresAt = {} -- [userId] = os.clock when the coil ends

-- Re-apply the coil speed when a player respawns while it is active.
function Shop.ApplyCoilIfActive(player)
	local expires = coilExpiresAt[player.UserId]
	if not expires or os.clock() >= expires then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = deps.Config.CoilWalkSpeed
	end
end

local function buyBoost(player)
	deps.Spawner.BoostNext()
	return "Spawn Boost armed — the next character is Epic or better!"
end

local function buyCoil(player, item)
	local duration = item.Duration or 60
	coilExpiresAt[player.UserId] = os.clock() + duration
	Shop.ApplyCoilIfActive(player)
	-- Restore normal speed when the coil runs out.
	task.delay(duration, function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and os.clock() >= (coilExpiresAt[player.UserId] or 0) then
			humanoid.WalkSpeed = deps.Config.NormalWalkSpeed
		end
	end)
	return "Speed Coil active for " .. duration .. " seconds!"
end

local handlers = {
	boost = buyBoost,
	coil = buyCoil,
}

function Shop.Init(dependencies)
	deps = dependencies
	deps.Remotes.ShopBuy.OnServerEvent:Connect(function(player, itemId)
		local item = deps.Config.GetShopItem(itemId)
		if not item then
			deps.Remotes.ClaimResult:FireClient(player, "No such shop item.")
			return
		end
		if deps.Income.GetCash(player) < item.Cost then
			deps.Remotes.ClaimResult:FireClient(
				player,
				"Not enough Cash: " .. item.Name .. " costs $" .. item.Cost .. "."
			)
			return
		end
		local handler = handlers[itemId]
		if not handler then
			deps.Remotes.ClaimResult:FireClient(player, "That item is not for sale.")
			return
		end
		deps.Income.AddCash(player, -item.Cost)
		local message = handler(player, item)
		deps.Remotes.ClaimResult:FireClient(player, message)
	end)

	-- If a player leaves, forget their coil timer.
	Players.PlayerRemoving:Connect(function(player)
		coilExpiresAt[player.UserId] = nil
	end)
end

return Shop

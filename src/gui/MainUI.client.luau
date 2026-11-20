-- MainUI (client): every on-screen element for Steal a Snackrot,
-- built in code. A cash counter, a hint line for server messages,
-- a shop window, and a panel listing the characters in your base.
-- The server drives it through the ClaimResult and BaseUpdate
-- remotes; the shop buys go back through ShopBuy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local claimResult = remotes:WaitForChild("ClaimResult")
local baseUpdate = remotes:WaitForChild("BaseUpdate")
local shopBuy = remotes:WaitForChild("ShopBuy")

local gui = Instance.new("ScreenGui")
gui.Name = "SnackGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function makeLabel(parent, name, text, size, position, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize
	label.Font = Enum.Font.SourceSansBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Cash counter, top left.
local cashFrame = Instance.new("Frame")
cashFrame.Name = "CashFrame"
cashFrame.AnchorPoint = Vector2.new(0, 0)
cashFrame.Position = UDim2.fromOffset(12, 12)
cashFrame.Size = UDim2.fromOffset(220, 52)
cashFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
cashFrame.BackgroundTransparency = 0.25
cashFrame.BorderSizePixel = 0
cashFrame.Parent = gui

local cashLabel = makeLabel(cashFrame, "CashLabel", "Cash: $0",
	UDim2.fromScale(1, 1), UDim2.fromOffset(12, 0), 26)
cashLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Shop button, top right.
local shopButton = Instance.new("TextButton")
shopButton.Name = "ShopButton"
shopButton.AnchorPoint = Vector2.new(1, 0)
shopButton.Position = UDim2.new(1, -12, 0, 12)
shopButton.Size = UDim2.fromOffset(110, 52)
shopButton.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
shopButton.Text = "SHOP"
shopButton.TextColor3 = Color3.fromRGB(40, 30, 0)
shopButton.TextSize = 26
shopButton.Font = Enum.Font.SourceSansBold
shopButton.Parent = gui

-- Base panel, left side under the cash counter.
local baseFrame = Instance.new("Frame")
baseFrame.Name = "BaseFrame"
baseFrame.Position = UDim2.fromOffset(12, 76)
baseFrame.Size = UDim2.fromOffset(260, 260)
baseFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
baseFrame.BackgroundTransparency = 0.25
baseFrame.BorderSizePixel = 0
baseFrame.Parent = gui

local baseTitle = makeLabel(baseFrame, "BaseTitle", "YOUR BASE", UDim2.fromOffset(240, 30),
	UDim2.fromOffset(12, 8), 20)

local baseList = makeLabel(baseFrame, "BaseList", "No characters yet.\nClaim snacks from the conveyor!",
	UDim2.fromOffset(240, 210), UDim2.fromOffset(12, 42), 16)
baseList.TextYAlignment = Enum.TextYAlignment.Top

-- Hint line, bottom center.
local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -24)
hintLabel.Size = UDim2.fromOffset(640, 40)
hintLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Text = ""
hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hintLabel.TextSize = 20
hintLabel.Font = Enum.Font.SourceSansBold
hintLabel.Visible = false
hintLabel.Parent = gui

local hintHideAt = 0
local function showHint(message)
	hintLabel.Text = message
	hintLabel.Visible = true
	hintHideAt = os.clock() + 4
end

-- Hide the hint a few seconds after it appears.
task.spawn(function()
	while true do
		task.wait(0.5)
		if hintLabel.Visible and os.clock() >= hintHideAt then
			hintLabel.Visible = false
		end
	end
end)

-- Shop window, hidden until the Shop button is pressed.
local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.AnchorPoint = Vector2.new(1, 0)
shopFrame.Position = UDim2.new(1, -12, 0, 76)
shopFrame.Size = UDim2.fromOffset(320, 220)
shopFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
shopFrame.BackgroundTransparency = 0.15
shopFrame.BorderSizePixel = 0
shopFrame.Visible = false
shopFrame.Parent = gui

makeLabel(shopFrame, "ShopTitle", "SHOP", UDim2.fromOffset(300, 30),
	UDim2.fromOffset(12, 8), 22)

local shopY = 48
for _, item in ipairs(Config.Shop) do
	local row = Instance.new("Frame")
	row.Name = "Item_" .. item.Id
	row.Position = UDim2.fromOffset(12, shopY)
	row.Size = UDim2.fromOffset(296, 76)
	row.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	row.BorderSizePixel = 0
	row.Parent = shopFrame

	makeLabel(row, "Name", item.Name, UDim2.fromOffset(200, 24),
		UDim2.fromOffset(10, 6), 18)
	makeLabel(row, "Desc", item.Description, UDim2.fromOffset(200, 40),
		UDim2.fromOffset(10, 30), 13)

	local buy = Instance.new("TextButton")
	buy.Name = "Buy_" .. item.Id
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -10, 0.5, 0)
	buy.Size = UDim2.fromOffset(80, 40)
	buy.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
	buy.Text = "$" .. item.Cost
	buy.TextColor3 = Color3.fromRGB(20, 50, 20)
	buy.TextSize = 18
	buy.Font = Enum.Font.SourceSansBold
	buy.Parent = row

	local itemId = item.Id
	buy.MouseButton1Click:Connect(function()
		shopBuy:FireServer(itemId)
	end)
	shopY = shopY + 84
end

shopButton.MouseButton1Click:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
end)

-- Cash counter follows the leaderstats value.
local leaderstats = player:WaitForChild("leaderstats")
local cash = leaderstats:WaitForChild("Cash")
local function refreshCash()
	cashLabel.Text = "Cash: $" .. tostring(cash.Value)
end
cash:GetPropertyChangedSignal("Value"):Connect(refreshCash)
refreshCash()

-- Server messages and base contents.
claimResult.OnClientEvent:Connect(function(message)
	showHint(message)
end)

baseUpdate.OnClientEvent:Connect(function(list, plotNumber)
	if plotNumber and plotNumber > 0 then
		baseTitle.Text = "YOUR BASE — Base " .. plotNumber
	else
		baseTitle.Text = "YOUR BASE"
	end
	if #list == 0 then
		baseList.Text = "No characters yet.\nClaim snacks from the conveyor!"
		return
	end
	local lines = {}
	local total = 0
	for _, entry in ipairs(list) do
		total = total + (entry.Income or 0)
		table.insert(lines, entry.Name .. " (" .. entry.Rarity .. ")  $" .. (entry.Income or 0) .. "/s")
	end
	table.insert(lines, "")
	table.insert(lines, "Total: $" .. total .. "/s  (" .. #list .. "/8 slots)")
	baseList.Text = table.concat(lines, "\n")
end)

showHint("Claim snacks from the conveyor, then defend your base!")

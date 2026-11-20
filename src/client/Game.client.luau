-- Game (client): the player's local controls for Steal a Snackrot.
-- Press E to drop whatever you are carrying into your own base
-- (or loose at your feet when the base is full). Everything else
-- the player does — clicking characters, slots and lock buttons —
-- is handled by the server through ClickDetectors, and all of the
-- on-screen UI lives in MainUI under StarterGui.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local dropCarried = remotes:WaitForChild("DropCarried")

local function onDropAction(_actionName, inputState, _inputObject)
	if inputState == Enum.UserInputState.Begin then
		dropCarried:FireServer()
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("DropCarried", onDropAction, false, Enum.KeyCode.E)

-- Keep the binding alive across respawns; ContextActionService
-- bindings survive them, but re-binding costs nothing and guards
-- against any client reset.
player.CharacterAdded:Connect(function()
	ContextActionService:BindAction("DropCarried", onDropAction, false, Enum.KeyCode.E)
end)

-- An on-screen DROP button for touch players, who have no E key.
-- It fires the same remote; the server ignores it when the player
-- is not carrying anything.
local playerGui = player:WaitForChild("PlayerGui")
local dropGui = Instance.new("ScreenGui")
dropGui.Name = "DropGui"
dropGui.ResetOnSpawn = false
dropGui.Parent = playerGui

local dropButton = Instance.new("TextButton")
dropButton.Name = "DropButton"
dropButton.AnchorPoint = Vector2.new(1, 1)
dropButton.Position = UDim2.new(1, -16, 1, -90)
dropButton.Size = UDim2.fromOffset(110, 56)
dropButton.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
dropButton.Text = "DROP (E)"
dropButton.TextColor3 = Color3.fromRGB(40, 30, 0)
dropButton.TextSize = 22
dropButton.Font = Enum.Font.SourceSansBold
dropButton.Parent = dropGui

dropButton.MouseButton1Click:Connect(function()
	dropCarried:FireServer()
end)

-- StarterPlayerScripts/GlobalEventUI.client.lua
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")

local EvShow = Remotes:WaitForChild("GlobalEventShow")
local EvHide = Remotes:WaitForChild("GlobalEventHide")

local plr = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "WorldEventUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn   = false
gui.Enabled        = false   -- vigtig for UIPanelStack
gui.Parent = plr:WaitForChild("PlayerGui")

-- Panel (samme naming/stil som Shrine/Horde)
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.fromScale(0.5, 0.06) -- UIPanelStack flytter evt.
panel.Size = UDim2.new(0, 520, 0, 66)
panel.BackgroundColor3 = Color3.fromRGB(25,25,25)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(255,120,100)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextColor3 = Color3.fromRGB(255,210,210)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.Text = "World Event"
title.Parent = panel

local body = Instance.new("TextLabel")
body.Size = UDim2.new(1, -16, 0, 24)
body.Position = UDim2.new(0, 8, 0, 36)
body.BackgroundTransparency = 1
body.TextXAlignment = Enum.TextXAlignment.Center
body.TextColor3 = Color3.fromRGB(230,230,230)
body.Font = Enum.Font.Gotham
body.TextScaled = true
body.Text = ""
body.Parent = panel

-- Remotes
EvShow.OnClientEvent:Connect(function(payload)
	payload = typeof(payload)=="table" and payload or {}
	title.Text = tostring(payload.title or "World Event")
	body.Text  = tostring(payload.desc or "")
	if typeof(payload.borderColor)=="Color3" then stroke.Color = payload.borderColor end
	gui.Enabled = true
	panel.Visible = true
end)

EvHide.OnClientEvent:Connect(function()
	panel.Visible = false
	gui.Enabled = false
end)

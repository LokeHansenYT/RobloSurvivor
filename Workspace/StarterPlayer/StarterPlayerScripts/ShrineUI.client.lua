-- StarterPlayerScripts/ShrineUI.client.lua
-- Kompakt top-panel for aktive shrines. Lægges over Horde UI.

local Players  = game:GetService("Players")
local RS       = game:GetService("ReplicatedStorage")
local Remotes  = RS:WaitForChild("Remotes")

local EvShow = Remotes:WaitForChild("ShrineShow")
local EvHide = Remotes:WaitForChild("ShrineHide")

local plr = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "ShrineUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn   = false
gui.Enabled        = false
gui.DisplayOrder   = 20 -- over Horde (som vi sætter til 19)
gui.Parent = plr:WaitForChild("PlayerGui")

local RARITY_COLORS = {
	Common    = Color3.fromRGB(220,220,220),
	Uncommon  = Color3.fromRGB(120,255,180),
	Rare      = Color3.fromRGB(110,200,255),
	Epic      = Color3.fromRGB(170,120,255),
	Legendary = Color3.fromRGB(255,180,80),
	Mythic    = Color3.fromRGB(255,210,110),
	Divine    = Color3.fromRGB(255,245,130),
}

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.fromScale(0.5, 0.06) -- øverst
panel.Size = UDim2.new(0, 520, 0, 66)
panel.BackgroundColor3 = Color3.fromRGB(25,25,25)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 5
panel.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(200,200,200)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.ZIndex = 6
title.Text = "Shrine"
title.Parent = panel

local body = Instance.new("TextLabel")
body.Name = "Body"
body.Size = UDim2.new(1, -16, 0, 24)
body.Position = UDim2.new(0, 8, 0, 36)
body.BackgroundTransparency = 1
body.TextXAlignment = Enum.TextXAlignment.Center
body.TextColor3 = Color3.fromRGB(230,230,230)
body.Font = Enum.Font.Gotham
body.TextScaled = true
body.ZIndex = 6
body.Text = "Effects"
body.Parent = panel

local function setRarityBorder(rarity)
	rarity = typeof(rarity) == "string" and rarity or "Common"
	local col = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	stroke.Color = col
end

EvShow.OnClientEvent:Connect(function(payload)
	payload = typeof(payload) == "table" and payload or {}
	title.Text = tostring(payload.title or "Shrine")
	body.Text  = tostring(payload.desc  or "")
	setRarityBorder(payload.rarity)
	gui.Enabled = true
	panel.Visible = true
end)

EvHide.OnClientEvent:Connect(function()
	panel.Visible = false
	gui.Enabled = false
end)

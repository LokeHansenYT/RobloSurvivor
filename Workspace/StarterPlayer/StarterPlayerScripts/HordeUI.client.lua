-- StarterPlayerScripts/HordeUI.client.lua
-- Viser Horde Mode overlay + panel.
-- Lægger sig ALTID i top, medmindre Shrine-panelet også er synligt — så rykker Horde ned under Shrine.
-- (ShrineUI har DisplayOrder 20, HordeUI har 19 ? Shrine ligger visuelt ovenpå, når begge er åbne.)

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")

-- Disse remotes skabes i InitRemotes.server.lua
local EvShow   = Remotes:WaitForChild("HordeShow")
local EvHide   = Remotes:WaitForChild("HordeHide")
local EvUpdate = Remotes:WaitForChild("HordeUpdate")

local plr = Players.LocalPlayer
local pg  = plr:WaitForChild("PlayerGui")

-- Egen GUI
local gui = Instance.new("ScreenGui")
gui.Name = "HordeUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn   = false
gui.Enabled        = false
gui.DisplayOrder   = 19 -- under ShrineUI (20)
gui.Parent = pg

-- Overlay
local overlay = Instance.new("Frame")
overlay.BackgroundColor3 = Color3.fromRGB(160, 0, 0)
overlay.BackgroundTransparency = 0.92
overlay.BorderSizePixel = 0
overlay.Size = UDim2.fromScale(1,1)
overlay.Visible = true
overlay.Parent = gui

-- Panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Size = UDim2.new(0, 560, 0, 54)
panel.BackgroundColor3 = Color3.fromRGB(20,10,10)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(180,30,30)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 1, -12)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextColor3 = Color3.fromRGB(255,200,200)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.Text = "HORDE MODE AKTIVERET – For mange monstre tæt på!"
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -16, 0, 18)
sub.Position = UDim2.new(0, 8, 0, 30)
sub.BackgroundTransparency = 1
sub.TextXAlignment = Enum.TextXAlignment.Center
sub.TextColor3 = Color3.fromRGB(255,220,220)
sub.Font = Enum.Font.Gotham
sub.TextScaled = true
sub.Text = "Hastighed & modstand øges"
sub.Parent = panel

-- Stacking-logik:
--  • Hvis kun Horde er synlig ? læg Horde i top (Y=0.06)
--  • Hvis Shrine også er synlig ? læg Horde lige under (Y=0.11)
local function isShrineVisible()
	local shrineGui = pg:FindFirstChild("ShrineUI")
	if not shrineGui or not shrineGui:IsA("ScreenGui") then return false end
	if not shrineGui.Enabled then return false end
	local shrinePanel = shrineGui:FindFirstChild("Panel")
	return shrinePanel and shrinePanel:IsA("Frame") and shrinePanel.Visible
end


-- Lyt på Shrine-panel synlighed (så vi live re-stacker)
task.spawn(function()
	while true do
		task.wait(0.2) -- let og stabil polling; alternativt: bind på PropertyChangedSignal hvis du vil
	end
end)

-- Remote-hooks
EvShow.OnClientEvent:Connect(function()
	gui.Enabled = true
	overlay.Visible = true
	panel.Visible = true
end)

EvHide.OnClientEvent:Connect(function()
	panel.Visible = false
	overlay.Visible = false
	gui.Enabled = false
end)

EvUpdate.OnClientEvent:Connect(function(msg)
	if typeof(msg) == "table" then
		if msg.title then title.Text = tostring(msg.title) end
		if msg.sub   then sub.Text   = tostring(msg.sub)   end
	elseif typeof(msg) == "string" then
		sub.Text = msg
	end
end)

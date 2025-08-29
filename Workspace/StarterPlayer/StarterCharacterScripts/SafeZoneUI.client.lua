-- StarterPlayerScripts/SafeZoneUI.client.lua
-- Safe Zone badge (top-center):
--  • Line 1: status (+countdown or +100% speed)
--  • Line 2: "Combat & XP disabled"
--  • Auto-shows while ZoneIsSafe = true; hides otherwise.

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "SafeZoneUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = lp:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Badge"
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, 8)
frame.Size = UDim2.new(0, 420, 0, 64) -- bigger
frame.BackgroundColor3 = Color3.fromRGB(20, 28, 35)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 200, 255)
stroke.Thickness = 1.5
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = frame

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 2)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 26)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(225, 245, 255)
title.TextXAlignment = Enum.TextXAlignment.Center
title.Text = ""
title.LayoutOrder = 1
title.Parent = frame

local sub = Instance.new("TextLabel")
sub.Name = "Subtitle"
sub.BackgroundTransparency = 1
sub.Size = UDim2.new(1, 0, 0, 22)
sub.Font = Enum.Font.Gotham
sub.TextSize = 16
sub.TextColor3 = Color3.fromRGB(190, 210, 220)
sub.TextXAlignment = Enum.TextXAlignment.Center
sub.Text = "Combat & XP disabled"
sub.LayoutOrder = 2
sub.Parent = frame

local function fmtCountdown(sec: number)
	if sec <= 0 then return "0s" end
	if sec < 10 then return string.format("%.1fs", sec) end
	return string.format("%ds", math.floor(sec + 0.5))
end

local function refresh()
	local safe   = lp:GetAttribute("ZoneIsSafe") == true
	frame.Visible = safe
	if not safe then return end

	local t0      = lp:GetAttribute("Safe_EnteredAt")
	local boosted = lp:GetAttribute("Safe_SpeedBoostActive") == true

	if boosted then
		title.Text = "SAFE ZONE — +100% Speed active"
	else
		if typeof(t0) == "number" then
			local remain = math.max(0, 10 - (os.clock() - t0))
			title.Text = "SAFE ZONE — heal & speed in " .. fmtCountdown(remain)
		else
			title.Text = "SAFE ZONE"
		end
	end

	-- Always show this line while safe:
	sub.Text = "Combat & XP disabled"
end

lp.AttributeChanged:Connect(function(attr)
	if attr == "ZoneIsSafe" or attr == "Safe_SpeedBoostActive" or attr == "Safe_EnteredAt" then
		refresh()
	end
end)

task.defer(refresh)

-- Smooth countdown while waiting for the 10s
task.spawn(function()
	while true do
		if frame.Visible and (lp:GetAttribute("Safe_SpeedBoostActive") ~= true) then
			refresh()
		end
		task.wait(0.2)
	end
end)

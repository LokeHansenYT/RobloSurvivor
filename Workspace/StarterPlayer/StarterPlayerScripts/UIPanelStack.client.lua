-- StarterPlayerScripts/UIPanelStack.client.lua
-- Samler top-paneler og placerer dem efter prioritet, så de ikke overlapper.

local Players = game:GetService("Players")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Registrér dine paneler her (GUI-Name -> priority)
local PANELS = {
	WorldEventUI = 100,
	ShrineUI     = 90,
	HordeUI      = 0,
}
-- 3 slots fra top og ned
local SLOTS_Y = {0.06, 0.12, 0.18}

local function isActive(gui)
	if not (gui and gui:IsA("ScreenGui") and gui.Enabled) then return false end
	local pnl = gui:FindFirstChild("Panel")
	return pnl and pnl:IsA("Frame") and pnl.Visible
end

local function tickStack()
	-- find aktive
	local actives = {}
	for name,prio in pairs(PANELS) do
		local gui = pg:FindFirstChild(name)
		if isActive(gui) then
			table.insert(actives, {gui=gui, prio=prio})
		end
	end
	-- sortér højest prio først
	table.sort(actives, function(a,b) return a.prio > b.prio end)

	-- læg i slots + sæt DisplayOrder = prio
	for i,entry in ipairs(actives) do
		entry.gui.DisplayOrder = entry.prio
		local pnl = entry.gui:FindFirstChild("Panel")
		if pnl and pnl:IsA("Frame") then
			pnl.AnchorPoint = Vector2.new(0.5,0)
			pnl.Position = UDim2.fromScale(0.5, SLOTS_Y[math.clamp(i,1,#SLOTS_Y)])
		end
	end
end

-- let polling (robust mod andres toggles)
task.spawn(function()
	while true do
		tickStack()
		task.wait(0.1)
	end
end)

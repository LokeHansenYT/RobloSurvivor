-- ServerScriptService/Fixes/StarterWeaponGuard.server.lua
-- Hindrer flere starter-våben efter respawn og rydder dubletter.
local Players = game:GetService("Players")

local STARTER_NAMES = { "BasicWeapon", "BasicGun", "StarterGun", "Basic" } -- tilpas hvis nødvendigt

local function isStarterTool(tool: Instance)
	if not tool or not tool:IsA("Tool") then return false end
	if tool:GetAttribute("IsStarterWeapon") then return true end
	for _, n in ipairs(STARTER_NAMES) do
		if string.lower(tool.Name) == string.lower(n) then return true end
	end
	return false
end

local function cleanDuplicates(plr: Player)
	local seen = false
	for _, container in ipairs({ plr:FindFirstChildOfClass("Backpack"), plr.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if isStarterTool(item) then
					if seen then
						item:Destroy()
					else
						seen = true
					end
				end
			end
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	if plr:GetAttribute("StarterWeaponGiven") ~= true then
		plr:SetAttribute("StarterWeaponGiven", true)
		-- Her kan du evt. give selve starter-tool'et én gang, hvis det ikke gives andetsteds.
		-- Jeg rører det ikke (ukendt navn/placering), vagt-scriptet rydder blot dubletter.
	end
	plr.CharacterAdded:Connect(function()
		task.defer(cleanDuplicates, plr)
	end)
end)

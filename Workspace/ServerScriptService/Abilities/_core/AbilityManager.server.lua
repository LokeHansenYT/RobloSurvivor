-- ServerScriptService/Abilities/_core/AbilityManager.server.lua
-- Boots all ability loops for a player based on the catalog (modules self-gate on level).

local Players = game:GetService("Players")
local SSS     = game:GetService("ServerScriptService")
local Rep     = game:GetService("ReplicatedStorage")

local Catalog = require(Rep.Shared.SkillsCatalog)

-- Ensure the player's Upgrades IntValues exist for every catalog entry
local function ensureUpgradeInts(plr)
	local up = plr:FindFirstChild("Upgrades")
	if not up then
		up = Instance.new("Folder"); up.Name = "Upgrades"; up.Parent = plr
	end
	for _,e in ipairs(Catalog.All()) do
		if not up:FindFirstChild(e.levelKey) then
			local v = Instance.new("IntValue"); v.Name = e.levelKey; v.Value = 0; v.Parent = up
		end
	end
end

-- require all ability modules once
local abilityModules = {}
do
	local abilitiesFolder = SSS:WaitForChild("Abilities")
	for _,e in ipairs(Catalog.All()) do
		local src = abilitiesFolder:FindFirstChild(e.moduleName)
		if src then
			local ok,mod = pcall(require, src)
			if ok and type(mod)=="table" and type(mod.start)=="function" then
				table.insert(abilityModules, mod)
			else
				warn("[AbilityManager] Couldn't load", e.moduleName, mod)
			end
		else
			warn("[AbilityManager] Missing ability module:", e.moduleName)
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	ensureUpgradeInts(plr)
	for _,mod in ipairs(abilityModules) do
		-- each module does its own: read levelKey, loop and act only when level>0
		task.spawn(function()
			local ok,err = pcall(mod.start, plr)
			if not ok then warn("[AbilityManager] start failed:", err) end
		end)
	end
end)

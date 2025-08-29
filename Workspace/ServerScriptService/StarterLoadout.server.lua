-- ServerScriptService/StarterLoadout.server.lua
local Players = game:GetService("Players")
local Rep     = game:GetService("ReplicatedStorage")

local Catalog = require(Rep.Shared.SkillsCatalog)
local Prog    = require(Rep.Shared.ProgressionConfig)

-- Remotes
local remRoot = Rep:FindFirstChild("Remotes") or Instance.new("Folder"); remRoot.Name="Remotes"; remRoot.Parent=Rep
local evShow  = remRoot:FindFirstChild("StarterChoice")    or Instance.new("RemoteEvent"); evShow.Name="StarterChoice";    evShow.Parent=remRoot
local evApply = remRoot:FindFirstChild("ApplyStarterChoice") or Instance.new("RemoteEvent"); evApply.Name="ApplyStarterChoice"; evApply.Parent=remRoot

local function ensureUpgrades(plr)
	local up = plr:FindFirstChild("Upgrades")
	if not up then up = Instance.new("Folder"); up.Name="Upgrades"; up.Parent=plr end
	for _,e in ipairs(Catalog.All()) do
		if not up:FindFirstChild(e.levelKey) then
			local v = Instance.new("IntValue"); v.Name=e.levelKey; v.Value=0; v.Parent=up
		end
	end
	return up
end

local function alreadyPickedSomething(plr)
	local up = ensureUpgrades(plr)
	for _,e in ipairs(Catalog.All()) do
		if up[e.levelKey].Value > 0 then return true end
	end
	return false
end

Players.PlayerAdded:Connect(function(plr)
	plr:SetAttribute("StarterPicked", false)
	plr.CharacterAdded:Connect(function()
		task.wait(0.25)
		if not alreadyPickedSomething(plr) and not plr:GetAttribute("StarterPicked") then
			if plr:FindFirstChild("Invulnerable") then plr.Invulnerable.Value = true end
			if plr:FindFirstChild("LevelUpMenuOpen") then plr.LevelUpMenuOpen.Value = true end

			local choices = {}
			for _,e in ipairs(Catalog.All()) do
				if e.starter then table.insert(choices, { id=e.id, name=e.name }) end
			end
			evShow:FireClient(plr, { choices = choices })
		end
	end)
end)

evApply.OnServerEvent:Connect(function(plr, choiceId)
	local entry = Catalog.GetById(choiceId); if not entry then return end
	local up = ensureUpgrades(plr)
	local v = up:FindFirstChild(entry.levelKey); if not v then return end

	v.Value = math.max(1, v.Value + 1)

	if plr:FindFirstChild("LevelUpMenuOpen") then plr.LevelUpMenuOpen.Value = false end
	task.delay(Prog.LevelUpInvulnSeconds or 0.5, function()
		if plr and plr:FindFirstChild("Invulnerable") then plr.Invulnerable.Value = false end
	end)
	plr:SetAttribute("StarterPicked", true)
end)

-- ServerScriptService/Skills.server.lua
local Players = game:GetService("Players")
local Rep     = game:GetService("ReplicatedStorage")

local Catalog = require(Rep.Shared.SkillsCatalog)

-- Remotes
local remRoot = Rep:FindFirstChild("Remotes") or Instance.new("Folder")
remRoot.Name = "Remotes"; remRoot.Parent = Rep
local rfLibrary     = remRoot:FindFirstChild("Skills_RequestLibrary") or Instance.new("RemoteFunction"); rfLibrary.Name="Skills_RequestLibrary"; rfLibrary.Parent=remRoot
local rfChoices     = remRoot:FindFirstChild("Skills_RequestChoices") or Instance.new("RemoteFunction"); rfChoices.Name="Skills_RequestChoices"; rfChoices.Parent=remRoot
local reSpend       = remRoot:FindFirstChild("Skills_ConfirmSpend") or Instance.new("RemoteEvent");    reSpend.Name="Skills_ConfirmSpend"; reSpend.Parent=remRoot

-- Util
local function upgradesFolder(plr)
	local up = plr:FindFirstChild("Upgrades")
	if not up then
		up = Instance.new("Folder"); up.Name="Upgrades"; up.Parent=plr
	end
	for _,e in ipairs(Catalog.All()) do
		if not up:FindFirstChild(e.levelKey) then
			local v = Instance.new("IntValue"); v.Name = e.levelKey; v.Value = 0; v.Parent = up
		end
	end
	return up
end

local function ensureSkillPoints(plr)
	local sp = plr:FindFirstChild("SkillPoints")
	if not sp then
		sp = Instance.new("IntValue"); sp.Name="SkillPoints"; sp.Value=0; sp.Parent=plr
	end
	return sp
end

-- Only allow spending in safe-zone (you already set this attribute from the zone system)
local function canSpendHere(plr)
	return plr:GetAttribute("ZoneIsSafe") == true
end

-- Build player's library (= all entries with current level)
local function buildLibrary(plr)
	local up = upgradesFolder(plr)
	local lib = {}
	for _,e in ipairs(Catalog.All()) do
		local cur = up:FindFirstChild(e.levelKey) and up[e.levelKey].Value or 0
		table.insert(lib, {
			id = e.id, name = e.name, desc = e.desc, level = cur, maxLevel = e.maxLevel or 99
		})
	end
	return lib
end

-- Weighted roll with “harder to roll the same thing again”
local function rollChoices(plr, count)
	count = count or 3
	local up = upgradesFolder(plr)

	-- pool = entries not at cap
	local pool = {}
	local totalW = 0
	for _,e in ipairs(Catalog.All()) do
		local cur = up[e.levelKey].Value
		if cur < (e.maxLevel or 99) then
			local w = (e.weight or 1.0) / (1 + math.max(0, cur) * 0.75)
			table.insert(pool, {e=e, w=w})
			totalW += w
		end
	end
	if #pool == 0 then return {} end

	local picks = {}
	for i=1, math.min(count, #pool) do
		local r = math.random() * totalW
		local idx = 1
		for j,item in ipairs(pool) do
			r -= item.w
			if r <= 0 then idx = j; break end
		end
		local chosen = table.remove(pool, idx)
		totalW -= chosen.w
		table.insert(picks, {
			id = chosen.e.id,
			name = chosen.e.name,
			desc = chosen.e.desc,
			levelKey = chosen.e.levelKey,
			cost = chosen.e.cost or 1,
			nextLevel = (up[chosen.e.levelKey].Value + 1),
			maxLevel = chosen.e.maxLevel or 99,
		})
	end
	return picks
end

-- Remote handlers
rfLibrary.OnServerInvoke = function(plr)
	return {
		points = ensureSkillPoints(plr).Value,
		library = buildLibrary(plr),
		canSpendHere = canSpendHere(plr),
	}
end

rfChoices.OnServerInvoke = function(plr)
	return {
		points = ensureSkillPoints(plr).Value,
		canSpendHere = canSpendHere(plr),
		choices = rollChoices(plr, 3),
	}
end

reSpend.OnServerEvent:Connect(function(plr, payload)
	-- payload = { id = "WEAPON_AURA" }
	if type(payload) ~= "table" then return end
	local entry = Catalog.GetById(payload.id); if not entry then return end
	if not canSpendHere(plr) then return end

	local sp = ensureSkillPoints(plr); if sp.Value <= 0 then return end
	local up = upgradesFolder(plr)
	local cur = up[entry.levelKey].Value
	local maxL = entry.maxLevel or 99
	local cost = entry.cost or 1

	if cur >= maxL then return end
	if sp.Value < cost then return end

	-- apply
	sp.Value -= cost
	up[entry.levelKey].Value = math.min(maxL, cur + 1)

	-- respond back so client can refresh UI (optional fire)
	reSpend:FireClient(plr, {
		points = sp.Value,
		library = buildLibrary(plr)
	})
end)

-- Make sure new joiners have the values
Players.PlayerAdded:Connect(function(plr)
	upgradesFolder(plr)
	ensureSkillPoints(plr)
end)

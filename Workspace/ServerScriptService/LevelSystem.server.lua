-- ServerScriptService/LevelSystem.server.lua
-- Instant level-ups (no lag): processes synchronously on every XP change.

local Players = game:GetService("Players")
local Rep     = game:GetService("ReplicatedStorage")
local Prog    = require(Rep:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))

local XP_BASE   = Prog.LevelXPBase   or Prog.XPBase   or 25
local XP_GROWTH = Prog.LevelXPGrowth or Prog.XPGrowth or 1.35
local START_LVL = Prog.StartingLevel or 1

local function requiredXPFor(levelValue)
	if typeof(Prog.RequiredXP) == "function" then
		return math.max(1, tonumber(Prog.RequiredXP(levelValue)) or 1)
	end
	return math.max(1, math.floor(XP_BASE * (XP_GROWTH ^ (levelValue - START_LVL))))
end

local function ensureStats(plr)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = plr end

	local lvl = ls:FindFirstChild("Level")
	if not lvl then lvl = Instance.new("IntValue"); lvl.Name = "Level"; lvl.Value = START_LVL; lvl.Parent = ls end

	local xp  = plr:FindFirstChild("XP")
	if not xp then xp = Instance.new("IntValue"); xp.Name = "XP"; xp.Value = 0; xp.Parent = plr end

	local nxp = plr:FindFirstChild("NextLevelXP")
	if not nxp then nxp = Instance.new("IntValue"); nxp.Name = "NextLevelXP"; nxp.Value = requiredXPFor(lvl.Value); nxp.Parent = plr end

	local xptn = plr:FindFirstChild("XPToNext")
	if not xptn then xptn = Instance.new("IntValue"); xptn.Name = "XPToNext"; xptn.Value = nxp.Value; xptn.Parent = plr end

	local sp = plr:FindFirstChild("SkillPoints")
	if not sp then sp = Instance.new("IntValue"); sp.Name = "SkillPoints"; sp.Value = 0; sp.Parent = plr end

	return lvl, xp, nxp, xptn
end

local function defaultOnLevelUp(plr, newLevel)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.Health = hum.MaxHealth end
	local sp = plr:FindFirstChild("SkillPoints"); if sp then sp.Value += 1 end
end

local busy = setmetatable({}, { __mode = "k" })

local function hookXP(plr)
	local lvl, xp, nxp, xptn = ensureStats(plr)

	local function syncReq()
		local req = requiredXPFor(lvl.Value)
		nxp.Value  = req
		xptn.Value = req
	end

	local function process()
		if busy[plr] then return end
		busy[plr] = true

		syncReq()
		-- Consume all surplus XP now (instant multi-level)
		while xp.Value >= nxp.Value do
			xp.Value -= nxp.Value
			lvl.Value += 1
			syncReq()
			if typeof(_G.OnPlayerLevelUp) == "function" then
				_G.OnPlayerLevelUp(plr, lvl.Value)
			else
				defaultOnLevelUp(plr, lvl.Value)
			end
		end

		busy[plr] = false
	end

	-- Public helper for all awarders: instant processing
	_G.AddXP = function(targetPlr, amount)
		if targetPlr ~= plr then return end
		if typeof(amount) ~= "number" or amount == 0 then return end
		xp.Value += math.floor(amount)   -- triggers Changed, but we also process now
		process()                        -- <<< instant, no defer
	end

	-- Also catch any direct XP assignments from other scripts
	xp:GetPropertyChangedSignal("Value"):Connect(process)

	-- Kickstart in case player already has surplus XP
	process()
end

Players.PlayerAdded:Connect(function(plr)
	ensureStats(plr)
	hookXP(plr)
end)

for _, plr in ipairs(Players:GetPlayers()) do
	ensureStats(plr)
	hookXP(plr)
end

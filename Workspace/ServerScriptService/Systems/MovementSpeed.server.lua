-- ServerScriptService/Systems/MovementSpeed.server.lua
-- Central WalkSpeed-beregner
--  Base 16 * Core-Upgrades * Shrine-buffs * Safe-zone-boost * Debuffs
--  Understøtter begge varianter af core-hastighed:
--    • Upgrades.MoveSpeedMult (NumberValue, fx 1.08)
--    • Upgrades.MoveSpeedLevel (IntValue, +8% pr. level)
--  Fallback-navne (hvis du har ældre navne i projektet):
--    • Upgrades.MoveSpeed (IntValue), Upgrades.SpeedLevel (IntValue),
--      Upgrades.SpeedMult (NumberValue), Upgrades.WalkSpeedMult (NumberValue)
--
--  Lytter også på Player-attributter:
--    • Buff_SpeedPercent (fx 0.30 = +30%)
--    • Debuff_SlowPercent (fx 0.20 = -20%)
--    • Safe_SpeedBoostActive (bool, +100% i safe-zone)
--
--  Denne version retter "FindChild"-typo -> bruger konsekvent FindFirstChild.

local Players = game:GetService("Players")

local BASE_SPEED = 16
local MIN_SPEED  = 6

-- Helpers
local function getNumberValue(inst)
	if not inst then return nil end
	if inst:IsA("NumberValue") or inst:IsA("IntValue") then
		return inst.Value
	end
	return nil
end

local function getCoreSpeedMult(plr: Player)
	local up = plr:FindFirstChild("Upgrades")
	if not up then return 1.0 end

	-- Primær: MoveSpeedMult (NumberValue)
	local v = getNumberValue(up:FindFirstChild("MoveSpeedMult"))
	if v then return math.max(0.1, v) end

	-- Primær: MoveSpeedLevel (IntValue) -> +8% pr. level
	local lvl = getNumberValue(up:FindFirstChild("MoveSpeedLevel"))
	if lvl then return 1.0 + 0.08 * math.max(0, lvl) end

	-- Fallbacks / legacy-navne
	local lvl2 = getNumberValue(up:FindFirstChild("MoveSpeed")) or getNumberValue(up:FindFirstChild("SpeedLevel"))
	if lvl2 then return 1.0 + 0.08 * math.max(0, lvl2) end

	local mult2 = getNumberValue(up:FindFirstChild("SpeedMult")) or getNumberValue(up:FindFirstChild("WalkSpeedMult"))
	if mult2 then return math.max(0.1, mult2) end

	return 1.0
end

local function computeSpeed(plr: Player)
	local coreMult   = getCoreSpeedMult(plr)
	local shrinePct  = plr:GetAttribute("Buff_SpeedPercent")  or 0    -- +X%
	local debuffPct  = plr:GetAttribute("Debuff_SlowPercent") or 0    -- -Y%
	local safeBoost  = (plr:GetAttribute("Safe_SpeedBoostActive") == true) and 2.0 or 1.0

	local totalMult = coreMult * (1 + shrinePct) * (1 - debuffPct) * safeBoost
	local out = math.max(MIN_SPEED, BASE_SPEED * math.max(0.1, totalMult))
	return out
end

local function applySpeed(plr: Player)
	local char = plr.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = computeSpeed(plr)
	end
end

local function wireUpgrades(plr: Player)
	local up = plr:FindFirstChild("Upgrades")
	if not up then return end

	local function onChild(v)
		if v:IsA("NumberValue") or v:IsA("IntValue") then
			v.Changed:Connect(function()
				applySpeed(plr)
			end)
		end
	end

	up.ChildAdded:Connect(function(v)
		onChild(v)
		applySpeed(plr)
	end)
	up.ChildRemoved:Connect(function()
		applySpeed(plr)
	end)
	for _,v in ipairs(up:GetChildren()) do
		onChild(v)
	end
end

local function wireAttributes(plr: Player)
	plr.AttributeChanged:Connect(function(attr)
		if attr == "Buff_SpeedPercent" or attr == "Debuff_SlowPercent" or attr == "Safe_SpeedBoostActive" then
			applySpeed(plr)
		end
	end)
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		task.defer(function()
			wireUpgrades(plr)
			wireAttributes(plr)
			applySpeed(plr)
		end)
	end)
	if plr.Character then
		task.defer(function()
			wireUpgrades(plr)
			wireAttributes(plr)
			applySpeed(plr)
		end)
	end
end)

-- Catch already present players (e.g., studio start)
for _,pl in ipairs(Players:GetPlayers()) do
	if pl.Character then
		task.defer(function()
			wireUpgrades(pl)
			wireAttributes(pl)
			applySpeed(pl)
		end)
	end
end

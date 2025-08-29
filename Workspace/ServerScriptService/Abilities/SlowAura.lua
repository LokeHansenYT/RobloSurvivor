-- ServerScriptService/Abilities/SlowAura.lua
-- Slow aura: lys-blå ring, tydelig "SLOWED", og robust varighed/styrke via attributes.

local RS = game:GetService("ReplicatedStorage")
local AuraVis = require(RS.Shared:WaitForChild("AuraVisual"))
local C       = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab      = C.Ab

local DEF       = Ab.SlowAura or {}
local LEVEL_KEY = "SlowAuraLevel"

local function radiusFor(lvl)
	local b = DEF.radius or 18
	local g = DEF.radiusGrowth or 0
	return b + g * math.max(0, (lvl or 1)-1)
end
local function slowFor(lvl)
	local b = DEF.slowPct or 0.20
	local g = DEF.slowGrowth or 0
	return b + g * math.max(0, (lvl or 1)-1)
end
local function tickFor(plr) -- shrine/horde scaling
	local base = DEF.tick or 0.5
	return (C.scaleInterval and C.scaleInterval(plr, base)) or base
end

local M = { id = DEF.id or "WEAPON_SLOWAURA", levelKey = LEVEL_KEY }

-- central helper: påfør/vedligehold slow på EN fjende
local function startSlowedTicker(enemy)
	-- sørg for kun én ticker pr. enemy
	if enemy:GetAttribute("SlowedTicker") then return end
	enemy:SetAttribute("SlowedTicker", 1)
	task.spawn(function()
		while enemy.Parent do
			local untilT = enemy:GetAttribute("SlowedUntil") or 0
			local pct    = enemy:GetAttribute("SlowedPct") or 0
			if time() > untilT or pct <= 0 then
				enemy:SetAttribute("SlowedTicker", nil)
				break
			end
			if C.FCT then
				if C.FCT.ShowDebuff then pcall(C.FCT.ShowDebuff, enemy, "SLOWED") end
				if C.FCT.ShowStatus and not C.FCT.ShowDebuff then pcall(C.FCT.ShowStatus, enemy, "SLOWED") end
			end
			task.wait(0.6)
		end
	end)
end

local function applySlow(e, hum, strength, duration)
	local newPct   = math.clamp(strength or 0, 0, 0.95)
	local newUntil = time() + (duration or 0.9)
	local oldUntil = e:GetAttribute("SlowedUntil") or 0
	local oldPct   = e:GetAttribute("SlowedPct")   or 0

	-- stærkeste pct vinder; varighed forlænges
	local finalPct   = math.max(oldPct, newPct)
	local finalUntil = math.max(oldUntil, newUntil)
	e:SetAttribute("SlowedPct",   finalPct)
	e:SetAttribute("SlowedUntil", finalUntil)

	-- opdater WalkSpeed deterministisk (samme princip som før)
	local oldFactor = e:GetAttribute("SlowAppliedFactor") or 1
	local baseSpeed = hum.WalkSpeed / oldFactor
	local newFactor = math.max(0.05, 1 - finalPct)
	hum.WalkSpeed   = baseSpeed * newFactor
	e:SetAttribute("SlowAppliedFactor", newFactor)

	-- kickstart vedligeholder + vedvarende tekst
	startSlowedTicker(e)

	-- vedligeholder (som du allerede havde)
	if not e:GetAttribute("SlowMaintainer") then
		e:SetAttribute("SlowMaintainer", 1)
		task.spawn(function()
			while e.Parent do
				local untilT = e:GetAttribute("SlowedUntil") or 0
				local pct    = e:GetAttribute("SlowedPct") or 0
				local cur    = e:GetAttribute("SlowAppliedFactor") or 1
				if time() > untilT or pct <= 0 then
					local h = e:FindFirstChildOfClass("Humanoid")
					if h then h.WalkSpeed = h.WalkSpeed / cur end
					e:SetAttribute("SlowedPct", 0)
					e:SetAttribute("SlowAppliedFactor", 1)
					e:SetAttribute("SlowMaintainer", nil)
					break
				else
					local h = e:FindFirstChildOfClass("Humanoid")
					if h then
						local target = (h.WalkSpeed / cur) * math.max(0.05, 1 - pct)
						h.WalkSpeed = target
					end
				end
				task.wait(0.15)
			end
		end)
	end
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local char = plr.Character or plr.CharacterAdded:Wait()
			local hrp  = char:WaitForChild("HumanoidRootPart")
			local vis; local wasActive=false

			while plr.Parent and char.Parent do
				local up  = plr:FindFirstChild("Upgrades")
				local lvl = up and up:FindFirstChild(LEVEL_KEY) and up[LEVEL_KEY].Value or 0
				local paused = (C.offensivePaused and C.offensivePaused(plr)) or false
				if lvl > 0 and not paused then
					if not vis then
						vis = AuraVis.new(hrp, {
							parent=char, name="SlowAuraRing",
							color=Color3.fromRGB(120,185,255), offset=0.10, height=0.06,
							transparency=0.35, alwaysOnTop=true,
							idle={fadePeriod=1.2, pause=2.0, alphaMin=0.88, alphaMax=1.0},
							cast={duration=0.18, alpha=0.85, edgeMinPct=0.18},
						})
					end
					local r = radiusFor(lvl)
					local s = slowFor(lvl)
					if vis then vis:update(r); vis:castPulse(r) end

					-- debuff alle fjender i radius (brug samme enemy-opsamling som andre evner)
					local zid = plr:GetAttribute("ZoneId")
					for _, e in ipairs(C.getEnemies(zid)) do
						local pp  = e.PrimaryPart
						local hum = e:FindFirstChildOfClass("Humanoid")
						local hrp2 = char:FindFirstChild("HumanoidRootPart")
						if pp and hum and hrp2 and hum.Health > 0 then
							if (pp.Position - hrp2.Position).Magnitude <= r then
								applySlow(e, hum, s, 0.9)
							end
						end
					end

					wasActive=true
					C.waitScaled(plr, tickFor(plr))
				else
					if wasActive and vis then vis:destroy(); vis=nil end
					wasActive=false
					task.wait(0.3)
				end
			end
			if vis then vis:destroy() end
		end
	end)
end

return M

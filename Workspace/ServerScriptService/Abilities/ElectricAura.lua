-- ServerScriptService/Abilities/ElectricAura.lua
-- Elektrisk aura med gul fading-border og cast-pulse. Chance-baseret skade + chance-baseret stun.

local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local C       = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab      = C.Ab
local AuraVis = require(RS.Shared:WaitForChild("AuraVisual"))

local DEF       = Ab.ElectricAura or {}
local LEVEL_KEY = "ElectricAuraLevel"
local DEFAULT_OFFSET = 0.1

-- radius/skade (som før)
local function radiusFor(lvl) local b=DEF.radiusBase or DEF.radius or 8; local p=DEF.radiusPerLevel or DEF.radiusGrowth or 0.75; return b + p*math.max(0,(lvl or 1)-1) end
local function baseDamageFor(lvl) local b=DEF.baseDamage or 1; local p=DEF.damagePerLevel or 1; return b + p*math.max(0,(lvl or 1)-1) end
-- skade-chance (som før)
local function damageChanceFor(lvl) local base=DEF.chanceBase or 0.10; local per=DEF.chancePerLevel or 0.01; local maxC=DEF.chanceMax or 1.0; return math.clamp(base + per*math.max(0,(lvl or 1)-1),0,maxC) end
-- stun-chance/duration fra AbilitiesConfig (fallbacks)
local function stunChanceFor(lvl) local b=DEF.stunChanceBase or 0.25; local p=DEF.stunChancePerLvl or 0.00; return math.clamp(b + p*math.max(0,(lvl or 1)-1),0,1) end
local function stunDurFor(lvl)
	if DEF.stunDuration then return DEF.stunDuration end
	local minD=DEF.stunMin or 1; local maxD=DEF.stunMax or 3; if maxD<minD then maxD=minD end
	return math.random(minD,maxD)
end
local function intervalFor(plr, lvl) local base=DEF.interval or 0.6; local grow=DEF.intervalGrowth or 0.98; local raw=base*(grow^math.max(0,(lvl or 1)-1)); return C.scaleInterval and C.scaleInterval(plr, raw) or raw end
local function scaleDamage(plr,d) local up=plr:FindFirstChild("Upgrades"); local mult=(up and up:FindFirstChild("DamageMult")) and up.DamageMult.Value or 1.0; local pct=plr:GetAttribute("Buff_DamagePercent") or 0; return math.max(1,math.floor(d*mult*(1+pct))) end

local function doTick(plr, hrp, radius, dmg, dmgChance, lvl)
	local zid = plr:GetAttribute("ZoneId")
	local seen = {}
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(hrp.Position, radius, nil)) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] then
			seen[model] = true
			if C.isEnemyModel and not C.isEnemyModel(model) then continue end
			local hum  = model:FindFirstChildOfClass("Humanoid")
			local body = model:FindFirstChild("Body") or model.PrimaryPart
			if hum and body and hum.Health > 0 then
				if (zid == nil) or ((body:GetAttribute("ZoneId") or -1) == zid) then
					local resist = body:GetAttribute("Horde_Resist") or 0
					-- SKADE: chance * (1-resist)
					local effDmgChance = math.clamp(dmgChance * (1 - resist), 0, 1)
					if math.random() < effDmgChance then
						local final = scaleDamage(plr, dmg)
						hum:TakeDamage(final)
						if C.FCT and C.FCT.ShowDamage then C.FCT.ShowDamage(model, final, (DEF.id or "WEAPON_EAURA")) end
					end
					-- STUN: separat chance * (1-resist)
					local effStunChance = math.clamp(stunChanceFor(lvl) * (1 - resist), 0, 1)
					if math.random() < effStunChance then
						local dur = stunDurFor(lvl)
						if C.applyElecStun then
							C.applyElecStun(hum, dur, { source="ELECTRIC_AURA", body=body, model=model })
						else
							body:SetAttribute("StunnedUntil", os.clock() + dur)
						end
						if C.FCT and C.FCT.ShowDebuff then C.FCT.ShowDebuff(model, "STUNNED") end
					end
				end
			end
		end
	end
end

local M = { id = DEF.id or "WEAPON_EAURA", levelKey = LEVEL_KEY }

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local char = plr.Character or plr.CharacterAdded:Wait()
			local hrp  = char:WaitForChild("HumanoidRootPart")

			local vis; local last=false
			while plr.Parent and char.Parent do
				local up   = plr:FindFirstChild("Upgrades")
				local lvl  = up and up:FindFirstChild(LEVEL_KEY) and up[LEVEL_KEY].Value or 0
				local pausedOff  = (C.offensivePaused and C.offensivePaused(plr)) or false
				local pausedSafe = (C.inSafeZone and C.inSafeZone(plr)) or false
				local active = (lvl > 0) and not (pausedOff or pausedSafe)
				local mode = plr:GetAttribute("AuraVisualMode") or 1

				if active then
					if not vis and mode ~= 0 then
						vis = AuraVis.new(hrp, {
							parent=char, name="ElectricAuraRing",
							color=Color3.fromRGB(255, 230, 90), -- GUL
							offset=DEFAULT_OFFSET, height=0.06, transparency=0.35,
							alwaysOnTop=true, mode=mode,
							idle = { fadePeriod = 1.0, pause = 2.3, alphaMin=0.9, alphaMax=1 },
							cast = { duration = 0.18, alpha = 0.85, edgeMinPct = 0.1 },
						})
					elseif vis and vis.setMode then
						vis:setMode(mode)
					end

					local r      = radiusFor(lvl)
					local dmg    = baseDamageFor(lvl)
					local dmgCh  = damageChanceFor(lvl)

					if vis then vis:update(r); vis:castPulse(r) end
					doTick(plr, hrp, r, dmg, dmgCh, lvl)

					last=true
					task.wait(math.clamp(intervalFor(plr, lvl), 0.08, 5))
				else
					if last and vis then vis:destroy(); vis=nil end
					last=false
					task.wait(0.3)
				end
			end
			if vis then vis:destroy() end
		end
	end)
end

return M

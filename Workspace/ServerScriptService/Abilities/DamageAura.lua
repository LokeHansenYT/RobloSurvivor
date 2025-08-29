-- ServerScriptService/Abilities/DamageAura.lua
-- Skade-aura med diskret visual:
--  • Dyb mørk rød farve
--  • Meget transparent idle (fading border)
--  • Cast: edge-only pulse (fra ~82% ? 100% af radius)
--  • Tynd skive, så arealet fylder minimalt visuelt

local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local C       = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab      = C.Ab
local AuraVis = require(RS.Shared:WaitForChild("AuraVisual"))

local DEF       = Ab.DamageAura or {}
local LEVEL_KEY = "AuraLevel"
local DEFAULT_OFFSET = 0.1

local function radiusFor(lvl)
	local base = DEF.radiusBase or DEF.radius or 8
	local per  = DEF.radiusPerLevel or DEF.radiusGrowth or 0.75
	return base + per * math.max(0, (lvl or 1) - 1)
end
local function baseDamageFor(lvl) local b=DEF.baseDamage or 1; local p=DEF.damagePerLevel or 1; return b + p*math.max(0,(lvl or 1)-1) end
local function intervalFor(plr, lvl) local base=DEF.interval or 0.6; local grow=DEF.intervalGrowth or 0.98; local raw=base*(grow^math.max(0,(lvl or 1)-1)); return C.scaleInterval and C.scaleInterval(plr, raw) or raw end
local function scaleDamage(plr, dmg)
	local up = plr:FindFirstChild("Upgrades")
	local dmgMult = (up and up:FindFirstChild("DamageMult")) and up.DamageMult.Value or 1.0
	local shrinePct = plr:GetAttribute("Buff_DamagePercent") or 0
	return math.max(1, math.floor(dmg * dmgMult * (1 + shrinePct)))
end
local function isEnemy(model) return model and model:IsA("Model") and (CollectionService:HasTag(model,"Enemy") or model.Name=="Enemy") end

local function tickDamage(plr, hrp, radius, dmg)
	local center = hrp.Position
	local zid = plr:GetAttribute("ZoneId")
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(center, radius, nil)) do
		local m = part:FindFirstAncestorOfClass("Model")
		if isEnemy(m) then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local body = m:FindFirstChild("Body") or m.PrimaryPart
			if hum and body and hum.Health > 0 then
				if (zid == nil) or ((body:GetAttribute("ZoneId") or -1) == zid) then
					local final = scaleDamage(plr, dmg)
					hum:TakeDamage(final)
					if C.FCT and C.FCT.ShowDamage then
						C.FCT.ShowDamage(m, final, "WEAPON_AURA")
					end
				end
			end
		end
	end
end

local M = { id = DEF.id or "WEAPON_AURA", levelKey = LEVEL_KEY }

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local char = plr.Character or plr.CharacterAdded:Wait()
			local hrp  = char:WaitForChild("HumanoidRootPart")

			local vis
			local last = false

			while plr.Parent and char.Parent do
				local up  = plr:FindFirstChild("Upgrades")
				local lvl = up and up:FindFirstChild(LEVEL_KEY) and up[LEVEL_KEY].Value or 0
				local paused = (C.offensivePaused and C.offensivePaused(plr)) or false
				local active = (lvl > 0) and not paused
				local mode = plr:GetAttribute("AuraVisualMode") or 1  -- 0/1/2

				if active then
					if not vis and mode ~= 0 then
						vis = AuraVis.new(hrp, {
							parent       = char,
							name         = "DamageAuraRing",
							color        = Color3.fromRGB(150, 25, 25), -- dyb mørk rød
							offset       = DEFAULT_OFFSET,
							height       = 0.04,   -- tyndere ? mindre fyldt areal
							transparency = 0.9,   -- mere gennemsigtighed som base
							alwaysOnTop  = true,
							mode         = mode,
							idle         = { fadePeriod = 1.0, pause = 2.8, alphaMin=0.9, alphaMax=1 },
							cast         = { duration = 0.5, alpha = 0.85, edgeMinPct = 0.1 }, -- edge-only pulse
						})
					elseif vis and vis.setMode then
						vis:setMode(mode)
					end

					local r = radiusFor(lvl)
					local d = baseDamageFor(lvl)

					if vis then vis:update(r) end   -- oprethold diskret ring
					tickDamage(plr, hrp, r, d)      -- effekt
					if vis then vis:castPulse(r) end -- diskret kant-pulse

					last = true
					task.wait(math.clamp(intervalFor(plr, lvl), 0.08, 5))
				else
					if last and vis then vis:destroy(); vis=nil end
					last = false
					task.wait(0.3)
				end
			end
			if vis then vis:destroy() end
		end
	end)
end

return M

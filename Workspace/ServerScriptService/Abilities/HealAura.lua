-- ServerScriptService/Abilities/HealAura.lua
-- Heal-aura med samme visual (idle fade + cast pulse). Healer spiller(e) i radius.

local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local C       = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab      = C.Ab
local AuraVis = require(RS.Shared:WaitForChild("AuraVisual"))

local DEF       = Ab.HealAura or {}
local LEVEL_KEY = "HealAuraLevel"
local DEFAULT_OFFSET = 0.1

local function radiusFor(lvl) local b=DEF.radiusBase or DEF.radius or 8; local p=DEF.radiusPerLevel or DEF.radiusGrowth or 0.75; return b + p*math.max(0,(lvl or 1)-1) end
local function baseHealFor(lvl) local b=DEF.baseHeal or DEF.healPerTick or 1; local p=DEF.healPerLevel or 1; return b + p*math.max(0,(lvl or 1)-1) end
local function intervalFor(plr, lvl) local base=DEF.interval or 0.6; local grow=DEF.intervalGrowth or 0.98; local raw=base*(grow^math.max(0,(lvl or 1)-1)); return C.scaleInterval and C.scaleInterval(plr, raw) or raw end
local function scaleHeal(plr, amt) local pct=plr:GetAttribute("Buff_HealingPercent") or plr:GetAttribute("Buff_HealPercent") or 0; local flat=plr:GetAttribute("Buff_HealFlat") or 0; return math.max(1, math.floor(amt*(1+pct)+flat)) end

local function doHealTick(plr, hrp, radius, healAmt)
	local center = hrp.Position
	local zid = plr:GetAttribute("ZoneId")
	for _, other in ipairs(Players:GetPlayers()) do
		local ch = other.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local r   = ch and ch:FindFirstChild("HumanoidRootPart")
		if hum and r and hum.Health > 0 then
			if (zid == nil) or (other:GetAttribute("ZoneId") == zid) then
				if (Vector3.new(r.Position.X, center.Y, r.Position.Z) - center).Magnitude <= radius then
					local final = scaleHeal(plr, healAmt)
					hum.Health = math.min(hum.MaxHealth, hum.Health + final)
					if C.FCT and C.FCT.ShowHeal then C.FCT.ShowHeal(ch, final, "HEAL_AURA") end
				end
			end
		end
	end
end

local M = { id = DEF.id or "WEAPON_HEAL", levelKey = LEVEL_KEY }

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local char = plr.Character or plr.CharacterAdded:Wait()
			local hrp  = char:WaitForChild("HumanoidRootPart")

			local vis; local last=false
			while plr.Parent and char.Parent do
				local up  = plr:FindFirstChild("Upgrades")
				local lvl = up and up:FindFirstChild(LEVEL_KEY) and up[LEVEL_KEY].Value or 0
				local pausedOff  = (C.offensivePaused and C.offensivePaused(plr)) or false
				local pausedSafe = (C.inSafeZone and C.inSafeZone(plr)) or false
				local active = (lvl > 0) and not (pausedOff or pausedSafe)
				local mode = plr:GetAttribute("AuraVisualMode") or 1

				if active then
					if not vis and mode ~= 0 then
						vis = AuraVis.new(hrp, {
							parent=char, name="HealAuraRing",
							color=Color3.fromRGB(90, 240, 160),
							offset=DEFAULT_OFFSET, height=0.06, transparency=0.35,
							alwaysOnTop=true, mode=mode,
							idle         = { fadePeriod = 1.0, pause = 2.5, alphaMin=0.9, alphaMax=1 },
							cast         = { duration = 0.2, alpha = 0.85, edgeMinPct = 0.1 }, -- edge-only pulse
						})
					elseif vis and vis.setMode then
						vis:setMode(mode)
					end

					local r = radiusFor(lvl)
					local h = baseHealFor(lvl)

					if vis then vis:update(r) end
					doHealTick(plr, hrp, r, h)
					if vis then vis:castPulse(r) end

					last = true
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

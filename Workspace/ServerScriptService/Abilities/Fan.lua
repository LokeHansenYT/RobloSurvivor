-- ServerScriptService/Abilities/Fan.lua
-- Vifte: skyder en vifte af lineære projektiler fremad i spillerens kigge-retning.
--  • Antal projektiler vokser med level (konfigurerbart)
--  • Projektiler flyver i samme “fodhøjde” som Spinner/Plus/Cross
--  • Bruger Shared.ProjectileCore (genbrugbar projektil-motor)

local RS        = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local C   = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab  = C.Ab
local PC  = require(RS.Shared:WaitForChild("ProjectileCore"))

local DEF       = Ab.Fan or {}
local LEVEL_KEY = "FanShotLevel"

local function dmgFor(lvl)
	local base = DEF.baseDamage or 1
	local per  = DEF.damagePerLevel or 1
	return base + per * math.max(0, (lvl or 1) - 1)
end

local function intervalFor(plr, lvl)
	local base = DEF.interval or 0.25
	local grow = DEF.intervalGrowth or 0.98
	local raw  = base * (grow ^ math.max(0, (lvl or 1) - 1))
	return C.scaleInterval and C.scaleInterval(plr, raw) or raw
end

local function bulletCountFor(lvl)
	-- Konfigdrevet; fallback: start 5, +1 pr level (du kan ændre i AbilitiesConfig.Fan)
	local base = DEF.bulletsBase or 5
	local per  = DEF.bulletsPerLevel or 1
	local n = base + per * math.max(0, (lvl or 1) - 1)
	local maxN = DEF.bulletsMax or 25
	return math.clamp(n, 1, maxN)
end

local function spreadDegFor(lvl)
	-- Total vifte-spread (grader). Eksempel: 120° ? halvcirkel-ish uden at være ekstrem
	local base = DEF.spreadDeg or 120
	-- du kan evt. øge let med level; her holder vi den fast
	return base
end

local function speedFor()      return DEF.speed or 60 end
local function rangeFor()      return DEF.rangeBase or 26 end
local function lifeFor()       return DEF.life or 1.6 end
local function hitRadiusFor()  return DEF.hitRadius or 2.0 end
local function sizeFor()       return DEF.size or Vector3.new(0.25, 0.25, 1.6) end
local function colorFor()      return DEF.color or Color3.fromRGB(235,235,255) end
local function materialFor()   return DEF.material or Enum.Material.Neon end
local function pierceFor(lvl)  return DEF.pierce or 0 end   -- 0 = stopper på første

local function fireVolley(plr, lvl)
	local char = plr.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local dmg    = dmgFor(lvl)
	local bullets= bulletCountFor(lvl)
	local spread = math.rad(spreadDegFor(lvl))    -- til radianer
	local half   = spread * 0.5

	-- Fremad-vektor i XZ-plan
	local fwdXZ = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
	if fwdXZ.Magnitude < 1e-6 then fwdXZ = Vector3.new(0,0,-1) end

	-- Basis-akse for at rotere omkring Y
	local up = Vector3.new(0,1,0)

	-- Skyd N projektiler jævnt fordelt i fanen (symmetrisk omkring forward)
	for i = 0, bullets-1 do
		local t = (bullets == 1) and 0.5 or (i/(bullets-1))  -- 0..1
		local angle = -half + spread * t                     -- -half .. +half
		local dir = CFrame.fromAxisAngle(up, angle):VectorToWorldSpace(fwdXZ)

		PC.spawnLinear(plr, hrp, dir, {
			speed      = speedFor(),
			range      = rangeFor(),
			life       = lifeFor(),
			size       = sizeFor(),
			color      = colorFor(),
			material   = materialFor(),
			hitRadius  = hitRadiusFor(),
			damage     = dmg,
			fctId      = Ab.Fan and Ab.Fan.id or "WEAPON_FAN",
			pierce     = pierceFor(lvl),
			hitCooldown= 0.08,
			yMode      = "foot",      -- samme højde som Spinner/Plus/Cross
			yOffset    = 0.0,
		})
	end
end

local M = { id = (DEF.id or "WEAPON_FAN"), levelKey = LEVEL_KEY }

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up  = plr:FindFirstChild("Upgrades")
			local lvl = up and up[M.levelKey] and up[M.levelKey].Value or 0

			if lvl > 0 and not (C.offensivePaused and C.offensivePaused(plr)) then
				fireVolley(plr, lvl)
				C.waitScaled(plr, intervalFor(plr, lvl))
			else
				task.wait(0.35)
			end
		end
	end)
end

return M

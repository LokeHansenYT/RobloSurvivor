-- ServerScriptService/Abilities/Cross.lua
-- Kryds: diagonale projektiler; ulige lvls +1 dmg, lige lvls +1 projektil.
-- Bruger Shared.ProjectileCore og låser til fodhøjde.

local RS        = game:GetService("ReplicatedStorage")
local C         = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab, FCT   = C.Ab, C.FCT
local PC        = require(RS.Shared:WaitForChild("ProjectileCore"))

local M = { id = Ab.Cross.id, levelKey = "CrossLevel" }

local function dmgFor(lvl)
	return (Ab.Cross.damageBase or 1) + math.max(0, ((lvl - 1 + 1) // 2))
end

local DIRS = {
	Vector3.new( 1,0, 1).Unit,
	Vector3.new(-1,0  ,1).Unit,
	Vector3.new( 1,0,-1).Unit,
	Vector3.new(-1,0,-1).Unit,
}

local function fireOne(plr, hrp, dir, dmg)
	PC.spawnLinear(plr, hrp, dir, {
		speed      = Ab.Cross.speed      or 42,
		range      = Ab.Cross.rangeBase  or 24,
		life       = Ab.Cross.life       or 1.5,
		size       = Ab.Cross.size       or Vector3.new(0.25, 0.25, 1.8),
		color      = Ab.Cross.color      or Color3.fromRGB(200,230,255),
		material   = Ab.Cross.material   or Enum.Material.Neon,
		hitRadius  = Ab.Cross.hitRadius  or 2.2,
		damage     = dmg,
		fctId      = M.id,
		pierce     = Ab.Cross.pierce     or 0,
		hitCooldown= 0.08,
		yMode      = "foot",
		yOffset    = 0.0,
	})
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up  = plr:FindFirstChild("Upgrades")
			local lvl = up and up[M.levelKey] and up[M.levelKey].Value or 0
			if lvl > 0 and not (C.offensivePaused and C.offensivePaused(plr)) then
				local ch  = plr.Character
				local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dmg   = dmgFor(lvl)
					-- skyd alle fire retninger pr. volley
					for _, d in ipairs(DIRS) do
						fireOne(plr, hrp, d, dmg)
					end
				end
				C.waitScaled(plr, Ab.Cross.interval or (0.8 * 4))
			else
				task.wait(0.35)
			end
		end
	end)
end

return M

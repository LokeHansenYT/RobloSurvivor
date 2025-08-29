-- ServerScriptService/Abilities/Plus.lua
-- Plus: 4 retninger samtidigt; ulige lvls +1 skade, lige lvls +1 projektil pr. retning.
-- Bruger Shared.ProjectileCore for ens bevægelse/hit og korrekt fodhøjde.

local RS        = game:GetService("ReplicatedStorage")
local C         = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab, FCT   = C.Ab, C.FCT
local PC        = require(RS.Shared:WaitForChild("ProjectileCore"))

local M = { id = Ab.Plus.id, levelKey = "PlusLevel" }

local function dmgFor(lvl)
	return (Ab.Plus.damageBase or 1) + math.floor((lvl + 1) / 2) -- ulige lvls +1
end

local function dirsFrom(hrp) -- frem, tilbage, højre, venstre i XZ-plan
	local f = Vector3.new(hrp.CFrame.LookVector.X,  0, hrp.CFrame.LookVector.Z).Unit
	local r = Vector3.new(hrp.CFrame.RightVector.X, 0, hrp.CFrame.RightVector.Z).Unit
	return { f, -f, r, -r }
end

local function fireLine(plr, hrp, dir, dmg)
	PC.spawnLinear(plr, hrp, dir, {
		speed      = Ab.Plus.speed      or 42,
		range      = Ab.Plus.rangeBase  or 24,
		life       = Ab.Plus.life       or 1.5,
		size       = Ab.Plus.size       or Vector3.new(0.25, 0.25, 1.6),
		color      = Ab.Plus.color      or Color3.fromRGB(235,235,255),
		material   = Ab.Plus.material   or Enum.Material.Neon,
		hitRadius  = Ab.Plus.hitRadius  or 2.0,
		damage     = dmg,
		fctId      = M.id,
		pierce     = Ab.Plus.pierce     or 0,
		hitCooldown= 0.08,
		yMode      = "foot",   -- samme højde som Spinner/Cross
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
					local dirs  = dirsFrom(hrp)
					local shots = 1 + math.floor(lvl / 2) -- lige lvls +1 “bølge”
					for s = 1, shots do
						for _, d in ipairs(dirs) do
							fireLine(plr, hrp, d, dmg)
						end
						task.wait(0.2) -- lille forskydning for pæn bølge
					end
				end
				C.waitScaled(plr, Ab.Plus.interval or (0.8 * 4))
			else
				task.wait(0.35)
			end
		end
	end)
end

return M

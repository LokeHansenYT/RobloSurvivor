local RS = game:GetService("ReplicatedStorage")
local AuraVis = require(RS.Shared:WaitForChild("AuraVisual"))
local C       = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab      = C.Ab
local DEF, KEY = Ab.FireAura or {}, "FireAuraLevel"

local function rFor(l)  local b=DEF.radius or 7;  local g=DEF.radiusGrowth or 0.6; return b + g*math.max(0,(l or 1)-1) end
local function durFor(l) local b=DEF.duration or 3;local g=DEF.durationGrowth or 1;  return b + g*math.max(0,(l or 1)-1) end
local function chFor(l)  local b=DEF.chance or 0.10;local g=DEF.chanceGrowth or 0.01; return b + g*math.max(0,(l or 1)-1) end
local function tickFor(plr) local base=DEF.tick or 0.5; return (C.scaleInterval and C.scaleInterval(plr, base)) or base end

local M = { id = DEF.id or "WEAPON_FIREAURA", levelKey = KEY }

local function startBurnTick(enemy)
	if enemy:GetAttribute("BurnTicker") then return end
	enemy:SetAttribute("BurnTicker", 1)
	task.spawn(function()
		while enemy.Parent do
			local untilT = enemy:GetAttribute("BurnUntil") or 0
			local dps    = enemy:GetAttribute("BurnDPS") or 0
			if time() >= untilT or dps <= 0 then
				enemy:SetAttribute("BurnTicker", nil)
				break
			end
			local hum = enemy:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum:TakeDamage(dps)
				-- vis “BURNING” løbende
				if C.FCT then
					if C.FCT.ShowDebuff then pcall(C.FCT.ShowDebuff, enemy, "BURNING") end
					if C.FCT.ShowStatus and not C.FCT.ShowDebuff then pcall(C.FCT.ShowStatus, enemy, "BURNING") end
				end
			end
			task.wait(1.0)
		end
	end)
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local ch   = plr.Character or plr.CharacterAdded:Wait()
			local hrp  = ch:WaitForChild("HumanoidRootPart")
			local vis; local active=false

			while plr.Parent and ch.Parent do
				local up  = plr:FindFirstChild("Upgrades")
				local lvl = up and up:FindFirstChild(KEY) and up[KEY].Value or 0
				local paused = (C.offensivePaused and C.offensivePaused(plr)) or false
				if lvl > 0 and not paused then
					if not vis then
						vis = AuraVis.new(hrp, {
							parent=ch, name="FireAuraRing",
							color=Color3.fromRGB(255,140,40), offset=0.08, height=0.05,
							transparency=0.35, alwaysOnTop=true,
							idle={fadePeriod=0.9, pause=2.0, alphaMin=0.88, alphaMax=1.0},
							cast={duration=0.18, alpha=0.9, edgeMinPct=0.18},
						})
					end
					local r = rFor(lvl)
					if vis then vis:update(r); vis:castPulse(r) end

					local dur = durFor(lvl)
					local zid = plr:GetAttribute("ZoneId")

					-- brænd fjender i radius
					for _, e in ipairs(C.getEnemies(zid)) do
						local pp=e.PrimaryPart; local hum=e:FindFirstChildOfClass("Humanoid")
						local hrp2 = ch:FindFirstChild("HumanoidRootPart")
						if pp and hum and hrp2 and hum.Health>0 and (pp.Position-hrp2.Position).Magnitude <= r then
							local untilT = time() + dur
							if (e:GetAttribute("BurnUntil") or 0) < untilT then e:SetAttribute("BurnUntil", untilT) end
							e:SetAttribute("BurnDPS", DEF.dps or 1)
							-- én synlig “BURNING” i det øjeblik vi sætter
							if C.FCT then
								if C.FCT.ShowDebuff then pcall(C.FCT.ShowDebuff, e, "BURNING") end
								if C.FCT.ShowStatus and not C.FCT.ShowDebuff then pcall(C.FCT.ShowStatus, e, "BURNING") end
							end
							startBurnTick(e)
						end
					end

					-- enkel spredning: brændende ? naboer indenfor 4 studs, chance pr. tick
					local chance = chFor(lvl)
					for _, src in ipairs(C.getEnemies(zid)) do
						if (src:GetAttribute("BurnUntil") or 0) > time() then
							local pps = src.PrimaryPart
							if pps then
								for _, dst in ipairs(C.getEnemies(zid)) do
									if dst ~= src then
										local ppd = dst.PrimaryPart
										if ppd and (ppd.Position - pps.Position).Magnitude <= 4 then
											if math.random() < chance then
												local u = time() + durFor(lvl)
												if (dst:GetAttribute("BurnUntil") or 0) < u then dst:SetAttribute("BurnUntil", u) end
												dst:SetAttribute("BurnDPS", DEF.dps or 1)
												if C.FCT then
													if C.FCT.ShowDebuff then pcall(C.FCT.ShowDebuff, dst, "BURNING") end
													if C.FCT.ShowStatus and not C.FCT.ShowDebuff then pcall(C.FCT.ShowStatus, dst, "BURNING") end
												end
												startBurnTick(dst)
											end
										end
									end
								end
							end
						end
					end

					active=true
					C.waitScaled(plr, tickFor(plr))
				else
					if active and vis then vis:destroy(); vis=nil end
					active=false; task.wait(0.3)
				end
			end
			if vis then vis:destroy() end
		end
	end)
end

return M

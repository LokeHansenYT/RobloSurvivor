-- ServerScriptService/Abilities/BounceBall.lua
local RunService = game:GetService("RunService")
local Debris     = game:GetService("Debris")
local C          = require(script.Parent._core.AbilityCommon)
local Ab         = C.Ab

local M = { id = Ab.BounceBall.id, levelKey = "BounceBallLevel" }

local function dmgFor(lvl)
	local d = Ab.BounceBall
	return math.floor((d.baseDamage or 8) + (d.damageGrowth or 3) * math.max(0, lvl-1))
end
local function maxBouncesFor(lvl)
	local d = Ab.BounceBall
	return (d.maxBounces or 2) + math.floor(math.max(0,lvl-1)/2)
end

local function nearestEnemy(fromPos, zid, exclude)
	local best, bestD = nil, math.huge
	for _,e in ipairs(C.getEnemies(zid)) do
		if not exclude[e] then
			local pp = e.PrimaryPart
			local hum = e:FindFirstChildOfClass("Humanoid")
			if pp and hum and hum.Health>0 then
				local d = (pp.Position - fromPos).Magnitude
				if d < bestD then best, bestD = e, d end
			end
		end
	end
	return best, bestD
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up  = plr:FindFirstChild("Upgrades")
			local lvl = up and up[M.levelKey] and up[M.levelKey].Value or 0
			if lvl > 0 and not (C.offensivePaused and C.offensivePaused(plr)) then
				local ch  = plr.Character; local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp then
					local zid       = plr:GetAttribute("ZoneId")
					local speed     = Ab.BounceBall.speed  or 70
					local range     = Ab.BounceBall.range  or 50
					local hitR      = Ab.BounceBall.hitRadius or 2.6
					local ttl       = Ab.BounceBall.ttl or 4
					local bounces   = maxBouncesFor(lvl)
					local dmg       = dmgFor(lvl)
					local bounceSR  = Ab.BounceBall.bounceSearchRadius or 40

					local pos = hrp.Position + hrp.CFrame.LookVector * 2
					local y   = (C.PROJECTILE_Y or pos.Y)
					pos = Vector3.new(pos.X, y, pos.Z)

					-- første retning: mod nærmeste fjende, ellers fremad
					local firstTarget = nearestEnemy(pos, zid, {})
					local dir = firstTarget and (firstTarget.PrimaryPart.Position - pos).Unit or hrp.CFrame.LookVector
					dir = Vector3.new(dir.X, 0, dir.Z).Unit

					local ball = Instance.new("Part")
					ball.Anchored = true; ball.CanCollide = false; ball.CanTouch = false; ball.CanQuery = false
					ball.Material = Enum.Material.Neon; ball.Color = Color3.fromRGB(255, 230, 90)
					ball.Size = Vector3.new(0.8, 0.8, 0.8)
					ball.CFrame = CFrame.new(pos)
					ball.Parent = workspace
					Debris:AddItem(ball, ttl + 0.2)

					local t0, traveled = os.clock(), 0
					local hitSet = {} -- undgå at hoppe straks tilbage til samme mål

					while ball.Parent do
						local dt = RunService.Heartbeat:Wait()
						if os.clock() - t0 > ttl then break end
						local step = speed * dt
						traveled += step
						if traveled > range then break end

						pos += dir * step
						ball.CFrame = CFrame.new(pos)

						-- hit-check
						local hitEnemy = nil
						for _,e in ipairs(C.getEnemies(zid)) do
							if not hitSet[e] then
								local pp = e.PrimaryPart
								local hum = e:FindFirstChildOfClass("Humanoid")
								if pp and hum and hum.Health>0 then
									local d = (pp.Position - pos).Magnitude
									if d <= hitR then hitEnemy = e; break end
								end
							end
						end

						if hitEnemy then
							C.dealDamage(hitEnemy, dmg, M.id)
							hitSet[hitEnemy] = true
							if bounces > 0 then
								bounces -= 1
								-- find næste mål tæt på det ramte
								local nextT, dist = nearestEnemy(hitEnemy.PrimaryPart.Position, zid, hitSet)
								if nextT and dist <= bounceSR then
									dir = (nextT.PrimaryPart.Position - pos).Unit
									dir = Vector3.new(dir.X, 0, dir.Z).Unit
								else
									break
								end
							else
								break
							end
						end
					end

					if ball and ball.Parent then ball:Destroy() end
				end
				C.waitScaled(plr, Ab.BounceBall.cooldown or 1.2)
			else
				task.wait(0.3)
			end
		end
	end)
end

return M

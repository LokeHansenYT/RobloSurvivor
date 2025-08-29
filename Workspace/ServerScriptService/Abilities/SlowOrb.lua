-- ServerScriptService/Abilities/SlowOrb.server.lua
-- Langsom orb der “hugger” jorden, rammer flere og skubber. Større og ~30% langsommere end originalen.
local RunService = game:GetService("RunService")
local C = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab, FCT = C.Ab, C.FCT
local M = { id = Ab.SlowOrb.id, levelKey = "SlowOrbLevel" }

-- Tuning: 2.5x større, ~30% langsommere (70% af opr. hastighed)
local SIZE_MULT  = 2.5
local SPEED_MULT = 0.7

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up = plr:FindFirstChild("Upgrades")
			local lvl = up and up:FindFirstChild(M.levelKey) and up[M.levelKey].Value or 0
			if lvl>0 and not C.offensivePaused(plr) then
				local ch = plr.Character; local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp then
					local cfg = Ab.SlowOrb
					local hitsLeft = cfg.maxHits + (lvl-1)*cfg.hitsPerLevel
					local dmg  = C.baseDamageFor(plr) * (cfg.damageMult*(cfg.damageGrowth^(lvl-1)))
					local speed= (cfg.speed * (cfg.speedGrowth^(lvl-1))) * SPEED_MULT
					local ttl  = cfg.ttl

					local groundY = C.getGroundY(hrp.Position, {plr.Character})
					local posY    = math.min(hrp.Position.Y - 1.0, groundY + 1.0)
					local dir     = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
					local pos     = Vector3.new(hrp.Position.X, posY, hrp.Position.Z)

					local orb = Instance.new("Part")
					orb.Shape=Enum.PartType.Ball
					local baseSize = 1.2
					local finalSize = baseSize * SIZE_MULT
					orb.Size = Vector3.new(finalSize, finalSize, finalSize)
					orb.Material=Enum.Material.Neon
					orb.Color=Color3.fromRGB(255,120,50)
					orb.CanCollide=false
					orb.Anchored=true
					orb.CFrame=CFrame.new(pos)
					orb.Name="SlowOrb"
					orb.Parent=workspace

					local ORB_R = orb.Size.X * 0.5
					local lastHit = {}

					while orb.Parent and hitsLeft > 0 and ttl > 0 do
						local dt = RunService.Heartbeat:Wait()
						ttl -= dt
						pos = Vector3.new(pos.X + dir.X*speed*dt, posY, pos.Z + dir.Z*speed*dt)
						orb.CFrame = CFrame.new(pos)

						local zid = plr:GetAttribute("ZoneId")
						for _, e in ipairs(C.getEnemies(zid)) do
							local pp = e.PrimaryPart
							if pp then
								local ep = pp.Position
								local dXZ = (Vector2.new(ep.X, ep.Z) - Vector2.new(pos.X, pos.Z)).Magnitude
								local dY  = math.abs(ep.Y - posY)
								if dXZ <= (ORB_R + 1.1) and dY <= 3.0 then
									local hum = e:FindFirstChildOfClass("Humanoid")
									if hum and hum.Health > 0 then
										local now = os.clock()
										if not lastHit[e] or (now - lastHit[e]) > cfg.hitSameEnemyCD then
											lastHit[e] = now
											hum:TakeDamage(dmg)
											FCT.ShowDamage(e, dmg, M.id)
											pp.AssemblyLinearVelocity = dir * cfg.knockback + Vector3.new(0, 8, 0)
											pp:SetAttribute("KnockbackUntil", os.clock() + 0.25)
											hitsLeft -= 1
											if hitsLeft <= 0 then break end
										end
									end
								end
							end
						end
					end

					if orb and orb.Parent then orb:Destroy() end
					task.wait(0.25)
				else
					task.wait(0.2)
				end
			else
				task.wait(0.3)
			end
		end
	end)
end

return M

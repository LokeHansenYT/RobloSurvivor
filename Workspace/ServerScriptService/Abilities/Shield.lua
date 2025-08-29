-- ServerScriptService/Abilities/Shield.lua
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local C  = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab = C.Ab

local ShieldCfg = Ab and Ab.Shield or {}
local M = { id = ShieldCfg.id or "WEAPON_SHIELD", levelKey = "ShieldLevel" }

local function dmgAtLevel(lvl)
	local base   = ShieldCfg.baseDamage or 5
	local growth = ShieldCfg.damageGrowth or 1.20
	return math.floor(base * (growth ^ math.max(0, lvl-1)))
end
local function angSpeedAtLevel(lvl)
	local base   = ShieldCfg.angularSpeed or 90
	local growth = ShieldCfg.speedGrowth  or 1.08
	return base * (growth ^ math.max(0, lvl-1))
end
local function countAtLevel(lvl)
	local base = ShieldCfg.baseCount or 1
	local inc  = ShieldCfg.countPerLevel or 1
	return math.max(1, math.min(8, base + inc * math.max(0, lvl-1)))
end

local ORBIT_R   = ShieldCfg.radius       or 5
local HIT_CD    = ShieldCfg.hitCooldown  or 0.35
local KNOCKBACK = ShieldCfg.knockback    or 25
local ORB_SIZE  = Vector3.new(1.6, 1.6, 1.6)
local ORB_COLOR = Color3.fromRGB(200, 255, 255)

function M.start(plr)
	task.spawn(function()
		local folder = Instance.new("Folder"); folder.Name = "Shields_" .. plr.UserId; folder.Parent = workspace
		local lastHitAt = {}

		local function ensureOrb(i)
			local n = ("Shield_%d"):format(i)
			local p = folder:FindFirstChild(n)
			if not p then
				p = Instance.new("Part")
				p.Name, p.Shape, p.Size = n, Enum.PartType.Ball, ORB_SIZE
				p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
				p.Material, p.Color = Enum.Material.Neon, ORB_COLOR
				p.Parent = folder
			end
			return p
		end
		local function destroyExtra(keep)
			local i=0; for _,c in ipairs(folder:GetChildren()) do
				if c:IsA("BasePart") and c.Name:match("^Shield_") then i+=1; if i>keep then c:Destroy() end end
			end
		end

		local angleDeg = 0
		while plr.Parent do
			local up  = plr:FindFirstChild("Upgrades")
			local lvl = (up and up:FindFirstChild(M.levelKey)) and up[M.levelKey].Value or 0
			local ch  = plr.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			local dt  = RunService.Heartbeat:Wait()

			if lvl > 0 and hrp and not C.offensivePaused(plr) then
				local orbCount = countAtLevel(lvl)
				local dps      = dmgAtLevel(lvl)
				local angSpd   = angSpeedAtLevel(lvl)
				angleDeg = (angleDeg + angSpd * dt) % 360

				-- LAVERE bane (default ~1.0 over fødder)
				local yOffset = ShieldCfg.yOffset; if yOffset == nil then yOffset = 1.0 end

				for i=1,orbCount do
					local orb = ensureOrb(i)
					local a   = math.rad(angleDeg + (i-1) * (360/orbCount))
					local pos = Vector3.new(
						hrp.Position.X + math.cos(a)*ORBIT_R,
						hrp.Position.Y + yOffset,
						hrp.Position.Z + math.sin(a)*ORBIT_R
					)
					orb.CFrame = CFrame.new(pos)
				end
				destroyExtra(orbCount)

				-- Kollision (2D XZ-afstand + vertikal toler.)
				local zid = plr:GetAttribute("ZoneId")
				if zid then
					local enemies = C.getEnemies(zid)
					if #enemies > 0 then
						for _,orb in ipairs(folder:GetChildren()) do
							if orb:IsA("BasePart") and orb.Name:match("^Shield_") then
								for _,e in ipairs(enemies) do
									local pp = e.PrimaryPart
									if pp then
										local horiz = (Vector2.new(pp.Position.X, pp.Position.Z) - Vector2.new(orb.Position.X, orb.Position.Z)).Magnitude
										local vert  = math.abs(pp.Position.Y - orb.Position.Y)
										if horiz <= 2.2 and vert <= 2.5 then
											local now = os.clock()
											local last = lastHitAt[e]
											if not last or (now - last) >= HIT_CD then
												lastHitAt[e] = now
												C.dealDamage(e, dps, M.id, C.DAMAGE.Physical, { knockback = KNOCKBACK, from = orb.Position })
											end
										end
									end
								end
							end
						end
					end
				end
			else
				task.wait(0.35)
			end
		end
		if folder then folder:Destroy() end
	end)
end

return M

--[[
EnemyAI.lua — bevægelse, kontakt-skade, ranged og XP/BP-awards ved død

Formål
  • Køre fjendens adfærdsløkke uafhængigt af spawneren.
  • Respekterer ZoneId + CombatEnabled (kun skad i aktive kampzoner).
  • Award XP (via global _G.AddXP hvis tilgængelig, ellers fallback) & BossPoints.

API
  start(Zones: table, zid: number, enemy: Model, body: BasePart, hum: Humanoid): ()
    - Starter en task.spawn(...) som holder livscyklus, og rydder op ved død.

Afhængigheder
  • RS.Shared.EnemyConfig, RS.Shared.ProgressionConfig
  • Systems.ZoneIndex (clampToTop, pointInZoneXZ)

Bemærk
  • Weak map til kontakt-cooldown for at undgå memory leaks.
]]--

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris    = game:GetService("Debris")
local RS        = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")


local ZoneIndex = require(script.Parent:WaitForChild("ZoneIndex"))
local EnemyConfig = require(RS.Shared:WaitForChild("EnemyConfig"))
local Prog        = (function() local ok,mod=pcall(function() return require(RS.Shared.ProgressionConfig) end); return ok and mod or {} end)()

local _contactHitAt = setmetatable({}, { __mode = "k" }) -- weak map

-- Debug-toggle: Zone-attribute "DebugBossBP" har højst prioritet, ellers Workspace.DebugBossBP
-- Globalt: vælg Workspace ? Attributes ? tilføj Bool ? navn: DebugBossBP ? true/false
local function BossBPDebugOn(Zones, zid)
	local z = Zones and Zones[zid] and Zones[zid].inst
	if z then
		local v = z:GetAttribute("DebugBossBP")
		if v ~= nil then return v == true end
	end
	return workspace:GetAttribute("DebugBossBP") == true
end


local M = {}

local function getAliveCharactersInZone(Zones, zid)
	local t = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("ZoneId") == zid and plr:GetAttribute("CombatEnabled")==true then
			local ch = plr.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then table.insert(t, ch) end
		end
	end
	return t
end

function M.start(Zones, zid, enemy: Model, body: BasePart, hum: Humanoid)
	local function awardXPAndCleanup()
		local nearestPlr, best = nil, math.huge
		for _,plr in ipairs(Players:GetPlayers()) do
			if plr:GetAttribute("ZoneId")==zid and plr:GetAttribute("CombatEnabled")==true then
				local ch2=plr.Character; local h2=ch2 and ch2:FindFirstChildOfClass("Humanoid")
				local r2=ch2 and ch2:FindFirstChild("HumanoidRootPart")
				if h2 and r2 and h2.Health>0 then
					local d=(r2.Position - body.Position).Magnitude
					if d<best then nearestPlr, best = plr, d end
				end
			end
		end
		if nearestPlr then
			local gain  = (EnemyConfig.XPDropped or 1) * (body:GetAttribute("XPMult") or 1)
			local bonus = nearestPlr:GetAttribute("Buff_XPBonusPerKill") or 0
			if _G.AddXP then _G.AddXP(nearestPlr, gain + bonus, enemy)
			else
				if nearestPlr:FindFirstChild("XP") then nearestPlr.XP.Value += gain + bonus end
			end

			if body:GetAttribute("IsBoss") then
				local award = (EnemyConfig and EnemyConfig.BossPointPerBossKill) or 1
				local ls = nearestPlr:FindFirstChild("leaderstats")
				local bpLeader = ls and ls:FindFirstChild("BP")
				local bpLoose  = nearestPlr:FindFirstChild("BossPoints")

				if BossBPDebugOn(Zones, zid) then
					local beforeL = bpLeader and bpLeader.Value or "nil"
					local beforeB = bpLoose  and bpLoose.Value  or "nil"
					print(("[BossBP] Boss died in Zone %s ? nearest %s | award=%d | BEFORE leaderBP=%s, BossPoints=%s")
						:format(tostring(zid), nearestPlr.Name, award, tostring(beforeL), tostring(beforeB)))
				end

				if bpLeader then bpLeader.Value += award end
				if bpLoose  then bpLoose.Value  += award end

				if BossBPDebugOn(Zones, zid) then
					local afterL = bpLeader and bpLeader.Value or "nil"
					local afterB = bpLoose  and bpLoose.Value  or "nil"
					print(("[BossBP] AFTER leaderBP=%s, BossPoints=%s")
						:format(tostring(afterL), tostring(afterB)))
				end
			end
		end
		if enemy and enemy.Parent then enemy:Destroy() end
	end

	local dead=false
	hum.Died:Connect(function() if not dead then dead=true; awardXPAndCleanup() end end)
	hum.HealthChanged:Connect(function(h) if h<=0 and not dead then dead=true; awardXPAndCleanup() end end)

	local function maybeRangedAttack(body: BasePart, targetHRP: BasePart)
		local now = os.clock()
		if now < (body:GetAttribute("StunnedUntil") or 0) then return end
		-- Læs ranged indstillinger fra Attributes (sættes af Fusion ved høje tiers)
		local lvl = body:GetAttribute("RangedLevel") or 0
		if lvl <= 0 then return end

		local rng = body:GetAttribute("RangedRange") or 0
		local dmg = body:GetAttribute("RangedDamage") or 0
		if rng <= 0 or dmg <= 0 then return end

		-- Cooldown via Attribute (Instances kan ikke få vilkårlige felter)
		local now   = os.clock()
		local last  = body:GetAttribute("LastShotAt") or 0
		local cd    = math.max(1.5, 3.0 - lvl*0.2) -- lidt hurtigere ved højere tier
		if (now - last) < cd then return end
		body:SetAttribute("LastShotAt", now)

		-- Opret projektil
		local proj = Instance.new("Part")
		proj.Shape = Enum.PartType.Ball
		proj.Size = Vector3.new(0.6, 0.6, 0.6)
		proj.Color = Color3.fromRGB(255, 120, 60)
		proj.Material = Enum.Material.Neon
		proj.CanCollide = false
		proj.Anchored = false
		proj.CFrame = body.CFrame
		proj.Parent = workspace:FindFirstChild("ProjectilesFolder") or workspace

		-- Skyd mod mål
		local dir = (targetHRP.Position - body.Position).Unit
		proj.AssemblyLinearVelocity = dir * (18 + 4*lvl)

		-- Kun spillere tager skade (ignorer andre enemies)
		local touched
		touched = proj.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			if not model then return end
			-- Ignorer alle objekter tagget som Enemy
			if CollectionService:HasTag(model, "Enemy") then return end

			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:TakeDamage(dmg)
				if touched then touched:Disconnect() end
				proj:Destroy()
			end
		end)

		game:GetService("Debris"):AddItem(proj, 5)
	end


	task.spawn(function()
		while enemy.Parent and hum.Health>0 do
			local tNow = os.clock()
			if tNow < (body:GetAttribute("StunnedUntil") or 0) then
				body.AssemblyLinearVelocity = body.AssemblyLinearVelocity * 0.98
			else
				local targets = getAliveCharactersInZone(Zones, zid)
				local closestHRP, cd=nil, math.huge
				for _,t in ipairs(targets) do
					local r=t:FindFirstChild("HumanoidRootPart")
					if r then local d=(r.Position - body.Position).Magnitude; if d<cd then closestHRP,cd=r,d end end
				end
				if closestHRP then
					local dir = closestHRP.Position - body.Position; dir=Vector3.new(dir.X,0,dir.Z)
					local zoneMul = body:GetAttribute("MoveSpeedMult") or 1
					local hordeMul = body:GetAttribute("Horde_SpeedMult") or 1
					local tierMul  = 1 + 0.03*(body:GetAttribute("Tier") or 0)
					local finalSpeed = (EnemyConfig.MoveSpeed or 10)*zoneMul*hordeMul*tierMul
					body.AssemblyLinearVelocity = (dir.Magnitude>1e-4) and dir.Unit*finalSpeed or Vector3.new(0,0,0)
					if not ZoneIndex.pointInZoneXZ(Zones[zid], body.Position) then
						local clamped = ZoneIndex.clampToTop(Zones[zid], body.Position)
						body.CFrame = CFrame.new(clamped)
						body.AssemblyLinearVelocity = Vector3.new(0, body.AssemblyLinearVelocity.Y, 0)
					end
					-- kontakt damage
					local cr = EnemyConfig.ContactRange or 3.0
					local off = closestHRP.Position - body.Position
					if Vector2.new(off.X,off.Z).Magnitude <= cr then
						local hum2 = closestHRP.Parent and closestHRP.Parent:FindFirstChildOfClass("Humanoid")
						if hum2 and hum2.Health>0 then
							local plr = game.Players:GetPlayerFromCharacter(closestHRP.Parent)
							local okZone = plr and (plr:GetAttribute("ZoneId")==zid)
							local combat = plr and (plr:GetAttribute("CombatEnabled")==true)
							local invuln = plr and plr:FindFirstChild("Invulnerable") and plr.Invulnerable.Value
							if okZone and combat and not invuln then
								local map = _contactHitAt[body]; if not map then map=setmetatable({}, {__mode="k"}); _contactHitAt[body]=map end
								local last = map[closestHRP.Parent] or 0
								if (tNow - last) >= (Prog.EnemyTouchCooldown or 0.8) then
									map[closestHRP.Parent] = tNow
									local touchMult = body:GetAttribute("TouchDamageMult") or 1
									local base = Prog.EnemyTouchDamage or 5
									local tier = body:GetAttribute("Tier") or 0
									local dmg = math.floor((base + tier) * touchMult)
									hum2:TakeDamage(math.max(1, dmg))
								end
							end
						end
					end
					maybeRangedAttack(body, closestHRP)
				else
					body.AssemblyLinearVelocity = Vector3.new(0,0,0)
				end
			end
			task.wait(0.05)
		end
	end)
end

return M

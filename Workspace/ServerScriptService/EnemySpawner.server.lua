-- ServerScriptService/EnemySpawner.server.lua
-- Zone-baseret enemy-spawn & AI
-- ? Per-player spawner: hver eligible spiller i en (ikke-safe) zone har sin egen spawn-timer
-- ? Kontinuerlig acceleration: interval falder gradvist mod gulv, s? pres stiger over tid
-- ? Bevarer: ground-snap, zone-clamp, horde, kontakt-CD (weak map), fusion, boss, XP
-- ? Ingen t?thedscaps ? tempo styres KUN af per-player spawners + dine EnemyConfig-tal

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")
local Workspace         = game:GetService("Workspace")
local PhysicsService    = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local RS                = game:GetService("ReplicatedStorage")

-- Systems (Etape 1)
local Systems   = game:GetService("ServerScriptService"):WaitForChild("Systems")
local Util      = require(Systems:WaitForChild("Util"))
local ZoneIndex = require(Systems:WaitForChild("ZoneIndex"))
local HUDSync   = require(Systems:WaitForChild("HUDSync"))

-- Systems (Etape 2)
local EnemyFactory = require(Systems:WaitForChild("EnemyFactory"))
local EnemyAI      = require(Systems:WaitForChild("EnemyAI"))

-- Systems (Etape 3)
local SpawnRules = require(Systems:WaitForChild("SpawnRules"))
local BossManager = require(Systems:WaitForChild("BossManager"))

-- Systems (Etape 4)
local Fusion = require(Systems:WaitForChild("Fusion"))





local EnemyConfig = require(RS.Shared.EnemyConfig)
local UpgradeCfg  = (function() local ok,mod=pcall(function() return require(RS.Shared.EnemyUpgradeConfig) end); return ok and mod or {} end)()
local Prog        = (function() local ok,mod=pcall(function() return require(RS.Shared.ProgressionConfig) end); return ok and mod or {} end)()

-- ==== Kollision ====
pcall(function() PhysicsService:RegisterCollisionGroup("Enemies") end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable("Enemies", "Default", true)
	PhysicsService:CollisionGroupSetCollidable("Enemies", "Enemies", true)
end)
pcall(function() PhysicsService:RegisterCollisionGroup("Players") end)
PhysicsService:CollisionGroupSetCollidable("Players", "Default", true)
PhysicsService:CollisionGroupSetCollidable("Enemies", "Players", false)

local function setPartGroupIfBasePart(obj) if obj:IsA("BasePart") then obj.CollisionGroup = "Players" end end
local function setCharacterCollisionGroup(char)
	for _,d in ipairs(char:GetDescendants()) do setPartGroupIfBasePart(d) end
	char.DescendantAdded:Connect(setPartGroupIfBasePart)
end
Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(setCharacterCollisionGroup) end)
for _,plr in ipairs(Players:GetPlayers()) do
	if plr.Character then setCharacterCollisionGroup(plr.Character) end
	plr.CharacterAdded:Connect(setCharacterCollisionGroup)
end



-- Til justering af ramp-up
local function zoneAttr(zone, name, default)
	local v = zone and zone:GetAttribute(name)
	if v == nil then return default end
	return v
end


-- Zones (via ZoneIndex)
local ZonesFolder     = Workspace:WaitForChild("Zones")
local ZoneEnemiesRoot = Workspace:FindFirstChild("ZoneEnemies") or Instance.new("Folder", Workspace)
ZoneEnemiesRoot.Name  = "ZoneEnemies"

local Zones = ZoneIndex.build(ZonesFolder, ZoneEnemiesRoot)

ZonesFolder.ChildAdded:Connect(function()
	Zones = ZoneIndex.build(ZonesFolder, ZoneEnemiesRoot)
end)
ZonesFolder.ChildRemoved:Connect(function()
	Zones = ZoneIndex.build(ZonesFolder, ZoneEnemiesRoot)
end)


-- Helpers (via Util/ZoneIndex)
local groundYAt        = Util.groundYAt
local placeOnGround    = Util.placeOnGround
local clampToZoneXZTop = ZoneIndex.clampToTop
local pointInZoneXZ    = ZoneIndex.pointInZoneXZ
local function getZoneAt(worldPos: Vector3)
	return ZoneIndex.getZoneAt(Zones, worldPos)
end


-- ==== Player eligibility ====
local function getPlayerLevel(plr)
	local ls = plr:FindFirstChild("leaderstats")
	local lvlVal = ls and ls:FindFirstChild("Level")
	return (lvlVal and lvlVal.Value) or 1
end
local function isPlayerEligibleForZone(plr, zid)
	if not zid or zid == -1 then return false end
	local z = Zones[zid]; if not z or z.isSafe then return false end
	local lvl = getPlayerLevel(plr)
	return lvl >= (z.minLvl or 1) and lvl <= (z.maxLvl or 9999)
end
local function updatePlayerZones()
	HUDSync.updatePlayerZones(Zones)
end

local function refreshZoneActivity()
	for zid, z in pairs(Zones) do
		local had = z.active
		local hasEligible = false
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr:GetAttribute("ZoneId") == zid and isPlayerEligibleForZone(plr, zid) then hasEligible = true; break end
		end
		if hasEligible and not z.isSafe then
			if not had then
				z.active      = true
				z.activatedAt = os.clock()
				z.bossNextAt  = os.clock() + (EnemyConfig.BossFirstAt or 60)
				z.spawners    = {} -- reset
			end
		else
			if had then
				for _, m in ipairs(z.enemies:GetChildren()) do if m:IsA("Model") and m.Name=="Enemy" then m:Destroy() end end
				z.active=false; z.activatedAt=0; z.bossNextAt=0; z.spawners={}
			end
		end
	end
end

-- ==== Spawn helpers ====
local function getAliveCharactersInZone(zid)
	local t = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("ZoneId") == zid and isPlayerEligibleForZone(plr, zid) then
			local ch = plr.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then table.insert(t, ch) end
		end
	end
	return t
end


-- === spawnOneEnemy (wrapper) ===============================================
local function spawnOneEnemy(zid: number, posWorld: Vector3, isBoss: boolean?)
	local z = Zones[zid]; if not z then return nil end
	return EnemyFactory.spawn({ zid = zid, pos = posWorld, isBoss = isBoss, zone = z })
end



local function spawnEnemyNear(character, zid, isBoss)
	local z = Zones[zid]; if not z then return end
	local hrp = character and character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
	local radius = math.random(EnemyConfig.SpawnRadiusMin or 14, EnemyConfig.SpawnRadiusMax or 26)
	local angle = math.random() * math.pi * 2
	local want = hrp.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
	local pos  = clampToZoneXZTop(z, want)
	return spawnOneEnemy(zid, pos, isBoss)
end



-- ==== Master-loop ====
task.spawn(function()
	while true do
		task.wait(0.25)
		updatePlayerZones()
		refreshZoneActivity()

		for zid, z in pairs(Zones) do
			if z.active then
				-- Saml planer fra BossManager + SpawnRules
				local plans = {}

				local bossPlans = BossManager.tick(Zones, zid)
				if bossPlans then
					for _,p in ipairs(bossPlans) do table.insert(plans, p) end
				end

				local spawnPlans = SpawnRules.tick(Zones, zid)
				if spawnPlans then
					for _,p in ipairs(spawnPlans) do table.insert(plans, p) end
				end

				-- Udfør planer
				for _,plan in ipairs(plans) do
					local e,b,h = spawnOneEnemy(plan.zid, plan.pos, plan.isBoss)
					if e then EnemyAI.start(Zones, plan.zid, e, b, h) end
				end

				Fusion.try(Zones, zid)
			end
		end
	end
end)


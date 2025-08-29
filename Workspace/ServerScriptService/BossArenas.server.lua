-- ServerScriptService/BossArenas.server.lua
-- Reagerer p? boss-spawns i zoner markeret IsBossArena = true
-- L?ser zonen (midlertidige v?gge), DoT over tid, join-vindue, bel?nner BossTokens.

local Players        = game:GetService("Players")
local Workspace      = game:GetService("Workspace")
local RunService     = game:GetService("RunService")
local Debris         = game:GetService("Debris")

local Rep            = game:GetService("ReplicatedStorage")
local EnemyConfig    = require(Rep.Shared:WaitForChild("EnemyConfig"))

-- === KONFIG (kan overrides via zone-attributes) =========================
local DEFAULTS = {
	JoinWindowSec       = 8,     -- sekunder efter boss-spawn hvor man m? g? ind
	BaseDoT             = 1,     -- skade/sek i starten
	DoTGrowthPerSec     = 0.20,  -- line?rt till?g/sek (0.2 => +1 dmg hvert 5. sekund)
	DoTTickSec          = 1.0,   -- hvor ofte vi ticker DoT
	WallHeight          = 40,    -- h?jde p? midlertidige v?gge
	WallThickness       = 1.5,
	WallTransparency    = 0.3,
	WallColor           = Color3.fromRGB(200, 80, 220), -- lilla-ish
	ReentryKickToZoneId = 0,     -- hvor sender vi folk hen hvis de pr?ver at g? ind efter join-vinduet (typisk safe = 0)
	KillBonusTokens     = 5,     -- ekstra tokens hvis bossen dr?bes
	TokenPerSurviveSec  = 1/10,  -- 1 token pr. 10 sek overlevelse (afrundet ned)
}

-- === HJ?LPERE ==============================================================

local ZonesFolder = Workspace:WaitForChild("Zones")
local ZoneEnemiesRoot = Workspace:FindFirstChild("ZoneEnemies") -- oprettes af EnemySpawner
if not ZoneEnemiesRoot then
	-- hvis f?rst gang p? tomt map
	ZoneEnemiesRoot = Instance.new("Folder")
	ZoneEnemiesRoot.Name = "ZoneEnemies"
	ZoneEnemiesRoot.Parent = Workspace
end

-- Sl? en zone op efter id
local function getZoneById(zid: number)
	for _,p in ipairs(ZonesFolder:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("ZoneId") == zid then
			return p
		end
	end
	return nil
end

-- Return?r ZoneEnemies/Zone_<zid> folder
local function getEnemyFolderForZoneId(zid: number)
	local name = "Zone_"..tostring(zid)
	local f = ZoneEnemiesRoot:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = ZoneEnemiesRoot
	end
	return f
end

-- Er spilleren i den givne zone (XZ-only)
local function pointInZoneXZ(part: BasePart, worldPos: Vector3)
	local lp = part.CFrame:PointToObjectSpace(worldPos)
	local h  = part.Size * 0.5
	return math.abs(lp.X) <= h.X and math.abs(lp.Z) <= h.Z
end

-- Find center/top af zone til teleportering o.l.
local function zoneTopCenter(part: BasePart)
	return part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y * 0.5 + 2, 0))
end

-- S?rg for at spiller har BossTokens (IntValue)
local function ensureBossTokens(plr: Player)
	local v = plr:FindFirstChild("BossTokens")
	if not v then
		v = Instance.new("IntValue")
		v.Name  = "BossTokens"
		v.Value = 0
		v.Parent = plr
	end
	return v
end

local function centerBossInZone(ArenaState)
	local boss = ArenaState.bossModel
	local zone = ArenaState.zonePart
	if boss and boss.PrimaryPart and zone then
		local body = boss.PrimaryPart
		local top  = zone.CFrame:PointToWorldSpace(Vector3.new(0, zone.Size.Y * 0.5 + 0.2, 0))
		body.AssemblyLinearVelocity = Vector3.new()
		body.CFrame = CFrame.new(top.X, top.Y + body.Size.Y * 0.5, top.Z)
	end
end


-- Byg 4 v?gge rundt om en zone-part (retning efter partens CFrame/Size)
local function buildWallsForZone(part: BasePart, height: number, thick: number, color: Color3, alpha: number)
	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "ArenaWalls_"..tostring(part:GetAttribute("ZoneId") or "?")
	wallsFolder.Parent = Workspace

	local cf   = part.CFrame
	local size = part.Size
	local hw, hh, hd = size.X*0.5, size.Y*0.5, size.Z*0.5

	local function makeWall(localPos: Vector3, sizeXZ: Vector2, yawDeg: number)
		local w = Instance.new("Part")
		w.Anchored = true
		w.CanCollide = true
		w.CanQuery = false
		w.CanTouch = false
		w.Color = color
		w.Material = Enum.Material.ForceField
		w.Transparency = alpha
		local worldPos = cf:PointToWorldSpace(localPos + Vector3.new(0, height*0.5, 0))
		w.Size = Vector3.new(sizeXZ.X, height, sizeXZ.Y)
		w.CFrame = (CFrame.new(worldPos) * cf.Rotation) * CFrame.Angles(0, math.rad(yawDeg), 0)
		w.Parent = wallsFolder
	end

	-- nord/syd v?gge (langs X), ?st/vest v?gge (langs Z)
	makeWall(Vector3.new( 0, 0, -hd + thick*0.5), Vector2.new(size.X, thick), 0)   -- nord
	makeWall(Vector3.new( 0, 0,  hd - thick*0.5), Vector2.new(size.X, thick), 0)   -- syd
	makeWall(Vector3.new(-hw + thick*0.5, 0, 0),  Vector2.new(size.Z, thick), 90)  -- vest
	makeWall(Vector3.new( hw - thick*0.5, 0, 0),  Vector2.new(size.Z, thick), 90)  -- ?st

	return wallsFolder
end

-- === ARENA STATE ============================================================

-- pr. boss-zone-id:
-- {
--   zonePart = BasePart,
--   active   = bool,
--   startedAt, joinCloseAt,
--   bossModel, bossHum,
--   wallsFolder,
--   participants = { [Player] = true },
--   aliveTime    = { [Player] = seconds },
--   lockedOut    = { [UserId] = true }, -- ingen re-entry f?r reset
-- }
local Arenas = {} :: { [number]: any }

-- l?s alle boss-arenas
for _,p in ipairs(ZonesFolder:GetChildren()) do
	if p:IsA("BasePart") and p:GetAttribute("IsBossArena") == true then
		local zid = p:GetAttribute("ZoneId")
		if typeof(zid) == "number" then
			Arenas[zid] = {
				zonePart     = p,
				active       = false,
				bossModel    = nil,
				bossHum      = nil,
				wallsFolder  = nil,
				participants = {},
				aliveTime    = {},
				lockedOut    = {},
				startedAt    = 0,
				joinCloseAt  = 0,
			}
		end
	end
end

-- === ARENA LIFECYCLE ========================================================

local function readCfgFromZone(part: BasePart)
	return {
		JoinWindowSec   = part:GetAttribute("JoinWindowSec")      or DEFAULTS.JoinWindowSec,
		BaseDoT         = part:GetAttribute("BossBaseDoT")        or DEFAULTS.BaseDoT,
		DoTGrowthPerSec = part:GetAttribute("BossDoTGrowthPerSec")or DEFAULTS.DoTGrowthPerSec,
		DoTTickSec      = DEFAULTS.DoTTickSec,
		WallHeight      = DEFAULTS.WallHeight,
		WallThickness   = DEFAULTS.WallThickness,
		WallTransparency= DEFAULTS.WallTransparency,
		WallColor       = DEFAULTS.WallColor,
		KillBonusTokens = DEFAULTS.KillBonusTokens,
		TokenPerSec     = DEFAULTS.TokenPerSurviveSec,
		ReentryKickTo   = part:GetAttribute("ReentryKickToZoneId") or DEFAULTS.ReentryKickToZoneId,
	}
end

local function beginArena(zid: number, bossModel: Model, bossHum: Humanoid)
	local A = Arenas[zid]; if not A or A.active then return end
	local cfg = readCfgFromZone(A.zonePart)

	A.active      = true
	A.bossModel   = bossModel
	A.bossHum     = bossHum
	A.startedAt   = os.clock()
	A.joinCloseAt = A.startedAt + cfg.JoinWindowSec
	A.wallsFolder = buildWallsForZone(A.zonePart, cfg.WallHeight, cfg.WallThickness, cfg.WallColor, cfg.WallTransparency)
	A.participants = {}
	A.aliveTime    = {}

	-- init: alle spillere inde i zonen bliver deltagere (og ikke lockedOut)
	for _,plr in ipairs(Players:GetPlayers()) do
		local ch = plr.Character; local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if hrp and pointInZoneXZ(A.zonePart, hrp.Position) then
			A.participants[plr] = true
			A.aliveTime[plr]    = 0
			A.lockedOut[plr.UserId] = nil
		end
	end
end

local function endArena(zid: number, bossKilled: boolean)
	local A = Arenas[zid]; if not A or not A.active then return end
	local cfg = readCfgFromZone(A.zonePart)

	-- bel?n deltagere (levende eller d?de?efter overlevelsessekunder)
	for plr,_ in pairs(A.participants) do
		if plr.Parent then
			local tokens = math.floor((A.aliveTime[plr] or 0) * cfg.TokenPerSec + 0.0001)
			if bossKilled then tokens += cfg.KillBonusTokens end
			if tokens > 0 then
				local v = ensureBossTokens(plr)
				v.Value += tokens
			end
		end
	end

	-- ryd l?s og v?gge
	if A.wallsFolder then A.wallsFolder:Destroy() end
	A.wallsFolder = nil
	A.bossModel   = nil
	A.bossHum     = nil
	A.active      = false
	A.participants= {}
	A.aliveTime   = {}
	A.startedAt   = 0
	A.joinCloseAt = 0
	-- l?sninger oph?ves efter arenaen er f?rdig
	A.lockedOut   = {}
end

-- === HOVEDLOOPS =============================================================

-- 1) Overv?g boss-spawns i arenaer + h?ndt?r lukket adgang & re-entry
task.spawn(function()
	while true do
		for zid,A in pairs(Arenas) do
			local zFolder = getEnemyFolderForZoneId(zid)
			-- find boss i zonen
			local boss, bossHum
			for _,m in ipairs(zFolder:GetChildren()) do
				if m:IsA("Model") and m.PrimaryPart and m.Name == "Enemy" then
					local isBoss = m.PrimaryPart:GetAttribute("IsBoss") == true
					if isBoss then
						local h = m:FindFirstChildOfClass("Humanoid")
						if h and h.Health > 0 then boss, bossHum = m, h; break end
					end
				end
			end

			if boss and not A.active then
				beginArena(zid, boss, bossHum)
			end

			-- l?s/ban indgang efter join-vindue
			if A.active then
				local now = os.clock()

				-- (a) Luk for nye efter joinCloseAt -> ?lockedOut?
				for _,plr in ipairs(Players:GetPlayers()) do
					local ch  = plr.Character
					local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
					if hrp then
						local inside = pointInZoneXZ(A.zonePart, hrp.Position)
						-- ny deltager?
						if inside and not A.participants[plr] then
							if now <= A.joinCloseAt and not A.lockedOut[plr.UserId] then
								-- tillad i vinduet
								A.participants[plr] = true
								A.aliveTime[plr]    = 0
							else
								-- kick ud til anden zone (typisk safe)
								local kickZone = getZoneById(readCfgFromZone(A.zonePart).ReentryKickTo)
								if kickZone then
									local target = zoneTopCenter(kickZone)
									hrp.AssemblyLinearVelocity = Vector3.new()
									hrp.CFrame = CFrame.new(target)
								end
								A.lockedOut[plr.UserId] = true
							end
						end
					end
				end

				-- hold bossen i arenaens XZ
				if A.bossModel and A.bossModel.PrimaryPart then
					if not pointInZoneXZ(A.zonePart, A.bossModel.PrimaryPart.Position) then
						centerBossInZone(A)
					end
				end


				-- (b) Ingen m? forlade zonen ? v?gge g?r jobbet.
				-- (c) Boss d?d ? afslut arena
				if not A.bossModel or not A.bossModel.Parent or (A.bossHum and A.bossHum.Health <= 0) then
					endArena(zid, true)
				end
			end
		end
		task.wait(0.2)
	end
end)

-- 2) DoT + overlevelsestid til deltagere
task.spawn(function()
	while true do
		for zid,A in pairs(Arenas) do
			if A.active and A.bossHum and A.bossHum.Health > 0 then
				local cfg = readCfgFromZone(A.zonePart)
				local now = os.clock()
				local elapsed = now - A.startedAt
				local dmg = math.max(0, cfg.BaseDoT + math.floor(elapsed * cfg.DoTGrowthPerSec + 0.0001))

				for plr,_ in pairs(A.participants) do
					if plr.Parent then
						local ch = plr.Character
						local hum = ch and ch:FindFirstChildOfClass("Humanoid")
						local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
						if hum and hrp then
							-- kun t?lle / skade hvis spilleren er inde i zonen
							if pointInZoneXZ(A.zonePart, hrp.Position) then
								A.aliveTime[plr] = (A.aliveTime[plr] or 0) + cfg.DoTTickSec
								-- p?f?r DoT (ignorer invuln/menu ? det er en arena)
								if hum.Health > 0 then
									hum:TakeDamage(dmg)
								end
							end
						end
					end
				end
			end
		end
		task.wait(DEFAULTS.DoTTickSec)
	end
end)

-- 3) Ryd hvis en boss forsvinder uden kill (despawn) ? afslut uden kill-bonus
task.spawn(function()
	while true do
		for zid,A in pairs(Arenas) do
			if A.active then
				if (not A.bossModel) or (not A.bossModel.Parent) or (A.bossHum and A.bossHum.Health <= 0) then
					-- hvis A.bossHum var nil/ despawn ? ingen killbonus
					local killed = (A.bossHum and A.bossHum.Health <= 0)
					endArena(zid, killed)
				end
			end
		end
		task.wait(1.0)
	end
end)

-- 4) S?rg for at alle spillere har BossTokens
Players.PlayerAdded:Connect(function(plr)
	ensureBossTokens(plr)
end)

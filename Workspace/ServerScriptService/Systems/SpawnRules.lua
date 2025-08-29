--[[
SpawnRules.lua — zonevise spawnregler (ramp, per-player spawns, cluster-minimum, HUD)

Formål
  • Ud fra zone-state returnere en liste af spawn-planer for næste tick.
  • Bevare/skrive zone-state: z.ramp, z.spawners, z.minOpp/cMin/cMax/minDist.
  • Opdatere spiller-HUD i zonen (ZoneOpponents, ZoneRampTier, ZoneEnterAt).

API
  tick(Zones: table, zid: number): { {zid:number, pos:Vector3, isBoss:boolean?}, ... }

Bemærk
  • Modulet spawner ikke — det returnerer kun planer. EnemySpawner kalder EnemyFactory/AI.
  • Sikker mod manglende felter; læser fallback fra EnemyConfig + zone attributes.
]]--

local Players   = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")
local EnemyConfig = require(RS.Shared:WaitForChild("EnemyConfig"))

local ZoneIndex = require(script.Parent:WaitForChild("ZoneIndex"))

local M = {}

local function readAttr(z, key, fallback)
	local v = z.inst and z.inst:GetAttribute(key)
	if v == nil then return fallback end
	return v
end

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

local function countAliveEnemies(z)
	local n = 0
	for _, m in ipairs(z.enemies:GetChildren()) do
		if m:IsA("Model") and m.Name=="Enemy" then
			local h = m:FindFirstChildOfClass("Humanoid")
			if h and h.Health>0 then n += 1 end
		end
	end
	return n
end

function M.tick(Zones, zid)
	local z = Zones[zid]; if not z then return {} end

	-- init ramp + misc once
	z.ramp = z.ramp or {
		mul   = readAttr(z, "RampMultiplier",   1.15),
		every = readAttr(z, "RampInterval",     25),
		last  = os.clock(),
		rate  = EnemyConfig.SpawnIntervalStart or 1.5,
		floor = EnemyConfig.SpawnIntervalFloor or 0.5,
		tier  = 0,
	}
	z.minOpp  = z.minOpp  or readAttr(z, "MinOpponents",       8)
	z.cMin    = z.cMin    or readAttr(z, "ClusterMin",         3)
	z.cMax    = z.cMax    or readAttr(z, "ClusterMax",         5)
	z.minDist = z.minDist or readAttr(z, "SpawnNotCloserThan", 25)
	z.spawners = z.spawners or {}

	local plans = {}

	-- ramp tick
	local now = os.clock()
	if (now - z.ramp.last) >= z.ramp.every then
		z.ramp.rate = math.max(z.ramp.floor, z.ramp.rate / z.ramp.mul)
		z.ramp.last = now
		z.ramp.tier = (z.ramp.tier or 0) + 1
	end

	-- aktive spillere i zonen
	local chars = getAliveCharactersInZone(Zones, zid)
	if #chars == 0 then
		-- nulstil HUD for alle spillere der står i zonen (ingen combat)
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr:GetAttribute("ZoneId")==zid then
				if plr:GetAttribute("ZoneOpponents") ~= 0 then plr:SetAttribute("ZoneOpponents", 0) end
				if plr:GetAttribute("ZoneRampTier") ~= (z.ramp.tier or 0) then
					plr:SetAttribute("ZoneRampTier", z.ramp.tier or 0)
				end
			end
		end
		return plans
	end

	-- ensure ZoneEnterAt (til HUD tid i zone)
	for _, ch in ipairs(chars) do
		local p = Players:GetPlayerFromCharacter(ch)
		if p then
			if p:GetAttribute("ZoneEnterAt") == nil or p:GetAttribute("ZoneId") ~= zid then
				p:SetAttribute("ZoneEnterAt", os.time())
			end
		end
	end

	-- HUD: antal aktive fjender i zonen + ramp-tier
	local activeCount = countAliveEnemies(z)
	for _, ch in ipairs(chars) do
		local p = Players:GetPlayerFromCharacter(ch)
		if p then
			if p:GetAttribute("ZoneOpponents") ~= activeCount then
				p:SetAttribute("ZoneOpponents", activeCount)
			end
			if p:GetAttribute("ZoneRampTier") ~= (z.ramp.tier or 0) then
				p:SetAttribute("ZoneRampTier", z.ramp.tier or 0)
			end
		end
	end

	-- cluster-spawn hvis under minimum
	if activeCount < z.minOpp then
		local need = math.random(z.cMin, z.cMax)
		local tries = 0
		while need > 0 and tries < 20 do
			tries += 1
			local who = chars[math.random(1, #chars)]
			local hrp = who:FindFirstChild("HumanoidRootPart")
			if hrp then
				local a = math.random() * math.pi * 2
				local r = math.random(18, 30)
				local want = hrp.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * r
				local pos  = ZoneIndex.clampToTop(z, want)

				local ok = true
				for _, pl in ipairs(Players:GetPlayers()) do
					local hrp2 = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
					if hrp2 and (hrp2.Position - pos).Magnitude < z.minDist then ok = false; break end
				end

				if ok then
					table.insert(plans, { zid = zid, pos = pos, isBoss = false })
					need -= 1
				end
			end
		end
		return plans
	end

	-- per-player spawners (ramp-rate)
	-- opret spawner pr. eligible spiller
	local start = EnemyConfig.SpawnIntervalStart or 1.5
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("ZoneId")==zid and plr:GetAttribute("CombatEnabled")==true then
			local uid = plr.UserId
			if not z.spawners[uid] then
				z.spawners[uid] = { interval = start, nextAt = now + math.random()*start*0.5 }
			end
		end
	end
	-- fjern inaktive
	for uid, sp in pairs(z.spawners) do
		local plr = Players:GetPlayerByUserId(uid)
		local keep = plr and (plr:GetAttribute("ZoneId")==zid) and (plr:GetAttribute("CombatEnabled")==true)
		if not keep then z.spawners[uid] = nil end
	end

	-- planlæg spawns
	for uid, sp in pairs(z.spawners) do
		if now >= (sp.nextAt or 0) then
			local plr = Players:GetPlayerByUserId(uid)
			local ch  = plr and plr.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hrp then
				local radius = math.random(EnemyConfig.SpawnRadiusMin or 14, EnemyConfig.SpawnRadiusMax or 26)
				local angle  = math.random() * math.pi * 2
				local want   = hrp.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
				local pos    = ZoneIndex.clampToTop(z, want)
				table.insert(plans, { zid = zid, pos = pos, isBoss = false })
			end
			sp.interval = z.ramp.rate
			sp.nextAt   = now + sp.interval
		end
	end

	return plans
end

return M

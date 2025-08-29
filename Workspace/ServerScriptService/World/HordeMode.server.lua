-- ServerScriptService/World/HordeMode.server.lua
-- Per-spiller “Horde Mode”: når mange fjender er tæt på, buffes fjender (hurtigere/modstandsdygtige)
-- og spilleren får et rødt overlay + infopanel via Remotes.

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local Workspace  = game:GetService("Workspace")
local Remotes    = RS:WaitForChild("Remotes")

local EvShow     = Remotes:WaitForChild("HordeShow")
local EvHide     = Remotes:WaitForChild("HordeHide")
local EvUpdate   = Remotes:WaitForChild("HordeUpdate")

-- Tuning
local THRESHOLD_MIN   = 15       -- min. fjender indenfor radius før Horde aktiveres
local RADIUS          = 40       -- 2D radius i studs omkring spilleren
local BASE_SPEED_PCT  = 0.10     -- +10% speed ved tærsklen
local PER_EXTRA_PCT   = 0.01     -- +1% pr. ekstra fjende ud over tærsklen
local BASE_RESIST_PCT = 0.10     -- +10% resist ved tærsklen
local PER_EXTRA_RES   = 0.01     -- +1% pr. ekstra
local MAX_PCT         = 0.75     -- maks 75% (0.75)

-- Per-spiller aktiv tilstand
local ACTIVE = {}  -- [player] = true/false

local function playerZoneId(plr) return plr:GetAttribute("ZoneId") end
local function zoneEnemiesFolder(zid)
	local root = Workspace:FindFirstChild("ZoneEnemies")
	return root and root:FindFirstChild("Zone_" .. tostring(zid)) or nil
end

local function listAliveEnemiesInZone(zid)
	local folder = zoneEnemiesFolder(zid)
	if not folder then return {} end
	local out = {}
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and m.Name == "Enemy" then
			local body = m:FindFirstChild("Body")
			local hum  = m:FindFirstChildOfClass("Humanoid")
			if body and hum and hum.Health > 0 then
				table.insert(out, m)
			end
		end
	end
	return out
end

local function dist2D(a: Vector3, b: Vector3)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx*dx + dz*dz)
end

local function hordePerc(count)
	if count < THRESHOLD_MIN then
		-- VIGTIGT: returnér to tal, ellers bliver #2 nil
		return 0, 0
	end
	local extra = count - THRESHOLD_MIN
	local spd = math.clamp(BASE_SPEED_PCT + PER_EXTRA_PCT * extra, 0, MAX_PCT)
	local res = math.clamp(BASE_RESIST_PCT + PER_EXTRA_RES * extra, 0, MAX_PCT)
	return spd, res
end

-- Sæt attributter på fjender efter største horde-effekt fra spillere i samme zone
local function applyEnemyBuffsForZone(zid)
	local enemies = listAliveEnemiesInZone(zid)
	if #enemies == 0 then return end

	-- Find alle aktive spillere i zonen
	local playersInZone = {}
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("ZoneId") == zid and plr:GetAttribute("CombatEnabled") == true then
			local ch = plr.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hrp then table.insert(playersInZone, {plr=plr, hrp=hrp}) end
		end
	end

	-- Ingen spillere ? nulstil buffs
	if #playersInZone == 0 then
		for _,e in ipairs(enemies) do
			local body = e:FindFirstChild("Body")
			if body then
				body:SetAttribute("Horde_SpeedMult", 1)
				body:SetAttribute("Horde_Resist", 0)
			end
		end
		return
	end

	for _,e in ipairs(enemies) do
		local body = e:FindFirstChild("Body")
		if body then
			local bestSpd, bestRes = 1, 0
			for _,pe in ipairs(playersInZone) do
				local d = dist2D(body.Position, pe.hrp.Position)
				if d <= RADIUS then
					-- Estimér tætheden omkring spilleren (antal enemies i radius)
					local count = 0
					for _,e2 in ipairs(enemies) do
						local b2 = e2:FindFirstChild("Body")
						if b2 and dist2D(b2.Position, pe.hrp.Position) <= RADIUS then
							count += 1
						end
					end
					local spdPct, resPct = hordePerc(count)
					spdPct = spdPct or 0
					resPct = resPct or 0
					bestSpd = math.max(bestSpd or 1, 1 + spdPct)
					bestRes = math.max(bestRes or 0, resPct)
				end
			end
			body:SetAttribute("Horde_SpeedMult", bestSpd or 1)
			body:SetAttribute("Horde_Resist", bestRes or 0)
		end
	end
end

-- UI toggling pr. spiller
local function updatePlayerUI(plr)
	local zid = playerZoneId(plr)
	if not zid or zid < 0 then
		if ACTIVE[plr] then EvHide:FireClient(plr); ACTIVE[plr] = false end
		return
	end
	local ch  = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp then
		if ACTIVE[plr] then EvHide:FireClient(plr); ACTIVE[plr] = false end
		return
	end

	local enemies = listAliveEnemiesInZone(zid)
	if #enemies == 0 then
		if ACTIVE[plr] then EvHide:FireClient(plr); ACTIVE[plr] = false end
		return
	end

	local close = 0
	for _,e in ipairs(enemies) do
		local body = e:FindFirstChild("Body")
		local hum  = e:FindFirstChildOfClass("Humanoid")
		if body and hum and hum.Health > 0 then
			if dist2D(body.Position, hrp.Position) <= RADIUS then
				close += 1
			end
		end
	end

	if close >= THRESHOLD_MIN then
		local spdPct, resPct = hordePerc(close)  -- altid to tal
		local title = "HORDE MODE AKTIVERET – For mange monstre tæt på!"
		local sub   = string.format("Nær: %d  |  Speed +%d%%  |  Resist +%d%%",
			close, math.floor(spdPct*100+0.5), math.floor(resPct*100+0.5))
		if not ACTIVE[plr] then
			ACTIVE[plr] = true
			EvShow:FireClient(plr)
		end
		EvUpdate:FireClient(plr, { title = title, sub = sub })
	else
		if ACTIVE[plr] then
			ACTIVE[plr] = false
			EvHide:FireClient(plr)
		end
	end
end

-- Main loop
task.spawn(function()
	while true do
		task.wait(0.4)

		-- UI pr. spiller
		for _,plr in ipairs(Players:GetPlayers()) do
			if plr:GetAttribute("CombatEnabled") == true then
				updatePlayerUI(plr)
			else
				if ACTIVE[plr] then ACTIVE[plr] = false; EvHide:FireClient(plr) end
			end
		end

		-- Buffs pr. zone (ud fra spillere i zonen)
		local visited = {}
		for _,plr in ipairs(Players:GetPlayers()) do
			local zid = plr:GetAttribute("ZoneId")
			if zid and zid >= 0 and not visited[zid] then
				visited[zid] = true
				applyEnemyBuffsForZone(zid)
			end
		end
	end
end)

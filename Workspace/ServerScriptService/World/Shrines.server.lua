-- ServerScriptService/World/Shrines.server.lua
-- Spawner “shrines” i aktive combat-zoner (aldrig i safe-zones).
-- Understøtter BasePart- og Model-zoner (med ZoneId-attribut).
-- Garanterer første spawn pr. zone efter 30 sek. (TEST-toggle).
-- FIX: Brug weak-table (InsideMap) i stedet for at sætte p._inside på Instance.

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local Replicated     = game:GetService("ReplicatedStorage")
local Workspace      = game:GetService("Workspace")

-- === Remotes ===
local RemotesFolder  = Replicated:FindFirstChild("Remotes") or Instance.new("Folder", Replicated)
RemotesFolder.Name = "Remotes"
local function ensure(name)
	local ev = RemotesFolder:FindFirstChild(name)
	if not ev then ev = Instance.new("RemoteEvent"); ev.Name = name; ev.Parent = RemotesFolder end
	return ev
end
local EvShrineShow   = ensure("ShrineShow")
local EvShrineHide   = ensure("ShrineHide")

-- === Tuning ===
local TEST   = { FORCE_FIRST_PER_ZONE = true }       -- garanter 1. spawn pr. zone
local TIMING = { firstDelaySec = 30, rollEverySec = 60 }
local ROLL   = { baseChance = 0.25, perExisting = 0.05, maxPerZone = 5 }

-- side-længder (kvadrater)
local SIZES = { 4, 8, 12, 16 }

-- Rarity tabel (chance summerer til 1.0)
local RARITY = {
	{ name="Divine",    chance=0.01, color=Color3.fromRGB(255,245,130), maxEffects=4, minEffects=2 },
	{ name="Mythic",    chance=0.01, color=Color3.fromRGB(255,210,110), maxEffects=3, minEffects=1 },
	{ name="Legendary", chance=0.02, color=Color3.fromRGB(255,180,80),  maxEffects=2, minEffects=1 },
	{ name="Epic",      chance=0.05, color=Color3.fromRGB(170,120,255), maxEffects=2, minEffects=1 },
	{ name="Rare",      chance=0.10, color=Color3.fromRGB(110,200,255), maxEffects=1, minEffects=1 },
	{ name="Uncommon",  chance=0.20, color=Color3.fromRGB(120,255,180), maxEffects=1, minEffects=1 },
	{ name="Common",    chance=0.61, color=Color3.fromRGB(220,220,220), maxEffects=1, minEffects=1 },
}

-- Effekter pr. shrine (label + outputfelter spilleren får som attributes)
local EFFECTS = {
	AttackRate = function(r) local m={Common=10,Uncommon=15,Rare=20,Epic=25,Legendary=30,Mythic=35,Divine=40};local p=m[r] or 10;return{key="AttackRate",label=("+"..p.."% attack speed"),rateMult=1+p/100}end,
	Damage    = function(r) local m={Common=10,Uncommon=15,Rare=20,Epic=25,Legendary=30,Mythic=35,Divine=40};local p=m[r] or 10;return{key="Damage",label=("+"..p.."% damage"),dmgMult=1+p/100}end,
	Regen     = function(r) local m={Common=0.10,Uncommon=0.14,Rare=0.20,Epic=0.50,Legendary=2.00,Mythic=5.00,Divine=10.00};local h=m[r] or 0.10;return{key="Regen",label=(string.format("+%.2f hp/sec", h)),hotPerSec=h}end,
	XP        = function(r) local m={Common=1,Uncommon=2,Rare=3,Epic=5,Legendary=10,Mythic=25,Divine=50};local x=m[r] or 1;return{key="XP",label=("+"..x.." xp/kill"),xpPerKill=x}end,
}
local ALL_KEYS = {"AttackRate","Damage","Regen","XP"}

-- === Zones (BasePart eller Model) ===
local ZonesRoot = Workspace:FindFirstChild("Zones") or Workspace
local function isSafeZone(inst)
	if not inst then return false end
	if inst:GetAttribute("IsSafeZone") == true then return true end
	if inst:GetAttribute("SafeZone") == true then return true end
	local n = string.lower(inst.Name)
	return n:find("safe") ~= nil
end

local function enumerateZones()
	local map = {}  -- zid -> {inst=<BasePart|Model>, isModel=bool}
	for _,d in ipairs(ZonesRoot:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Model") then
			local zid = d:GetAttribute("ZoneId")
			if typeof(zid) == "number" then
				map[zid] = { inst=d, isModel=d:IsA("Model") }
			end
		end
	end
	return map
end
local Zones = enumerateZones()

local function zoneBox(zrec)
	if zrec.isModel then
		local cf, size = zrec.inst:GetBoundingBox()
		return cf, size
	else
		local p: BasePart = zrec.inst
		return p.CFrame, p.Size
	end
end

local function playersInZone(zid)
	local out = {}
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("ZoneId") == zid and plr:GetAttribute("CombatEnabled") == true then
			table.insert(out, plr)
		end
	end
	return out
end

-- Alle shrines placeres herunder
local ShrinesFolder = Workspace:FindFirstChild("Shrines") or Instance.new("Folder", Workspace)
ShrinesFolder.Name = "Shrines"

local function shrinesInZone(zid)
	local t = {}
	for _,p in ipairs(ShrinesFolder:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("ZoneId") == zid then table.insert(t, p) end
	end
	return t
end

-- AABB overlap i X/Z (kvadrater)
local function overlaps(posA, halfA, posB, halfB)
	local dx = math.abs(posA.X - posB.X)
	local dz = math.abs(posA.Z - posB.Z)
	return (dx <= (halfA + halfB)) and (dz <= (halfA + halfB))
end

-- === Random helpers ===
local function pickRarity()
	local r = math.random(); local acc = 0
	for _,it in ipairs(RARITY) do acc = acc + it.chance; if r <= acc then return it end end
	return RARITY[#RARITY]
end

local function pickEffects(rarity)
	local want = math.random(rarity.minEffects, rarity.maxEffects)
	local pool = table.clone(ALL_KEYS)
	for i=#pool,2,-1 do local j=math.random(i); pool[i],pool[j]=pool[j],pool[i] end
	local out = {}
	for i=1,want do local e = EFFECTS[pool[i]](rarity.name); table.insert(out, e) end
	return out
end

local function effectLabelList(effects)
	local names = {}
	for _,e in ipairs(effects) do table.insert(names, e.label) end
	return table.concat(names, ", ")
end

-- Vælg tilfældig position i zones AABB (med marginer), uden overlap m. eksisterende shrines.
local function pickPositionInside(zrec, halfSide, tries)
	tries = tries or 50
	local cf, size = zoneBox(zrec)
	local halfX = math.max(0, size.X*0.5 - halfSide - 1)
	local halfZ = math.max(0, size.Z*0.5 - halfSide - 1)
	local baseY = cf.Position.Y
	for _=1, tries do
		local rx = (math.random()*2 - 1) * halfX
		local rz = (math.random()*2 - 1) * halfZ
		local world = cf * CFrame.new(rx, 0, rz)
		local pos = world.Position
		local ok = true
		for _,p in ipairs(ShrinesFolder:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("ZoneId") == zrec.inst:GetAttribute("ZoneId") then
				if overlaps(pos, halfSide, p.Position, p.Size.X * 0.5) then ok=false; break end
			end
		end
		if ok then return Vector3.new(pos.X, baseY + 0.1, pos.Z) end
	end
	return nil
end

-- === Inside tracking (weak table) ===
-- Part -> { [Player] = true }
local InsideMap = setmetatable({}, { __mode = "k" })
local function getInside(part)
	local t = InsideMap[part]
	if not t then
		t = setmetatable({}, { __mode = "k" })
		InsideMap[part] = t
	end
	return t
end

-- Giv/fjern buffs + UI
local function applyShrineBuffs(plr, shrinePart, onEnter)
	if onEnter then
		local rarity = shrinePart:GetAttribute("RarityName") or "Common"
		local label  = shrinePart:GetAttribute("Label") or "Shrine"
		local rate  = shrinePart:GetAttribute("BuffRateMult") or 1
		local dmg   = shrinePart:GetAttribute("BuffDmgMult") or 1
		local hot   = shrinePart:GetAttribute("BuffHoTPerSec") or 0
		local xpk   = shrinePart:GetAttribute("BuffXPPerKill") or 0

		plr:SetAttribute("Buff_RateMult",       rate)
		plr:SetAttribute("Buff_DamageMult",     dmg)
		plr:SetAttribute("Buff_HoTPerSec",      hot)
		plr:SetAttribute("Buff_XPBonusPerKill", xpk)

		EvShrineShow:FireClient(plr, {
			title = string.format("%s Shrine", rarity),
			desc  = label,
			rarity= rarity,
		})
	else
		plr:SetAttribute("Buff_RateMult",       nil)
		plr:SetAttribute("Buff_DamageMult",     nil)
		plr:SetAttribute("Buff_HoTPerSec",      nil)
		plr:SetAttribute("Buff_XPBonusPerKill", nil)
		EvShrineHide:FireClient(plr)
	end
end

-- Opdater spillere på/af shrine + TTL
local function updateOccupants(shrinePart, zid, dt)
	local half = shrinePart.Size.X * 0.5
	local px, pz = shrinePart.Position.X, shrinePart.Position.Z
	local inside = getInside(shrinePart)

	local present = {}
	for _,plr in ipairs(playersInZone(zid)) do
		local ch = plr.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if hrp then
			local dx = math.abs(hrp.Position.X - px)
			local dz = math.abs(hrp.Position.Z - pz)
			if dx <= half and dz <= half then
				present[plr] = true
				if not inside[plr] then
					inside[plr] = true
					applyShrineBuffs(plr, shrinePart, true)
				end
			end
		end
	end
	for plr,_ in pairs(inside) do
		if not present[plr] then
			inside[plr] = nil
			applyShrineBuffs(plr, shrinePart, false)
		end
	end

	-- TTL kun hvis tom
	if next(inside) == nil then
		local ttl = shrinePart:GetAttribute("TTL") or 0
		ttl = math.max(0, ttl - dt)
		shrinePart:SetAttribute("TTL", ttl)
		if ttl <= 0 then
			-- destroy håndterer cleanup
			shrinePart:Destroy()
			InsideMap[shrinePart] = nil
		end
	end
end

-- Lyt på .Destroyed for cleanup (failsafe)
local function hookCleanup(part)
	part.Destroying:Connect(function()
		local inside = InsideMap[part]
		if inside then
			for plr,_ in pairs(inside) do
				applyShrineBuffs(plr, part, false)
			end
		end
		InsideMap[part] = nil
	end)
end

-- Spawn én shrine i en zone
local function spawnShrineInZone(zrec)
	local zid = zrec.inst:GetAttribute("ZoneId")
	if not zid then return end
	local side    = SIZES[math.random(1, #SIZES)]
	local rarity  = pickRarity()
	local effects = pickEffects(rarity)

	local rateMult, dmgMult, hotPerSec, xpPerKill = 1, 1, 0, 0
	for _,e in ipairs(effects) do
		if e.rateMult then rateMult = rateMult * e.rateMult end
		if e.dmgMult  then dmgMult  = dmgMult  * e.dmgMult  end
		if e.hotPerSec then hotPerSec = hotPerSec + e.hotPerSec end
		if e.xpPerKill then xpPerKill = xpPerKill + e.xpPerKill end
	end

	local pos = pickPositionInside(zrec, side*0.5, 80)
	if not pos then return end

	local p = Instance.new("Part")
	p.Name = string.format("Shrine_%s", rarity.name)
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = rarity.color
	p.Transparency = 0.25
	p.Size = Vector3.new(side, 0.35, side)
	p.CFrame = CFrame.new(pos)
	p.Parent = ShrinesFolder

	p:SetAttribute("ZoneId", zid)
	p:SetAttribute("RarityName", rarity.name)
	p:SetAttribute("Label", effectLabelList(effects))
	p:SetAttribute("BuffRateMult",  rateMult)
	p:SetAttribute("BuffDmgMult",   dmgMult)
	p:SetAttribute("BuffHoTPerSec", hotPerSec)
	p:SetAttribute("BuffXPPerKill", xpPerKill)
	p:SetAttribute("TTL", 60)

	-- initialiser empty inside map + cleanup hook
	getInside(p)
	hookCleanup(p)

	return p
end

-- Per-zone state (for garanti af første spawn + rul)
local ZoneState = {} -- zid -> { activeSince, lastRoll, forcedDone }
local function ensureZoneState(zid)
	local st = ZoneState[zid]
	if not st then st = { activeSince=nil, lastRoll=0, forcedDone=false }; ZoneState[zid]=st end
	return st
end

-- === Hovedloop ===
task.spawn(function()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 1 then return end
		local step = accum
		accum = 0

		for zid, zrec in pairs(Zones) do
			-- safe-zoner: ryd og skip
			if isSafeZone(zrec.inst) then
				for _,p in ipairs(shrinesInZone(zid)) do
					-- Destroy ? cleanup via hookCleanup
					p:Destroy()
				end
				ZoneState[zid] = nil
			else
				local plrs = playersInZone(zid)
				local st = ensureZoneState(zid)
				local now = os.clock()

				if #plrs == 0 then
					for _,p in ipairs(shrinesInZone(zid)) do p:Destroy() end
					st.activeSince = nil
				else
					if not st.activeSince then st.activeSince = now end

					-- opdater eksisterende shrines
					local list = shrinesInZone(zid)
					for _,p in ipairs(list) do
						updateOccupants(p, zid, step)
					end

					-- spawn regler
					if (now - st.activeSince) >= TIMING.firstDelaySec then
						if TEST.FORCE_FIRST_PER_ZONE and (not st.forcedDone) and (#list == 0) then
							if spawnShrineInZone(zrec) then
								st.forcedDone = true
								st.lastRoll = now
							end
						elseif (now - st.lastRoll) >= TIMING.rollEverySec then
							st.lastRoll = now
							if #list < ROLL.maxPerZone then
								local chance = math.max(0, ROLL.baseChance - ROLL.perExisting * #list)
								if math.random() < chance then spawnShrineInZone(zrec) end
							end
						end
					end
				end
			end
		end
	end)
end)

--[[
ZoneIndex.lua  —  indeks over zoner + simple zone-geometrier (ROBUST SAFE-DETEKTION)

Formål
  • Læse zones fra Workspace/Zones og bygge et tabel-indeks ? { [zid] = Zone }
  • Hjælpe med at finde zone for en world-position
  • Begrænse et ønsket punkt til toppen af en zone-boks (til spawn)
  • Sikre stabil markering af Safe-zoner (attribut, ZoneId==0, navne-heuristik)
  • Safe-zone har forrang hvis flere zoner overlapper spilleren

Eksporterer
  • build(zonesFolder: Instance, zoneEnemiesRoot: Folder): table<zid, Zone>
  • pointInZoneXZ(z: Zone, worldPos: Vector3): boolean
  • clampToTop(z: Zone, want: Vector3): Vector3
  • getZoneAt(zones: table, worldPos: Vector3): (zid: number?, z: Zone?)

Zone-struktur (uddrag)
  Zone = {
    inst: BasePart, part: BasePart, name: string,
    minLvl: number, maxLvl: number, isSafe: boolean,
    enemies: Folder,
    minOpp: number, cMin: number, cMax: number, minDist: number,
    ramp: { rate, floor, mul, every, last, tier },
    mods: { HpMult?, SpeedMult?, TouchDamageMult?, XPMult? },
    fuse: { lastCheck, checkEvery, maxAliveBeforeFuse }
  }
]]--

local ZoneIndex = {}

local function readNumberAttr(inst, key, default)
	local v = inst:GetAttribute(key)
	return (typeof(v) == "number") and v or default
end

local function readBoolAttr(inst, key, default)
	local v = inst:GetAttribute(key)
	return (typeof(v) == "boolean") and v or default
end

-- ROBUST safe-detektion: attribut, ZoneId==0, navne-heuristik
local function detectSafe(inst: Instance): boolean
	if not inst then return false end
	if inst:GetAttribute("IsSafeZone") == true then return true end
	if inst:GetAttribute("SafeZone")  == true then return true end
	local zid = inst:GetAttribute("ZoneId")
	if zid == 0 then return true end
	local nm = tostring(inst.Name):lower()
	if nm:find("safe") or nm:find("start") then return true end
	return false
end

function ZoneIndex.build(zonesFolder: Instance, zoneEnemiesRoot: Folder)
	local zones = {}
	for _,p in ipairs(zonesFolder:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("ZoneId") ~= nil then
			local zid    = tonumber(p:GetAttribute("ZoneId"))
			local folder = zoneEnemiesRoot:FindFirstChild("Zone_"..zid) or Instance.new("Folder", zoneEnemiesRoot)
			folder.Name  = "Zone_"..zid

			local z = {
				inst    = p,
				part    = p,
				name    = p:GetAttribute("ZoneName") or p.Name,
				minLvl  = readNumberAttr(p, "MinPlayerLevel", 1),
				maxLvl  = readNumberAttr(p, "MaxPlayerLevel", 9999),
				isSafe  = detectSafe(p),
				enemies = folder,

				minOpp  = readNumberAttr(p, "MinOpponents", 8),
				cMin    = readNumberAttr(p, "ClusterMin", 3),
				cMax    = readNumberAttr(p, "ClusterMax", 5),
				minDist = readNumberAttr(p, "SpawnNotCloserThan", 25),

				ramp = {
					rate  = readNumberAttr(p, "SpawnIntervalStart", 1.5),
					floor = readNumberAttr(p, "SpawnIntervalFloor", 0.5),
					mul   = readNumberAttr(p, "RampMultiplier", 1.15),
					every = readNumberAttr(p, "RampInterval", 25),
					last  = os.clock(),
					tier  = 0,
				},

				mods = {
					HpMult          = readNumberAttr(p, "HpMult", 1),
					SpeedMult       = readNumberAttr(p, "SpeedMult", 1),
					TouchDamageMult = readNumberAttr(p, "TouchDamageMult", 1),
					XPMult          = readNumberAttr(p, "XPMult", 1),
				},

				-- standard-fuse state (bruges af spawnerens tryFuseInZone)
				fuse = {
					lastCheck = 0,
					checkEvery = 2.0,
					maxAliveBeforeFuse = 30,
				},
			}

			zones[zid] = z
		end
	end
	return zones
end

function ZoneIndex.pointInZoneXZ(z, worldPos: Vector3)
	local lp = z.part.CFrame:PointToObjectSpace(worldPos)
	local h  = z.part.Size * 0.5
	return math.abs(lp.X) <= h.X and math.abs(lp.Z) <= h.Z
end

function ZoneIndex.clampToTop(z, want: Vector3)
	local p  = z.part
	local lp = p.CFrame:PointToObjectSpace(want)
	local h  = p.Size * 0.5
	lp = Vector3.new(
		math.clamp(lp.X, -h.X + 1, h.X - 1),
		h.Y + 0.5,
		math.clamp(lp.Z, -h.Z + 1, h.Z - 1)
	)
	return p.CFrame:PointToWorldSpace(lp)
end

-- To-pass lookup: Safe vinder, ellers første kampzone der matcher
function ZoneIndex.getZoneAt(zones, worldPos: Vector3)
	local firstCombatId, firstCombat = nil, nil
	-- Først: safe-zoner
	for zid, z in pairs(zones) do
		if z.isSafe and ZoneIndex.pointInZoneXZ(z, worldPos) then
			return zid, z
		end
	end
	-- Dernæst: kampzoner
	for zid, z in pairs(zones) do
		if (not z.isSafe) and ZoneIndex.pointInZoneXZ(z, worldPos) then
			firstCombatId, firstCombat = zid, z
			break
		end
	end
	return firstCombatId, firstCombat
end

return ZoneIndex

-- ReplicatedStorage/Shared/SkillsCatalog.lua
-- Ensartet katalog over evner til UI/Vendors m.m.
-- Hver entry har: id, name, levelKey, moduleName, maxLevel, cost, weight, starter, desc, tags
-- Tags er harmoniseret (fx: "ground","frontal","area","aura","trail","electric","fire","void","vampiric","armor","any")

local Catalog = {}

Catalog.list = {
	-- Starter / basis
	{ id="WEAPON_AURA",   name="Skade-aura",       levelKey="AuraLevel",        moduleName="DamageAura",  maxLevel=99, cost=1, weight=1.0, starter=true,  desc="Skader tæt på dig i ticks.",                             tags={"aura","area"} },
	{ id="WEAPON_SHIELD", name="Roterende skjold",  levelKey="ShieldLevel",      moduleName="Shield",      maxLevel=99, cost=1, weight=1.0, starter=true,  desc="Kugler i kredsløb der skubber og skader.",               tags={"aura","area"} },
	{ id="WEAPON_HEAL",   name="Healing-aura",      levelKey="HealAuraLevel",    moduleName="HealAura",    maxLevel=99, cost=1, weight=1.0, starter=true,  desc="Healer dig og nære spillere periodisk.",                 tags={"aura","area"} },
	{ id="WEAPON_SLOWORB",name="Langsom orb",       levelKey="SlowOrbLevel",     moduleName="SlowOrb",     maxLevel=99, cost=1, weight=1.0, starter=true,  desc="Langsom orb der rammer og skubber.",                     tags={"any"} },
	{ id="WEAPON_MINE",   name="Miner",             levelKey="MinesLevel",       moduleName="Mines",       maxLevel=99, cost=1, weight=1.0, starter=true,  desc="Lægger miner der eksploderer i radius.",                 tags={"any"} },
	{ id="WEAPON_FAN",    name="Vifte-skud",        levelKey="FanShotLevel",     moduleName="Fan",         maxLevel=99, cost=1, weight=1.0, starter=true,  desc="Hurtige projektiler i en vifte.",                        tags={"any"} },

	-- Klassiske projektiler / mønstre
	{ id="WEAPON_WHIP",   name="Pisk",              levelKey="WhipLevel",        moduleName="Whip",        maxLevel=99, cost=1, weight=1.0, starter=false, desc="Rektangulær stråle foran spilleren.",                    tags={"frontal"} },
	{ id="WEAPON_AXE",    name="Økse",              levelKey="AxeLevel",         moduleName="Axe",         maxLevel=99, cost=1, weight=1.0, starter=false, desc="Fremad/tilbage i halvcirkel.",                          tags={"any"} },
	{ id="WEAPON_BMR",    name="Boomerang",         levelKey="BoomerangLevel",   moduleName="Boomerang",   maxLevel=99, cost=1, weight=1.0, starter=false, desc="Søger fjende og returnerer.",                           tags={"any"} },
	{ id="WEAPON_SPIN",   name="Snurretop",         levelKey="SpinnerLevel",     moduleName="Spinner",     maxLevel=99, cost=1, weight=1.0, starter=false, desc="Skifter retning periodisk.",                            tags={"any"} },
	{ id="WEAPON_PLUS",   name="Plus",              levelKey="PlusLevel",        moduleName="Plus",        maxLevel=99, cost=1, weight=1.0, starter=false, desc="Fire retninger (plus).",                               tags={"any"} },
	{ id="WEAPON_CROSS",  name="Kryds",             levelKey="CrossLevel",       moduleName="Cross",       maxLevel=99, cost=1, weight=1.0, starter=false, desc="Fire diagonaler (kryds).",                              tags={"any"} },
	{ id="WEAPON_BOUNCEBALL", name="Bounce Ball",   levelKey="BounceBallLevel",  moduleName="BounceBall",  maxLevel=99, cost=1, weight=1.0, starter=false, desc="Hoppende projektil der skader pr. hop.",                  tags={"any"} },

	-- Elementer og el-linje
	{ id="WEAPON_ZAP",    name="Lyn",               levelKey="LightningLevel",   moduleName="Lightning",   maxLevel=99, cost=1, weight=1.0, starter=false, desc="Slår tilfældig fjende i stort område.",                  tags={"electric"} },
	{ id="WEAPON_CHAIN",  name="Chain Lightning",   levelKey="ChainLightningLevel", moduleName="ChainLightning", maxLevel=99, cost=1, weight=1.0, starter=false, desc="Forgrenet lyn med stun-chance.",                    tags={"electric"} },
	{ id="WEAPON_EAURA",  name="Electric Aura",     levelKey="ElectricAuraLevel",moduleName="ElectricAura",maxLevel=99, cost=1, weight=1.0, starter=false, desc="Chance for stun og skade i nærhed.",                     tags={"electric","aura","area"} },
	{ id="WEAPON_EARMOR", name="Electric Armor",    levelKey="ElectricArmorLevel",moduleName="ElectricArmor",maxLevel=99, cost=1, weight=1.0, starter=false, desc="Reaktiv stun ved slag.",                                 tags={"electric","armor"} },
	{ id="WEAPON_CSTORM", name="Charged Storm",     levelKey="ChargedStormLevel",moduleName="ChargedStorm",maxLevel=99, cost=2, weight=1.0, starter=false, desc="Lightning + Charged Ground-combo.",                       tags={"electric"} },
	{ id="WEAPON_EDEF",   name="Electric Defense",  levelKey="ElectricDefenseLevel", moduleName="ElectricDefense", maxLevel=99, cost=2, weight=1.0, starter=false, desc="Aura der kan trigge Chain Lightning.",             tags={"electric","aura"} },
	{ id="WEAPON_RAIDEN", name="Raiden",            levelKey="RaidenLevel",      moduleName="Raiden",      maxLevel=99, cost=3, weight=1.0, starter=false, desc="Mester af stormen.",                                    tags={"electric"} },

	-- Ground / trail
	{ id="WEAPON_FIRETRAIL", name="Ildspor",        levelKey="FireTrailLevel",   moduleName="FireTrail",   maxLevel=99, cost=1, weight=1.0, starter=false, desc="Efterlader et brændende spor bag dig.",                  tags={"ground","trail","area","fire"} },
	{ id="WEAPON_CGROUND",   name="Charged Ground", levelKey="ChargedGroundLevel", moduleName="ChargedGround", maxLevel=99, cost=1, weight=1.0, starter=false, desc="Flyttende elektrisk felt.",                       tags={"ground","area","electric","frontal"} },

	-- Aura-varianter
	{ id="WEAPON_SLOWAURA",  name="Slow Aura",      levelKey="SlowAuraLevel",    moduleName="SlowAura",    maxLevel=99, cost=1, weight=1.0, starter=false, desc="Aura der sænker fjenders hastighed.",                   tags={"aura","area"} },
	{ id="WEAPON_FIREAURA",  name="Fire Aura",      levelKey="FireAuraLevel",    moduleName="FireAura",    maxLevel=99, cost=1, weight=1.0, starter=false, desc="Sætter fjender i brand (DoT) og kan sprede sig.",        tags={"aura","area","fire"} },

	-- VOID (nye ground evner)
	{ id="WEAPON_VOIDZONE",  name="Void Zone",      levelKey="VoidZoneLevel",    moduleName="VoidZone",    maxLevel=99, cost=1, weight=1.0, starter=false, desc="Felt der gør fjender 'Vulnerable' mens de står i det.",  tags={"ground","area","void","frontal"} },
	{ id="WEAPON_SOULPIT",   name="Soul Pit",       levelKey="SoulPitLevel",     moduleName="SoulPit",     maxLevel=99, cost=1, weight=1.0, starter=false, desc="Skade i feltet healer nærliggende spillere.",             tags={"ground","area","void","frontal","vampiric"} },
	{ id="WEAPON_SIPHON",    name="Siphon Power",   levelKey="SiphonPowerLevel", moduleName="SiphonPower", maxLevel=99, cost=1, weight=1.0, starter=false, desc="Kills i feltet giver midlertidig +flat dmg (stacker).",   tags={"ground","area","void","frontal","vampiric"} },
}

-- Indekser
Catalog.byId, Catalog.byLevelKey = {}, {}
for _,e in ipairs(Catalog.list) do
	Catalog.byId[e.id] = e
	if e.levelKey then Catalog.byLevelKey[e.levelKey] = e end
end

-- Tag-map (lowercase)
Catalog.byTag = {}
for _,e in ipairs(Catalog.list) do
	for _,t in ipairs(e.tags or {}) do
		local k = string.lower(tostring(t))
		Catalog.byTag[k] = Catalog.byTag[k] or {}
		table.insert(Catalog.byTag[k], e)
	end
end

-- API
function Catalog.All() return Catalog.list end
function Catalog.GetById(id) return Catalog.byId[id] end
function Catalog.GetByLevelKey(k) return Catalog.byLevelKey[k] end
function Catalog.AllWithTag(tag) return Catalog.byTag[string.lower(tostring(tag))] or {} end

return Catalog

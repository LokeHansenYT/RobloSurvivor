-- ReplicatedStorage/Shared/AbilitiesConfig.lua
-- Samlet, konsistent konfiguration uden table.insert:
--  • Alle evner defineres først under Ab.*
--  • Ab.WeaponDefs er en samlet, statisk liste
--  • Autowire kopierer levelKey ind på evnerne, så vendors/preview kan læse den

local Ab = {}

-- ====== Klassiske/eksisterende evner ======

Ab.DamageAura = {
	id="WEAPON_AURA", name="Skade-aura",
	desc="Skader fjender tæt på dig periodisk.",
	baseDamage=4, damageGrowth=1.25,
	tick=0.5, radius=10, radiusGrowth=1.03,
	tags={"aura"},
}

Ab.Shield = {
	id="WEAPON_SHIELD", name="Roterende skjold",
	desc="Kugler i kredsløb, skubber og skader.",
	baseDamage=5,  damageGrowth=1.20,
	baseCount=1,   countPerLevel=1,
	radius=5,
	angularSpeed=90, speedGrowth=1.08,
	knockback=25,
	hitCooldown=0.35,
	tags={"projectile","shield"},
	yOffset = 1.8,
}

Ab.HealAura = {
	id="WEAPON_HEAL", name="Healing aura",
	desc="Healer dig (og nærtstående) periodisk.",
	heal=6, healGrowth=1.30,
	interval=2.5, intervalGrowth=0.93,
	radius=16, radiusGrowth=1.03,
	tags={"aura"},
}

Ab.SlowOrb = {
	id="WEAPON_SLOWORB", name="Langsom orb",
	desc="Tung, langsom orb i din retning. Høj skade og knockback.",
	damageMult=3.0, damageGrowth=1.15,
	speed=30, speedGrowth=1.10,
	maxHits=3, hitsPerLevel=1,
	hitSameEnemyCD=0.35, ttl=3.5, knockback=35,
	tags={"projectile","frontal"},
}

Ab.Mine = {
	id="WEAPON_MINE", name="Mine",
	desc="Læg en mine der detonerer ved kontakt.",
	interval=3.0, intervalGrowth=0.94,
	damageMult=2.0, damageGrowth=1.12,
	radius=10, radiusGrowth=1.05, lifetime=12,
	armTime=1.2, armGrowth=0.92,
	tags={"projectile","ground","area","trail"},
}

Ab.Fan = {
	id="WEAPON_FAN", name="Vifte-skud",
	desc="Skyder en vifte af projektiler fremad.",
	count=3, countPerLevel=1, spreadDeg=18,
	damageMult=0.4, damageGrowth=1.12,
	interval=1.2, intervalGrowth=0.97,
	tags={"projectile","frontal"},
}

Ab.Plus = {
	id="WEAPON_PLUS", name="Plus",
	desc="Projektiler i +-mønster (for/tilbage/venstre/højre).",
	speed=42, rangeBase=24, damageBase=1,
	interval=0.8*4,
	tags={"projectile"},
}

Ab.Cross = {
	id="WEAPON_CROSS", name="Kryds",
	desc="Projektiler i x-mønster (diagonalt).",
	speed=42, rangeBase=24, damageBase=1,
	interval=0.8*4,
	tags={"projectile"},
}

Ab.Spinner = {
	id="WEAPON_SPIN", name="Snurretop",
	desc="Roterende projektil der ændrer retning periodisk.",
	baseRange=12, speed=18, damageBase=1, lifeBase=9, interval=0.9,
	tags={"projectile","frontal"},
}

Ab.Boomerang = {
	id="WEAPON_BMR", name="Boomerang",
	desc="Søger mål og vender tilbage.",
	rangeFactor=3, speed=36, damageBase=1, interval=1.0,
	tags={"projectile","frontal"},
}

Ab.Axe = {
	id="WEAPON_AXE", name="Økse",
	desc="Fejer frem og buer tilbage bag dig.",
	baseRadius=12, speed=22, damageBase=1, interval=0.9,
	tags={"projectile","frontal"},
}

Ab.Whip = {
	id="WEAPON_WHIP", name="Pisk",
	desc="Tyk stråle/rect i kigretning som gennemtrænger fjender.",
	baseRange=12, width=4, damageBase=1, interval=0.8,
	tags={"projectile","frontal"},
}

Ab.FireTrail = {
	id="WEAPON_FIRETRAIL", name="Ildspor",
	desc="Efterlader ildspor der giver skade over tid.",
	baseRange=12, width=4, damageBase=1, interval=0.8,
	dotTick=0.5, dotDamageBase=1,
	dotDurationBase=1.5, dotDurationPerLevel=0.25, dotDurationMax=3.0,
	tags={"projectile","fire","ground","area","trail"},
}

-- ====== Elektriske evner ======

Ab.Lightning = {
	id="WEAPON_ZAP", name="Lyn",
	desc="Slår tilfældig fjende i stort område. (Skade øges ulige lvls; CD kortere lige lvls.)",
	rangeFactor=3, damageBase=30, cooldownBase=60,
	tags={"electric"},
}

Ab.ChainLightning = {
	id="WEAPON_CHAIN", name="Kæde-lyn",
	desc="Zapper én, halverer skade og hopper til flere (så længe >1).",
	damageBase=2, rangeFactor=3, cooldown=1.2,
	tags={"electric","frontal"},
	stunChanceBase = 0.25,
	stunChancePerLvl = 0.00,
	stunDuration = 0.8,
}

Ab.ElectricAura = {
	id="WEAPON_EAURA", name="Elektrisk aura",
	desc="Chance for at lamme fjender tæt på dig og give skade.",
	damageBase=1, chanceBase=0.10,
	radius=Ab.HealAura.radius, radiusFactor=1.2,
	interval=0.9, tickInterval=0.8,
	tags={"aura","electric"},
	stunChanceBase = 0.25,
	stunChancePerLvl = 0.00,
	stunDuration = 0.6,
}

Ab.ElectricArmor = {
	id="WEAPON_EARMOR", name="Elektrisk rustning",
	desc="Angribere får chance for at blive lammet & tage skade.",
	damageBase=1, cooldownBase=60, activeDuration=15, chanceBase=0.25,
	tags={"electric"},
}

Ab.ChargedGround = {
	id="WEAPON_CGROUND", name="Charged ground",
	desc="Elektrisk felt på jorden der flytter sig og kan splitte.",
	damageBase=1, size=Vector3.new(8,0.4,8), intervalPerStep=1.0, interval=1.0,
	tags={"electric","ground","area","frontal"},
}

Ab.ChargedStorm = {
	id="WEAPON_CSTORM", name="Charged storm",
	desc="Kombination af Lyn + Charged ground (begrænset af laveste level).",
	requires={"Lightning","ChargedGround"},
	capByLowestOf={"Lightning","ChargedGround"},
	tags={"electric","combo"},
}

Ab.ElectricDefense = {
	id="WEAPON_EDEF", name="Electric defense",
	desc="Elektrisk aura der samtidig starter kæde-lyn.",
	requires={"ElectricAura","ChainLightning"},
	capByLowestOf={"ElectricAura","ChainLightning"},
	tags={"electric","aura","combo"},
}

Ab.Raiden = {
	id="WEAPON_RAIDEN", name="Raiden",
	desc="Lyn rammer i aura-område, spawner charged ground og starter kæde-lyn.",
	requires={"Lightning","ChargedStorm","ElectricDefense"},
	capByLowestOf={"Lightning","ChargedStorm","ElectricDefense"},
	tags={"electric","combo"},
}

-- ====== Nye evner ======

Ab.BounceBall = {
	id   = "WEAPON_BOUNCEBALL",
	name = "Bounce Ball",
	desc = "Et tungt projektil, der hopper mellem fjender/overflader og giver skade pr. hop.",
	tags = {"projectile","frontal"},
	baseDamage   = 8,
	damageGrowth = 3,
	maxBounces   = 2,
	cooldown     = 1.2,
}

Ab.SlowAura = {
	id   = "WEAPON_SLOWAURA",
	name = "Slow Aura",
	desc = "En aura der sænker fjenders hastighed i nærheden.",
	tags = {"aura","slow","debuff"},
	slowPct = 0.20, slowGrowth = 0.05, tick = 0.5, radius = 18, radiusGrowth = 2,
}

Ab.FireAura = {
	id="WEAPON_FIREAURA", name="Fire Aura", tags={"aura","fire","damage"},
	radius=7, radiusGrowth=0.6,
	dps=1, duration=3, chance=0.10,  -- base
	dpsGrowth=0, durationGrowth=1, chanceGrowth=0.01,
	color = {255,140,40}, -- UI/FCT farve
}

Ab.VoidZone = {
	id="WEAPON_VOIDZONE", name="Void Zone",
	desc="Et void-felt der gør fjender mere sårbare mens de står i det.",
	damageKind="void",
	tags={"ground","area","void","frontal"},
}

Ab.SoulPit = {
	id="WEAPON_SOULPIT", name="Soul Pit",
	desc="Fjender der tager skade i feltet healer nærliggende spillere.",
	damageKind="void",
	tags={"ground","area","void","frontal","vampiric"},
}

Ab.SiphonPower = {
	id="WEAPON_SIPHON", name="Siphon Power",
	desc="Fjender der dør i feltet giver +1 flad skade (stacker) i kort tid.",
	damageKind="void",
	tags={"ground","area","void","frontal","vampiric"},
}




-- ====== WeaponDefs: fuld liste af evner + deres levelKey ======
Ab.WeaponDefs = {
	-- klassikere
	{ key="DamageAura",      id=Ab.DamageAura.id,      name=Ab.DamageAura.name,      levelKey="AuraLevel" },
	{ key="Shield",          id=Ab.Shield.id,          name=Ab.Shield.name,          levelKey="ShieldLevel" },
	{ key="HealAura",        id=Ab.HealAura.id,        name=Ab.HealAura.name,        levelKey="HealAuraLevel" },
	{ key="SlowOrb",         id=Ab.SlowOrb.id,         name=Ab.SlowOrb.name,         levelKey="SlowOrbLevel" },
	{ key="Mine",            id=Ab.Mine.id,            name=Ab.Mine.name,            levelKey="MinesLevel" },
	{ key="Fan",             id=Ab.Fan.id,             name=Ab.Fan.name,             levelKey="FanShotLevel" },
	{ key="Plus",            id=Ab.Plus.id,            name=Ab.Plus.name,            levelKey="PlusLevel" },
	{ key="Cross",           id=Ab.Cross.id,           name=Ab.Cross.name,           levelKey="CrossLevel" },
	{ key="Spinner",         id=Ab.Spinner.id,         name=Ab.Spinner.name,         levelKey="SpinnerLevel" },
	{ key="Boomerang",       id=Ab.Boomerang.id,       name=Ab.Boomerang.name,       levelKey="BoomerangLevel" },
	{ key="Axe",             id=Ab.Axe.id,             name=Ab.Axe.name,             levelKey="AxeLevel" },
	{ key="Whip",            id=Ab.Whip.id,            name=Ab.Whip.name,            levelKey="WhipLevel" },
	{ key="FireTrail",       id=Ab.FireTrail.id,       name=Ab.FireTrail.name,       levelKey="FireTrailLevel" },

	-- electricity
	{ key="Lightning",       id=Ab.Lightning.id,       name=Ab.Lightning.name,       levelKey="LightningLevel" },
	{ key="ChainLightning",  id=Ab.ChainLightning.id,  name=Ab.ChainLightning.name,  levelKey="ChainLightningLevel" },
	{ key="ElectricAura",    id=Ab.ElectricAura.id,    name=Ab.ElectricAura.name,    levelKey="ElectricAuraLevel" },
	{ key="ElectricArmor",   id=Ab.ElectricArmor.id,   name=Ab.ElectricArmor.name,   levelKey="ElectricArmorLevel" },
	{ key="ChargedGround",   id=Ab.ChargedGround.id,   name=Ab.ChargedGround.name,   levelKey="ChargedGroundLevel" },
	{ key="ChargedStorm",    id=Ab.ChargedStorm.id,    name=Ab.ChargedStorm.name,    levelKey="ChargedStormLevel" },
	{ key="ElectricDefense", id=Ab.ElectricDefense.id, name=Ab.ElectricDefense.name, levelKey="ElectricDefenseLevel" },
	{ key="Raiden",          id=Ab.Raiden.id,          name=Ab.Raiden.name,          levelKey="RaidenLevel" },

	-- nye
	{ key="BounceBall", id=Ab.BounceBall.id, name=Ab.BounceBall.name, levelKey="BounceBallLevel" },
	{ key="SlowAura",   id=Ab.SlowAura.id,   name=Ab.SlowAura.name,   levelKey="SlowAuraLevel" },
	{ key="FireAura",   id=Ab.FireAura.id,   name=Ab.FireAura.name,   levelKey="FireAuraLevel" },
	{ key="VoidZone",     id=Ab.VoidZone.id,     name=Ab.VoidZone.name,     levelKey="VoidZoneLevel" },
	{ key="SoulPit",      id=Ab.SoulPit.id,      name=Ab.SoulPit.name,      levelKey="SoulPitLevel" },
	{ key="SiphonPower",  id=Ab.SiphonPower.id,  name=Ab.SiphonPower.name,  levelKey="SiphonPowerLevel" },

}

-- ====== Autowire: kopier levelKey ind på evnerne ======
do
	local map = {}
	for _,e in ipairs(Ab.WeaponDefs) do map[e.key] = e.levelKey end
	for key,def in pairs(Ab) do
		if type(def)=="table" and (def.id or def.name) and not def.levelKey and map[key] then
			def.levelKey = map[key]
		end
	end
end

return Ab

-- ReplicatedStorage/Shared/ProgressionConfig.lua
local Progression = {
	-- XP-krav pr. level: base * growth^(level-1)
	XPBase = 20,
	XPGrowth = 1.35,

	-- Invulnerability + disable damage duration (sek) ved level-up
	LevelUpInvulnSeconds = 3,

	-- Spiller-HP
	BaseMaxHP = 100,
	MaxHPPerLevel = 10, -- ekstra pr. level

	-- Kontakt-skade fra fjende til spiller pr. “stød”
	EnemyTouchDamage = 10,
	EnemyTouchCooldown = 0.6, -- sekunder per spiller

	-- Upgrade-pool (server vælger 3 tilfældige)
	Upgrades = {
		{ id="DAMAGE_PCT_20",  name="+20% Damage",        apply=function(p) p.Upgrades.DamageMult.Value = p.Upgrades.DamageMult.Value * 1.20 end },
		{ id="FIRERATE_ADD_15",name="+0.15 Fire rate",    apply=function(p) p.Upgrades.FireRateAdd.Value = p.Upgrades.FireRateAdd.Value + 0.15 end },
		{ id="MAXHP_ADD_20",   name="+20 Max HP",         apply=function(p) p.Upgrades.MaxHPAdd.Value   = p.Upgrades.MaxHPAdd.Value + 20 end },
		{ id="MOVESPD_PCT_10", name="+10% Move speed",    apply=function(p) p.Upgrades.MoveSpeedMult.Value = p.Upgrades.MoveSpeedMult.Value * 1.10 end },
	},
}
function Progression.RequiredXP(level)
	return math.floor(Progression.XPBase * (Progression.XPGrowth ^ (level-1)))
end
return Progression

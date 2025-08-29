-- ReplicatedStorage/Shared/EnemyUpgradeConfig.lua
local E = {}

-- Fusion
E.FusionRadius = 2.6            -- hvor tæt 3 basis-fjender skal være (inkl. host)
E.StunSeconds  = 3.0            -- stun mens opgradering sker



-- Hvad sker der ved en opgradering? (vælg 1 tilfældig)
-- weights kan justeres; alle "effects" kan tweakes
E.Upgrades = {
	{
		id="MAXHP",
		weight=4,
		apply=function(ctx)
			-- fordobl MaxHealth + heal tilsvarende
			local hum = ctx.hum
			hum.MaxHealth = hum.MaxHealth * 2
			hum.Health    = math.min(hum.MaxHealth, hum.Health * 2)
			ctx.body.Size = ctx.body.Size * 1.26 -- pæn skalering
			ctx.body.Color = Color3.fromRGB(150,150,255)
			ctx.body:SetAttribute("MaxHpScale", (ctx.body:GetAttribute("MaxHpScale") or 1) * 2)
		end
	},
	{
		id="SPEED",
		weight=3,
		apply=function(ctx)
			local mult = 1.10
			ctx.body:SetAttribute("MoveSpeedMult", (ctx.body:GetAttribute("MoveSpeedMult") or 1) * mult)
			ctx.body.Color = Color3.fromRGB(255,230,120)
		end
	},
	{
		id="DAMAGE",
		weight=3,
		apply=function(ctx)
			local mult = 2.0 -- +100%
			ctx.body:SetAttribute("TouchDamageMult", (ctx.body:GetAttribute("TouchDamageMult") or 1) * mult)
			ctx.body.Color = Color3.fromRGB(255,180,150)
		end
	},
	{
		id="RESIST",
		weight=2,
		apply=function(ctx)
			local mult = 0.90 -- tager 10% mindre skade
			ctx.body:SetAttribute("DamageTakenMult", (ctx.body:GetAttribute("DamageTakenMult") or 1) * mult)
			ctx.body.Color = Color3.fromRGB(160,160,160)
		end
	},
	{
		id="REGEN",
		weight=2,
		apply=function(ctx)
			ctx.body:SetAttribute("RegenPerSec", (ctx.body:GetAttribute("RegenPerSec") or 0) + 1)
			ctx.body.Color = Color3.fromRGB(140,220,140)
		end
	},
	{
		id="MAXHP_GROW",
		weight=1,
		apply=function(ctx)
			ctx.body:SetAttribute("MaxHPGainPerSec", (ctx.body:GetAttribute("MaxHPGainPerSec") or 0) + 1)
			ctx.body.Color = Color3.fromRGB(100,200,160)
		end
	},
	{
		id="RANGED",
		weight=2,
		apply=function(ctx)
			-- første gang får den basen; senere fusioner øger rækkevidde+skade
			local lvl = (ctx.body:GetAttribute("RangedLevel") or 0) + 1
			ctx.body:SetAttribute("RangedLevel", lvl)
			local baseDmg   = 1
			local baseRange = 18
			local dmgPerLvl = 1      -- +1 pr. ekstra fusion
			local rngPerLvl = 4      -- +4 studs pr. ekstra fusion
			ctx.body:SetAttribute("RangedDamage", (baseDmg + (lvl-1)*dmgPerLvl))
			ctx.body:SetAttribute("RangedRange",  (baseRange + (lvl-1)*rngPerLvl))
			ctx.body.Color = Color3.fromRGB(255,120,120)
		end
	},
}

-- hvis en fjende har flere forskellige upgrades, farv sort (visuel indikator)
function E.applyMultiColor(body)
	local seen = {}
	for _,u in ipairs({"RegenPerSec","MaxHPGainPerSec","RangedLevel","DamageTakenMult","MoveSpeedMult","TouchDamageMult"}) do
		local v = body:GetAttribute(u)
		if (u=="DamageTakenMult" and v and v<1) or (u~="DamageTakenMult" and v and v>0 and v~=1) then
			table.insert(seen, u)
		end
	end
	if #seen >= 2 then
		body.Color = Color3.new(0,0,0)
	end
end

-- Find en upgrade-def efter id
function E.getUpgradeById(id)
	for _,u in ipairs(E.Upgrades) do
		if u.id == id then return u end
	end
	return nil
end

-- Boss-basis: fordobl MaxHealth 'doubles' gange uden at ændre tier/XPMult
-- (bruges før de tilfældige opgraderinger)
function E.applyBossBaseline(ctx, doubles)
	doubles = math.max(1, doubles or 2)
	local maxhp = E.getUpgradeById("MAXHP")
	if not maxhp then return end
	for i = 1, doubles do
		maxhp.apply(ctx)  -- ændrer kun HP/Size/Color
	end
end


return E

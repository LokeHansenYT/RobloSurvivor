-- ReplicatedStorage/Shared/AbilityPreviews.lua
-- Viser “current ? next level” tekster for evner (bruges af Vendors m.fl.).

local Ab = require(game.ReplicatedStorage.Shared.AbilitiesConfig)  -- stats m.m.
local Preview = {}

-- ======== Hjælpere ========
local function fmtPlus(v) return (v>=0 and ("+"..tostring(v))) or tostring(v) end
local function lvlOr1(lvl) return math.max(1, tonumber(lvl) or 1) end

-- Roterende gevinst for VOID-felter: varighed ? flat-dmg/effekt ? størrelse(+10%) ? gentag
local function rotatedGains(level)
	local extraDur, extraVal, extraScale = 0,0,0
	for i=1, math.max(0, level-1) do
		local r = (i % 3)
		if r==1 then extraDur += 1
		elseif r==2 then extraVal += 1
		else extraScale += 10 end -- i procent
	end
	return extraDur, extraVal, extraScale
end

-- ======== Standard preview (fallback) ========
function Preview._generic(name, base)
	local function at(level)
		local l = lvlOr1(level)
		return {
			name = name,
			lines = {
				("Level %d"):format(l),
				-- læs generiske felter hvis de findes
				base.damageBase and ("Skade/tick: %d"):format(base.damageBase + math.max(0,l-1)) or nil,
				base.radius and ("Radius: %d"):format(base.radius) or nil,
			}
		}
	end
	return at
end

-- ======== SÆRLIGE PREVIEWS ========

-- Ildspor (forbliver som før, bare eksempel hvis du vil udvide)
Preview.FireTrail = function(level)
	local l = lvlOr1(level)
	return {
		name = "Ildspor",
		lines = {
			("Varighed pr. segment: %.1fs"):format((Ab.FireTrail and Ab.FireTrail.segmentTTL) or 1.0),
			("Burn skade/sek: %d"):format((Ab.FireTrail and Ab.FireTrail.burnPerSecBase or 1) + math.max(0,l-1)),
			("Sprede-chance: %d%%"):format((Ab.FireTrail and math.floor((Ab.FireTrail.spreadChanceBase or 10))) or 10),
			"Efterlader spor på jorden (sprites, hvis slået til)."
		}
	}
end

-- === Fire Aura (nyt preview) ===
Preview.FireAura = function(level)
	local l = lvlOr1(level)
	local base = Ab.FireAura or {}
	local dps   = (base.dps or 1) + math.max(0, l-1) * (base.dpsGrowth or 0)
	local dur   = (base.duration or 3) + math.max(0, l-1) * (base.durationGrowth or 0)
	local ch    = ((base.chance or 0.10) + math.max(0, l-1) * (base.chanceGrowth or 0)) * 100
	local rad   = (base.radius or 7) + math.max(0, l-1) * (base.radiusGrowth or 0)
	return {
		name  = "Fire Aura",
		lines = {
			string.format("DoT: %.0f/sek i %.1fs", dps, dur),
			string.format("Sprede-chance: %d%%", math.floor(ch + 0.5)),
			string.format("Radius: %.1f", rad),
			"Farve matcher auraen.",
		}
	}
end

-- Charged Ground (kort)
Preview.ChargedGround = function(level)
	local l = lvlOr1(level)
	return {
		name = "Charged Ground",
		lines = {
			("Stun: %d–%ds"):format(1,3),
			("Skade pr. tick: %d"):format((Ab.ChargedGround and Ab.ChargedGround.damageBase or 1) + math.floor(math.max(0,l-1)/3)),
			"Flytter sig i trin og splitter af og til.",
		}
	}
end

-- VOID: Void Zone – Vulnerable
Preview.VoidZone = function(level)
	local l = lvlOr1(level)
	local extraDur, extraFlat, extraScalePct = rotatedGains(l)
	local ttl = 4 + 1 + extraDur
	local flat = 1 + extraFlat
	return {
		name = "Void Zone",
		lines = {
			("Varighed: %ds ? %ds"):format(ttl, ttl + ( ( (l%3)==1 ) and 1 or 0 )),
			("Vulnerable: +%d dmg i 1s (refresh i feltet)"):format(flat),
			("Størrelse: 100%% ? %d%%"):format(100 + (( (l%3)==0 ) and 10 or 0)),
			"Udvider + nulstiller tid ved kill i feltet.",
		}
	}
end

-- VOID: Soul Pit – Heal nærliggende spillere når en fjende tager skade
Preview.SoulPit = function(level)
	local l = lvlOr1(level)
	local extraDur, extraHeal, extraScalePct = rotatedGains(l)
	local ttl = 4 + 1 + extraDur
	local heal = 1 + extraHeal
	return {
		name = "Soul Pit",
		lines = {
			("Varighed: %ds ? %ds"):format(ttl, ttl + ( ( (l%3)==1 ) and 1 or 0 )),
			("Heal: +%d HP når fjende tager skade i feltet"):format(heal),
			("Størrelse: 100%% ? %d%%"):format(100 + (( (l%3)==0 ) and 10 or 0)),
			"Udvider + nulstiller tid ved kill i feltet.",
		}
	}
end

-- VOID: Siphon Power – Kills giver +flat dmg buff (stacker op til level)
Preview.SiphonPower = function(level)
	local l = lvlOr1(level)
	local extraDur, extraFlat, extraScalePct = rotatedGains(l)
	local ttl  = 4 + 1 + extraDur
	local flat = 1 + extraFlat
	return {
		name = "Siphon Power",
		lines = {
			("Varighed: %ds ? %ds"):format(ttl, ttl + ( ( (l%3)==1 ) and 1 or 0 )),
			("Buff: +%d flat dmg pr. kill (max stacks = level)"):format(flat),
			("Størrelse: 100%% ? %d%%"):format(100 + (( (l%3)==0 ) and 10 or 0)),
			"Udvider + nulstiller tid ved kill i feltet.",
		}
	}
end

-- ======== PUBLIC API ========
-- describe(key, level): finder navngivet preview eller bruger generisk
function Preview.describe(key, level)
	-- direkte match
	if type(Preview[key]) == "function" then
		return Preview[key](level)
	end
	-- fallback til generisk baseret på AbilitiesConfig
	local base = Ab[key]
	if base then
		return Preview._generic(key, base)(level)
	end
	return { name = key, lines = {"Ingen data."} }
end

return Preview

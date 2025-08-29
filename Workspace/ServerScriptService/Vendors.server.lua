-- ServerScriptService/Vendors.server.lua
-- Vendor-tilbud m/prereq + “kan opgraderes” + dynamiske previews (AbilityPreviews).

local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes   = RS:WaitForChild("Remotes")
local EvBuy     = Remotes:WaitForChild("VendorBuy")
local GetOffers = Remotes:WaitForChild("VendorGetOffers")
local EvClose   = Remotes:WaitForChild("VendorClose")

local Ab       = require(RS.Shared:WaitForChild("AbilitiesConfig"))
local Preview  = require(RS.Shared:WaitForChild("AbilityPreviews"))

local DEBUG = false
local function dprint(...) if DEBUG then print("[Vendors]", ...) end end

local LK_FALLBACK = {
	DamageAura="AuraLevel", Shield="ShieldLevel", HealAura="HealAuraLevel", SlowOrb="SlowOrbLevel",
	Mine="MinesLevel", Fan="FanShotLevel", Plus="PlusLevel", Cross="CrossLevel", Spinner="SpinnerLevel",
	Boomerang="BoomerangLevel", Axe="AxeLevel", Whip="WhipLevel", FireTrail="FireTrailLevel",
	Lightning="LightningLevel", ChainLightning="ChainLightningLevel", ElectricAura="ElectricAuraLevel",
	ElectricArmor="ElectricArmorLevel", ChargedGround="ChargedGroundLevel", ChargedStorm="ChargedStormLevel",
	ElectricDefense="ElectricDefenseLevel", Raiden="RaidenLevel",
}

local function getUpgrades(plr)
	local up = plr:FindFirstChild("Upgrades")
	if not up then up = Instance.new("Folder"); up.Name="Upgrades"; up.Parent=plr end
	return up
end
local function getLevelKeyForKey(key)
	local def = Ab[key]
	if def and def.levelKey then return def.levelKey end
	if type(Ab.WeaponDefs)=="table" then
		for _,e in ipairs(Ab.WeaponDefs) do if e.key==key and e.levelKey then return e.levelKey end end
	end
	return LK_FALLBACK[key] or (key.."Level")
end
local function getLevel(plr, levelKey)
	local iv = getUpgrades(plr):FindFirstChild(levelKey)
	return (iv and iv:IsA("IntValue") and iv.Value) or 0
end
local function bumpLevel(plr, levelKey, inc)
	local up = getUpgrades(plr)
	local iv = up:FindFirstChild(levelKey)
	if not iv then iv = Instance.new("IntValue"); iv.Name=levelKey; iv.Value=0; iv.Parent=up end
	iv.Value += (inc or 1)
	return iv.Value
end

local function hasAllPrereqs(plr, keys)
	if not keys or #keys==0 then return true end
	for _,k in ipairs(keys) do
		local lk = getLevelKeyForKey(k)
		if getLevel(plr, lk) <= 0 then return false end
	end
	return true
end
local function lowestLevelOf(plr, keys)
	if not keys or #keys==0 then return math.huge end
	local m=math.huge
	for _,k in ipairs(keys) do
		local lk=getLevelKeyForKey(k)
		local lv=getLevel(plr, lk)
		if lv<m then m=lv end
	end
	return m
end
local function hasTag(def, wanted)
	if not def then return false end
	local t = def.tags or def.Tags
	if not t then return false end
	wanted = string.lower(wanted)
	for _,x in ipairs(t) do if tostring(x):lower()==wanted then return true end end
	return false
end
local function allAbilityKeys()
	local out={}
	if type(Ab.WeaponDefs)=="table" then
		for _,e in ipairs(Ab.WeaponDefs) do if e.key and Ab[e.key] then table.insert(out, e.key) end end
	end
	return out
end
local function rnd3(list)
	local pool=table.clone(list)
	for i=#pool,2,-1 do local j=math.random(i); pool[i],pool[j]=pool[j],pool[i] end
	local out={}; for i=1, math.min(3, #pool) do out[i]=pool[i] end; return out
end

local function buildStatsDesc(def, currLv, nextLv, plr)
	-- Brug specialiserede previews først:
	local s = Preview.describe(def and def._key or "?", def, plr, currLv, nextLv, getLevel, getLevelKeyForKey)
	if s and #s>0 then return s end

	-- fallback: meget kort generisk (hvis der slet ikke findes data/funktioner)
	local lines = {}
	if def and def.desc then table.insert(lines, def.desc) end
	return table.concat(lines, "\n")
end

local function makeOffer(plr, key, currLv, cap)
	local def = Ab[key]; if not def then return nil end
	-- husk nøgle på def (til Preview-routeren)
	def._key = key

	local title = def.name or key
	local nextLv = (currLv < (cap or 99)) and (currLv + 1) or nil
	local stats  = buildStatsDesc(def, math.max(0,currLv), nextLv, plr)
	local desc   = (def.desc and def.desc~="") and (def.desc.."\n\n"..(stats or "")) or (stats or "")
	return { id=key, title=title, desc=desc }
end

local CORE_CHOICES = {
	{ id="MaxHP",        title="Max HP +20",         desc="Øger maks liv."      },
	{ id="DamageMult",   title="+10% Damage",        desc="Øger din skade."     },
	{ id="FireRateMult", title="+10% Fire Rate",     desc="Hurtigere angreb."   },
	{ id="MoveSpeed",    title="+8% Move Speed",     desc="Bevæg dig hurtigere."},
}

local function abilityCanUpgrade(plr, key)
	local def = Ab[key]; if not def then return false,"unknown" end
	if def.requires and not hasAllPrereqs(plr, def.requires) then return false,"prereq" end
	local lk   = getLevelKeyForKey(key)
	local curr = getLevel(plr, lk)
	local hard = def.maxLevel or 99
	local capL = def.capByLowestOf or def.cap or def.combine or def.requires
	local capP = capL and lowestLevelOf(plr, capL) or math.huge
	local eff  = math.min(hard, capP)
	return (curr < eff), eff, curr, lk
end

local function pickAllowed(plr, keys)
	local allowed={}
	for _,k in ipairs(keys) do
		local ok, eff, curr, lk = abilityCanUpgrade(plr, k)
		if ok then table.insert(allowed, {k, curr, eff, lk}) end
	end
	return allowed
end

local function buildOffersForVendor(plr, vendorType)
	if vendorType == "Core3" then
		return rnd3(CORE_CHOICES)
	end

	-- 1) Start med type-baseret key-liste
	local keys = {}
	if vendorType == "Auras" then
		for _,k in ipairs(allAbilityKeys()) do
			if hasTag(Ab[k], "aura") then table.insert(keys, k) end
		end
		if #keys == 0 then
			for _,k in ipairs(allAbilityKeys()) do
				local n = (Ab[k] and Ab[k].name or k):lower()
				if n:find("aura") then table.insert(keys, k) end
			end
		end
	elseif vendorType == "Electric" then
		for _,k in ipairs(allAbilityKeys()) do
			if hasTag(Ab[k], "electric") then table.insert(keys, k) end
		end
		if #keys == 0 then
			for _,k in ipairs({"Lightning","ChainLightning","ElectricAura","ElectricArmor","ChargedGround","ChargedStorm","ElectricDefense","Raiden"}) do
				if Ab[k] then table.insert(keys, k) end
			end
		end
	else
		keys = allAbilityKeys()
	end

	-- 2) Valgfrit: snævr ind yderligere på TagFilter (trail/ground/frontal/area/…)
	local tagFilter = (plr:GetAttribute("VendorTagFilter") and tostring(plr:GetAttribute("VendorTagFilter")):lower()) or ""
	if tagFilter ~= "" then
		local filtered = {}
		for _,k in ipairs(keys) do
			if hasTag(Ab[k], tagFilter) then table.insert(filtered, k) end
		end
		if #filtered > 0 then keys = filtered end
	end

	-- 3) Resten som før (prereqs/caps ? pickAllowed ? rnd3 ? makeOffer)
	local allowed = pickAllowed(plr, keys)
	if #allowed == 0 then
		for _,k in ipairs(keys) do table.insert(allowed, {k, 0, 99, getLevelKeyForKey(k)}) end
	end
	local picks = rnd3(allowed)
	local offers = {}
	for _,t in ipairs(picks) do
		local k, curr, cap = t[1], t[2], t[3]
		local off = makeOffer(plr, k, curr, cap)
		if off then table.insert(offers, off) end
	end
	return offers
end


GetOffers.OnServerInvoke = function(plr, vendorType)
	return { offers = buildOffersForVendor(plr, vendorType) }
end

local function findSPValue(plr)
	local cand = {}
	local stats = plr:FindFirstChild("Stats")
	if stats then
		table.insert(cand, stats:FindFirstChild("SP"))
		table.insert(cand, stats:FindFirstChild("Sp"))
	end
	table.insert(cand, plr:FindFirstChild("SkillPoints"))
	local ls = plr:FindFirstChild("leaderstats")
	if ls then table.insert(cand, ls:FindFirstChild("SP")) end

	for _,v in ipairs(cand) do
		if typeof(v)=="Instance" and (v:IsA("IntValue") or v:IsA("NumberValue")) then
			return v
		end
	end
	return nil
end

local function trySpendSP(plr, cost)
	cost = tonumber(cost) or 0
	if cost <= 0 then return true end
	local sp = findSPValue(plr); if not sp then return false end
	if sp.Value < cost then return false end
	sp.Value -= cost
	return true
end





local function applyCoreChoice(plr, id)
	local up = getUpgrades(plr)
	if id=="MaxHP" then
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.MaxHealth += 20; hum.Health = hum.MaxHealth; return true,"+20 Max HP" end
	elseif id=="DamageMult" then
		local v = up:FindFirstChild("DamageMult") or Instance.new("NumberValue"); v.Name="DamageMult"; v.Parent=up
		v.Value = (v.Value>0 and v.Value or 1.0)*1.10; return true,"+10% Damage"
	elseif id=="FireRateMult" then
		local v = up:FindFirstChild("FireRateMult") or Instance.new("NumberValue"); v.Name="FireRateMult"; v.Parent=up
		v.Value = (v.Value>0 and v.Value or 1.0)*1.10; return true,"+10% Fire Rate"
	elseif id=="MoveSpeed" then
		local v = up:FindFirstChild("MoveSpeedLevel") or Instance.new("IntValue"); v.Name="MoveSpeedLevel"; v.Parent=up
		v.Value += 1; return true,"+8% Move Speed"
	end
	return false,"Ukendt valg"
end

local function applyAbilityPurchase(plr, key)
	local def = Ab[key]; if not def then return false,"Ukendt evne" end
	local lk = getLevelKeyForKey(key)
	local ok, cap, curr = abilityCanUpgrade(plr, key)
	if not ok and cap ~= "unknown" then
		return false, (cap=="prereq" and "Mangler forkrav" or "Maks niveau nået")
	end
	local new = bumpLevel(plr, lk, 1)
	return true, string.format("%s -> Lv.%d", def.name or key, new)
end

EvBuy.OnServerEvent:Connect(function(plr, vendorType, choiceId, cost)
	if Ab[choiceId] then
		if not trySpendSP(plr, tonumber(cost) or 0) then EvClose:FireClient(plr,"Not enough SP"); return end
		local ok,msg = applyAbilityPurchase(plr, choiceId)
		EvClose:FireClient(plr, msg or (ok and "Purchased" or "Failed"))
	else
		if not trySpendSP(plr, tonumber(cost) or 0) then EvClose:FireClient(plr,"Not enough SP"); return end
		local ok,msg = applyCoreChoice(plr, choiceId)
		EvClose:FireClient(plr, msg or (ok and "Purchased" or "Failed"))
	end
end)

-- ServerScriptService/Abilities/ChainLightning.lua
-- Kædelyn: rammer mål og splitter (kun hvis nuværende skade > 1). Cooldown skaleres.
local Debris = game:GetService("Debris")
local C = require(script.Parent._core.AbilityCommon)
local Ab,FCT = C.Ab,C.FCT
local M = { id = Ab.ChainLightning.id, levelKey = "ChainLightningLevel" }

local function bolt(a,b)
	local dir=(b-a); local len=dir.Magnitude; if len<0.5 then return end
	local p=Instance.new("Part"); p.Anchored=true; p.CanCollide=false; p.Material=Enum.Material.Neon
	p.Color=Color3.fromRGB(255,230,120); p.Size=Vector3.new(0.25,0.25,len)
	p.CFrame=CFrame.lookAt((a+b)/2,b); p.Parent=workspace; Debris:AddItem(p,0.15)
end

local function spec(lvl)
	local heal = (Ab.HealAura and Ab.HealAura.radius) or 12
	local dmgStart = (Ab.ChainLightning.damageBase or 2) + math.floor((math.max(0,lvl-1)+1)/2)
	local cd = Ab.ChainLightning.cooldown or 1.2
	local range = (Ab.ChainLightning.rangeFactor or 3)*heal
	local startBonusPct = 2 * math.floor(lvl/2)
	return { dmgStart=dmgStart, cooldown=cd, range=range, startBonusPct=startBonusPct }
end

-- stun-parametre fra config
local function stunChanceFor(lvl)
	local base = Ab.ChainLightning.stunChanceBase   or 0.25
	local per  = Ab.ChainLightning.stunChancePerLvl or 0.00
	return math.clamp(base + per * math.max(0, (lvl or 1)-1), 0, 1)
end
local function stunDurFor()
	return Ab.ChainLightning.stunDuration or 0.8
end

local function picksAround(pos, exclude, n, range, zid)
	local out={}
	for _,e in ipairs(C.getEnemies(zid)) do
		if not exclude[e] then
			local pp=e.PrimaryPart; if pp then
				local d=(pp.Position-pos).Magnitude
				if d<=range then table.insert(out,{m=e,pp=pp,d=d}) end
			end
		end
	end
	table.sort(out,function(a,b) return a.d<b.d end)
	local r={}; for i=1,math.min(n,#out) do r[i]=out[i] end; return r
end

local function tryStun(model, lvl)
	local hum  = model:FindFirstChildOfClass("Humanoid")
	local body = model:FindFirstChild("Body") or model.PrimaryPart
	if not (hum and body) then return end
	local resist = body:GetAttribute("Horde_Resist") or 0
	local chance = stunChanceFor(lvl) * math.clamp(1 - resist, 0, 1)
	if math.random() < chance then
		local dur = stunDurFor()
		if C.applyElecStun then
			C.applyElecStun(hum, dur)
		else
			body:SetAttribute("StunnedUntil", os.clock() + dur)
		end
		if FCT and FCT.ShowDebuff then FCT.ShowDebuff(model, "STUNNED") end
	end
end

-- nu med stun-parametre ned gennem rekursionen
local function explodeFrom(srcModel, damage, rays, range, zid, hitSet, lvl)
	if damage<1 or rays<=0 then return end
	local srcPP=srcModel and srcModel.PrimaryPart; if not srcPP then return end
	local picks=picksAround(srcPP.Position, hitSet, rays, range, zid); if #picks==0 then return end
	for _,rec in ipairs(picks) do
		local hum=rec.m:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health>0 then
			hitSet[rec.m]=true
			bolt(srcPP.Position+Vector3.new(0,2,0), rec.pp.Position+Vector3.new(0,2,0))
			hum:TakeDamage(damage); if FCT then FCT.ShowDamage(rec.m, damage, M.id) end
			tryStun(rec.m, lvl)
		end
	end
	if damage>1 then
		local nextD=math.floor(damage/2); if nextD>=1 then
			for _,rec in ipairs(picks) do explodeFrom(rec.m, nextD, 2, range, zid, hitSet, lvl) end
		end
	end
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up=plr:FindFirstChild("Upgrades"); local lvl=up and up[M.levelKey] and up[M.levelKey].Value or 0
			if lvl>0 and not C.offensivePaused(plr) then
				local s=spec(lvl); local ch=plr.Character; local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp then
					local zid=plr:GetAttribute("ZoneId")
					local bonus=s.startBonusPct
					local shots=1+math.floor(bonus/100); if (bonus%100)>0 and math.random(1,100)<= (bonus%100) then shots+=1 end
					local first=picksAround(hrp.Position, {}, shots, s.range, zid)
					if #first>0 then
						local hitSet={}
						for _,rec in ipairs(first) do
							local hum=rec.m:FindFirstChildOfClass("Humanoid"); if hum and hum.Health>0 then
								hitSet[rec.m]=true
								bolt(hrp.Position+Vector3.new(0,2,0), rec.pp.Position+Vector3.new(0,2,0))
								hum:TakeDamage(s.dmgStart); if FCT then FCT.ShowDamage(rec.m, s.dmgStart, M.id) end
								tryStun(rec.m, lvl)
								if s.dmgStart>1 then
									local nextD=math.floor(s.dmgStart/2); if nextD>=1 then explodeFrom(rec.m,nextD,2,s.range,zid,hitSet,lvl) end
								end
							end
						end
					end
				end
				C.waitScaled(plr, s.cooldown)
			else task.wait(0.3) end
		end
	end)
end

M.__explodeFrom=function(src, damage, range, zid, lvl)
	if damage and damage>=1 then explodeFrom(src, math.floor(damage+0), 2, range, zid, {[src]=true}, lvl or 1) end
end
return M

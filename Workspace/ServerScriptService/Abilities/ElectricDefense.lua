-- ServerScriptService/Abilities/ElectricDefense.lua
-- Aura-proc (stun+dmg) som også starter mini-kædelyn. Cooldowns/tick skaleres via auraens interval.
local Debris=game:GetService("Debris")
local C=require(script.Parent._core.AbilityCommon)
local Ab,FCT=C.Ab,C.FCT
local M={ id=Ab.ElectricDefense.id, levelKey="ElectricDefenseLevel" }

local function effLevel(plr)
	local up=plr:FindFirstChild("Upgrades")
	local A=up and up.ElectricArmorLevel and up.ElectricArmorLevel.Value or 0
	local CL=up and up.ChainLightningLevel and up.ChainLightningLevel.Value or 0
	local S=up and up[M.levelKey] and up[M.levelKey].Value or 0
	return math.min(S,A,CL)
end

local function auraSpec(lvl)
	local heal=(Ab.HealAura and Ab.HealAura.radius) or 12
	local base=Ab.ElectricAura or {}
	local damage=(base.damageBase or 1)+math.floor((math.max(0,lvl-1)+1)/2)
	local chance=(base.chanceBase or 0.10)+0.01*math.floor(lvl/2)
	local radius=base.radius or heal
	local interval=base.interval or 0.9
	return {damage=damage,chance=chance,radius=radius,interval=interval}
end

local function bolt(a,b)
	local dir=(b-a); local len=dir.Magnitude; if len<0.5 then return end
	local p=Instance.new("Part"); p.Anchored=true; p.CanCollide=false; p.Material=Enum.Material.Neon
	p.Color=Color3.fromRGB(255,230,120); p.Size=Vector3.new(0.25,0.25,len)
	p.CFrame=CFrame.lookAt((a+b)/2,b); p.Parent=workspace; Debris:AddItem(p,0.15)
end

local function rangeFor(lvl) return (Ab.ChainLightning.rangeFactor or 3)*((Ab.HealAura and Ab.HealAura.radius) or 12) end
local function explodeFrom(srcModel, damage, range, zid, hitSet)
	if damage<1 then return end
	local srcPP=srcModel and srcModel.PrimaryPart; if not srcPP then return end
	local list={}
	for _,e in ipairs(C.getEnemies(zid)) do if not hitSet[e] then local pp=e.PrimaryPart; if pp and (pp.Position-srcPP.Position).Magnitude<=range then table.insert(list,{m=e,pp=pp,d=(pp.Position-srcPP.Position).Magnitude}) end end end
	table.sort(list,function(a,b) return a.d<b.d end)
	local picks={}; for i=1, math.min(2,#list) do picks[i]=list[i] end
	for _,rec in ipairs(picks) do local hum=rec.m:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health>0 then hitSet[rec.m]=true; bolt(srcPP.Position+Vector3.new(0,2,0), rec.pp.Position+Vector3.new(0,2,0))
			hum:TakeDamage(damage); FCT.ShowDamage(rec.m, damage, M.id); C.applyElecStun(hum, math.random(1,3))
		end
	end
	if damage>1 then local nextD=math.floor(damage/2); if nextD>=1 then for _,rec in ipairs(picks) do explodeFrom(rec.m,nextD,range,zid,hitSet) end end end
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local lvl=effLevel(plr)
			if lvl>0 and not C.offensivePaused(plr) then
				local a=auraSpec(lvl); local ch=plr.Character; local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp then local zid=plr:GetAttribute("ZoneId")
					for _,e in ipairs(C.getEnemies(zid)) do
						local pp=e.PrimaryPart; local hum=e:FindFirstChildOfClass("Humanoid")
						if pp and hum and hum.Health>0 and (pp.Position-hrp.Position).Magnitude<=a.radius then
							if math.random()<math.min(1,a.chance) then
								hum:TakeDamage(a.damage); FCT.ShowDamage(e,a.damage,M.id); C.applyElecStun(hum,math.random(1,3))
								local hitSet={[e]=true}; local start=math.floor(((Ab.ChainLightning.damageBase or 2)+math.floor((math.max(0,lvl-1)+1)/2))/2)
								if start>=1 then explodeFrom(e,start,rangeFor(lvl),zid,hitSet) end
							end
						end
					end
				end
				C.waitScaled(plr, a.interval) -- ?
			else task.wait(0.4) end
		end
	end)
end
return M

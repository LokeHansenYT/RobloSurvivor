-- ServerScriptService/Abilities/Raiden.lua
-- Raiden: kombinerer lightning + charged ground + mini-chain. Cooldown skaleres.
local Debris=game:GetService("Debris")
local C=require(script.Parent._core.AbilityCommon)
local Ab,FCT=C.Ab,C.FCT
local M={ id=Ab.Raiden.id, levelKey="RaidenLevel" }

local function effLevel(plr)
	local up=plr:FindFirstChild("Upgrades")
	local L=up and up.LightningLevel and up.LightningLevel.Value or 0
	local D=up and up.ElectricDefenseLevel and up.ElectricDefenseLevel.Value or 0
	local S=up and up.ChargedStormLevel and up.ChargedStormLevel.Value or 0
	local R=up and up[M.levelKey] and up[M.levelKey].Value or 0
	return math.min(L,D,S,R)
end

local function auraR() return (Ab.ElectricAura and Ab.ElectricAura.radius) or (Ab.HealAura and Ab.HealAura.radius) or 12 end
local function spec(lvl)
	local base=Ab.Lightning or {}
	return {
		dmg=(base.damageBase or 30)+15*math.floor((lvl+1)/2),
		cd=math.max(3,(base.cooldownBase or 60)-4*math.floor(lvl/2)),
		range=auraR()
	}
end

local function bolt(a,b)
	local dir=(b-a); local len=dir.Magnitude; if len<0.5 then return end
	local p=Instance.new("Part"); p.Anchored=true; p.CanCollide=false; p.Material=Enum.Material.Neon
	p.Color=Color3.fromRGB(255,230,120); p.Size=Vector3.new(0.3,0.3,len)
	p.CFrame=CFrame.lookAt((a+b)/2,b); p.Parent=workspace; Debris:AddItem(p,0.15)
end

local ChainLightning,ChargedGround

function M.start(plr)
	task.spawn(function()
		ChainLightning=ChainLightning or require(script.Parent:FindFirstChild("ChainLightning"))
		ChargedGround=ChargedGround or require(script.Parent:FindFirstChild("ChargedGround"))
		while plr.Parent do
			local lvl=effLevel(plr)
			if lvl>0 and not C.offensivePaused(plr) then
				local s=spec(lvl); local ch=plr.Character; local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp then
					local zid=plr:GetAttribute("ZoneId"); local best,bm=nil,1e9
					for _,e in ipairs(C.getEnemies(zid)) do local pp=e.PrimaryPart
						if pp then local d=(pp.Position-hrp.Position).Magnitude; if d<=s.range and d<bm then best=e; bm=d end end
					end
					if best then local hum=best:FindFirstChildOfClass("Humanoid"); local pp=best.PrimaryPart
						if hum and hum.Health>0 and pp then
							bolt(pp.Position+Vector3.new(0,35,0), pp.Position+Vector3.new(0,2,0))
							hum:TakeDamage(s.dmg); FCT.ShowDamage(best,s.dmg,M.id); C.applyElecStun(hum,math.random(1,3))
							if ChargedGround and ChargedGround.__pulse then ChargedGround.__pulse(plr, Vector3.new(pp.Position.X, hrp.Position.Y-2, pp.Position.Z), lvl) end
							if ChainLightning and ChainLightning.__explodeFrom then
								local base=(Ab.ChainLightning.damageBase or 2)+math.floor((math.max(0,lvl-1)+1)/2)
								ChainLightning.__explodeFrom(best, math.floor(base/2 + 0.0), (Ab.ChainLightning.rangeFactor or 3)*((Ab.HealAura and Ab.HealAura.radius) or 12), zid)
							end
						end
					end
				end
				C.waitScaled(plr, s.cd) -- ?
			else task.wait(0.4) end
		end
	end)
end
return M

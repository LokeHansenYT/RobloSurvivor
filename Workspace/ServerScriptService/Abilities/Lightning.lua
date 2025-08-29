-- ServerScriptService/Abilities/Lightning.lua
-- Lyn: vælger tilfældig fjende i range. Skade + stun. Cooldown skaleres.
local Debris=game:GetService("Debris")
local C=require(script.Parent._core.AbilityCommon)
local Ab,FCT=C.Ab,C.FCT
local M={ id=Ab.Lightning.id, levelKey="LightningLevel" }

local function bolt(a,b)
	local dir=(b-a); local len=dir.Magnitude; if len<0.5 then return end
	local p=Instance.new("Part"); p.Anchored=true; p.CanCollide=false; p.Material=Enum.Material.Neon
	p.Color=Color3.fromRGB(255,230,120); p.Size=Vector3.new(0.3,0.3,len)
	p.CFrame=CFrame.lookAt((a+b)/2,b); p.Parent=workspace; Debris:AddItem(p,0.15)
end

local function spec(lvl)
	local heal=(Ab.HealAura and Ab.HealAura.radius) or 12
	local base=Ab.Lightning or {}
	local dmg=(base.damageBase or 30)+15*math.floor((lvl+1)/2)
	local cd=math.max(3,(base.cooldownBase or 60)-4*math.floor(lvl/2))
	local range=(base.rangeFactor or 3)*heal
	return {dmg=dmg,cd=cd,range=range}
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up=plr:FindFirstChild("Upgrades"); local lvl=up and up[M.levelKey] and up[M.levelKey].Value or 0
			if lvl>0 and not C.offensivePaused(plr) then
				local s=spec(lvl); local ch=plr.Character; local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp then
					local zid=plr:GetAttribute("ZoneId"); local cand=nil; local best=1e9
					for _,e in ipairs(C.getEnemies(zid)) do local pp=e.PrimaryPart
						if pp then local d=(pp.Position-hrp.Position).Magnitude; if d<=s.range and d<best then cand=e; best=d end end
					end
					if cand then local hum=cand:FindFirstChildOfClass("Humanoid"); local pp=cand.PrimaryPart
						if hum and hum.Health>0 and pp then
							bolt(pp.Position+Vector3.new(0,35,0), pp.Position+Vector3.new(0,2,0))
							hum:TakeDamage(s.dmg); FCT.ShowDamage(cand,s.dmg,M.id)
							C.applyElecStun(hum, math.random(1,3))
						end
					end
				end
				C.waitScaled(plr, s.cd) -- ?
			else task.wait(0.4) end
		end
	end)
end
return M

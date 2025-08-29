-- ServerScriptService/Abilities/ElectricArmor.lua
-- Elektrisk rustning: on-hit proc (stun + dmg). Aktivt vindue + cooldown; cooldown skaleres.
local C=require(script.Parent._core.AbilityCommon)
local Ab,FCT=C.Ab,C.FCT
local M={ id=Ab.ElectricArmor.id, levelKey="ElectricArmorLevel" }

local function spec(lvl)
	local base=Ab.ElectricArmor or {}
	local dmg=(base.damageBase or 1)+math.floor((math.max(0,lvl-1)+1)/2)
	local cd = math.max(0,(base.cooldownBase or 60)-math.floor(lvl/2))
	local dur= base.activeDuration or 15
	local chance= base.chanceBase or 0.25
	local alwaysOn=cd<=dur; return{damage=dmg,cooldown=cd,duration=dur,chance=chance,alwaysOn=alwaysOn}
end

function M.start(plr)
	task.spawn(function()
		local ch=plr.Character; local hum=ch and ch:FindFirstChildOfClass("Humanoid"); local lastHitT=0
		if hum then hum.HealthChanged:Connect(function(nh,oh) if oh and nh<oh then lastHitT=os.clock() end end) end
		while plr.Parent do
			local up=plr:FindFirstChild("Upgrades"); local lvl=up and up[M.levelKey] and up[M.levelKey].Value or 0
			if lvl>0 and not C.offensivePaused(plr) then
				local s=spec(lvl); local t0=os.clock()
				while plr.Parent and (os.clock()-t0)<s.duration do
					if (os.clock()-lastHitT)<1.0 then
						local zid=plr:GetAttribute("ZoneId"); local best,bd=nil,1e9
						for _,e in ipairs(C.getEnemies(zid)) do local pp=e.PrimaryPart; if pp then local d=(pp.Position-(ch and ch.PrimaryPart and ch.PrimaryPart.Position or pp.Position)).Magnitude; if d<bd then bd=d; best=e end end end
						if best then local h=best:FindFirstChildOfClass("Humanoid"); if h and h.Health>0 then
								h:TakeDamage(s.damage); FCT.ShowDamage(best,s.damage,M.id); C.applyElecStun(h,math.random(1,3))
							end end
					end
					task.wait(0.1)
				end
				C.waitScaled(plr, s.cooldown) -- ? (hvis alwaysOn, cd˜0 og den kører kontinuerligt)
			else task.wait(0.4) end
		end
	end)
end
return M

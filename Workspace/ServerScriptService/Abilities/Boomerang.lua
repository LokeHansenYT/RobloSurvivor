-- ServerScriptService/Abilities/Boomerang.lua
-- Boomerang: buer mod en fjende og tilbage. Lige lvls +1 søgende projektil, ulige lvls +1 proj.
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local C = require(script.Parent._core.AbilityCommon)
local Ab,FCT = C.Ab,C.FCT
local M = { id = Ab.Boomerang.id, levelKey = "BoomerangLevel" }

local function range() return (Ab.Boomerang.rangeFactor or 3) * ((Ab.HealAura and Ab.HealAura.radius) or 12) end
local function damageFor() return Ab.Boomerang.damageBase or 1 end
local function countFor(lvl) return 1 + math.max(0,lvl-1) end -- +1 pr lvl

local function pickTargets(plr, want, dist)
	local zid=plr:GetAttribute("ZoneId"); local list={}
	for _,e in ipairs(C.getEnemies(zid)) do
		local pp=e.PrimaryPart; if pp and (pp.Position-(plr.Character and plr.Character:WaitForChild("HumanoidRootPart").Position or pp.Position)).Magnitude<=dist then
			table.insert(list,{m=e, pp=pp})
		end
	end
	return list
end

local function flyOne(plr, targetPP, dmg, dist)
	local ch=plr.Character; local hrp=ch and ch:FindFirstChild("HumanoidRootPart"); if not hrp then return end
	local pos = hrp.Position + Vector3.new(0,1,0)
	local p=Instance.new("Part"); p.Anchored=true; p.CanCollide=false; p.Material=Enum.Material.Neon
	p.Color=Color3.fromRGB(120,200,255); p.Size=Vector3.new(0.3,0.3,1.8); p.CFrame=CFrame.new(pos); p.Parent=workspace; Debris:AddItem(p,2.0)
	local s=Ab.Boomerang.speed or 36; local t=0; local out=true; local zid=plr:GetAttribute("ZoneId")
	while p.Parent and t<2.2 do
		local dt=RunService.Heartbeat:Wait(); t+=dt
		local targetPos
		if out then
			if targetPP and targetPP.Parent then targetPos=targetPP.Position else targetPos=pos+hrp.CFrame.LookVector*dist end
			if (pos-targetPos).Magnitude<=2 then out=false end
		else
			targetPos=hrp.Position
			if (pos-targetPos).Magnitude<=2 then break end
		end
		local dir=(targetPos-pos).Unit; pos += dir*s*dt; p.CFrame=CFrame.lookAt(pos,pos+dir)

		for _,e in ipairs(C.getEnemies(zid)) do
			local pp=e.PrimaryPart; local hum=e:FindFirstChildOfClass("Humanoid")
			if pp and hum and hum.Health>0 and (pp.Position-pos).Magnitude<=2.5 then
				hum:TakeDamage(dmg); FCT.ShowDamage(e,dmg,M.id)
			end
		end
	end
	if p.Parent then p:Destroy() end
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up=plr:FindFirstChild("Upgrades"); local lvl=up and up[M.levelKey] and up[M.levelKey].Value or 0
			if lvl>0 and not C.offensivePaused(plr) then
				local n=countFor(lvl); local dist=range()
				local targs=pickTargets(plr, math.ceil(lvl/2), dist)
				for i=1,n do
					local pick = targs[((i-1)%math.max(1,#targs))+1]
					task.spawn(flyOne, plr, pick and pick.pp or nil, damageFor(), dist)
				end
				C.waitScaled(plr, Ab.Boomerang.interval or 1.0) -- ?
			else task.wait(0.3) end
		end
	end)
end
return M

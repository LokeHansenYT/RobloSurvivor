-- ServerScriptService/Abilities/Axe.lua
-- Økse: skyder frem og buer rundt bag spilleren. Ulige levels: +1 skade; lige levels: +1 projektil/radius.
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local C = require(script.Parent._core.AbilityCommon)
local Ab = C.Ab
local FCT = C.FCT

local M = { id = (Ab.Axe and Ab.Axe.id) or "WEAPON_AXE", levelKey = "AxeLevel" }

local function countForLevel(lvl)
	return 1 + math.floor(lvl / 2)
end

-- Skade: +1 på ULIGE levels (1,3,5,...) = ceil(lvl/2)
local function damageForLevel(lvl)
	local base = (Ab.Axe and Ab.Axe.damageBase) or 1
	local bonus = math.floor((lvl + 1) / 2)
	return base + bonus
end

local function radiusForLevel(lvl)
	local baseR = (Ab.Axe and Ab.Axe.baseRadius) or 12
	local addR = 0.6 * math.floor(lvl / 2)
	return baseR + addR
end

local function runOne(plr, side, lvl)
	local ch = plr.Character
	if not ch then return end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local dmg = damageForLevel(lvl)
	local R = radiusForLevel(lvl)

	local pos = hrp.Position + Vector3.new(0, 0.5, 0)
	local look = hrp.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude > 0 then
		dir = dir.Unit
	else
		dir = Vector3.new(0, 0, -1)
	end

	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 180, 90)
	p.Size = Vector3.new(0.4, 0.4, 3.2)
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	Debris:AddItem(p, 2.5)

	local arcT = 0
	local arcDur = 1.2
	local spd = (Ab.Axe and Ab.Axe.speed) or 22
	local sgn = (side == "right") and 1 or -1

	local hitCd = {}
	local zid = plr:GetAttribute("ZoneId")

	while arcT < arcDur do
		local dt = RunService.Heartbeat:Wait()
		local f = arcT / arcDur
		if f > 1 then f = 1 end

		-- frem ? bue bagud i halv-cirkel
		local ahead = dir * R * math.sin(math.pi * f)
		local lateral = hrp.CFrame.RightVector * sgn * R * math.sin(math.pi * f)
		local back = -dir * R * math.max(0, (f - 0.5) * 2)
		local target = hrp.Position + ahead + lateral + back

		local step = spd * dt / R
		if step < 0 then step = 0 end
		if step > 1 then step = 1 end
		pos = pos:Lerp(target, step)
		p.CFrame = CFrame.lookAt(pos, pos + dir)

		-- hit
		local enemies = C.getEnemies(zid)
		for _, e in ipairs(enemies) do
			local pp = e.PrimaryPart
			local hum = e:FindFirstChildOfClass("Humanoid")
			if pp and hum and hum.Health > 0 then
				local d = (pp.Position - pos).Magnitude
				if d <= 3.0 then
					local now = os.clock()
					local last = hitCd[e]
					if (not last) or (now - last) > 0.25 then
						hitCd[e] = now
						hum:TakeDamage(dmg)
						FCT.ShowDamage(e, dmg, M.id)
					end
				end
			end
		end

		arcT = arcT + dt
	end

	if p.Parent then p:Destroy() end
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up = plr:FindFirstChild("Upgrades")
			local iv = up and up:FindFirstChild(M.levelKey)
			local lvl = iv and iv.Value or 0

			if lvl > 0 and not C.offensivePaused(plr) then
				local n = countForLevel(lvl)
				for i = 1, n do
					local side = ((i % 2) == 0) and "right" or "left"
					task.spawn(runOne, plr, side, lvl)
				end
				local waitTime = 0.9
				if Ab.Axe and Ab.Axe.interval then waitTime = Ab.Axe.interval end
				C.waitScaled(plr, waitTime) -- shrine haste
			else
				task.wait(0.3)
			end
		end
	end)
end

return M

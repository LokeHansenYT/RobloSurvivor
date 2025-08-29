-- ReplicatedStorage/Shared/ProjectileCore.lua
-- Fælles hjælpe-modul til lineære projektiler:
--  • Samme fod-højde som Spinner/Plus/Cross (låst Y pr. frame)
--  • Konfiguration: speed, range, lifetime, størrelse, farve, pierce, hit-radius, homing mm.
--  • Skader kun fjender i spillerens ZoneId (hvis sat)
--  • Ingen hard wait på AbilityCommon (robust auto-resolver); virker også uden AbilityCommon.

local RunService          = game:GetService("RunService")
local Debris              = game:GetService("Debris")
local Workspace           = game:GetService("Workspace")
local CollectionService   = game:GetService("CollectionService")
local RS                  = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- === Robust optional require af AbilityCommon (uanset placering) ===
local function tryRequire(inst)
	if not inst then return nil end
	local ok, mod = pcall(require, inst)
	if ok then return mod end
	return nil
end

local function resolveAbilityCommon()
	-- 1) Prøv ReplicatedStorage/Shared/AbilityCommon.lua (hvis du engang flytter den dertil)
	local shared = RS:FindFirstChild("Shared")
	if shared then
		local m = tryRequire(shared:FindFirstChild("AbilityCommon"))
		if m then return m end
	end
	-- 2) Prøv ServerScriptService/Abilities/_core/AbilityCommon.lua (din nuværende placering)
	local abilities = ServerScriptService:FindFirstChild("Abilities")
	local core      = abilities and abilities:FindFirstChild("_core")
	local ac        = core and core:FindFirstChild("AbilityCommon")
	local m         = tryRequire(ac)
	return m -- kan være nil; modulet håndterer fallback
end

local Common = resolveAbilityCommon()

local M = {}

local function getProjectilesFolder()
	local f = Workspace:FindFirstChild("ProjectilesFolder")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ProjectilesFolder"
		f.Parent = Workspace
	end
	return f
end

-- Samme Y-højde som dine tidligere projektiler (Spinner/Plus/Cross): “fodhøjde”
local function footY(plr)
	local ch  = plr and plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hrp and hum then
		return hrp.Position.Y - (hum.HipHeight or 2) + 0.5
	end
	return (hrp and (hrp.Position.Y - 1.5)) or 0
end

local function getEnemiesInZone(zoneId)
	if Common and Common.getEnemies then
		return Common.getEnemies(zoneId)
	end
	-- Fallback: scan efter modeller tagget "Enemy"
	local out = {}
	for _,inst in ipairs(CollectionService:GetTagged("Enemy")) do
		if inst:IsA("Model") then table.insert(out, inst) end
	end
	return out
end

local function unitOrZero(v)
	return (v.Magnitude > 1e-6) and v.Unit or Vector3.new(0,0,0)
end

-- === Offentlig API: spawn et lineært projektil ===
-- dir skal være normaliseret (vi normaliserer dog defensivt)
function M.spawnLinear(plr, hrp, dir, opts)
	opts = opts or {}
	dir  = unitOrZero(dir)

	local folder   = getProjectilesFolder()
	local color    = opts.color or Color3.fromRGB(235,235,255)
	local material = opts.material or Enum.Material.Neon
	local size     = opts.size or Vector3.new(0.25, 0.25, 1.8)
	local speed    = opts.speed or 60
	private = nil
	local range    = opts.range or 24
	local life     = opts.life or (range / speed + 0.25)
	local hitR     = opts.hitRadius or 2.0
	local damage   = opts.damage or 1
	local fctId    = opts.fctId
	local pierce   = opts.pierce or 0 -- 0 = stopper på første
	local hitCooldown = opts.hitCooldown or 0.08
	local yMode    = opts.yMode or "foot"  -- "foot" | "fixed"
	local yOffset  = opts.yOffset or 0.0
	local homing   = opts.homingStrength or 0
	local seekR    = opts.seekRange or 0

	local baseY
	if yMode == "foot" then
		baseY = footY(plr) + yOffset
	else
		local hrpY = hrp.Position.Y
		baseY = hrpY + yOffset
	end

	local pos = Vector3.new(hrp.Position.X, baseY, hrp.Position.Z)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Material = material; p.Color = color; p.Size = size
	p.CFrame = CFrame.new(pos, pos + dir)
	p.Parent = folder
	Debris:AddItem(p, life + 0.5)

	local zid = plr and plr:GetAttribute("ZoneId")
	local traveled, hitCount = 0, 0
	local lastHitAt = {}  -- enemyModel -> os.clock()

	local function scaledDamage()
		if Common and Common.scaleProjectileDamage then
			return Common.scaleProjectileDamage(plr, damage)
		end
		return damage
	end

	local function showDamage(eModel, amt)
		if Common and Common.FCT and Common.FCT.ShowDamage then
			Common.FCT.ShowDamage(eModel, amt, fctId or "MAIN")
		end
	end

	task.spawn(function()
		local t0 = os.clock()
		while p.Parent do
			local dt = RunService.Heartbeat:Wait()
			if os.clock() - t0 > life then break end

			-- homing mod nærmeste mål (valgfrit)
			if homing > 0 and seekR > 0 then
				local nearest, nd, npp
				for _,e in ipairs(getEnemiesInZone(zid)) do
					local pp = e.PrimaryPart
					local hum = e:FindFirstChildOfClass("Humanoid")
					if pp and hum and hum.Health > 0 then
						local d = (pp.Position - pos).Magnitude
						if d <= seekR and (not nearest or d < nd) then
							nearest, nd, npp = e, d, pp
						end
					end
				end
				if npp then
					local want = unitOrZero((npp.Position - pos))
					dir = unitOrZero(dir:Lerp(want, math.clamp(homing * dt, 0, 1)))
				end
			end

			-- Flyt frem og lås Y
			pos = pos + dir * (speed * dt)
			pos = Vector3.new(pos.X, baseY, pos.Z)
			traveled += speed * dt
			p.CFrame = CFrame.new(pos, pos + dir)

			-- Hit detect
			for _, e in ipairs(getEnemiesInZone(zid)) do
				local pp  = e.PrimaryPart
				local hum = e:FindFirstChildOfClass("Humanoid")
				if pp and hum and hum.Health > 0 then
					if (pp.Position - pos).Magnitude <= hitR then
						local last = lastHitAt[e]
						if not last or (os.clock() - last) >= hitCooldown then
							lastHitAt[e] = os.clock()
							local final = scaledDamage()
							hum:TakeDamage(final)
							showDamage(e, final)
							if opts.onHit then
								pcall(opts.onHit, e, hum, p)
							end
							if pierce <= 0 then
								p:Destroy()
								return
							else
								pierce -= 1
								hitCount += 1
							end
						end
					end
				end
			end

			if traveled >= range then break end
		end

		if p.Parent then p:Destroy() end
	end)

	return p
end

return M

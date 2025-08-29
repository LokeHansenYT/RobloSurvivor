-- ServerScriptService/Abilities/Spinner.lua
-- Snurretop: bevæger sig i skiftende retninger, roterer visuelt. Kadence (spawn-frekvens) skaleres.
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local C = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab, FCT = C.Ab, C.FCT
local M = { id = Ab.Spinner.id, levelKey = "SpinnerLevel" }

local DIRS = {
	Vector3.new( 1,0, 0), Vector3.new(-1,0, 0), Vector3.new( 0,0, 1), Vector3.new( 0,0,-1),
	Vector3.new( 1,0, 1).Unit, Vector3.new(-1,0, 1).Unit, Vector3.new( 1,0,-1).Unit, Vector3.new(-1,0,-1).Unit,
}

local function footY(plr)
	local ch  = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hrp and hum then return hrp.Position.Y - (hum.HipHeight or 2) + 0.5 end
	return hrp and (hrp.Position.Y - 1.5) or 0
end

local function dmgFor(lvl)   return (Ab.Spinner.damageBase or 1) + ((lvl % 2 == 1) and 1 or 0) end
local function countFor(lvl) return 1 + math.floor(lvl/2) end
local function lifeFor(lvl)  return (Ab.Spinner.lifeBase or 9) + math.floor(lvl/3) end
local function maxRange()    local heal = Ab.HealAura and Ab.HealAura.radius or 12; return 3 * heal end

local function runOne(plr, lvl)
	local ch  = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local folder = workspace:FindFirstChild("ProjectilesFolder") or Instance.new("Folder", workspace)
	folder.Name = "ProjectilesFolder"

	local baseY = footY(plr)
	local pos   = Vector3.new(hrp.Position.X, baseY, hrp.Position.Z)

	local hb  = Instance.new("Part")
	hb.Anchored, hb.CanQuery, hb.CanTouch, hb.CanCollide = true, false, false, false
	hb.Size, hb.Transparency = Vector3.new(1.8,1.8,1.8), 1
	hb.CFrame = CFrame.new(pos)
	hb.Parent = folder

	local vis = Instance.new("Part")
	vis.Anchored, vis.CanCollide, vis.Material = true, false, Enum.Material.Neon
	vis.Color, vis.Shape, vis.Size = Color3.fromRGB(190,120,255), Enum.PartType.Ball, Vector3.new(1.2,1.2,1.2)
	vis.CFrame = hb.CFrame
	vis.Parent = folder

	local a0 = Instance.new("Attachment", vis)
	local a1 = Instance.new("Attachment", vis)
	a0.Position = Vector3.new(0,0,-0.6)
	a1.Position = Vector3.new(0,0, 0.6)
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1, tr.Lifetime, tr.LightEmission = a0, a1, 0.2, 1
	tr.Parent = vis

	Debris:AddItem(hb,  lifeFor(lvl)+1)
	Debris:AddItem(vis, lifeFor(lvl)+1)

	local dmg     = dmgFor(lvl)
	local speed   = Ab.Spinner.speed or 18
	local lifespan= lifeFor(lvl)
	local zid     = plr:GetAttribute("ZoneId")
	local lastHit = {}

	local dir      = DIRS[math.random(1, #DIRS)]
	local nextTurn = os.clock() + 3
	local t0       = os.clock()

	local spinRate = 8  -- rad/s
	local angle    = 0

	while (os.clock() - t0) < lifespan do
		if not plr.Parent then break end
		local root = ch:FindFirstChild("HumanoidRootPart")
		if not root then break end

		local rootXZ = Vector3.new(root.Position.X, baseY, root.Position.Z)
		if (pos - rootXZ).Magnitude > maxRange() then break end

		if os.clock() >= nextTurn then
			dir = DIRS[math.random(1, #DIRS)]
			nextTurn = os.clock() + 3
		end

		local dt = RunService.Heartbeat:Wait()
		pos = pos + Vector3.new(dir.X, 0, dir.Z) * (speed * dt)
		pos = Vector3.new(pos.X, baseY, pos.Z)

		hb.CFrame = CFrame.new(pos)
		angle = angle + spinRate * dt
		vis.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0)

		for _, enemy in ipairs(C.getEnemies(zid)) do
			local pp = enemy.PrimaryPart
			if pp and (pp.Position - pos).Magnitude <= 2.4 then
				local hum = enemy:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					local now = os.clock()
					if not lastHit[hum] or (now - lastHit[hum]) > 0.3 then
						lastHit[hum] = now
						hum:TakeDamage(dmg)
						FCT.ShowDamage(enemy, dmg, M.id)
					end
				end
			end
		end
	end

	hb:Destroy()
	vis:Destroy()
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up  = plr:FindFirstChild("Upgrades")
			local lvl = up and up:FindFirstChild(M.levelKey) and up[M.levelKey].Value or 0
			if lvl > 0 and not C.offensivePaused(plr) then
				for i = 1, countFor(lvl) do task.spawn(runOne, plr, lvl) end
				C.waitScaled(plr, Ab.Spinner.interval or 0.9) -- ? shrine-haste
			else
				task.wait(0.3)
			end
		end
	end)
end

return M

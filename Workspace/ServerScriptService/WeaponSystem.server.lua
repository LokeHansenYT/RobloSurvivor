-- ServerScriptService/WeaponSystem.server.lua (zone-aware hitscan, no goto)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local WeaponConfig = require(game.ReplicatedStorage.Shared.WeaponConfig)
Workspace:SetAttribute("UseSpriteFX", true)

workspace:SetAttribute("VoidTwirlsId", "rbxassetid://113636793791160")
workspace:SetAttribute("SoulPitId",   "rbxassetid://85273692215295")
workspace:SetAttribute("SiphonId",    "rbxassetid://102691592186866")

-- Sænk alle ground-evner 2 cm:
-- workspace:SetAttribute("GroundFX_YOffset", -0.02)
workspace:SetAttribute("GroundFX_YOffset", -0.9)

-- Hæv en smule:
-- workspace:SetAttribute("GroundFX_YOffset", 0.03)

-- === Utils ===

local function offensivePaused(plr)
	-- Slå hele angrebssystemet fra, hvis spilleren ikke må kæmpe
	if plr:GetAttribute("CombatEnabled") ~= true then
		return true
	end
	-- (de her to kan du beholde, hvis du stadig bruger dem)
	local inv  = plr:FindFirstChild("Invulnerable") and plr.Invulnerable.Value or false
	local menu = plr:FindFirstChild("LevelUpMenuOpen") and plr.LevelUpMenuOpen.Value or false
	return inv or menu
end


-- Fjender i en bestemt zone (zid kan være nil = alle)
local function getEnemiesInZone(zid)
	local out = {}
	for _,m in ipairs(CollectionService:GetTagged("Enemy")) do
		if m.Parent and m:IsA("Model") and m.PrimaryPart then
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local pp = m.PrimaryPart
				if zid == nil or (pp:GetAttribute("ZoneId") == zid) then
					table.insert(out, m)
				end
			end
		end
	end
	return out
end

local function nearestEnemyFrom(pos, range, zid)
	local best, bestD = nil, range or math.huge
	for _, e in ipairs(getEnemiesInZone(zid)) do
		local pp = e.PrimaryPart
		if pp then
			local d = (pp.Position - pos).Magnitude
			if d < bestD then best, bestD = e, d end
		end
	end
	return best, bestD
end

-- kosmetisk tracer
local function drawTracer(a, b)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 240, 80)
	p.Size = Vector3.new(0.15, 0.15, (b - a).Magnitude)
	p.CFrame = CFrame.new(a, b) * CFrame.new(0, 0, -p.Size.Z/2)
	p.Parent = workspace
	game:GetService("Debris"):AddItem(p, 0.06)
end

-- Ét hitscan-skud mod en mål-model, men **kun** hvis zone matcher
local function fireHitscanShot(muzzlePos, targetModel, damage, zid)
	if not (targetModel and targetModel.PrimaryPart) then return false end
	local pp = targetModel.PrimaryPart
	if zid ~= nil and (pp:GetAttribute("ZoneId") ~= zid) then return false end

	local aimPoint = pp.Position
	drawTracer(muzzlePos, aimPoint)

	local dir = aimPoint - muzzlePos
	if dir.Magnitude < 1e-4 then return false end

	-- Raycast der ignorerer spiller-karakterer
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(ignore, pl.Character) end
	end
	rp.FilterDescendantsInstances = ignore

	local res = Workspace:Raycast(muzzlePos, dir, rp)
	if res then
		local model = res.Instance:FindFirstAncestorOfClass("Model")
		if model and model.Name == "Enemy" then
			local pp2 = model.PrimaryPart
			if pp2 and (zid == nil or pp2:GetAttribute("ZoneId") == zid) then
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then hum:TakeDamage(damage) return true end
			end
		end
		return false
	else
		-- Intet blokerede ? giv skade på det tiltænkte mål hvis det stadig er gyldigt
		local hum = targetModel:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then hum:TakeDamage(damage) return true end
		return false
	end
end

-- === Auto-våben pr. spiller ===
local function autoWeaponLoop(plr)
	while plr and plr.Parent do
		if offensivePaused(plr) then
			task.wait(0.2)
		else
			local ch   = plr.Character
			local hum  = ch and ch:FindFirstChildOfClass("Humanoid")
			local root = ch and ch:FindFirstChild("HumanoidRootPart")

			if hum and hum.Health > 0 and root then
				local lvl = (plr:FindFirstChild("leaderstats") and plr.leaderstats.Level.Value) or 1

				-- Upgrades (FireRateMult og evt. DamageMult)
				local up         = plr:FindFirstChild("Upgrades")
				local fireMult   = (up and up:FindFirstChild("FireRateMult")) and up.FireRateMult.Value or 1.0
				local damageMult = (up and up:FindFirstChild("DamageMult"))   and up.DamageMult.Value   or 1.0

				-- grundværdier
				local damage   = (WeaponConfig.BaseDamage + (lvl - 1) * WeaponConfig.LevelDamageBonus) * damageMult
				local fireRate = (WeaponConfig.FireRate + (lvl - 1) * WeaponConfig.LevelFireRateBonus) * fireMult

				-- zone-filtering (som du allerede gør)
				local zid    = plr:GetAttribute("ZoneId")
				local target = nearestEnemyFrom(root.Position, WeaponConfig.Range, zid)

				if target and target.PrimaryPart then
					local muzzlePos = root.Position + Vector3.new(0, 1.5, 0)
					fireHitscanShot(muzzlePos, target, damage, zid)
				end

				task.wait(1 / math.max(0.1, fireRate))
			else
				task.wait(0.2)
			end
		end
	end
end


Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		task.wait(0.5)
		autoWeaponLoop(plr)
	end)
end)

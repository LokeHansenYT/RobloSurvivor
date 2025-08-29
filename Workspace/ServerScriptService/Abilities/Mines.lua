-- ServerScriptService/Abilities/Mines.lua
-- Miner som kun skader fjender (tag "Enemy"/navn "Enemy"), ikke spilleren.
-- Returnerer table med .start(plr), så det passer til AbilityManager.
-- Bruger AbilitiesConfig for tal og AbilityCommon for fælles hjælpefunktioner.

local RS         = game:GetService("ReplicatedStorage")
local Workspace  = game:GetService("Workspace")
local Debris     = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

-- Fælles helpers (interval-skalering, floating text m.m.)
local C = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab = C.Ab

-- Konfiguration (støtter både Ab.Mine og Ab.Mines afhængigt af din config)
local DEF = Ab.Mine or Ab.Mines or {}
local LEVEL_KEY = "MinesLevel"

-- Hvor projektiler/effekter placeres
local PROJECTILES = Workspace:FindFirstChild("ProjectilesFolder") or Instance.new("Folder", Workspace)
PROJECTILES.Name = "ProjectilesFolder"
PROJECTILES.Parent = Workspace

local function isEnemyModel(model: Instance)
	if not model or not model:IsA("Model") then return false end
	if CollectionService:HasTag(model, "Enemy") then return true end
	return model.Name == "Enemy"
end

local function groundUnder(point: Vector3, ignore: {Instance}?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { PROJECTILES }
	if ignore then for _,i in ipairs(ignore) do table.insert(ex, i) end end
	params.FilterDescendantsInstances = ex
	local from = point + Vector3.new(0, 200, 0)
	local res  = Workspace:Raycast(from, Vector3.new(0, -600, 0), params)
	return res and res.Position or Vector3.new(point.X, 0, point.Z)
end

local function showPulse(pos: Vector3, r: number)
	-- lille neon-puls
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 200, 80)
	p.CanCollide = false
	p.Anchored = true
	local d = math.max(1, r * 0.6)
	p.Size = Vector3.new(d, d, d)
	p.CFrame = CFrame.new(pos)
	p.Parent = PROJECTILES
	Debris:AddItem(p, 0.2)
end

local function explodeAt(origin: Vector3, radius: number, damage: number, ownerZoneId: number?)
	showPulse(origin, radius)
	-- Brug bounding-query for at finde ofre
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(origin, radius, nil)) do
		local model = part:FindFirstAncestorOfClass("Model")
		if isEnemyModel(model) then
			local hum = model:FindFirstChildOfClass("Humanoid")
			local pp  = model.PrimaryPart
			if hum and pp and hum.Health > 0 then
				-- zone-filter for at undgå cross-zone hits
				if (ownerZoneId == nil) or ((pp:GetAttribute("ZoneId") or -1) == ownerZoneId) then
					hum:TakeDamage(math.max(1, math.floor(damage)))
					if C.FCT then C.FCT.ShowDamage(model, damage, "WEAPON_MINE") end
				end
			end
		end
	end
end

local function placeMine(ownerChar: Model, level: number, ownerZoneId: number?)
	local hrp = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Find jorden under spilleren og plant minen dér
	local ground = groundUnder(hrp.Position, { ownerChar })
	local pos = Vector3.new(ground.X, ground.Y + 0.05, ground.Z)

	local mine = Instance.new("Part")
	mine.Name = "Mine"
	mine.Size = Vector3.new(1, 0.3, 1)
	mine.Material = Enum.Material.Metal
	mine.Color = Color3.fromRGB(255, 180, 50)
	mine.Anchored = true
	mine.CanCollide = false
	mine.CFrame = CFrame.new(pos)
	mine.Parent = PROJECTILES

	-- Tal (med sikre defaults)
	local triggerRadius = (DEF.triggerRadiusBase or 6) + math.floor((level or 1) * (DEF.triggerRadiusPerLvl or 0.6))
	local explosionRad  = (DEF.explosionRadiusBase or 12) + math.floor((level or 1) * (DEF.explosionRadiusPerLvl or 1.2))
	local damage        = (DEF.baseDamage or 4) + math.max(0, (level or 1) - 1)

	-- Armer minen en anelse efter placering
	task.delay(0.12, function()
		if not mine.Parent then return end
		local armed = true
		-- Poll for fjender i nærheden
		task.spawn(function()
			while armed and mine.Parent do
				task.wait(0.1)
				for _, part in ipairs(Workspace:GetPartBoundsInRadius(mine.Position, triggerRadius, nil)) do
					local model = part:FindFirstAncestorOfClass("Model")
					if isEnemyModel(model) then
						armed = false
						local where = mine.Position
						mine:Destroy()
						explodeAt(where, explosionRad, damage, ownerZoneId)
						break
					end
				end
			end
		end)
		-- failsafe TTL
		Debris:AddItem(mine, 12)
	end)
end

local function calcInterval(plr, lvl)
	-- Brug AbilitiesConfig hvis sat – ellers fornuftige defaults
	local base  = DEF.interval or 1.4
	local grow  = DEF.intervalGrowth or 0.98
	local raw   = base * (grow ^ math.max(0, (lvl or 1) - 1))
	-- Skaler med fælles hastighedsmod (shrines, upgrades mm.)
	if C.scaleInterval then
		return C.scaleInterval(plr, raw)
	end
	return raw
end

local M = {
	id = (DEF.id or "WEAPON_MINE"),
	levelKey = LEVEL_KEY,
}

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up   = plr:FindFirstChild("Upgrades")
			local lvl  = up and up:FindFirstChild(M.levelKey) and up[M.levelKey].Value or 0
			local ch   = plr.Character
			local hrp  = ch and ch:FindFirstChild("HumanoidRootPart")

			if lvl > 0 and hrp and (not C.offensivePaused(plr)) then
				local zid = plr:GetAttribute("ZoneId")
				placeMine(ch, lvl, zid)
				task.wait(math.clamp(calcInterval(plr, lvl), 0.25, 10))
			else
				task.wait(0.3)
			end
		end
	end)
end

return M

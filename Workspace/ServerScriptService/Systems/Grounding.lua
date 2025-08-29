--[[
Grounding.lua
Formål:
  • Stabil “læg på jorden”-placering for abilities.
  • Collision: sæt BasePart.CollisionGroup = "AttackFields" (uden deprecated API).
  • Fast-Y helpers: lås plader til en valgt Y (fx spillerens "foot-Y").

Brug:
  local Grounding = require(ServerScriptService.Systems.Grounding)

  -- Collision & standard placering:
  Grounding.tagAttackField(part)
  Grounding.placePlateOriented(part, centerXZ, forward, height, lift, extraIgnore)
  Grounding.placePlateCentered(part,  centerXZ,              height, lift, extraIgnore)

  -- Fast-Y:
  local y = Grounding.footY(character)               -- ground-Y under spiller
  Grounding.placePlateOrientedAtY(part, centerXZ, forward, y, height, lift)
  Grounding.placePlateCenteredAtY(part,  centerXZ,          y, height, lift)
]]--

local PhysicsService = game:GetService("PhysicsService")
local Workspace      = game:GetService("Workspace")

local M = {}
local GROUP   = "AttackFields"
local _inited = false

-- === GLOBALT OFFSET FOR GROUND-EVNER ===
local function getGroundFxOffset()
	-- Én "knap" til at hæve/sænke ALLE ground-evner (studs)
	local v = Workspace:GetAttribute("GroundFX_YOffset")
	if typeof(v) == "number" then return v end
	return 0.01 -- standard: næsten flush med gulvet
end

-- Find base-Y én gang for en evneplacering:
--  • hvis centerXZ gives: raycast under center (ignorerer dynamik via rayToGround)
--  • ellers: brug spillerens foot-Y
function M.computeBaseY(actor: Model?, centerXZ: Vector3?, extraIgnore: {Instance}?)
	if centerXZ then
		return M.rayToGround(centerXZ, extraIgnore).Y
	end
	if actor then
		return M.footY(actor, extraIgnore)
	end
	-- fallback: 0 hvis intet givet (bør ikke ske i praksis)
	return 0
end

-- Læg plade centreret på centerXZ ved globalt styret Y (inkl. anti-z-fight og global offset)
function M.placeGroundFXCentered(part: BasePart, actor: Model?, centerXZ: Vector3, height: number?)
	local baseY = M.computeBaseY(actor, centerXZ)
	local h     = height or part.Size.Y
	local lift  = 0.005 + getGroundFxOffset()
	part.CFrame = CFrame.new(centerXZ.X, baseY + (h*0.5) + lift, centerXZ.Z)
	return part.CFrame
end

-- Som ovenfor, men med orientering (forward)
function M.placeGroundFXOriented(part: BasePart, actor: Model?, centerXZ: Vector3, forward: Vector3?, height: number?)
	local baseY = M.computeBaseY(actor, centerXZ)
	local h     = height or part.Size.Y
	local lift  = 0.005 + getGroundFxOffset()
	local pos   = Vector3.new(centerXZ.X, baseY + (h*0.5) + lift, centerXZ.Z)
	local aim   = (forward and forward.Magnitude > 0) and forward.Unit or Vector3.zAxis
	part.CFrame = CFrame.new(pos, pos + Vector3.new(aim.X, 0, aim.Z))
	return part.CFrame
end


local function ensureGroup()
	if _inited then return end
	_inited = true
	pcall(function() PhysicsService:RegisterCollisionGroup(GROUP) end)
	local function safeCG(a, b, can) pcall(function() PhysicsService:CollisionGroupSetCollidable(a, b, can) end) end
	safeCG(GROUP, "Default",           false)
	safeCG(GROUP, "Enemies",           false)
	safeCG(GROUP, "PlayerProjectiles", false)
	safeCG(GROUP, "EnemyProjectiles",  false)
end

local function buildIgnore(extraIgnore)
	local ignore = {}
	local function add(x) if x then table.insert(ignore, x) end end
	add(Workspace:FindFirstChild("ZoneEnemies"))
	add(Workspace:FindFirstChild("ProjectilesFolder"))
	add(Workspace:FindFirstChild("Vendors"))
	add(Workspace:FindFirstChild("DroppedLoot"))
	if extraIgnore then for _,v in ipairs(extraIgnore) do add(v) end end
	return ignore
end

function M.rayToGround(point: Vector3, extraIgnore: {Instance}?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = buildIgnore(extraIgnore)
	local from = point + Vector3.new(0, 120, 0)
	local hit  = Workspace:Raycast(from, Vector3.new(0, -500, 0), params)
	return hit and hit.Position or point
end

-- Ground-Y lige under spillerens HRP (ignorerer altid spillerens character)
function M.footY(character: Model, extraIgnore: {Instance}?)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	-- sørg for at character er i ignore-listen, så vi ikke rammer vores egne dele
	local list = { character }
	if extraIgnore then
		for _,v in ipairs(extraIgnore) do table.insert(list, v) end
	end
	return M.rayToGround(hrp.Position, list).Y
end


function M.tagAttackField(part: BasePart)
	ensureGroup()
	part.CollisionGroup = GROUP
	part.Massless   = true
	part.Anchored   = true
	part.CanCollide = false
	part.CanTouch   = false
	part.CanQuery   = false
end

-- Standard placering (ray ved center)
function M.placePlateOriented(part: BasePart, centerXZ: Vector3, forward: Vector3?, height: number?, lift: number?, extraIgnore: {Instance}?)
	local y   = M.rayToGround(centerXZ, extraIgnore).Y
	local h   = height or part.Size.Y
	local lft = (lift or 0) + 0.02
	local pos = Vector3.new(centerXZ.X, y + (h*0.5) + lft, centerXZ.Z)
	local aim = (forward and forward.Magnitude > 0) and forward.Unit or Vector3.zAxis
	part.CFrame = CFrame.new(pos, pos + Vector3.new(aim.X, 0, aim.Z))
	return part.CFrame
end

function M.placePlateCentered(part: BasePart, centerXZ: Vector3, height: number?, lift: number?, extraIgnore: {Instance}?)
	local y   = M.rayToGround(centerXZ, extraIgnore).Y
	local h   = height or part.Size.Y
	local lft = (lift or 0) + 0.02
	part.CFrame = CFrame.new(centerXZ.X, y + (h*0.5) + lft, centerXZ.Z)
	return part.CFrame
end

-- Fast-Y placering (låst til en valgt Y)
function M.placePlateOrientedAtY(part: BasePart, centerXZ: Vector3, forward: Vector3?, y: number, height: number?, lift: number?)
	local h   = height or part.Size.Y
	local lft = (lift or 0) + 0.02
	local pos = Vector3.new(centerXZ.X, y + (h*0.5) + lft, centerXZ.Z)
	local aim = (forward and forward.Magnitude > 0) and forward.Unit or Vector3.zAxis
	part.CFrame = CFrame.new(pos, pos + Vector3.new(aim.X, 0, aim.Z))
	return part.CFrame
end

function M.placePlateCenteredAtY(part: BasePart, centerXZ: Vector3, y: number, height: number?, lift: number?)
	local h   = height or part.Size.Y
	local lft = (lift or 0) + 0.02
	part.CFrame = CFrame.new(centerXZ.X, y + (h*0.5) + lft, centerXZ.Z)
	return part.CFrame
end

return M

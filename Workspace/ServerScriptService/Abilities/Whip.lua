-- ServerScriptService/Abilities/Whip.lua
-- Pisk: rektangulært slag FORAN spilleren i kig-retning. Kadence skaleres.
local Debris = game:GetService("Debris")
local C = require(script.Parent:WaitForChild("_core"):WaitForChild("AbilityCommon"))
local Ab, FCT = C.Ab, C.FCT
local M = { id = Ab.Whip.id, levelKey = "WhipLevel" }

local function footY(plr)
	local ch  = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hrp and hum then return hrp.Position.Y - (hum.HipHeight or 2) + 0.5 end
	return hrp and (hrp.Position.Y - 1.5) or 0
end

local function spec(lvl)
	local healR = Ab.HealAura and Ab.HealAura.radius or 12
	return {
		range    = math.max(Ab.Whip.baseRange or 12, healR),
		width    = Ab.Whip.width or 4,
		height   = 1.2,
		damage   = (Ab.Whip.damageBase or 1) + math.max(0, lvl - 1),
		interval = Ab.Whip.interval or 0.8,
	}
end

local function inBox(worldCF, halfSize, worldPos)
	local lp = worldCF:PointToObjectSpace(worldPos)
	return math.abs(lp.X) <= halfSize.X and math.abs(lp.Y) <= halfSize.Y and math.abs(lp.Z) <= halfSize.Z
end

local function castOnce(plr, lvl)
	local ch  = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local s      = spec(lvl)
	local baseY  = footY(plr)
	local look   = hrp.CFrame.LookVector
	local origin = Vector3.new(hrp.Position.X, baseY, hrp.Position.Z)

	-- CENTER FORAN spilleren (RETNING FREMAD)
	local midPos = origin + look * (s.range/2)
	local midCF  = CFrame.lookAt(midPos, midPos + look)
	local half   = Vector3.new(s.width/2, s.height/2, s.range/2)

	-- VFX (kort blink)
	do
		local beam = Instance.new("Part")
		beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch = true, false, false, false
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(180,160,255)
		beam.Transparency = 0.35
		beam.Size = Vector3.new(s.width, s.height, s.range)
		beam.CFrame = midCF
		beam.Name = "WhipBeam"
		local folder = workspace:FindFirstChild("ProjectilesFolder") or Instance.new("Folder", workspace)
		folder.Name = "ProjectilesFolder"
		beam.Parent = folder
		Debris:AddItem(beam, 0.12)
	end

	local zid = plr:GetAttribute("ZoneId")
	for _, enemy in ipairs(C.getEnemies(zid)) do
		local pp  = enemy.PrimaryPart
		local hum = enemy:FindFirstChildOfClass("Humanoid")
		if pp and hum and hum.Health > 0 then
			if inBox(midCF, half, pp.Position) then
				hum:TakeDamage(s.damage)
				FCT.ShowDamage(enemy, s.damage, M.id)
			end
		end
	end
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up  = plr:FindFirstChild("Upgrades")
			local lvl = up and up:FindFirstChild(M.levelKey) and up[M.levelKey].Value or 0
			if lvl > 0 and not C.offensivePaused(plr) then
				castOnce(plr, lvl)
				C.waitScaled(plr, spec(lvl).interval) -- ? shrine-haste
			else
				task.wait(0.3)
			end
		end
	end)
end

return M

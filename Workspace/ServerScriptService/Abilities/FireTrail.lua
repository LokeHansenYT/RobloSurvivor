-- Efterlader brændende spor. Nu med fast Y låst til spillerens "foot-Y".

local Debris    = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local C          = require(script.Parent._core.AbilityCommon)
local Grounding  = require(game.ServerScriptService.Systems.Grounding)
local SpriteFX   = require(game.ServerScriptService.Systems.SpriteFX)

local Ab, FCT = C.Ab, C.FCT
local M = { id = Ab.FireTrail.id, levelKey = "FireTrailLevel" }

local EMBERS_TEXTURE_ID_FALLBACK = 99348248956031

local function spec(lvl)
	lvl = math.max(1, tonumber(lvl) or 1)
	local segTTL   = math.min(0.8 + 0.12*(lvl-1), 1.6)
	local dropEvery= math.max(0.28 - 0.02*(lvl-1), 0.12)
	return {
		segLen   = 3.2,
		segWidth = (Ab.FireTrail.width or 4),
		segTTL   = segTTL,
		dmg      = (Ab.FireTrail.damageBase or 1) + math.max(0,lvl-1),
		dotTick  = Ab.FireTrail.dotTick or 0.5,
		dotDmg   = Ab.FireTrail.dotDamageBase or 1,
		dotDur   = math.min((Ab.FireTrail.dotDurationBase or 1.5) + (Ab.FireTrail.dotDurationPerLevel or 0.25)*(lvl-1), Ab.FireTrail.dotDurationMax or 3.0),
		dropEvery= dropEvery,
		minStep  = 1.6,
	}
end

local function startBurnTick(enemy)
	if enemy:GetAttribute("BurnTicker") then return end
	enemy:SetAttribute("BurnTicker", 1)
	task.spawn(function()
		while enemy.Parent do
			local untilT = enemy:GetAttribute("BurnUntil") or 0
			local dps    = enemy:GetAttribute("BurnDPS") or 0
			if time() >= untilT or dps <= 0 then enemy:SetAttribute("BurnTicker", nil) break end
			local hum = enemy:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum:TakeDamage(dps)
				if FCT and FCT.ShowDebuff then FCT.ShowDebuff(enemy, "BURNING") end
			end
			task.wait(1.0)
		end
	end)
end

local function burnEnemiesInBox(cf, size, dmg, dotDur)
	for _, part in ipairs(Workspace:GetPartBoundsInBox(cf, size, nil)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum:TakeDamage(dmg)
			if FCT then FCT.ShowDamage(model, dmg, M.id or "WEAPON_FIRETRAIL") end
			local untilT = time() + dotDur
			if (model:GetAttribute("BurnUntil") or 0) < untilT then model:SetAttribute("BurnUntil", untilT) end
			model:SetAttribute("BurnDPS", 1)
			if FCT and FCT.ShowDebuff then FCT.ShowDebuff(model, "BURNING") end
			startBurnTick(model)
		end
	end
end

local function dropSegment(plr, lastPos, s)
	local ch  = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return lastPos end

	local nowPos = hrp.Position
	if lastPos and (nowPos - lastPos).Magnitude < s.minStep then return lastPos end

	local yBase  = Grounding.footY(ch) or nowPos.Y
	local backDir = -hrp.CFrame.LookVector
	backDir = Vector3.new(backDir.X, 0, backDir.Z).Unit
	local centerXZ = (lastPos and lastPos or nowPos) + backDir * (s.segLen * 0.5)

	-- afgør sprites vs. neon ud fra om vi HAR et id
	local wantSprites = SpriteFX.useSprites(plr)
	local spriteId = wantSprites and SpriteFX.getTextureIdFrom("FireTrail_EmbersId", EMBERS_TEXTURE_ID_FALLBACK) or 0
	if spriteId <= 0 then wantSprites = false end

	-- Base-pladen
	local part = Instance.new("Part")
	part.Name  = "FireTrailSeg"
	part.Color = Color3.fromRGB(255, 180, 70)
	Grounding.tagAttackField(part)

	if wantSprites then
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 1
	else
		part.Material = Enum.Material.Neon
		part.Transparency = 0.45
	end

	part.Size = Vector3.new(s.segLen, 0.25, s.segWidth)
	-- NY: brug fælles placeringshelper med globalt offset
	Grounding.placeGroundFXOriented(part, ch, centerXZ, backDir, part.Size.Y)
	part.Parent = Workspace
	Debris:AddItem(part, s.segTTL)

	if wantSprites then
		SpriteFX.addFlipbookOrGui(part, {
			image = spriteId,
			frames = 8, rows = 1, fps = 10, ttl = s.segTTL,
			rate = 10 + math.floor((part.Size.X + part.Size.Z) * 0.8),
			frameSize = 32
		})
	end


	-- skade/DoT som før
	burnEnemiesInBox(part.CFrame, part.Size, s.dmg, s.dotDur)
	return nowPos
end


function M.start(plr)
	task.spawn(function()
		local lastPos = nil
		while plr.Parent do
			local up = plr:FindFirstChild("Upgrades")
			local lvl = up and up[M.levelKey] and up[M.levelKey].Value or 0
			if lvl > 0 and not C.offensivePaused(plr) then
				local s = spec(lvl)
				lastPos = dropSegment(plr, lastPos, s)
				C.waitScaled(plr, s.dropEvery)
			else
				lastPos = nil
				task.wait(0.35)
			end
		end
	end)
end

return M

-- ServerScriptService/Abilities/ChargedGround.lua
-- Charged Ground with fixed foot-Y placement, sprites fallback, and reliable AABB damage.

local Debris    = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local C          = require(script.Parent._core.AbilityCommon)
local Grounding  = require(game.ServerScriptService.Systems.Grounding)
local SpriteFX   = require(game.ServerScriptService.Systems.SpriteFX)

local Ab  = C.Ab
local FCT = C.FCT

local M = {
	id = (Ab.ChargedGround and Ab.ChargedGround.id) or "WEAPON_CGROUND",
	levelKey = "ChargedGroundLevel"
}
local DEBUG = (Ab.ChargedGround and Ab.ChargedGround.debug) == true

-- Fallback texture id (your existing one). You can override via
-- Workspace.ChargedGround_LightningId / ChargedGround_SparklesId
local CHARGED_TEXTURE_FALLBACK = 122817115689044

local function spec(lvl)
	local base = Ab.ChargedGround or {}
	local healR = (Ab.HealAura and Ab.HealAura.radius) or 12
	local baseSide = 8
	if base.size then
		baseSide = math.max(base.size.X, base.size.Z)
	else
		baseSide = math.max(baseSide, math.floor(healR * 1.25))
	end
	return {
		intervalPerStep = base.intervalPerStep or 1.0,
		damage          = (base.damageBase or 1) + math.floor(math.max(0, lvl - 1) / 3),
		stunMin         = 1,
		stunMax         = 3,
		splitChance     = 0.05 * math.max(0, lvl),
		maxMoves        = 10,
		baseMoves       = 3,
		maxSplits       = 5,

		side    = (baseSide * 0.5),
		height  = 0.25,   -- var 0.50 ? tyndere, visuelt tættere på jord
		yLift   = 0.00,   -- fjern ekstra løft; vi bruger kun en lille fixed lift i placerings-helper
		yHitPad = 1.25,   -- lidt lavere pad nok til at ramme fødder

		alpha   = 0.65,
		color   = Color3.fromRGB(255, 230, 120),

		stepFrac = 0.80,
		sampleDt = 0.08,
	}
end


local DIRS = {
	Vector3.new( 1,0, 0), Vector3.new(-1,0, 0),
	Vector3.new( 0,0, 1), Vector3.new( 0,0,-1),
	Vector3.new( 1,0, 1).Unit, Vector3.new(-1,0, 1).Unit,
	Vector3.new( 1,0,-1).Unit, Vector3.new(-1,0,-1).Unit,
}

local function diagonalStart(hrp, side)
	local cf = hrp.CFrame
	local f  = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z); if f.Magnitude > 0 then f = f.Unit else f = Vector3.new(0,0,-1) end
	local r  = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z); if r.Magnitude > 0 then r = r.Unit else r = Vector3.new(1,0,0) end
	local sign = (math.random() < 0.5) and 1 or -1
	local pos  = hrp.Position + f * side + r * side * sign
	return Vector3.new(pos.X, hrp.Position.Y, pos.Z)
end

local function pulseOnce(plr, centerXZ, s)
	-- Lås Y til GULVET under selve feltets center (ignorer player + mobs)
	local ch = plr.Character
	local groundPos = Grounding.rayToGround(centerXZ, { ch })  -- Grounding ignorerer ZoneEnemies m.m.
	local yBase = (groundPos and groundPos.Y) or centerXZ.Y

	-- Sprites vs. neon (failsafe: neon hvis intet gyldigt sheet-id)
	local wantSprites = SpriteFX.useSprites(plr)
	local spriteId = wantSprites and SpriteFX.getTextureIdFrom(
		{"ChargedGround_LightningId","ChargedGround_SparklesId"},
		CHARGED_TEXTURE_FALLBACK
	) or 0
	if spriteId <= 0 then wantSprites = false end

	-- Base-plade
	local p = Instance.new("Part")
	p.Name = "ChargedGroundQuad"
	if wantSprites then
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 1
	else
		p.Material = Enum.Material.Neon
		p.Color = s.color
		p.Transparency = s.alpha
	end
	p.Size = Vector3.new(s.side, s.height, s.side)
	Grounding.tagAttackField(p)

	-- NY: globalt styret højde via fælles helper
	Grounding.placeGroundFXCentered(p, ch, centerXZ, p.Size.Y)

	p.Parent = workspace
	Debris:AddItem(p, s.intervalPerStep + 0.05)

	if wantSprites then
		SpriteFX.addFlipbookOrGui(p, spriteId, {
			frames=8, rows=1, fps=12, ttl=s.intervalPerStep + 0.05, frameSize=32
		})
	end

	-- Enemy-only AABB (ignorer plade + spiller)
	local hitOnce   = {}
	local deadline  = os.clock() + s.intervalPerStep
	local params    = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { p, ch }

	local enemiesRoot = workspace:FindFirstChild("ZoneEnemies")

	while os.clock() < deadline do
		for _, part in ipairs(workspace:GetPartBoundsInBox(p.CFrame, p.Size, params)) do
			local model = part:FindFirstAncestorOfClass("Model")
			if model and model ~= ch and (not enemiesRoot or model:IsDescendantOf(enemiesRoot)) and not hitOnce[model] then
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hitOnce[model] = true
					hum:TakeDamage(s.damage)
					FCT.ShowDamage(model, s.damage, M.id)
					C.applyElecStun(hum, math.random(s.stunMin, s.stunMax))
				end
			end
		end
		task.wait(s.sampleDt)
	end
end



local function walk(plr, startPos, s, movesLeft, splitsLeft)
	if movesLeft <= 0 then return end
	if DEBUG then
		print(string.format("[CG] pulse at (%.1f,%.1f,%.1f)", startPos.X, startPos.Y, startPos.Z))
	end

	pulseOnce(plr, startPos, s)
	task.wait(s.intervalPerStep)

	local dir  = DIRS[math.random(1, #DIRS)]
	local step = Vector3.new(s.side * s.stepFrac * dir.X, 0, s.side * s.stepFrac * dir.Z)
	local nextPos = startPos + step

	if splitsLeft > 0 and math.random() < s.splitChance then
		task.spawn(walk, plr, nextPos, s, math.min(movesLeft - 1, s.maxMoves), splitsLeft - 1)
	end
	walk(plr, nextPos, s, math.min(movesLeft - 1, s.maxMoves), splitsLeft)
end

function M.start(plr)
	task.spawn(function()
		while plr.Parent do
			local up  = plr:FindFirstChild("Upgrades")
			local iv  = up and up:FindFirstChild(M.levelKey)
			local lvl = iv and iv.Value or 0
			if lvl > 0 and not C.offensivePaused(plr) then
				local ch  = plr.Character
				local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp then
					local s     = spec(lvl)
					local start = diagonalStart(hrp, s.side)
					task.spawn(walk, plr, start, s, s.baseMoves, s.maxSplits)
					C.waitScaled(plr, Ab.ChargedGround and Ab.ChargedGround.interval or 1.0)
				else
					task.wait(0.2)
				end
			else
				task.wait(0.4)
			end
		end
	end)
end

return M

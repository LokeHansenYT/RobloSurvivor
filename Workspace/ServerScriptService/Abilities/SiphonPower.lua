-- Abilities/SiphonPower.lua
-- Ground VOID: kills i feltet ? +1 flat dmg buff (stacker op til level) i feltets resterende tid; kill udvider + nulstiller tid.
local Common    = require(script.Parent._core.AbilityCommon)
local Ab        = require(game.ReplicatedStorage.Shared.AbilitiesConfig)
local Grounding = require(game.ServerScriptService.Systems.Grounding)
local SpriteFX  = require(game.ServerScriptService.Systems.SpriteFX)
local FieldCore = require(game.ServerScriptService.Systems.FieldCore)

local M = {}

local BASE_TTL           = 4
local MIN_DIST, MAX_DIST = 6, 30
local BASE_SIZE          = Vector3.new(14, 0.2, 14)
local BUFF_KEY           = "Siphon"
local BUFF_RADIUS        = 28

local function levelGains(level)
	local extraDur, extraFlat, extraScale = 0,0,0
	for i=1, math.max(0, level-1) do
		local r = (i % 3)
		if r==1 then extraDur += 1
		elseif r==2 then extraFlat += 1
		else extraScale += 0.10 end
	end
	return extraDur, extraFlat, extraScale
end

local function pickForwardCF(player, minDist, maxDist)
	local ch  = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return CFrame.new() end
	local look = hrp.CFrame.LookVector; look = Vector3.new(look.X, 0, look.Z).Unit
	local right = hrp.CFrame.RightVector; right = Vector3.new(right.X, 0, right.Z).Unit
	local dist = math.random() * (maxDist-minDist) + minDist
	local lateral = (math.random() < 0.5 and -1 or 1) * math.random() * (dist*0.6)
	local pos = hrp.Position + look*dist + right*lateral
	return CFrame.new(pos, pos + look)
end

function M.run(player, level, C)
	level = math.max(1, level or 1)
	local extraDur, extraFlat, extraScale = levelGains(level)
	local ttl      = BASE_TTL + 1 + extraDur
	local addFlat  = 1 + extraFlat
	local maxStacks= level

	local castCf = pickForwardCF(player, MIN_DIST, MAX_DIST)
	local center = castCf.Position
	local ch  = player.Character

	local p = Instance.new("Part")
	p.Name = "SiphonPower"
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.Size = BASE_SIZE
	Grounding.tagAttackField(p)
	Grounding.placeGroundFXCentered(p, ch, center, p.Size.Y)
	p.Parent = workspace

	SpriteFX.addFlipbookOrGui(p, {
		image = SpriteFX.Assets and (SpriteFX.Assets.Siphon or SpriteFX.Assets.Embers) or nil,
		frames = 64, rows = 8, fps = 16, ttl = ttl + 0.05, frameSize = 32
	})

	local function giveBuff(plr)
		Common.giveFlatDamageBuff(plr, BUFF_KEY, addFlat, ttl, maxStacks)
	end

	local field = FieldCore.new(p, {
		baseSize        = Vector3.new(BASE_SIZE.X, 0, BASE_SIZE.Z),
		ttl             = ttl,
		maxScale        = 2.0 * (1 + extraScale),
		expandPctOnKill = 0.10,
		onEnemyDied     = function(model, hum)
			for _,plr in ipairs(game.Players:GetPlayers()) do
				local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - p.Position).Magnitude <= BUFF_RADIUS then
					giveBuff(plr)
				end
			end
		end,
		onExpired       = function() p:Destroy() end,
	})
	field:start()
end

function M.start(player)
	local up = player:WaitForChild("Upgrades"):WaitForChild(Ab.SiphonPower.levelKey)
	while player.Parent do
		local lvl = up.Value
		if lvl > 0 and not Common.offensivePaused(player) then
			M.run(player, lvl, Common)
		end
		Common.waitScaled(player, 3.2)
	end
end

return M

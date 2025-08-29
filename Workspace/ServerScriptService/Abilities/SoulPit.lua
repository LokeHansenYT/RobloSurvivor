-- Abilities/SoulPit.lua
-- Ground VOID: fjende der tager skade i feltet ? heal nærliggende spillere; kill i feltet udvider + nulstiller tid.
local Common    = require(script.Parent._core.AbilityCommon)
local Ab        = require(game.ReplicatedStorage.Shared.AbilitiesConfig)
local Grounding = require(game.ServerScriptService.Systems.Grounding)
local SpriteFX  = require(game.ServerScriptService.Systems.SpriteFX)
local FieldCore = require(game.ServerScriptService.Systems.FieldCore)

local M = {}

local BASE_TTL           = 4
local MIN_DIST, MAX_DIST = 6, 24
local BASE_SIZE          = Vector3.new(14, 0.2, 14)
local HEAL_PER_HIT       = 1
local HEAL_RADIUS        = 28

local function levelGains(level)
	local extraDur, extraHeal, extraScale = 0,0,0
	for i=1, math.max(0, level-1) do
		local r = (i % 3)
		if r==1 then extraDur += 1
		elseif r==2 then extraHeal += 1
		else extraScale += 0.10 end
	end
	return extraDur, extraHeal, extraScale
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
	local extraDur, extraHeal, extraScale = levelGains(level)
	local ttl  = BASE_TTL + 1 + extraDur
	local heal = HEAL_PER_HIT + extraHeal

	local castCf = pickForwardCF(player, MIN_DIST, MAX_DIST)
	local center = castCf.Position
	local ch  = player.Character

	local p = Instance.new("Part")
	p.Name = "SoulPit"
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.Size = BASE_SIZE
	Grounding.tagAttackField(p)
	Grounding.placeGroundFXCentered(p, ch, center, p.Size.Y)
	p.Parent = workspace

	SpriteFX.addFlipbookOrGui(p, {
		image = SpriteFX.Assets and (SpriteFX.Assets.SoulPit or SpriteFX.Assets.Embers) or nil,
		frames = 64, rows = 8, fps = 16, ttl = ttl + 0.05, frameSize = 32
	})

	-- Track fjende-skade mens de står i feltet ? heal spillere i nærheden
	local watchers = {}
	local function ensureWatcher(model, hum)
		if watchers[model] then return end
		local last = hum.Health
		watchers[model] = hum:GetPropertyChangedSignal("Health"):Connect(function()
			if hum.Health < last then
				for _,plr in ipairs(game.Players:GetPlayers()) do
					local char = plr.Character
					local h = char and char:FindFirstChildOfClass("Humanoid")
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if h and root and (root.Position - p.Position).Magnitude <= HEAL_RADIUS then
						h.Health = math.min(h.MaxHealth, h.Health + heal)
						if Common.showFloatingText then
							Common.showFloatingText(root.Position, "+"..tostring(heal).." heal", Color3.fromRGB(180,30,30))
						end
					end
				end
			end
			last = hum.Health
		end)
	end
	local function clearWatcher(model)
		local c = watchers[model]
		if c then c:Disconnect() end
		watchers[model] = nil
	end

	local field = FieldCore.new(p, {
		baseSize        = Vector3.new(BASE_SIZE.X, 0, BASE_SIZE.Z),
		ttl             = ttl,
		maxScale        = 2.0 * (1 + extraScale),
		expandPctOnKill = 0.10,
		onEnemyTick     = function(model, hum) ensureWatcher(model, hum) end,
		onExpired       = function()
			for m,_ in pairs(watchers) do clearWatcher(m) end
			p:Destroy()
		end,
	})
	field:start()
end

function M.start(player)
	local up = player:WaitForChild("Upgrades"):WaitForChild(Ab.SoulPit.levelKey)
	while player.Parent do
		local lvl = up.Value
		if lvl > 0 and not Common.offensivePaused(player) then
			M.run(player, lvl, Common)
		end
		Common.waitScaled(player, 3.0)
	end
end

return M

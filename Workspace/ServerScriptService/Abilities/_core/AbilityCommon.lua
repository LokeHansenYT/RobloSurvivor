-- ServerScriptService/Abilities/_core/AbilityCommon.lua
-- Fælles helpers til abilities (damage-typer, FCT, ground-raycasts, shrine-haste m.m.)
-- Opdateret:
--   • scaleInterval / waitScaled (shrines påvirker kadencer globalt)
--   • applyElecStun: respekterer Boss/fusion-resist OG Horde-resist (chance + evt. afkortning)
--   • dealDamage: +50% fysisk skade hvis målet er elektrisk lammet
--   • getEnemies: robust lookup pr. zone, tag "Enemy" eller Model navn "Enemy"

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")

local Ab           = require(RS.Shared.AbilitiesConfig)
local WeaponConfig = require(RS.Shared.WeaponConfig)
local AreaViz      = require(RS.Shared.AreaViz)
local FCT          = require(RS.Shared.FloatingText)
local CollectionService = game:GetService("CollectionService")

local Common = {}
Common.Ab           = Ab
Common.WeaponConfig = WeaponConfig
Common.AreaViz      = AreaViz
Common.FCT          = FCT

Common.DAMAGE = {
	Physical = "physical",
	Electric = "electric",
	Fire     = "fire",
	Ice      = "ice",
	Magic    = "magic",
	Void    = "void",
	Other    = "other",
}

-- Giver 'Vulnerable' på en enemy (flat +dmg i duration sek.)
function Common.applyVulnerable(model, flatAdd, duration)
	if not model then return end
	local untilT = os.clock() + (duration or 1)
	model:SetAttribute("VulnerableUntil", untilT)
	model:SetAttribute("VulnerableAdd", math.max(0, flatAdd or 1))
end

-- Giv spiller fladt skade-buff (stacker op til maxStacks og nulstiller tid)
function Common.giveFlatDamageBuff(player, key, flatAdd, duration, maxStacks)
	if not player then return end
	key = "Buff_"..tostring(key)
	local stacks = tonumber(player:GetAttribute(key.."_Stacks")) or 0
	local add = tonumber(player:GetAttribute(key.."_Add")) or 0
	local now = os.clock()
	local untilT = now + (duration or 4)

	-- stack: +1 pr. trigger, cap til maxStacks
	stacks = math.min(maxStacks or 1, stacks + 1)
	add = tonumber(flatAdd or 1)

	player:SetAttribute(key.."_Stacks", stacks)
	player:SetAttribute(key.."_Add", add)
	player:SetAttribute(key.."_Until", untilT)
end

local function now() return os.clock() end

-- === Shrine-haste: skaler ventetider ===
function Common.scaleInterval(plr, baseSeconds)
	local mul = 1 / (plr:GetAttribute("Buff_RateMult") or 1)
	return math.max(0.01, baseSeconds * mul)
end
function Common.waitScaled(plr, baseSeconds)
	return task.wait(Common.scaleInterval(plr, baseSeconds))
end

-- intern watcher der frigiver humanoid efter stun
local _elecWatch = setmetatable({}, {__mode="k"})
local function _startElecWatcher(hum)
	if _elecWatch[hum] then return end
	_elecWatch[hum] = true
	task.spawn(function()
		while hum and hum.Parent do
			local untilT = hum:GetAttribute("ElecStunUntil") or 0
			if now() >= untilT then
				if hum:GetAttribute("ElecStunActive") then
					local prevSpd = hum:GetAttribute("ElecPrevWalk") or 16
					local prevJmp = hum:GetAttribute("ElecPrevJump") or 50
					hum.WalkSpeed = prevSpd
					if hum.UseJumpPower ~= false then hum.JumpPower = prevJmp end
					hum:SetAttribute("ElecStunActive", false)
				end
				break
			else
				task.wait(0.05)
			end
		end
		_elecWatch[hum] = nil
	end)
end

-- === Elektrisk stun (boss/fusion resist + Horde-resist) ===
function Common.applyElecStun(targetHumanoid, durationSeconds, opts)
	opts = opts or {}
	if not targetHumanoid or not targetHumanoid.Parent then return false, 0 end

	local model = targetHumanoid.Parent
	local body  = model.PrimaryPart

	-- Boss/fusion ignore-chance
	local boss = (model:GetAttribute("IsBoss") == true)
		or (model:GetAttribute("Boss") == true)
		or (body and (body:GetAttribute("IsBoss") == true or body:GetAttribute("Boss") == true))

	local fusionCount = tonumber(
		model:GetAttribute("FusionCount")
			or model:GetAttribute("Fusions")
			or (body and body:GetAttribute("Tier"))
			or 0
	) or 0

	local ignoreChance = 0
	if boss then ignoreChance = ignoreChance + 0.90 end
	ignoreChance = math.clamp(ignoreChance + 0.10 * math.max(0, fusionCount), 0, 0.95)
	if math.random() < ignoreChance then
		return false, 0
	end

	-- Horde-resist (chance til at undgå, ellers afkort duration)
	local hordeResist = 0
	if body then hordeResist = body:GetAttribute("Horde_ResistImmobilize") or 0 end
	if hordeResist > 0 then
		hordeResist = math.clamp(hordeResist, 0, 0.95)
		if math.random() < hordeResist then
			-- (valgfrit: FCT “Resisted”)
			return false, 0
		end
		-- blød reduktion i varighed
		durationSeconds = durationSeconds * (1 - 0.5 * hordeResist)
	end

	if opts.doubleDuration then durationSeconds = durationSeconds * 2 end
	durationSeconds = math.max(0, durationSeconds)

	-- 1) Humanoid immobilisering + attributter
	local untilT   = targetHumanoid:GetAttribute("ElecStunUntil") or 0
	local newUntil = math.max(untilT, now() + durationSeconds)
	targetHumanoid:SetAttribute("ElecStunUntil", newUntil)

	if not targetHumanoid:GetAttribute("ElecStunActive") then
		targetHumanoid:SetAttribute("ElecStunActive", true)
		if targetHumanoid.WalkSpeed > 0 then targetHumanoid:SetAttribute("ElecPrevWalk", targetHumanoid.WalkSpeed) end
		if targetHumanoid.UseJumpPower ~= false and (targetHumanoid.JumpPower or 0) > 0 then
			targetHumanoid:SetAttribute("ElecPrevJump", targetHumanoid.JumpPower)
		end
		targetHumanoid.WalkSpeed = 0
		if targetHumanoid.UseJumpPower ~= false then targetHumanoid.JumpPower = 0 end
	end
	_startElecWatcher(targetHumanoid)

	-- 2) AI-signal
	if body then
		local cur = body:GetAttribute("StunnedUntil") or 0
		if newUntil > cur then body:SetAttribute("StunnedUntil", newUntil) end
	end

	return true, (newUntil - now())
end

function Common.isElecStunned(humanoid)
	if not humanoid then return false end
	local untilT = humanoid:GetAttribute("ElecStunUntil") or 0
	return now() < untilT
end

function Common.onElectricDamage(humanoid)
	if not humanoid or not Common.isElecStunned(humanoid) then return end
	if math.random() < 0.25 then
		local untilT = humanoid:GetAttribute("ElecStunUntil") or 0
		humanoid:SetAttribute("ElecStunUntil", untilT + 0.1)
	end
end


function Common.dealDamage(sourcePlayer, targetModel, baseAmount, kind)
	-- >>> NY defensiv normalisering af argumenter <<<
	-- Byt om hvis der er sendt (player, number, Model, kind)
	if typeof(targetModel) == "number" and typeof(baseAmount) == "Instance" then
		targetModel, baseAmount = baseAmount, targetModel
	end

	-- Accepter Humanoid eller BasePart og find frem til Model
	if typeof(targetModel) == "Instance" then
		if targetModel:IsA("Humanoid") then
			targetModel = targetModel.Parent
		elseif not targetModel:IsA("Model") then
			local anc = targetModel:FindFirstAncestorOfClass("Model")
			if anc then targetModel = anc end
		end
	end

	-- Hvis vi stadig ikke har en gyldig model, så giv op stille og roligt
	if typeof(targetModel) ~= "Instance" or not targetModel:IsA("Model") then
		return
	end

	local hum = targetModel:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local dmg = math.max(0, tonumber(baseAmount) or 0)

	-- 1) Vulnerable (flat bonus på fjenden)
	local vuntil = tonumber(targetModel:GetAttribute("VulnerableUntil") or 0)
	if os.clock() < vuntil then
		dmg += tonumber(targetModel:GetAttribute("VulnerableAdd") or 0)
	end

	-- 2) Flat buff fra kilde-spiller (hvis nogen)
	if sourcePlayer then
		for _,key in ipairs({"Buff_Siphon"}) do
			local untilT = tonumber(sourcePlayer:GetAttribute(key.."_Until") or 0)
			if os.clock() < untilT then
				local stacks = tonumber(sourcePlayer:GetAttribute(key.."_Stacks") or 0)
				local add = tonumber(sourcePlayer:GetAttribute(key.."_Add") or 0)
				dmg += math.max(0, stacks * add)
			end
		end
	end

	-- Elec-interaktioner
	if kind == Common.DAMAGE.Physical and Common.isElecStunned(hum) then
		dmg = dmg * 1.5
	end
	if kind == Common.DAMAGE.Electric then
		Common.onElectricDamage(hum)
	end

	hum:TakeDamage(dmg)

	-- FCT – kun hvis vi har PrimaryPart
	if Common.showFloatingText and targetModel.PrimaryPart then
		Common.showFloatingText(
			targetModel.PrimaryPart.Position,
			tostring(math.floor(dmg+0.5)),
			Common.colorForKind(kind)
		)
	end
end


function Common.getEnemies(zoneId)
	local out = {}
	local function consider(model)
		if not model or not model.Parent then return end
		if not model:IsA("Model") then return end
		if (model.Name ~= "Enemy") and (not CollectionService:HasTag(model, "Enemy")) then return end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local pp  = model.PrimaryPart
		if hum and pp and hum.Health > 0 then
			if zoneId == nil or (pp:GetAttribute("ZoneId") == zoneId) then
				table.insert(out, model)
			end
		end
	end
	local tagged = CollectionService:GetTagged("Enemy")
	if #tagged > 0 then
		for _,m in ipairs(tagged) do consider(m) end
	else
		local root = workspace:FindFirstChild("ZoneEnemies") or workspace
		for _,m in ipairs(root:GetDescendants()) do if m:IsA("Model") then consider(m) end end
	end
	return out
end

function Common.baseDamageFor(plr)
	local lvl = (plr:FindFirstChild("leaderstats") and plr.leaderstats.Level.Value) or 1
	local dmg = WeaponConfig.BaseDamage + (lvl-1) * WeaponConfig.LevelDamageBonus
	local up = plr:FindFirstChild("Upgrades")
	if up and up:FindFirstChild("DamageMult") then
		dmg = dmg * up.DamageMult.Value
	end
	local buff = plr:GetAttribute("Buff_DamageMult") or 1.0
	dmg = dmg * buff
	return dmg
end

function Common.offensivePaused(plr)
	if plr:GetAttribute("CombatEnabled") ~= true then return true end
	local inv  = (plr:FindFirstChild("Invulnerable") and plr.Invulnerable.Value) or false
	local menu = (plr:FindFirstChild("LevelUpMenuOpen") and plr.LevelUpMenuOpen.Value) or false
	return inv or menu
end

function Common.getGroundY(pos, extraIgnore)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { Workspace:FindFirstChild("AreaViz") }
	if extraIgnore then for _,x in ipairs(extraIgnore) do table.insert(ignore, x) end end
	rp.FilterDescendantsInstances = ignore
	local res = Workspace:Raycast(pos + Vector3.new(0,10,0), Vector3.new(0,-200,0), rp)
	return res and res.Position.Y or pos.Y
end

function Common.makeRayParamsExcludeDecorAndPlayers()
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _,pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(ignore, pl.Character) end
		local sh = Workspace:FindFirstChild("Shields_"..pl.UserId); if sh then table.insert(ignore, sh) end
		local mi = Workspace:FindFirstChild("Mines_"..pl.UserId);   if mi then table.insert(ignore, mi) end
	end
	for _,name in ipairs({"AreaViz","ProjectilesFolder"}) do
		local inst = Workspace:FindFirstChild(name); if inst then table.insert(ignore, inst) end
	end
	rp.FilterDescendantsInstances = ignore
	return rp
end

return Common

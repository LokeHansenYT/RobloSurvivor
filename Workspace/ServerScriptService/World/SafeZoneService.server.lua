-- ServerScriptService/World/SafeZoneService.server.lua
-- Safe-zone QoL service
--  • Detects safe-zone using player attribute "ZoneIsSafe" (set by EnemySpawner)
--  • After 10s inside: full heal + particle effect
--  • Speed boost +100% while inside safe-zone (immediately on login if you spawn in safe-zone,
--    otherwise after the same 10s delay). Cleared immediately on exit.
--  • Exposes attribute Safe_SpeedBoostActive = true/false
--  • Optional DEBUG prints

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local DEBUG = false

local function dprint(...)
	if DEBUG then
		print("[SafeZoneService]", ...)
	end
end

local IN_SAFE      = {}  -- Player -> bool
local ENTER_T0     = {}  -- Player -> number (os.clock())
local HEALED_ONCE  = {}  -- Player -> bool
local FAST_AT_LOGIN= {}  -- Player -> bool

local HEAL_DELAY   = 3.10
local FX_DURATION  = 1.2

local function setSpeedBoost(plr: Player, on: boolean)
	plr:SetAttribute("Safe_SpeedBoostActive", on and true or false)
end

local function playHealFx(char: Model)
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local p = Instance.new("ParticleEmitter")
	p.Name = "SafeHealFX"
	p.Rate = 0
	p.Lifetime = NumberRange.new(0.6, 0.9)
	p.Speed = NumberRange.new(2, 6)
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-20, 20)
	p.SpreadAngle = Vector2.new(360, 360)
	p.Texture = "rbxassetid://241594419"
	p.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(120,255,140)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255,255,255))
	}
	p.LightEmission = 0.7
	p.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0.1)
	}
	p.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1.0)
	}
	p.Parent = hrp
	p:Emit(40)
	task.delay(FX_DURATION, function()
		if p.Parent then p.Parent = nil end
	end)
end

local function tryHeal(plr: Player)
	local char = plr.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health < hum.MaxHealth then
		hum.Health = hum.MaxHealth
		playHealFx(char)
		dprint(plr.Name, "auto-healed to 100% in safe-zone")
	end
end

local function onEnter(plr: Player, isLogin: boolean)
	dprint(plr.Name, "ENTER safe zone (login=", isLogin, ")")
	ENTER_T0[plr] = os.clock(); plr:SetAttribute("Safe_EnteredAt", ENTER_T0[plr])
	HEALED_ONCE[plr] = false
	if isLogin and not FAST_AT_LOGIN[plr] then
		setSpeedBoost(plr, true) -- immediate at login
		FAST_AT_LOGIN[plr] = true
	end
end

local function onExit(plr: Player)
	dprint(plr.Name, "EXIT safe zone")
	setSpeedBoost(plr, false)
	ENTER_T0[plr] = nil
	plr:SetAttribute("Safe_EnteredAt", nil)
	HEALED_ONCE[plr] = nil
end

local function tick()
	while true do
		for _,plr in ipairs(Players:GetPlayers()) do
			if IN_SAFE[plr] then
				local t0 = ENTER_T0[plr]
				if t0 and not HEALED_ONCE[plr] and (os.clock() - t0) >= HEAL_DELAY then
					tryHeal(plr)
					HEALED_ONCE[plr] = true
					if plr:GetAttribute("Safe_SpeedBoostActive") ~= true then
						setSpeedBoost(plr, true)
					end
				end
			end
		end
		task.wait(0.25)
	end
end

local function setInside(plr: Player, inside: boolean)
	if inside and not IN_SAFE[plr] then
		IN_SAFE[plr] = true
		onEnter(plr, false)
	elseif (not inside) and IN_SAFE[plr] then
		IN_SAFE[plr] = false
		onExit(plr)
	end
end

local function hookPlayer(plr: Player)
	plr.AttributeChanged:Connect(function(attr)
		if attr == "ZoneIsSafe" then
			setInside(plr, plr:GetAttribute("ZoneIsSafe") == true)
		end
	end)

	plr.CharacterAdded:Connect(function(char)
		task.defer(function()
			local inside = plr:GetAttribute("ZoneIsSafe") == true
			IN_SAFE[plr] = inside
			if inside then onEnter(plr, true) end
		end)
	end)

	if plr.Character then
		task.defer(function()
			local inside = plr:GetAttribute("ZoneIsSafe") == true
			IN_SAFE[plr] = inside
			if inside then onEnter(plr, true) end
		end)
	end
end

game:GetService("Players").PlayerAdded:Connect(hookPlayer)
for _,pl in ipairs(Players:GetPlayers()) do hookPlayer(pl) end

task.spawn(tick)

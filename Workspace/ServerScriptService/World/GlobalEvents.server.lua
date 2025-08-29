-- ServerScriptService/World/GlobalEvents.server.lua
-- Periodiske globale events med midlertidige buffs/debuffs til alle spillere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Show = Remotes:WaitForChild("GlobalEventShow")
local Hide = Remotes:WaitForChild("GlobalEventHide")

-- Hjælpere: sørg for at NumberValue findes og multiplicér sikkert
local function ensureNumber(parent, name, defaultValue)
	local v = parent:FindFirstChild(name)
	if not v then
		v = Instance.new("NumberValue")
		v.Name = name
		v.Value = defaultValue
		v.Parent = parent
	end
	return v
end

local function withMultiplier(numVal, mult)
	numVal.Value = numVal.Value * mult
end

local function applyEventToPlayer(player, ev)
	-- Placér mods under player.Stats eller separat folder "Modifiers"
	local stats = player:FindFirstChild("Stats") or player
	local dmg   = ensureNumber(stats, "DamageMult", 1)
	local rate  = ensureNumber(stats, "FireRateMult", 1)
	local moves = ensureNumber(stats, "GlobalMoveSpeedMult", 1) -- nyt, læses af MovementSpeed.server.lua hvis du ønsker

	withMultiplier(dmg,   ev.damageMult or 1)
	withMultiplier(rate,  ev.fireRateMult or 1)
	withMultiplier(moves, ev.moveSpeedMult or 1)
end

local function revertEventForPlayer(player, ev)
	local stats = player:FindFirstChild("Stats") or player
	for _, pair in ipairs({
		{"DamageMult",       ev.damageMult},
		{"FireRateMult",     ev.fireRateMult},
		{"GlobalMoveSpeedMult", ev.moveSpeedMult},
		}) do
		local name, mult = pair[1], pair[2]
		if mult and mult ~= 1 then
			local n = stats:FindFirstChild(name)
			if n then n.Value = n.Value / mult end
		end
	end
end

-- Definér events (justér tal efter smag)
local EVENTS = {
	{
		key = "HasteStorm",
		title = "Haste Storm",
		desc  = "+40% Fire Rate, +20% Move Speed",
		duration = 45,
		damageMult = 1.0,
		fireRateMult = 1.4,
		moveSpeedMult = 1.2,
	},
	{
		key = "BloodMoon",
		title = "Blood Moon",
		desc  = "+50% Damage, -15% Move Speed",
		duration = 45,
		damageMult = 1.5,
		fireRateMult = 1.0,
		moveSpeedMult = 0.85,
	},
	{
		key = "FrostWave",
		title = "Frost Wave",
		desc  = "+20% Damage, +10% Fire Rate",
		duration = 45,
		damageMult = 1.2,
		fireRateMult = 1.1,
		moveSpeedMult = 1.0,
	},
}

-- Scheduler: kør et event hvert ~3-4 min. Justér efter behov.
task.spawn(function()
	while true do
		task.wait(math.random(160, 220)) -- pause før næste event

		local ev = EVENTS[math.random(1, #EVENTS)]
		-- Broadcast UI
		for _, plr in ipairs(Players:GetPlayers()) do
			applyEventToPlayer(plr, ev)
			Show:FireClient(plr, { title = ev.title, desc = ev.desc, duration = ev.duration })
		end

		task.wait(ev.duration)

		for _, plr in ipairs(Players:GetPlayers()) do
			revertEventForPlayer(plr, ev)
			Hide:FireClient(plr)
		end
	end
end)

-- Ryd pænt op ved join/leave
Players.PlayerRemoving:Connect(function(plr)
	-- Ingen specifik oprydning nødvendig her, men plads til det hvis du logger stacks.
end)

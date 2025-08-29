-- ServerScriptService/Leaderstats.server.lua 
local Prog = require(game.ReplicatedStorage.Shared.ProgressionConfig)

game.Players.PlayerAdded:Connect(function(plr)
	-- leaderstats
	local stats = Instance.new("Folder"); stats.Name = "leaderstats"; stats.Parent = plr
	local level = Instance.new("IntValue"); level.Name="Level"; level.Value=1; level.Parent=stats
	

	-- XP & næste krav
	local xp = Instance.new("IntValue"); xp.Name="XP"; xp.Value=0; xp.Parent=plr
	local nextReq = Instance.new("IntValue"); nextReq.Name="XPToNext"; nextReq.Value=Prog.RequiredXP(level.Value); nextReq.Parent=plr

	-- Upgrades/buffs
	local up = Instance.new("Folder"); up.Name="Upgrades"; up.Parent=plr
	local dmg = Instance.new("NumberValue"); dmg.Name="DamageMult"; dmg.Value=1; dmg.Parent=up
	local fr  = Instance.new("NumberValue"); fr.Name="FireRateAdd"; fr.Value=0; fr.Parent=up
	local hpA = Instance.new("NumberValue"); hpA.Name="MaxHPAdd"; hpA.Value=0; hpA.Parent=up
	local msM = Instance.new("NumberValue"); msM.Name="MoveSpeedMult"; msM.Value=1; msM.Parent=up

	-- Evne-levels (0 = låst)
	for _,name in ipairs({ "AuraLevel","ShieldLevel","HealAuraLevel","SlowOrbLevel","MinesLevel","FanShotLevel" }) do
		local v = Instance.new("IntValue"); v.Name = name; v.Value = 0; v.Parent = up
	end

	-- Level-up UI/flag
	local flag = Instance.new("BoolValue"); flag.Name="LevelUpMenuOpen"; flag.Value=false; flag.Parent=plr
	local inv  = Instance.new("BoolValue"); inv.Name="Invulnerable";   inv.Value=false;  inv.Parent=plr
	
	-- (NYT) BP i leaderstats til "People"-tavlen
	local bpStat = stats:FindFirstChild("BP")
	if not bpStat then
		bpStat = Instance.new("IntValue")
		bpStat.Name = "BP"
		bpStat.Value = 0
		bpStat.Parent = stats
	end

	-- (NYT) BossPoints som løs værdi (bruges af HUDBottom m.fl.)
	local bpLoose = plr:FindFirstChild("BossPoints")
	if not bpLoose then
		bpLoose = Instance.new("IntValue")
		bpLoose.Name = "BossPoints"
		bpLoose.Value = 0
		bpLoose.Parent = plr
	end

	-- Recompute krav ved level
	local function refreshReq()
		nextReq.Value = Prog.RequiredXP(level.Value)
	end
	level:GetPropertyChangedSignal("Value"):Connect(refreshReq)

	-- Karakter HP/speed
	plr.CharacterAdded:Connect(function(char)
		task.wait()
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			local maxHp = Prog.BaseMaxHP + (level.Value-1)*Prog.MaxHPPerLevel + hpA.Value
			hum.MaxHealth = maxHp
			hum.Health    = maxHp
			hum.WalkSpeed = 16 * msM.Value
		end
	end)
end)

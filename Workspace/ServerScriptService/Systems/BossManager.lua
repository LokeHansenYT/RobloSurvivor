--[[
BossManager.lua — boss-timere og boss-arena overlevelses-BP

Formål
  • Afvikle boss-timer pr. zone og returnere boss-spawn-planer.
  • Give Boss Points passivt ved overlevelse i zoner markeret med IsBossArena.

API
  tick(Zones: table, zid: number): { {zid:number, pos:Vector3, isBoss:boolean}, ... }

Afhængigheder
  • EnemyConfig for BossEvery/BossFirstAt og BP-survive interval (BossBPSurviveEvery attr fallback).
  • ZoneIndex.clampToTop for sikre bossspawn-positioner.
]]--

local Players   = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")
local EnemyConfig = require(RS.Shared:WaitForChild("EnemyConfig"))
local ZoneIndex   = require(script.Parent:WaitForChild("ZoneIndex"))

local M = {}

local function getAliveCharactersInZone(Zones, zid)
	local t = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("ZoneId") == zid and plr:GetAttribute("CombatEnabled")==true then
			local ch = plr.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then table.insert(t, ch) end
		end
	end
	return t
end

function M.tick(Zones, zid)
	local z = Zones[zid]; if not z then return {} end
	local plans = {}

	local now = os.clock()

	-- init on activation (EnemySpawner sætter z.active)
	if z.active and (z.bossNextAt == nil or z.bossNextAt == 0) then
		z.bossNextAt = now + (EnemyConfig.BossFirstAt or 60)
	end

	-- overlevelses-BP i boss-arenaer
	if z.inst:GetAttribute("IsBossArena") then
		z.bpSurvive = z.bpSurvive or {
			every  = (z.inst:GetAttribute("BossBPSurviveEvery") or 60),
			nextAt = now + (z.inst:GetAttribute("BossBPSurviveEvery") or 60),
		}
		if now >= z.bpSurvive.nextAt then
			z.bpSurvive.nextAt = now + z.bpSurvive.every
			for _, ch in ipairs(getAliveCharactersInZone(Zones, zid)) do
				local p = Players:GetPlayerFromCharacter(ch)
				if p then
					local ls = p:FindFirstChild("leaderstats")
					local bpLeader = ls and ls:FindFirstChild("BP")
					if bpLeader then bpLeader.Value += 1 end
					local bpLoose = p:FindFirstChild("BossPoints")
					if bpLoose then bpLoose.Value += 1 end
				end
			end
		end
	end

	-- boss spawn?
	if z.bossNextAt and z.bossNextAt > 0 and now >= z.bossNextAt then
		local chars = getAliveCharactersInZone(Zones, zid)
		if #chars > 0 then
			local who  = chars[math.random(1, #chars)]
			local hrp  = who:FindFirstChild("HumanoidRootPart")
			if hrp then
				local a   = math.random() * math.pi * 2
				local r   = math.random(22, 34)
				local want= hrp.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * r
				local pos = ZoneIndex.clampToTop(z, want)
				table.insert(plans, { zid = zid, pos = pos, isBoss = true })
			end
			z.bossNextAt = now + (EnemyConfig.BossEvery or 120)
		else
			-- ingen spillere lige nu – prøv igen senere
			z.bossNextAt = now + 5
		end
	end

	return plans
end

return M

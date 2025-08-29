--[[
HUDSync.lua  �  server ? spiller-attributter for zone-info

Form�l
  � Vedligeholde spiller-attributter som HUD�en l�ser:
      ZoneId, ZoneName, ZoneMinLvl, ZoneMaxLvl, ZoneIsSafe,
      ZoneEnterAt, ZoneOpponents, ZoneRampTier
  � S�tte CombatEnabled korrekt (true kun i kampzone og n�r spillerens level matcher)
  � Valgfri debug: ZoneEligible, ZoneReason ("SAFE" / "LOW" / "HIGH" / "OK")

Eksporterer
  � updatePlayerZones(zones: table)

Afh�ngigheder
  � ZoneIndex.getZoneAt til at finde aktuel zone.

Bem�rk
  � Ingen spawner- eller AI-logik her; kun attributter p� Player.
]]--

local Players   = game:GetService("Players")
local ZoneIndex = require(script.Parent:WaitForChild("ZoneIndex"))

local HUDSync = {}

local function getPlayerLevel(plr: Player): number
	local ls = plr:FindFirstChild("leaderstats")
	local lvlVal = ls and ls:FindFirstChild("Level")
	return (lvlVal and lvlVal.Value) or 1
end

function HUDSync.updatePlayerZones(zones)
	for _, pl in ipairs(Players:GetPlayers()) do
		local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")

		-- default v�rdier
		local zidNow, name, minL, maxL, isSafe = -1, "Unknown", 1, 9999, false
		if hrp then
			local zid, z = ZoneIndex.getZoneAt(zones, hrp.Position)
			if z then
				zidNow = zid
				name   = z.name
				minL   = z.minLvl
				maxL   = z.maxLvl
				isSafe = z.isSafe
			end
		end

		-- nulstil, n�r man skifter zone
		local prev = pl:GetAttribute("ZoneId")
		if prev ~= zidNow then
			pl:SetAttribute("ZoneEnterAt", os.time())
			pl:SetAttribute("ZoneOpponents", 0)
			pl:SetAttribute("ZoneRampTier", 0)
		end

		-- hoved-attributter
		pl:SetAttribute("ZoneId", zidNow)
		pl:SetAttribute("ZoneName", name)
		pl:SetAttribute("ZoneMinLvl", minL)
		pl:SetAttribute("ZoneMaxLvl", maxL)
		pl:SetAttribute("ZoneIsSafe", isSafe)

		-- CombatEnabled: kun hvis vi st�r i en IKKE-safe zone og level matcher
		local lvl = getPlayerLevel(pl)
		local eligible = (zidNow ~= -1) and (not isSafe) and (lvl >= minL and lvl <= maxL)
		pl:SetAttribute("ZoneEligible", eligible)     -- valgfri (til HUD/debug)
		pl:SetAttribute("CombatEnabled", eligible)

		-- valgfri �rsag (til HUD/debug/log)
		local reason = ""
		if zidNow ~= -1 then
			if isSafe then reason = "SAFE"
			elseif lvl < minL then reason = "LOW"
			elseif lvl > maxL then reason = "HIGH"
			else reason = "OK" end
		end
		pl:SetAttribute("ZoneReason", reason)
	end
end

return HUDSync

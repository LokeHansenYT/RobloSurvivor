--[[
Fusion.lua — triade-baseret, lokal fusion med cooldown (genskaber 3-berørings-reglen)

Hvad gør den:
  • Fuser KUN hvis der findes en “triade” (tre fjender i nærkontakt).
    - For en ikke-fusioneret (Tier==0): kræver =2 NÆRLIGGENDE naboer med Tier==0.
      -> Vi fuser to af dem ind i “ankeret” i ét tick (sekventielt).
    - For en fusioneret (Tier>=1): kræver =2 naboer med Tier==0 for at flette igen.
      -> Vi absorberer to Tier==0 ind i ankeret i ét tick.
  • “Lokal” = fjenderne skal fysisk være tæt på hinanden (afstand ~ kollisions-radier + padding).
  • Ingen teleport langt væk; ankeret bliver hvor det er (kun lille justering).
  • Sætter cooldown: StunnedUntil og FusedUntil, så en enhed ikke kan fusionere igen
    eller bevæge/skyde i X sekunder efter en fusion.

Zone-attributter (valgfri) på hver zone-part (Workspace/Zones/<Zone>):
  • FuseMinAlive        (number)  default: max(minOpp+2, 10) eller 15
  • FuseCheckEvery      (number)  default: 1.5 (sek.)
  • FuseMaxTriads       (number)  default: 2   (triader pr. tick)
  • FuseStunSeconds     (number)  default: 2.5 (sekunder “stilstand” efter fusion)
  • FuseContactPad      (number)  default: 0.5 (ekstra afstand, “berøring” tolerance)
  • DebugFusion         (bool)    default: false (log i Output)

Bemærk:
  • Bosser ignoreres i fusion.
  • Farve/tier-opgradering genbruges fra applyTierUpgrades (hvis til stede), ellers minimum farve.
]]--

local Debris = game:GetService("Debris")

local M = {}

-- ========== utils / debug ==========
local function dbg(z, on, msg, ...)
	if not on then return end
	local name = (z.inst and z.inst.Name) or ("Zone_"..tostring(z.id or "?"))
	print(("[Fusion:%s] "..msg):format(name, ...))
end

local function colorForTier(t: number, isBoss: boolean)
	if isBoss then
		return Color3.fromRGB(150, 0, 180)               -- boss-lilla
	end
	if t >= 10 then return Color3.fromRGB(20,20,20)     -- meget mørk
	elseif t >= 6 then return Color3.fromRGB(255,140,0) -- orange
	elseif t >= 4 then return Color3.fromRGB(255,70,120)-- magenta-ish
	elseif t >= 2 then return Color3.fromRGB(200,200,255)-- lys blå
	else return Color3.fromRGB(200,200,200) end         -- neutral grå
end

local function aliveEnemies(z)
	local out = {}
	for _, m in ipairs(z.enemies:GetChildren()) do
		if m:IsA("Model") and m.Name == "Enemy" then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local pp  = m.PrimaryPart
			if hum and pp and hum.Health > 0 then
				if pp:GetAttribute("IsBoss") ~= true then
					table.insert(out, m)
				end
			end
		end
	end
	return out
end

local function radiusForPart(p: BasePart)
	-- cirkel-approksimation ud fra X/Z
	return (p.Size.X + p.Size.Z) * 0.25  -- (X/2 + Z/2)/2 = (X+Z)/4
end

local function inContact(a: BasePart, b: BasePart, pad: number)
	local ra = radiusForPart(a)
	local rb = radiusForPart(b)
	local d  = (a.Position - b.Position)
	local distXZ = Vector2.new(d.X, d.Z).Magnitude
	return distXZ <= (ra + rb + pad)
end

local function eligibleNow(p: BasePart, now: number)
	local fu = p:GetAttribute("FusedUntil") or 0
	return now >= fu
end

local function applyTierUpgrades(pp: BasePart, hum: Humanoid)
	-- findes muligvis allerede i din fil; denne version er self-contained
	local t     = pp:GetAttribute("Tier") or 0
	local boss  = pp:GetAttribute("IsBoss") == true

	-- VISUELT
	pp.Color    = colorForTier(t, boss)
	pp.Material = Enum.Material.SmoothPlastic

	-- Enkel ranged unlock pr. tier (EnemyAI læser disse)
	local wantLevel = (t>=6) and 3 or (t>=4) and 2 or (t>=2) and 1 or 0
	if wantLevel > 0 then
		local cur = pp:GetAttribute("RangedLevel") or 0
		if wantLevel > cur then
			pp:SetAttribute("RangedLevel", wantLevel)
			pp:SetAttribute("RangedRange",  math.max(pp:GetAttribute("RangedRange")  or 0, 26 + 6*wantLevel))
			pp:SetAttribute("RangedDamage", math.max(pp:GetAttribute("RangedDamage") or 0,  5 + 3*wantLevel))
		end
	end

	if hum.Health > hum.MaxHealth then hum.Health = hum.MaxHealth end
end

local function fusePair(anchor: Model, other: Model, padFXColor: Color3?)
	local pa, pb = anchor.PrimaryPart, other.PrimaryPart
	local ha = anchor:FindFirstChildOfClass("Humanoid")
	local hb = other:FindFirstChildOfClass("Humanoid")
	if not (pa and pb and ha and hb) then return false end

	-- Ny tier = sum + 1 (sekventiel absorption)
	local newTier = (pa:GetAttribute("Tier") or 0) + (pb:GetAttribute("Tier") or 0) + 1
	pa:SetAttribute("Tier", newTier)

	-- Skaler stats (tab aldrig HP ved selve fusionen)
	local oldHealth = ha.Health
	ha.MaxHealth = math.max(1, math.floor(ha.MaxHealth * 1.5))
	local mergedHealth = (ha.Health or 0) + (hb.Health or 0)
	ha.Health = math.clamp(math.max(oldHealth, mergedHealth), 1, ha.MaxHealth)

	-- Let størrelse og styrke
	pa.Size = pa.Size * 1.10
	pa:SetAttribute("MoveSpeedMult",   (pa:GetAttribute("MoveSpeedMult")   or 1) * 1.05)
	pa:SetAttribute("TouchDamageMult", (pa:GetAttribute("TouchDamageMult") or 1) * 1.10)
	pa:SetAttribute("XPMult",          (pa:GetAttribute("XPMult")          or 1) * 1.05)

	-- Lille effekt ved anchor (ingen teleport)
	local fx = Instance.new("Part")
	fx.Anchored = true; fx.CanCollide = false
	fx.Material = Enum.Material.Neon
	fx.Color    = padFXColor or Color3.fromRGB(255,200,80)
	fx.Size     = Vector3.new(0.6,0.6,0.6)
	fx.CFrame   = pa.CFrame
	fx.Parent   = anchor
	Debris:AddItem(fx, 0.2)

	-- Fjern “other”
	other:Destroy()

	-- Opgrader visuel/ranged
	applyTierUpgrades(pa, ha)
	return true
end

-- find naboer i “kontakt” (fysisk tæt); returner sorteret efter afstand
local function contactNeighbors(anchor: Model, pool: {Model}, pad: number, now: number)
	local out = {}
	local pa = anchor.PrimaryPart
	if not pa then return out end
	for _,m in ipairs(pool) do
		if m~=anchor then
			local pp = m.PrimaryPart
			if pp and eligibleNow(pp, now) then
				if inContact(pa, pp, pad) then
					table.insert(out, m)
				end
			end
		end
	end
	table.sort(out, function(x,y)
		local dx = (x.PrimaryPart.Position - pa.Position)
		local dy = (y.PrimaryPart.Position - pa.Position)
		return Vector2.new(dx.X,dx.Z).Magnitude < Vector2.new(dy.X,dy.Z).Magnitude
	end)
	return out
end

function M.try(Zones, zid)
	local z = Zones[zid]; if not z then return end
	local inst = z.inst
	local now = os.clock()

	-- konfig
	local defaultMinAlive = (z.minOpp and math.max(z.minOpp + 2, 10)) or 15
	local minAlive   = (inst and inst:GetAttribute("FuseMinAlive"))    or defaultMinAlive
	local checkEvery = (inst and inst:GetAttribute("FuseCheckEvery"))  or 1.5
	local maxTriads  = (inst and inst:GetAttribute("FuseMaxTriads"))   or 2
	local stunSecs   = (inst and inst:GetAttribute("FuseStunSeconds")) or 2.5
	local pad        = (inst and inst:GetAttribute("FuseContactPad"))  or 0.5
	local debugLog   = (inst and inst:GetAttribute("DebugFusion"))     or false

	-- interval kontrol
	z.fuse = z.fuse or {}
	local waitLeft = (z.fuse.checkEvery or checkEvery) - (now - (z.fuse.lastCheck or 0))
	if waitLeft > 0 then dbg(z, debugLog, "skip (interval %.2fs left)", waitLeft); return end
	z.fuse.lastCheck  = now
	z.fuse.checkEvery = checkEvery

	-- kandidater
	local pool = aliveEnemies(z)
	if #pool < minAlive then
		dbg(z, debugLog, "alive=%d < min=%d (no fuse)", #pool, minAlive)
		return
	end

	-- triade-fusioner pr. tick
	local triadsDone = 0
	-- vi holder styr på dem vi “forbruger” dette tick
	local consumed = {}

	local function isConsumed(m) return consumed[m] == true end
	local function consume(m) consumed[m] = true end

	-- gennemløb: find anchor som er “klar” (ikke i cooldown), og som har nødvendige naboer
	for _, anchor in ipairs(pool) do
		if triadsDone >= maxTriads then break end
		if not isConsumed(anchor) then
			local pa = anchor.PrimaryPart
			local ha = anchor:FindFirstChildOfClass("Humanoid")
			if pa and ha and ha.Health > 0 and eligibleNow(pa, now) then
				local tierA = pa:GetAttribute("Tier") or 0
				local neigh = contactNeighbors(anchor, pool, pad, now)

				-- filtrér naboer der er brugbare (ikke boss, ikke consumed, Tier==0)
				local zeroNeighbors = {}
				for _,n in ipairs(neigh) do
					if not isConsumed(n) then
						local pn = n.PrimaryPart
						if pn and pn:GetAttribute("IsBoss") ~= true then
							local tn = pn:GetAttribute("Tier") or 0
							if tn == 0 and eligibleNow(pn, now) then
								table.insert(zeroNeighbors, n)
							end
						end
					end
				end

				-- log
				dbg(z, debugLog, "anchor@T%d has %d zero-neighbors in contact", tierA, #zeroNeighbors)

				-- regler:
				--  - Hvis anchor T==0  => kræver 2 zero-neighbors
				--  - Hvis anchor T>=1  => kræver 2 zero-neighbors
				local need = 2
				if #zeroNeighbors >= need then
					-- vælg de 2 nærmeste
					local n1, n2 = zeroNeighbors[1], zeroNeighbors[2]
					local ok1 = fusePair(anchor, n1)
					if ok1 then
						consume(n1)
						local ok2 = fusePair(anchor, n2)
						if ok2 then
							consume(n2)
							-- cooldown: stå stille og forbyd fusion i perioden
							pa:SetAttribute("StunnedUntil", now + stunSecs)
							pa:SetAttribute("FusedUntil",   now + stunSecs)
							consume(anchor)  -- undgå at anchor bruges igen i samme tick
							triadsDone += 1
							dbg(z, debugLog, "triad fused (anchor stayed put). triads=%d", triadsDone)
						end
					end
				else
					dbg(z, debugLog, "insufficient neighbors (need 2, have %d)", #zeroNeighbors)
				end
			end
		end
	end

	if triadsDone == 0 then
		dbg(z, debugLog, "no triads found this tick")
	end
end

return M

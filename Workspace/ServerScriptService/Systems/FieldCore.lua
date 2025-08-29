-- Systems/FieldCore.lua
-- F�lles hj�lpeklasse til "felter p� jorden" (Void/Soul/Siphon m.fl.)
-- H�ndterer: levetid, max-scale, overv�gning af fjender i feltet,
-- onEnemyDied callbacks og "forst�r + nulstil tid".
local FieldCore = {}
local HttpService = game:GetService("HttpService")

FieldCore.__index = FieldCore

-- opts:
--   baseSize: Vector3 (X,Z g�lder; Y ignoreres)
--   ttl: number (sek)
--   maxScale: number (fx 2.0 for 200%)
--   expandPctOnKill: number (fx 0.10 = +10% af base pr. kill)
--   onEnemyTick(model, hum): optional, kaldt ~10/sek pr. enemy i felt
--   onEnemyDied(model, hum): optional, kaldt n�r fjende d�r *i* felt
--   onScaled(sizeXZ): optional, n�r felt �ndrer skala
--   onExpired(): optional, ved udl�b
function FieldCore.new(part, opts)
	local self = setmetatable({}, FieldCore)
	self.part = part
	self.opts = opts or {}
	self.baseSizeXZ = Vector2.new(opts.baseSize.X, opts.baseSize.Z)
	self.curScale = 1.0
	self.dead = false
	self.enemies = {}   -- [model] = {hum=Humanoid, diedConn=RBXSignal?}
	--self.mark = ("InField_%s"):format(tostring(part:GetDebugId()))
	self.mark = ("InField_%s"):format(HttpService:GenerateGUID(false):gsub("-", ""))
	-- valgfrit til debugging: part:SetAttribute("FieldKey", self.mark)
	self.ttlLeft = opts.ttl or 4
	self._hb = nil
	return self
end

function FieldCore:_setSizeFromScale()
	local p = self.part
	local x = self.baseSizeXZ.X * self.curScale
	local z = self.baseSizeXZ.Y * self.curScale
	p.Size = Vector3.new(x, p.Size.Y, z)
	if self.opts.onScaled then
		self.opts.onScaled(Vector2.new(x, z))
	end
end

function FieldCore:expandAndRefresh()
	if self.dead then return end
	local maxScale = self.opts.maxScale or 2.0
	local add = self.opts.expandPctOnKill or 0.10
	self.curScale = math.min(maxScale, self.curScale * (1.0 + add))
	self.ttlLeft = self.opts.ttl or self.ttlLeft
	self:_setSizeFromScale()
end

function FieldCore:_touchEnemy(model, hum)
	if self.enemies[model] then return end
	-- mark�r
	model:SetAttribute(self.mark, os.clock())
	-- tilmeld d�ds-callback
	local conn = hum.Died:Connect(function()
		if self.dead then return end
		-- var fjenden i feltet ved d�d?
		if model:GetAttribute(self.mark) then
			if self.opts.onEnemyDied then
				self.opts.onEnemyDied(model, hum)
			end
			self:expandAndRefresh()
		end
	end)
	self.enemies[model] = {hum=hum, diedConn=conn}
end

function FieldCore:_untouchEnemy(model)
	if not self.enemies[model] then return end
	model:SetAttribute(self.mark, nil)
	local rec = self.enemies[model]
	if rec.diedConn then rec.diedConn:Disconnect() end
	self.enemies[model] = nil
end

function FieldCore:start()
	if self._hb then return end
	self:_setSizeFromScale()
	self._hb = game:GetService("RunService").Heartbeat:Connect(function(dt)
		if self.dead then return end
		self.ttlLeft -= dt
		if self.ttlLeft <= 0 then
			self:stop()
			if self.opts.onExpired then self.opts.onExpired() end
			return
		end
		-- scan for fjender i feltet
		local region = OverlapParams.new()
		region.FilterType = Enum.RaycastFilterType.Exclude
		region.FilterDescendantsInstances = {self.part}
		local parts = workspace:GetPartBoundsInBox(self.part.CFrame, self.part.Size, region)
		local seen = {}
		for _,bp in ipairs(parts) do
			local m = bp:FindFirstAncestorWhichIsA("Model")
			if m and m:FindFirstChildOfClass("Humanoid") then
				local hum = m:FindFirstChildOfClass("Humanoid")
				seen[m] = true
				self:_touchEnemy(m, hum)
				if self.opts.onEnemyTick then
					self.opts.onEnemyTick(m, hum)
				end
			end
		end
		-- fjern dem der ikke l�ngere er i feltet
		for m,_ in pairs(self.enemies) do
			if not seen[m] then self:_untouchEnemy(m) end
		end
	end)
end

function FieldCore:stop()
	if self.dead then return end
	self.dead = true
	if self._hb then self._hb:Disconnect() end
	self._hb = nil
	for m,_ in pairs(self.enemies) do
		self:_untouchEnemy(m)
	end
end

return FieldCore

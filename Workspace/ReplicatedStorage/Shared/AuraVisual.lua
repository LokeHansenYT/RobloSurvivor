-- ReplicatedStorage/Shared/AuraVisual.lua
-- Fælles aura-visual (flad CylinderHandleAdornment lige over gulvet).
-- Understøtter:
--  • Idle: fading border (fadePeriod + idlePause)
--  • Cast: pulser hvor radius animeres fra edgeMinPct*R ? 1.0*R
--  • Modes pr. spiller: 0=Off, 1=Fade borders (default), 2=Always on

local Workspace = game:GetService("Workspace")

local AuraVisual = {}
AuraVisual.__index = AuraVisual

local DEFAULT_IGNORE = { "ProjectilesFolder", "ZoneEnemies" }

local function groundYUnder(hrp: BasePart, extraIgnore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { hrp.Parent }
	for _, name in ipairs(DEFAULT_IGNORE) do
		local inst = Workspace:FindFirstChild(name)
		if inst then table.insert(ignore, inst) end
	end
	if extraIgnore then
		for _,i in ipairs(extraIgnore) do table.insert(ignore, i) end
	end
	params.FilterDescendantsInstances = ignore

	local origin = hrp.Position + Vector3.new(0, 500, 0)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -2000, 0), params)
	return (hit and hit.Position.Y) or (hrp.Position.Y - hrp.Size.Y*0.5)
end

-- mode: 0=Off, 1=Fade borders, 2=Always on
function AuraVisual.new(hrp: BasePart, opts)
	opts = opts or {}
	local self = setmetatable({}, AuraVisual)
	self.hrp         = hrp
	self.parent      = opts.parent or hrp.Parent
	self.name        = opts.name or "AuraRing"
	self.color       = opts.color or Color3.fromRGB(255,255,255)
	self.offset      = opts.offset or 0.1
	self.height      = opts.height or 0.06
	self.alphaBase   = (opts.transparency ~= nil and opts.transparency) or 0.35
	self.alwaysOnTop = (opts.alwaysOnTop ~= false)
	self.mode        = opts.mode or 1

	-- Idle (fade)
	self.idleFadePeriod = (opts.idle and opts.idle.fadePeriod) or 1.0
	self.idlePause      = (opts.idle and opts.idle.pause) or 2.5
	self.idleAlphaMin   = (opts.idle and opts.idle.alphaMin) or 0.15
	self.idleAlphaMax   = (opts.idle and opts.idle.alphaMax) or 0.45

	-- Cast (pulse)
	self.castDuration   = (opts.cast and opts.cast.duration) or 0.22
	self.castAlpha      = (opts.cast and opts.cast.alpha) or 0.15
	self.castEdgeMinPct = (opts.cast and opts.cast.edgeMinPct) or 0.10  -- NY: hvor “kantet” pulsen starter

	-- Cleanup gammel
	local old = self.parent:FindFirstChild(self.name)
	if old then old:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = self.name
	folder.Parent = self.parent
	self.folder = folder

	local adorn = Instance.new("CylinderHandleAdornment")
	adorn.Name = "Ring"
	adorn.Adornee = hrp
	adorn.Color3 = self.color
	adorn.Transparency = self.alphaBase
	adorn.AlwaysOnTop = self.alwaysOnTop
	adorn.Height = self.height
	adorn.ZIndex = 0
	adorn.Parent = folder
	self.adorn = adorn

	-- state
	self._baseRadius   = 0
	self._idleRunning  = false
	self._castRunning  = false

	-- start idle hvis mode=1
	if self.mode == 1 then
		self:_startIdle()
	end

	return self
end

function AuraVisual:setColor(c: Color3)
	self.color = c
	if self.adorn then self.adorn.Color3 = c end
end

function AuraVisual:setOffset(o: number)
	self.offset = o
end

function AuraVisual:setMode(mode: number)
	self.mode = mode
	if not self.adorn then return end
	if mode == 0 then
		self.adorn.Transparency = 1
		self:_stopIdle()
	elseif mode == 1 then
		self:_startIdle()
	elseif mode == 2 then
		self:_stopIdle()
		self.adorn.Transparency = self.alphaBase
	end
end

function AuraVisual:_startIdle()
	if self._idleRunning or self.mode ~= 1 then return end
	self._idleRunning = true
	task.spawn(function()
		while self._idleRunning and self.adorn and self.adorn.Parent do
			local T = self.idleFadePeriod
			local t0 = os.clock()
			while self._idleRunning and (os.clock() - t0) < T and self.mode == 1 do
				local p = (os.clock() - t0)/T
				local s = (math.sin(p*math.pi*2 - math.pi/2)+1)/2
				self.adorn.Transparency = self.idleAlphaMin + (self.idleAlphaMax - self.idleAlphaMin)*s
				task.wait(0.03)
			end
			local pauseT = self.idlePause
			local t1 = os.clock()
			while self._idleRunning and (os.clock() - t1) < pauseT and self.mode == 1 do
				task.wait(0.05)
			end
		end
	end)
end

function AuraVisual:_stopIdle()
	self._idleRunning = false
end

-- Pulser fra edgeMinPct*R ? 1.0*R (edge-only følelse)
function AuraVisual:castPulse(targetRadius: number)
	if self.mode == 0 or not self.adorn then return end
	local resumeIdle = self._idleRunning
	self:_stopIdle()
	self._castRunning = true

	task.spawn(function()
		local T = math.max(0.08, self.castDuration)
		local t0 = os.clock()
		local startPct = math.clamp(self.castEdgeMinPct or 0.1, 0, 1)

		while self._castRunning and (os.clock() - t0) < T and self.adorn and self.adorn.Parent do
			local p = (os.clock() - t0)/T
			local e = 1 - (1 - p)*(1 - p) -- ease-out
			local frac = startPct + (1 - startPct)*e
			local r = math.max(0.25, targetRadius * frac)
			self:_applyRadius(r)
			self.adorn.Transparency = self.castAlpha
			self:_applyCFrame()
			task.wait()
		end

		-- tilstand efter cast
		self:_applyRadius(self._baseRadius)
		if self.mode == 2 then
			self.adorn.Transparency = self.alphaBase
		else
			self.adorn.Transparency = self.idleAlphaMax
		end
		self._castRunning = false
		if resumeIdle and self.mode == 1 then
			self:_startIdle()
		end
	end)
end

function AuraVisual:_applyRadius(r: number)
	if not self.adorn then return end
	self.adorn.Radius = r
end

function AuraVisual:_applyCFrame()
	if not (self.hrp and self.hrp.Parent and self.adorn and self.adorn.Parent) then return end
	local gY = groundYUnder(self.hrp)
	local worldPos = Vector3.new(self.hrp.Position.X, gY + (self.offset or 0.1), self.hrp.Position.Z)
	local localPos = self.hrp.CFrame:PointToObjectSpace(worldPos)
	self.adorn.CFrame = CFrame.new(localPos) * CFrame.Angles(math.rad(90), 0, 0)
end

function AuraVisual:update(baseRadius: number)
	if not (self.adorn and self.adorn.Parent) then return end
	self._baseRadius = math.max(0.25, baseRadius or 0.25)
	if not self._castRunning then
		self:_applyRadius(self._baseRadius)
		self:_applyCFrame()
	end
end

function AuraVisual:destroy()
	self._idleRunning = false
	self._castRunning = false
	if self.folder and self.folder.Parent then self.folder:Destroy() end
	self.folder = nil
	self.adorn = nil
end

return AuraVisual

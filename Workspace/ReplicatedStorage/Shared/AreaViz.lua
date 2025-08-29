-- ReplicatedStorage/Shared/AreaViz.lua
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local rootFolder = workspace:FindFirstChild("AreaViz") or Instance.new("Folder", workspace)
rootFolder.Name = "AreaViz"

local AreaViz = {}
AreaViz.__index = AreaViz

function AreaViz.new(id, color, yOffset, thickness)
	local self = setmetatable({}, AreaViz)
	self.part = Instance.new("Part")
	self.part.Name = id .. "_Ring"
	self.part.Shape = Enum.PartType.Cylinder
	self.part.Anchored, self.part.CanCollide, self.part.CanTouch, self.part.CanQuery = true, false, false, false
	self.part.Material = Enum.Material.Neon
	self.part.Color = color or Color3.fromRGB(255,255,255)
	self.part.CastShadow = false
	self.part.Transparency = 1
	self.part.Size = Vector3.new(thickness or 0.06, 1, 1) -- X=tykkelse, Y/Z=diameter
	self.part.Parent = rootFolder

	self.yOffset  = yOffset or 0.05
	self.thick    = thickness or 0.06
	self._hb      = nil
	self._hrp     = nil
	self._radiusF = nil
	return self
end

function AreaViz:followHRP(hrp, radiusFunc)
	self._hrp, self._radiusF = hrp, radiusFunc
	if self._hb then self._hb:Disconnect() end
	self._hb = RunService.Heartbeat:Connect(function()
		if not self._hrp or not self._hrp.Parent then return end
		local r = self._radiusF and self._radiusF() or 0
		self.part.Size = Vector3.new(self.thick, r*2, r*2)
		self.part.CFrame = CFrame.new(self._hrp.Position + Vector3.new(0, self.yOffset, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		self.part.Transparency = 0.65
	end)
	return self
end

function AreaViz:pulse(radius, duration)
	duration = duration or 0.3
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = self.part.Color
	p.CastShadow = false
	p.Transparency = 0.15
	p.Size = Vector3.new(self.thick, radius*0.2*2, radius*0.2*2)
	p.CFrame = self.part.CFrame
	p.Parent = rootFolder
	local ti = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(p, ti, { Size = Vector3.new(self.thick, radius*2, radius*2), Transparency = 1 }):Play()
	task.delay(duration, function() if p and p.Parent then p:Destroy() end end)
end

-- Enkeltstående, voksende ring (fx mine-arming)
function AreaViz.growRingAt(pos, duration, startR, endR, color, yOffset, thickness)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanTouch, ring.CanQuery = true, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = color or Color3.fromRGB(255,200,80)
	ring.Transparency = 0.2
	ring.CastShadow = false
	thickness = thickness or 0.06
	yOffset   = yOffset   or 0.05
	ring.Size = Vector3.new(thickness, startR*2, startR*2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, yOffset, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = rootFolder
	local ti = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	TweenService:Create(ring, ti, { Size = Vector3.new(thickness, endR*2, endR*2), Transparency = 0.6 }):Play()
	task.delay(duration, function() if ring and ring.Parent then ring:Destroy() end end)
	return ring
end

function AreaViz:destroy()
	if self._hb then self._hb:Disconnect() end
	if self.part and self.part.Parent then self.part:Destroy() end
end

return AreaViz

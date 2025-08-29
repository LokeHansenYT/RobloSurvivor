-- ReplicatedStorage/Shared/FloatingText.lua
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local FloatingText = {}

-- Farver pr. kilde (damage)
local COLORS = {
	MAIN            = Color3.fromRGB(255,240,80),

	-- Auraer/klassikere
	WEAPON_AURA     = Color3.fromRGB(150,25,25),   -- matcher DamageAura-ring (rød)  ? vigtig
	WEAPON_HEAL     = Color3.fromRGB(90,240,160),
	WEAPON_SLOWAURA = Color3.fromRGB(120,185,255),
	WEAPON_FIREAURA = Color3.fromRGB(255,140,40),

	WEAPON_SHIELD   = Color3.fromRGB(200,255,255),
	WEAPON_SLOWORB  = Color3.fromRGB(255,120,50),
	WEAPON_MINE     = Color3.fromRGB(255,200,80),
	WEAPON_FAN      = Color3.fromRGB(120,200,255),
	WEAPON_AXE      = Color3.fromRGB(255,140,90),
	WEAPON_BMR      = Color3.fromRGB(120,255,220),
	WEAPON_SPIN     = Color3.fromRGB(190,120,255),
	WEAPON_ZAP      = Color3.fromRGB(255,230,120),
	WEAPON_PLUS     = Color3.fromRGB(240,240,255),
	WEAPON_CROSS    = Color3.fromRGB(160,240,255),
	WEAPON_WHIP     = Color3.fromRGB(180,160,255),
	WEAPON_FIRETRAIL= Color3.fromRGB(255,220,120),
	WEAPON_CHAIN    = Color3.fromRGB(200,240,255),
	WEAPON_CGROUND  = Color3.fromRGB(250,230,140),
	WEAPON_EAURA    = Color3.fromRGB(180,220,255),
	WEAPON_EARMOR   = Color3.fromRGB(220,240,255),
	WEAPON_CSTORM   = Color3.fromRGB(255,245,160),
	WEAPON_EDEF     = Color3.fromRGB(190,240,255),
	WEAPON_RAIDEN   = Color3.fromRGB(255,255,200),

	DEFAULT         = Color3.fromRGB(255,230,230),
}

-- Farver til status/debuff-beskeder
local STYLE_COLORS = {
	HEAL_AURA   = Color3.fromRGB(90,240,160),
	SLOWED      = Color3.fromRGB(120,185,255),
	BURNING     = Color3.fromRGB(255,140,40),
	STUNNED     = Color3.fromRGB(255,210,70),
	DAMAGE_AURA = Color3.fromRGB(255,160,60),
	DEFAULT     = Color3.fromRGB(255,255,255),
}

local function billboard(adornee, sizeX, sizeY, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, sizeX, 0, sizeY)
	gui.StudsOffset = Vector3.new((math.random()-0.5)*0.6, offsetY, (math.random()-0.5)*0.6)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Adornee = adornee
	gui.Parent = workspace
	return gui
end

local function ensureAdornee(inst)
	if not inst then return nil end
	if inst:IsA("Model") then
		return inst.PrimaryPart
	end
	return inst
end

-- Damage tal
function FloatingText.ShowDamage(inst, amount, sourceId)
	local adornee = ensureAdornee(inst)
	if not adornee or not adornee:IsA("BasePart") then return end

	local color = COLORS[sourceId] or COLORS.DEFAULT
	local text = tostring(math.floor((tonumber(amount) or 0) + 0.5))

	local gui = billboard(adornee, 100, 40, 3 + (math.random()*0.2))
	gui.Name = "DamageText"

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1,0,1,0)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.TextColor3 = color
	tl.TextTransparency = 0
	tl.TextStrokeTransparency = 0.4
	tl.Parent = gui

	local t1 = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local t2 = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local startOffset = gui.StudsOffset
	local mid = TweenService:Create(gui, t1, { StudsOffset = startOffset + Vector3.new(0, 0.35, 0) })
	mid:Play()
	mid.Completed:Connect(function()
		local fade = TweenService:Create(gui, t2, { StudsOffset = startOffset + Vector3.new(0, 1.2, 0) })
		fade:Play()
		TweenService:Create(tl, t2, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)

	Debris:AddItem(gui, 0.6)
end

-- Debuff/status tekst (fx "SLOWED", "BURNING")
function FloatingText.ShowDebuff(inst, token)
	local adornee = ensureAdornee(inst)
	if not adornee or not adornee:IsA("BasePart") then return end

	local color = STYLE_COLORS[token] or STYLE_COLORS.DEFAULT
	local gui = billboard(adornee, 110, 32, 3.2)
	gui.Name = "StatusText"

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1,0,1,0)
	tl.BackgroundTransparency = 1
	tl.Text = tostring(token or "")
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.TextColor3 = color
	tl.TextTransparency = 0
	tl.TextStrokeTransparency = 0.25
	tl.Parent = gui

	local t = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, t, { StudsOffset = gui.StudsOffset + Vector3.new(0, 1.1, 0) }):Play()
	TweenService:Create(tl, t, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	Debris:AddItem(gui, 0.9)
end

-- Alias (nogle evner kalder ShowStatus)
FloatingText.ShowStatus = FloatingText.ShowDebuff

return FloatingText

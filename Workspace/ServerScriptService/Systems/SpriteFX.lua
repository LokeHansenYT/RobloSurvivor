-- Systems/SpriteFX.lua  (flat ground sprites by default)
local RunService = game:GetService("RunService")
local Debris     = game:GetService("Debris")
local Workspace  = game:GetService("Workspace")

local SpriteFX = {}


SpriteFX.Assets = setmetatable({}, {
	__index = function(_, k)
		-- prøv både "<Key>Id" og "<Key>"
		local v = Workspace:GetAttribute(tostring(k) .. "Id")
		if v == nil then v = Workspace:GetAttribute(tostring(k)) end
		return v
	end
})


-- === toggles / helpers (bagud-kompatible) ===
local KNOWN_KEYS = { "FireTrail_EmbersId", "ChargedGround_LightningId", "ChargedGround_SparklesId" }
local function anyConfiguredId()
	for _,k in ipairs(KNOWN_KEYS) do
		local v = Workspace:GetAttribute(k)
		if typeof(v) == "number" and v > 0 then return true end
	end
	return false
end

function SpriteFX.useSprites(plr)
	-- spiller-attr > workspace-attr > auto-on hvis vi har et id et sted
	local v = plr and plr:GetAttribute("UseSpriteFX")
	if v ~= nil then return v == true end
	v = Workspace:GetAttribute("UseSpriteFX")
	if v ~= nil then return v == true end
	return anyConfiguredId()
end

function SpriteFX.getTextureIdFrom(attrs, fallback)
	if typeof(attrs) == "string" then attrs = {attrs} end
	for _,name in ipairs(attrs or {}) do
		local v = Workspace:GetAttribute(name)
		if typeof(v) == "number" and v > 0 then return v end
	end
	if typeof(fallback) == "number" and fallback > 0 then return fallback end
	return 0
end

-- === interne utils ===
local function resolveId(img)
	if type(img) == "number" then return "rbxassetid://" .. img end
	if type(img) == "string" then
		if img:find("^rbxassetid://") then return img else return "rbxassetid://" .. img end
	end
	if type(img) == "table" then
		return resolveId(img.id or img.image)
	end
	return nil
end

local function num(v, default)
	if type(v) == "number" then return v end
	if type(v) == "string" then local n = tonumber(v); if n then return n end end
	return default
end

-- === SurfaceGui fallback (flad på jorden) ===
local function makeSurface(part, id, frames, rows, fps, ttl, fsize, pps)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 32
	gui.AlwaysOnTop = true
	gui.Adornee = part
	gui.Parent = part
	Debris:AddItem(gui, ttl)

	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1,1)
	img.Image = id or ""
	img.ImageRectSize = Vector2.new(fsize, fsize) -- VIGTIGT: crop pr. tile
	img.Parent = gui

	frames = math.max(1, frames or 1)
	rows   = math.max(1, rows   or 1)
	local cols  = math.max(1, math.floor(frames/rows + 0.5))
	local start = os.clock()
	local hb; hb = RunService.Heartbeat:Connect(function()
		if not gui.Parent or not part.Parent then hb:Disconnect(); return end
		if os.clock() - start >= ttl then hb:Disconnect(); gui:Destroy(); return end
		local f = math.floor((os.clock() - start) * (fps or 12)) % frames
		local r = math.floor(f / cols)
		local c = f % cols
		img.ImageRectOffset = Vector2.new(c * fsize, r * fsize)
	end)
	return gui
end

-- === (valgfri) ParticleEmitter flipbook ===
local function makeFlipbook(pe, frames, rows, fps, fsize)
	-- Nogle Studio-builds bruger Rows/Columns, andre Frames + Size; prøv bredt:
	pcall(function()
		pe.FlipbookMode        = Enum.ParticleFlipbookMode.Loop
		pe.FlipbookLayout      = Enum.ParticleFlipbookLayout.Grid
		pe.FlipbookFramerate   = fps
		pe.FlipbookStartRandom = true
		pe.FlipbookRows        = rows
		pe.FlipbookColumns     = math.max(1, math.floor(frames/rows + 0.5))
		pe.FlipbookFrames      = frames
		pe.FlipbookSize        = Vector2.new(fsize, fsize)
	end)
end

-- === offentlig API ===
function SpriteFX.addFlipbookOrGui(part, a, b)
	-- dual-signature: (part, optsTable)  eller  (part, textureIdNumberOrString, optsTable)
	local opts = {}
	if type(a) == "table" then opts = a else opts = b or {}; opts.image = opts.image or a end

	local id   = resolveId(opts.image) or resolveId(SpriteFX.Assets.Embers)
	local frames = num(opts.frames, (type(opts.image)=="table" and num(opts.image.frames, 8)) or 8)
	local rows   = num(opts.rows,   (type(opts.image)=="table" and num(opts.image.rows,   1)) or 1)
	local fps    = num(opts.fps,    (type(opts.image)=="table" and num(opts.image.fps,   12)) or 12)
	local ttl    = num(opts.ttl, 1)
	local fsize  = num(opts.frameSize, 32)
	local pps    = num(opts.pixelsPerStud, 32)

	-- Default = SurfaceGui (så det ligger fladt). Sæt opts.useFlipbook=true for at prøve ParticleEmitter.
	if opts.useFlipbook ~= true then
		return makeSurface(part, id, frames, rows, fps, ttl, fsize, pps)
	end

	-- ParticleEmitter (bemærk: sprites vil stadig være kamera-billboarded)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture  = id or ""
	pe.Speed    = NumberRange.new(0)
	pe.Rate     = num(opts.rate, 8)
	pe.Lifetime = NumberRange.new(ttl, ttl)
	pe.LightInfluence = 0
	pe.LockedToPart   = true
	pe.Parent = part
	makeFlipbook(pe, frames, rows, fps, fsize)

	-- Hvis flipbook-egenskaber ikke findes i din build, falder vi tilbage til SurfaceGui
	if pe.FlipbookFrames == nil and pe.FlipbookColumns == nil then
		pe.Enabled = false
		pe:Destroy()
		return makeSurface(part, id, frames, rows, fps, ttl, fsize, pps)
	end

	task.delay(ttl + 0.05, function() if pe then pe.Enabled=false; pe:Destroy() end end)
	return pe
end

return SpriteFX

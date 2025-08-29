-- ServerScriptService/Enemies/EnemyStatus.server.lua
-- Live status-tekst over Enemy-modeller.
-- Viser "Evolving..." (animeret) hvis StunnedUntil & FusedUntil er aktive (fusion-stun),
-- ellers almindelig "stunned" for andre stuns. Viser også "slowed"/"burning" m.m.

local Workspace   = game:GetService("Workspace")

local TRACK = {}  -- [Model Enemy] = true

local function makeGui(enemyModel: Model, body: BasePart)
	-- Opret/returnér én billboard til status
	local existing = enemyModel:FindFirstChild("StatusBillboard")
	if existing and existing:IsA("BillboardGui") then
		return existing
	end
	local ui = Instance.new("BillboardGui")
	ui.Name = "StatusBillboard"
	ui.Size = UDim2.new(0, 110, 0, 26)
	ui.StudsOffset = Vector3.new(0, 3.8, 0)
	ui.AlwaysOnTop = true
	ui.Adornee = body
	ui.Parent = enemyModel

	local text = Instance.new("TextLabel")
	text.Name = "StatusLabel"
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 1, 0)
	text.TextScaled = true
	text.Font = Enum.Font.Gotham
	text.TextColor3 = Color3.fromRGB(255, 230, 120)
	text.Text = ""
	text.Parent = ui

	return ui
end

-- Returnér en tabel af tokens + flag om fusion-stun
local function collectStatusTokens(body: BasePart)
	local now = os.clock()
	local tokens = {}

	-- fusion-stun?
	local stunnedUntil = body:GetAttribute("StunnedUntil")
	local fusedUntil   = body:GetAttribute("FusedUntil")
	local fusionActive = (type(stunnedUntil)=="number" and stunnedUntil > now)
		and (type(fusedUntil)  =="number" and fusedUntil   > now)

	if not fusionActive then
		-- almindelig stun (fx elektricitet)
		if type(stunnedUntil)=="number" and stunnedUntil > now then
			table.insert(tokens, "stunned")
		end
	end

	-- øvrige effekter
	local burningUntil = body:GetAttribute("BurningUntil")
	if type(burningUntil)=="number" and burningUntil > now then
		table.insert(tokens, "burning")
	end

	local slowedUntil = body:GetAttribute("SlowedUntil")
	if type(slowedUntil)=="number" and slowedUntil > now then
		table.insert(tokens, "slowed")
	end

	return tokens, fusionActive
end

local function ensureTracked(enemyModel: Model)
	if TRACK[enemyModel] then return end
	local body = enemyModel:FindFirstChild("Body")
	if not (body and body:IsA("BasePart")) then return end

	local ui = makeGui(enemyModel, body)
	local label = ui and ui:FindFirstChild("StatusLabel")

	local function refresh()
		if not (ui and label and label:IsA("TextLabel") and body.Parent) then return end
		local tokens, isFusion = collectStatusTokens(body)
		if isFusion then
			-- Lille "…"-animation baseret på tid
			local n = (math.floor(os.clock()*3) % 3) + 1
			label.Text = "Evolving" .. string.rep(".", n)
		else
			label.Text = (#tokens > 0) and table.concat(tokens, ", ") or ""
		end
	end

	-- Reager på relevante attribute-ændringer
	for _,attr in ipairs({ "StunnedUntil","FusedUntil","BurningUntil","SlowedUntil" }) do
		body:GetAttributeChangedSignal(attr):Connect(refresh)
	end

	-- Løbende polling, så ellipsis kan animeres (og hvis flere felter ændres på én gang)
	task.spawn(function()
		while enemyModel.Parent do
			refresh()
			task.wait(0.25)
		end
	end)

	TRACK[enemyModel] = true
end

-- Hoved-loop: opdag nye fjender
task.spawn(function()
	while true do
		task.wait(0.5)
		local root = Workspace:FindFirstChild("ZoneEnemies")
		if not root then continue end
		for _, zoneFolder in ipairs(root:GetChildren()) do
			for _, m in ipairs(zoneFolder:GetChildren()) do
				if m:IsA("Model") and m.Name == "Enemy" then
					ensureTracked(m)
				end
			end
		end
	end
end)

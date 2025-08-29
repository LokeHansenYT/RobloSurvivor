-- StarterPlayerScripts/VendorShop.client.lua
-- Vendor UI: større vindue, centreret titel, "Close" i bundbjælke under de 3 kort.
-- Bevarer eksisterende remotes og købslogik.

local Rep = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Remotes (kræver InitRemotes.server.lua kører på serveren)
local Remotes = Rep:WaitForChild("Remotes")
local EvOpen  = Remotes:WaitForChild("VendorOpen")
local EvBuy   = Remotes:WaitForChild("VendorBuy")
local EvClose = Remotes:WaitForChild("VendorClose")
local GetOffers = Remotes:WaitForChild("VendorGetOffers") -- RemoteFunction

-- (Valgfrit legacy-alias: lyt kun hvis den findes)
local EvLegacyOpen = Remotes:FindFirstChild("OpenSpendFromVendor")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- holder buy-button connections pr. kort, så vi kan disconnecte dem ved næste åbning
local buyConnections = {}

local function makeGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VendorShopGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	-- === Root frame (Chrome) ===
	local frame = Instance.new("Frame")
	frame.Name = "Chrome"  -- VIGTIGT: så Gui.Chrome.* virker
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(760, 360) -- større panel
	frame.BackgroundColor3 = Color3.fromRGB(22,24,28)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0,12)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(60, 70, 90)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = frame

	-- === Titel (centreret) ===
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = "Shop"
	title.TextColor3 = Color3.fromRGB(230,235,245)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 6)
	title.Size = UDim2.new(1, -40, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = frame

	-- === Kort-listen (giver plads til footer nederst) ===
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.AnchorPoint = Vector2.new(0.5, 0)
	list.Position = UDim2.new(0.5, 0, 0, 52)
	list.Size = UDim2.new(1, -28, 1, -120) -- plads til titel + footer
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 12)
	layout.Parent = list

	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 6)
	listPad.PaddingBottom = UDim.new(0, 6)
	listPad.PaddingLeft = UDim.new(0, 6)
	listPad.PaddingRight = UDim.new(0, 6)
	listPad.Parent = list

	local function makeCard()
		local c = Instance.new("Frame")
		c.Size = UDim2.new(1/3, -8, 1, 0)
		c.BackgroundColor3 = Color3.fromRGB(34,38,46)
		c.BackgroundTransparency = 0.1
		c.BorderSizePixel = 0
		Instance.new("UICorner", c).CornerRadius = UDim.new(0,10)

		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(235,236,244)
		t.Text = "Item"
		t.Position = UDim2.fromOffset(10,8)
		t.Size = UDim2.new(1, -20, 0, 28)
		t.Parent = c

		local d = Instance.new("TextLabel")
		d.Name = "Desc"
		d.BackgroundTransparency = 1
		d.Font = Enum.Font.Gotham
		d.TextScaled = true
		d.TextWrapped = true
		d.TextColor3 = Color3.fromRGB(200,205,215)
		d.Text = ""
		d.Position = UDim2.fromOffset(10, 44)
		d.Size = UDim2.new(1, -20, 1, -96)
		d.Parent = c

		local b = Instance.new("TextButton")
		b.Name = "Buy"
		b.Text = "Buy"
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.TextColor3 = Color3.fromRGB(245,245,250)
		b.BackgroundColor3 = Color3.fromRGB(60,64,82)
		b.Size = UDim2.fromOffset(120, 34)
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, 0, 1, -10)
		b.Parent = c
		Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)

		return c
	end

	for _=1,3 do
		makeCard().Parent = list
	end

	-- === Footer med Close-knap (centreret) ===
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.new(0.5, 0, 1, -8)
	footer.Size = UDim2.new(1, -28, 0, 50)
	footer.Parent = frame

	local footLay = Instance.new("UIListLayout")
	footLay.FillDirection = Enum.FillDirection.Horizontal
	footLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	footLay.VerticalAlignment = Enum.VerticalAlignment.Center
	footLay.Padding = UDim.new(0, 8)
	footLay.Parent = footer

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "Close"
	close.Font = Enum.Font.GothamBold
	close.TextScaled = true
	close.Size = UDim2.fromOffset(140, 36)
	close.BackgroundColor3 = Color3.fromRGB(55,60,75)
	close.TextColor3 = Color3.fromRGB(235,236,244)
	close.Parent = footer
	Instance.new("UICorner", close).CornerRadius = UDim.new(0,8)
	close.MouseButton1Click:Connect(function() gui.Enabled = false end)

	return gui
end

local Gui = playerGui:FindFirstChild("VendorShopGui") or makeGui()

local currentCost = 0
local currentType = ""

local function setTitleAndOffers(vendorType, offers, cost)
	currentType = vendorType or ""
	currentCost = tonumber(cost) or 0

	Gui.Enabled = true
	Gui.Chrome.Title.Text = string.format("%s — Cost: %d SP", currentType, currentCost)

	-- ryd gamle connections
	for i,conn in ipairs(buyConnections) do
		if conn and conn.Connected then conn:Disconnect() end
		buyConnections[i] = nil
	end

	-- opdater kort
	local cards = {}
	for _,child in ipairs(Gui.Chrome.List:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChild("Buy") then
			table.insert(cards, child)
		end
	end

	-- hvis offers mangler, skjul alle kort pænt
	if type(offers) ~= "table" then
		for _,c in ipairs(cards) do c.Visible = false end
		return
	end

	for i,card in ipairs(cards) do
		local o = offers[i]
		if o then
			card.Title.Text = o.title or o.name or ("Choice "..i)
			card.Desc.Text  = o.desc or o.description or ""
			card.Visible = true

			local id = o.id or o.key or tostring(i)
			-- tilmeld klik
			local conn = card.Buy.MouseButton1Click:Connect(function()
				EvBuy:FireServer(currentType, id, currentCost)
			end)
			table.insert(buyConnections, conn)
		else
			card.Visible = false
		end
	end
end

-- Hovedåbner: accepter både payload-table eller (vendorType, offers, cost)
EvOpen.OnClientEvent:Connect(function(a, b, c)
	local vendorType, cost

	if typeof(a) == "table" then
		local payload = a
		vendorType = payload.VendorType or payload.Title or "Vendor"
		cost       = payload.CostSP or payload.cost or 0
	else
		vendorType = a
		cost       = tonumber(c) or tonumber(b) or 0
	end

	-- HENT TILBUD FRA SERVEREN
	local offers
	local ok, result = pcall(function()
		return GetOffers:InvokeServer(vendorType)
	end)
	if ok and result then
		offers = result.offers
		-- Hvis serveren angav en default cost, og din payload ikke havde cost, brug den:
		if (not cost or cost == 0) and result.cost then
			cost = result.cost
		end
	end

	setTitleAndOffers(vendorType, offers, cost)
end)

EvClose.OnClientEvent:Connect(function(msg)
	if msg and #msg > 0 and Gui and Gui.Chrome and Gui.Chrome:FindFirstChild("Title") then
		Gui.Chrome.Title.Text = tostring(msg)
	end
	task.delay(0.6, function()
		if Gui then Gui.Enabled = false end
	end)
end)

-- (Valgfri) Legacy-åbner: hvis din server stadig fyrer OpenSpendFromVendor
if EvLegacyOpen then
	EvLegacyOpen.OnClientEvent:Connect(function(meta)
		if _G.OpenSkillsSpend then
			_G.OpenSkillsSpend()
			return
		end
		setTitleAndOffers(meta and (meta.VendorType or meta.Title) or "Vendor", nil, meta and meta.CostSP or 0)
	end)
end

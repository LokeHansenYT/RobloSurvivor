-- StarterPlayerScripts/StarterLoadout.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer

local remFolder = ReplicatedStorage:WaitForChild("Remotes")
local StarterChoiceEvent = remFolder:WaitForChild("StarterChoice")
local ApplyStarterChoice = remFolder:WaitForChild("ApplyStarterChoice")

-- UI byggefunktion (simpel, pæn og responsiv)
local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "StarterLoadoutGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(520, 360)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0, 16)
	local stroke = Instance.new("UIStroke", frame); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(50,50,50)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 40)
	title.Position = UDim2.fromOffset(12, 12)
	title.BackgroundTransparency = 1
	title.Text = "Vælg et start-våben"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.Parent = frame

	local gridHolder = Instance.new("Frame")
	gridHolder.BackgroundTransparency = 1
	gridHolder.Position = UDim2.fromOffset(12, 60)
	gridHolder.Size = UDim2.new(1, -24, 1, -110)
	gridHolder.Parent = frame

	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.CellSize = UDim2.new(0.5, -10, 0, 60)
	grid.FillDirectionMaxCells = 2
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.Parent = gridHolder

	local bottomBar = Instance.new("Frame")
	bottomBar.BackgroundTransparency = 1
	bottomBar.Size = UDim2.new(1, -24, 0, 40)
	bottomBar.Position = UDim2.new(0, 12, 1, -48)
	bottomBar.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 1, 0)
	hint.BackgroundTransparency = 1
	hint.Text = "Du er udødelig mens menuen er åben."
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(190,190,190)
	hint.Parent = bottomBar

	return gui, frame, gridHolder, grid
end

-- Beskrivende tekst (valgfrit)
local SHORT_DESC = {
	WEAPON_AURA    = "Skader tæt på dig i ticks.",
	WEAPON_SHIELD  = "Kugler i kredsløb, skubber og skader.",
	WEAPON_HEAL    = "Healer dig/nære spillere periodisk.",
	WEAPON_SLOWORB = "Langsom orb der rammer og skubber.",
	WEAPON_MINE    = "Lægger miner der eksploderer i radius.",
	WEAPON_FAN     = "Hurtige projektiler i en vifte.",
}

local ui, frame, gridHolder, grid = buildGui()
ui.Parent = lp:WaitForChild("PlayerGui")
frame.Visible = false

local btnConns = {}
local function clearConns()
	for _,c in ipairs(btnConns) do if c and c.Disconnect then c:Disconnect() end end
	btnConns = {}
end

StarterChoiceEvent.OnClientEvent:Connect(function(payload)
	clearConns()
	for _,child in ipairs(gridHolder:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local clicked = false
	for _,opt in ipairs(payload.choices or {}) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromScale(1, 0)
		btn.AutomaticSize = Enum.AutomaticSize.Y
		btn.BackgroundColor3 = Color3.fromRGB(30,30,30)
		btn.AutoButtonColor = true
		btn.TextWrapped = true
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Parent = gridHolder

		local bCorner = Instance.new("UICorner", btn); bCorner.CornerRadius = UDim.new(0,10)
		local bStroke = Instance.new("UIStroke", btn); bStroke.Thickness = 1; bStroke.Color = Color3.fromRGB(60,60,60)

		local nameL = Instance.new("TextLabel")
		nameL.BackgroundTransparency = 1
		nameL.Size = UDim2.new(1, -16, 0, 26)
		nameL.Position = UDim2.fromOffset(12, 6)
		nameL.Font = Enum.Font.GothamBold
		nameL.TextColor3 = Color3.fromRGB(235,235,235)
		nameL.TextSize = 18
		nameL.TextXAlignment = Enum.TextXAlignment.Left
		nameL.Text = opt.name
		nameL.Parent = btn

		local desc = Instance.new("TextLabel")
		desc.BackgroundTransparency = 1
		desc.TextWrapped = true
		desc.Size = UDim2.new(1, -16, 0, 24)
		desc.Position = UDim2.fromOffset(12, 30)
		desc.Font = Enum.Font.Gotham
		desc.TextColor3 = Color3.fromRGB(170,170,170)
		desc.TextSize = 14
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Text = SHORT_DESC[opt.id] or ""
		desc.Parent = btn

		local conn = btn.MouseButton1Click:Connect(function()
			if clicked then return end
			clicked = true
			frame.Visible = false
			ApplyStarterChoice:FireServer(opt.id)
		end)
		table.insert(btnConns, conn)
	end

	frame.Visible = true
end)

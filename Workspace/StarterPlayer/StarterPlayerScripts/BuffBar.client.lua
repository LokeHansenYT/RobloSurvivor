-- StarterPlayerScripts/BuffBar.client.lua
-- Viser simple buff-ikoner m. stacks/timer. Lytter på Player Attributes.
local plr = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui"); gui.Name="BuffBar"; gui.ResetOnSpawn=false; gui.Parent=plr:WaitForChild("PlayerGui")
local holder = Instance.new("Frame"); holder.BackgroundTransparency=1; holder.Size=UDim2.new(0,400,0,48); holder.Position=UDim2.new(0.5,-200,0,8); holder.Parent=gui
local layout = Instance.new("UIListLayout", holder); layout.FillDirection=Enum.FillDirection.Horizontal; layout.Padding=UDim.new(0,8)

local function makeIcon(name, assetId)
	local f = Instance.new("Frame"); f.Name=name; f.Size=UDim2.new(0,48,0,48); f.BackgroundTransparency=0.2; f.BackgroundColor3=Color3.fromRGB(20,20,26)
	local corner = Instance.new("UICorner", f); corner.CornerRadius = UDim.new(0,10)
	local img = Instance.new("ImageLabel", f); img.BackgroundTransparency=1; img.Size=UDim2.fromScale(1,1); img.Image = assetId or "rbxassetid://0"
	local stack = Instance.new("TextLabel", f); stack.BackgroundTransparency=1; stack.Size=UDim2.new(1,0,0,14); stack.Position=UDim2.new(0,0,1,-14)
	stack.Font=Enum.Font.GothamBold; stack.TextScaled=true; stack.TextColor3=Color3.fromRGB(240,240,255); stack.Text="x1"
	local bar = Instance.new("Frame", f); bar.Size=UDim2.new(1,0,0,3); bar.Position=UDim2.new(0,0,1,-3); bar.BorderSizePixel=0; bar.BackgroundColor3=Color3.fromRGB(180,160,40)
	return f, stack, bar
end

local siphon, siphonStackLbl, siphonBar = makeIcon("Siphon","rbxassetid://0") -- skift til dit ikon
siphon.Visible=false; siphon.Parent=holder

local function tickBuffIcons()
	local now=os.clock()

	-- Siphon
	local untilT = tonumber(plr:GetAttribute("Buff_Siphon_Until") or 0)
	if now < untilT then
		local stacks = tonumber(plr:GetAttribute("Buff_Siphon_Stacks") or 0)
		siphon.Visible = true
		siphonStackLbl.Text = "x"..tostring(stacks)
		local durLeft = math.max(0, untilT - now)
		local baseDur = 8 -- groft skøn (visuelt); du kan gemme varighed pr. tildeling hvis du vil
		siphonBar.Size = UDim2.new(math.clamp(durLeft/baseDur,0,1),0,0,3)
	else
		siphon.Visible = false
	end
end

for _,a in ipairs({"Buff_Siphon_Until","Buff_Siphon_Stacks"}) do
	plr:GetAttributeChangedSignal(a):Connect(tickBuffIcons)
end
task.spawn(function()
	while true do tickBuffIcons(); task.wait(0.25) end
end)
tickBuffIcons()

-- StarterPlayerScripts/HUDBottom.client.lua
local Players = game:GetService("Players")
local Rep     = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer

-- ====== Layout config ======
local PADDING_X, PADDING_Y = 10, 8
local ROW_H       = 18
local BAR_H       = 74
local CORNER      = 12
local COL1_W      = 210 -- stats
local COL2_W      = 180 -- currencies
local COL4_W      = 220 -- zone stats
-- (NY) Lille venstreknap inde i baren
local LIB_BTN_W   = 120
local LIB_BTN_H   = 32
local LIB_INSET   = 8  -- luft til venstre kant

-- ====== Helpers ======
local function mk(parent, className, props)
	local o = Instance.new(className)
	for k,v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end
local function pct(n) return string.format("%d%%", math.floor(n+0.5)) end

-- XP curve (keep in sync with server)
local Prog = require(Rep.Shared:WaitForChild("ProgressionConfig"))
local function xpToNext(level)
	local base   = Prog.XPBase or 50
	local factor = Prog.XPRamp or 1.25
	return math.max(1, math.floor(base * (factor ^ (math.max(0, level-1)))))
end

-- 3 stacked rows
local function threeRows(parent)
	local frame = mk(parent, "Frame", {BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y, Size=UDim2.new(0,100,1,0)})
	mk(frame, "UIListLayout", {FillDirection=Enum.FillDirection.Vertical, Padding=UDim.new(0,4), HorizontalAlignment=Enum.HorizontalAlignment.Left})
	local a = mk(frame, "TextLabel", {
		BackgroundTransparency=1, Size=UDim2.new(1,-4,0,ROW_H),
		TextXAlignment=Enum.TextXAlignment.Left, Font=Enum.Font.GothamSemibold, TextScaled=true,
		TextColor3=Color3.fromRGB(210,225,240),
	})
	local b = a:Clone(); b.Parent = frame
	local c = a:Clone(); c.Parent = frame
	return frame, a, b, c
end

-- ====== Build HUD bar (bottom) ======
local gui = mk(plr:WaitForChild("PlayerGui"), "ScreenGui", {Name="HUDBottom", ResetOnSpawn=false, IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling})

local bar = mk(gui, "Frame", {
	BackgroundColor3=Color3.fromRGB(25,28,33), BackgroundTransparency=0.15,
	Size=UDim2.new(1,-(PADDING_X*2),0,BAR_H),
	Position=UDim2.new(0,PADDING_X,1,-(BAR_H+PADDING_Y)),
})
mk(bar, "UICorner", {CornerRadius=UDim.new(0,CORNER)})
mk(bar, "UIStroke", {Color=Color3.fromRGB(0,0,0), Transparency=0.5, Thickness=1})

-- LILLE h?jreknap (forankret inde i baren)
local libBtn = mk(bar, "TextButton", {
	Size = UDim2.fromOffset(LIB_BTN_W, LIB_BTN_H),
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -LIB_INSET, 1, -LIB_INSET),
	Text = "Skills",
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(235,235,245),
	BackgroundColor3 = Color3.fromRGB(45,65,105),
	AutoButtonColor = true,
})
mk(libBtn, "UICorner", { CornerRadius = UDim.new(0,10) })

-- Indholdet (row) skubbes FRA h?jre, s? der er plads til knappen
local RIGHT_GUTTER = LIB_INSET + LIB_BTN_W + 10
local row = mk(bar, "Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -(RIGHT_GUTTER + PADDING_X), 1, -(PADDING_Y*2)),
	Position = UDim2.new(0, PADDING_X, 0, PADDING_Y),
})
mk(row, "UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0,24),
	HorizontalAlignment = Enum.HorizontalAlignment.Left
})

-- Col 1: stats
local col1, lvlLbl, xpLbl, hpLbl = threeRows(row); col1.Size = UDim2.new(0,COL1_W,1,0)

-- Col 2: wallet
local col2, spLbl, bpLbl, rpLbl = threeRows(row); col2.Size = UDim2.new(0,COL2_W,1,0)

-- Col 3: zone (fast bredde)
local col3, zoneNameLbl, zoneRangeLbl, zoneStatusLbl = threeRows(row)
col3.Size = UDim2.new(0, 320, 1, 0)

-- Col 4: zone stats (Opponents / Time in zone / Ramp Tier)
local col4, oppLbl, timeLbl, rampLbl = threeRows(row)
col4.Size = UDim2.new(0, COL4_W, 1, 0)
oppLbl.Text  = "[Opponents: --]"
timeLbl.Text = "[Time: 00:00:00]"
rampLbl.Text = "[Ramp Tier: 0]"

-- ====== Stats wiring ======
local leader = plr:WaitForChild("leaderstats")
local level  = leader:WaitForChild("Level")
local xpVal  = plr:WaitForChild("XP")

local function refreshStats()
	local L = tonumber(level.Value) or 1
	local need = xpToNext(L)
	local cur  = tonumber(xpVal.Value) or 0
	lvlLbl.Text = string.format("[Lvl: %d]", L)
	xpLbl.Text  = string.format("[Xp: %d/%d %s]", cur, need, pct((cur/math.max(1,need))*100))
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.MaxHealth > 0 then
		hpLbl.Text = string.format("[Hp: %d/%d %s]", math.floor(hum.Health), math.floor(hum.MaxHealth), pct((hum.Health/hum.MaxHealth)*100))
		hpLbl.TextColor3 = Color3.fromRGB(120,245,150)
	else
		hpLbl.Text = "[Hp: --/--]"
	end
end
level:GetPropertyChangedSignal("Value"):Connect(refreshStats)
xpVal:GetPropertyChangedSignal("Value"):Connect(refreshStats)
plr.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then
		hum:GetPropertyChangedSignal("Health"):Connect(refreshStats)
		hum:GetPropertyChangedSignal("MaxHealth"):Connect(refreshStats)
	end
	refreshStats()
end)
refreshStats()

-- ====== Wallet wiring ======
local sp = plr:FindFirstChild("SkillPoints") or Instance.new("IntValue", plr); sp.Name="SkillPoints"

-- BP: prim?rt leaderstats.BP, fallback BossPoints (s? EnemySpawner/leaderboard og HUD matcher)
local function getBPRef()
	local ls = plr:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("BP")
	if not v then
		v = plr:FindFirstChild("BossPoints")
		if not v then v = Instance.new("IntValue", plr); v.Name = "BossPoints" end
	end
	return v
end
local bp = getBPRef()

local rp = plr:FindFirstChild("RebirthPoints") or Instance.new("IntValue", plr); rp.Name="RebirthPoints"

local function refreshWallet()
	spLbl.Text = ("[Sp: %d]"):format(sp.Value)
	bpLbl.Text = ("[Bp: %d]"):format(bp.Value)
	rpLbl.Text = ("[Rp: %d]"):format(rp.Value)
end
for _,v in ipairs({sp,bp,rp}) do v:GetPropertyChangedSignal("Value"):Connect(refreshWallet) end
refreshWallet()


-- ====== Zone wiring (server sets attributes on player) ======
local function refreshZone()
	local name = plr:GetAttribute("ZoneName") or "Unknown Area"
	local minL = tonumber(plr:GetAttribute("ZoneMinLvl")) or 1
	local maxL = tonumber(plr:GetAttribute("ZoneMaxLvl")) or 9999
	local safe = plr:GetAttribute("ZoneIsSafe") == true
	zoneNameLbl.Text   = ("[%s]"):format(name)
	zoneRangeLbl.Text  = ("[Levels %d-%d]"):format(minL, maxL)
	zoneStatusLbl.Text = safe and "[Safe]" or "[Combat]"
end
for _,a in ipairs({"ZoneName","ZoneMinLvl","ZoneMaxLvl","ZoneIsSafe"}) do
	plr:GetAttributeChangedSignal(a):Connect(refreshZone)
end
refreshZone()

-- zone stats (monsters, time, ramp)
local function fmtHMS(sec)
	sec = math.max(0, math.floor(tonumber(sec) or 0))
	local h = math.floor(sec/3600); local m = math.floor((sec%3600)/60); local s = sec%60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function refreshZoneStats()
	local opp  = tonumber(plr:GetAttribute("ZoneOpponents")) or 0
	local tier = tonumber(plr:GetAttribute("ZoneRampTier")) or 0
	local enterAt = tonumber(plr:GetAttribute("ZoneEnterAt")) or 0
	local now = os.time()
	oppLbl.Text  = ("[Opponents: %d]"):format(opp)
	timeLbl.Text = ("[Time: %s]"):format(fmtHMS(now - enterAt))
	rampLbl.Text = ("[Ramp Tier: %d]"):format(tier)
end

for _,a in ipairs({"ZoneOpponents","ZoneRampTier","ZoneEnterAt"}) do
	plr:GetAttributeChangedSignal(a):Connect(refreshZoneStats)
end
-- opdater l?bende tidst?ller
task.spawn(function()
	while true do
		refreshZoneStats()
		task.wait(1)
	end
end)
refreshZoneStats()


-- =================================================================
-- ==============  Skills Library (dynamic)  =======================
-- =================================================================
local SkillsCatalog = require(Rep.Shared:WaitForChild("SkillsCatalog"))

-- helpers for library
local function catalogList()
	local t = SkillsCatalog.All
	return (type(t)=="function") and t() or t
end

local upgradesFolder; local libGui; local grid; local cards = {}
local function levelFor(ab)
	upgradesFolder = upgradesFolder or plr:FindFirstChild("Upgrades")
	if not upgradesFolder then return 0 end
	local key
	if ab.levelKey then key = ab.levelKey
	elseif ab.id then key = ab.id.."Level"
	end
	if not key then return 0 end
	local v = upgradesFolder:FindFirstChild(key)
	return (v and tonumber(v.Value)) or 0
end

local function ensureLibraryGui()
	if libGui then return end
	libGui = mk(plr.PlayerGui, "ScreenGui", {Name="SkillsLibraryGui", ResetOnSpawn=false, Enabled=false})
	local modal = mk(libGui, "Frame", {
		BackgroundColor3=Color3.fromRGB(17,18,22), BackgroundTransparency=0.05,
		Size=UDim2.new(0.64,0,0.6,0), Position=UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5),
	})
	mk(modal, "UICorner", {CornerRadius=UDim.new(0,14)})
	mk(modal, "UIStroke", {Color=Color3.fromRGB(0,0,0), Transparency=0.35, Thickness=1})
	mk(modal, "TextLabel", {
		BackgroundTransparency=1, Size=UDim2.new(1,-56,0,40), Position=UDim2.new(0,16,0,12),
		TextXAlignment=Enum.TextXAlignment.Left, Text="Skills (library)", Font=Enum.Font.GothamBold, TextScaled=true,
		TextColor3=Color3.fromRGB(230,235,245),
	})
	local closeBtn = mk(modal, "TextButton", {
		Size=UDim2.new(0,36,0,36), Position=UDim2.new(1,-44,0,8),
		Text="?", Font=Enum.Font.GothamBold, TextScaled=true,
		BackgroundColor3=Color3.fromRGB(45,47,56), TextColor3=Color3.fromRGB(230,235,245),
	})
	mk(closeBtn, "UICorner", {CornerRadius=UDim.new(0,10)})
	closeBtn.MouseButton1Click:Connect(function() libGui.Enabled = false end)

	local scroller = mk(modal, "ScrollingFrame", {
		BackgroundTransparency=1, Size=UDim2.new(1,-24,1,-64), Position=UDim2.new(0,12,0,52),
		CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarImageTransparency=0.3,
	})
	grid = mk(scroller, "UIGridLayout", {CellSize=UDim2.new(0,260,0,110), CellPadding=UDim2.new(0,10,0,10), FillDirectionMaxCells=3})
end

local function buildCardsIfNeeded()
	ensureLibraryGui()
	if next(cards) ~= nil then return end

	for _,ab in ipairs(catalogList()) do
		if not ab.hidden then
			local card = mk(grid.Parent, "Frame", {BackgroundColor3=Color3.fromRGB(28,30,36), Size=UDim2.new(0,260,0,110)})
			mk(card, "UICorner", {CornerRadius=UDim.new(0,10)})
			mk(card, "UIStroke", {Color=Color3.fromRGB(0,0,0), Transparency=0.5, Thickness=1})
			local title = mk(card, "TextLabel", {
				BackgroundTransparency=1, Position=UDim2.new(0,10,0,8), Size=UDim2.new(1,-20,0,24),
				Font=Enum.Font.GothamBold, TextScaled=true, TextXAlignment=Enum.TextXAlignment.Left,
				TextColor3=Color3.fromRGB(235,240,255), Text=(ab.name or ab.title or ab.id or "Skill")
			})
			local desc = mk(card, "TextLabel", {
				BackgroundTransparency=1, Position=UDim2.new(0,10,0,40), Size=UDim2.new(1,-20,1,-50),
				Font=Enum.Font.Gotham, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top,
				TextColor3=Color3.fromRGB(200,205,220), Text=(ab.desc or "")
			})
			local lvlLbl = mk(card, "TextLabel", {
				BackgroundTransparency=1, AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-10,1,-8), Size=UDim2.new(0,80,0,18),
				Font=Enum.Font.GothamSemibold, TextXAlignment=Enum.TextXAlignment.Right, TextScaled=true, TextColor3=Color3.fromRGB(180,185,195),
			})
			cards[ab.id or tostring(ab)] = {frame=card, lvl=lvlLbl, ab=ab}
		end
	end
end

local function refreshAllCards()
	buildCardsIfNeeded()
	for _,info in pairs(cards) do
		local L = levelFor(info.ab)
		info.lvl.Text = ("Level %d"):format(L)
		info.lvl.TextColor3 = (L>0) and Color3.fromRGB(235,245,255) or Color3.fromRGB(180,185,195)
	end
end

-- Button opens / toggles the library
libBtn.MouseButton1Click:Connect(function()
	buildCardsIfNeeded()
	refreshAllCards()
	libGui.Enabled = not libGui.Enabled
end)

-- Keep levels live
plr.ChildAdded:Connect(function(ch) if ch.Name=="Upgrades" then refreshAllCards() end end)

--[[
EnemyFactory.lua — opret fjender (model + part + humanoid) og sæt alle attributes

Formål
  • Samle alt der hører til selve “konstruktionen” af en fjende ét sted.
  • Tilføje HP-billboard.
  • Kun bosser får titel-billboard “BOSS (Tn)” (almindelige mobs har ingen titel).
  • Håndtere DamageTakenMult < 1 som “mitigation” (give-back), som i din spawner.

API
  spawn({ zid:number, pos:Vector3, isBoss:boolean?, zone:Zone }): (enemy:Model?, body:BasePart?, hum:Humanoid?)
    - 'zone' er Zones[zid] fra spawneren (bruges til mods og folderen at placere i).

Afhængigheder
  • ReplicatedStorage.Shared.EnemyConfig (for defaults)
  • Systems/Util.placeOnGround (snap til terræn)
  • CollectionService tagges med "Enemy"

Bemærk
  • Starter IKKE AI — det gør spawneren via EnemyAI.start(...)
]]--

local RS                = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Util         = require(script.Parent:WaitForChild("Util"))
local EnemyConfig  = require(RS.Shared:WaitForChild("EnemyConfig"))

local M = {}

local function makeHPBillboard(body: BasePart, hum: Humanoid)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 80, 0, 30)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = body
	gui.Parent = body.Parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.fromRGB(255,255,255)
	lbl.Parent = gui

	local function upd() lbl.Text = tostring(math.ceil(hum.Health)) end
	upd(); hum.HealthChanged:Connect(upd)
end

local function makeBossTitle(enemy: Model, body: BasePart)
	-- kun bosser får titel
	if body:GetAttribute("IsBoss") ~= true then
		local old = enemy:FindFirstChild("TitleBillboard"); if old then old:Destroy() end
		return
	end

	local gui = enemy:FindFirstChild("TitleBillboard")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name        = "TitleBillboard"
		gui.Size        = UDim2.new(0, 160, 0, 24)
		gui.StudsOffset = Vector3.new(0, 4.2, 0)
		gui.AlwaysOnTop = true
		gui.Adornee     = body
		gui.Parent      = enemy

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1,0,1,0)
		lbl.BackgroundTransparency = 1
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.TextColor3 = Color3.fromRGB(255,180,220)
		lbl.TextStrokeTransparency = 0.5
		lbl.Name = "Text"
		lbl.Parent = gui
	end

	local lbl = gui:FindFirstChildWhichIsA("TextLabel")
	local function refresh()
		local tier = tonumber(body:GetAttribute("Tier")) or 1
		if tier < 1 then tier = 1 end
		lbl.Text = ("BOSS (T%d)"):format(tier)
	end
	refresh()
	body:GetAttributeChangedSignal("Tier"):Connect(refresh)
	body:GetAttributeChangedSignal("IsBoss"):Connect(function()
		if body:GetAttribute("IsBoss") ~= true then
			local b = enemy:FindFirstChild("TitleBillboard"); if b then b:Destroy() end
		else
			refresh()
		end
	end)
end

function M.spawn(args)
	local zid, posWorld, isBoss, z = args.zid, args.pos, args.isBoss, args.zone
	if not z then return nil end

	-- Model + parts
	local enemy = Instance.new("Model"); enemy.Name = "Enemy"
	local body  = Instance.new("Part");  body.Name  = "Body"
	body.Size = Vector3.new(2,2,2)
	body.Anchored, body.CanCollide = false, true
	body.CFrame = CFrame.new(posWorld)
	body.CollisionGroup = "Enemies"
	body.Parent = enemy

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = EnemyConfig.MaxHealth or 20
	hum.Health    = hum.MaxHealth
	hum.Parent    = enemy

	enemy.PrimaryPart = body
	enemy.Parent      = z.enemies
	CollectionService:AddTag(enemy, "Enemy")

	-- Basale attributes (zone-mods)
	body:SetAttribute("ZoneId",          zid)
	body:SetAttribute("MoveSpeedMult",   z.mods and z.mods.SpeedMult       or 1)
	body:SetAttribute("TouchDamageMult", z.mods and z.mods.TouchDamageMult or 1)
	body:SetAttribute("DamageTakenMult", z.mods and z.mods.DamageTakenMult or 1)
	body:SetAttribute("XPMult",          z.mods and z.mods.XPMult          or 1)
	body:SetAttribute("Tier",            isBoss and 1 or 0)     -- bosser = mindst T1
	body:SetAttribute("StunnedUntil",    0)
	body:SetAttribute("IsBoss",          isBoss == true)

	-- BaseXP (til LevelSystem cap)
	local baseXP = (z.inst and z.inst:GetAttribute("BaseXP")) or 1
	body:SetAttribute("BaseXP", baseXP)

	-- HP/skalering fra zone-mods
	if z.mods and z.mods.HpMult and z.mods.HpMult ~= 1 then
		hum.MaxHealth = math.max(1, math.floor(hum.MaxHealth * z.mods.HpMult))
		hum.Health    = hum.MaxHealth
		body.Size     = body.Size * (1 + 0.12 * (z.mods.HpMult - 1))
	end

	-- Boss styling (VISUELT) — kun farve/str.
	if isBoss then
		body.Size  = Vector3.new(3,3,3)
		body.Color = Color3.fromRGB(150,0,180) -- boss-lilla
	else
		-- neutral grå ved T0
		body.Color = Color3.fromRGB(200,200,200)
	end

	-- Placer på terræn + billboards
	Util.placeOnGround(body, { enemy })
	makeHPBillboard(body, hum)
	makeBossTitle(enemy, body)

	-- DamageTakenMult “give-back” (så <1 virker som mitigation)
	local lastH = hum.Health; local adjusting=false
	hum.HealthChanged:Connect(function(h)
		if adjusting then lastH=h return end
		local mult = body:GetAttribute("DamageTakenMult") or 1
		if mult < 1 and h < lastH then
			local delta = lastH - h
			local giveBack = delta * (1 - mult)
			adjusting = true
			hum.Health = math.min(hum.MaxHealth, h + giveBack)
			adjusting = false
		end
		lastH = hum.Health
	end)

	return enemy, body, hum
end

return M

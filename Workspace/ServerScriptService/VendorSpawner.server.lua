-- ServerScriptService/VendorSpawner.server.lua
-- Spawner vendors ud fra parts (Workspace.VendorSpawns eller BaseParts med VendorType-attribute).
-- Sender VendorOpen payload og sætter Player attributes "VendorType" + "VendorCost" til brug på serveren.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local VendorOpen  = Remotes:WaitForChild("VendorOpen")
local VendorClose = Remotes:WaitForChild("VendorClose")

local VendorsFolder = workspace:FindFirstChild("Vendors")
if not VendorsFolder then
	VendorsFolder = Instance.new("Folder")
	VendorsFolder.Name = "Vendors"
	VendorsFolder.Parent = workspace
end

local function normalizeVendorType(raw)
	local vt = string.lower(tostring(raw or ""))
	if vt:find("electric") or vt == "elec" then return "Electric" end
	if vt:find("aura")     then return "Auras" end
	if vt:find("core")     then return "Core3" end
	if vt == "any" or vt:find("random") then return "Random3" end
	return "Random3"
end

local function defaultCostFor(vendorType) -- kun fallback: kan overskrives af attribute CostSP (inkl. 0)
	if vendorType == "Auras" then return 3 end
	if vendorType == "Core3" then return 2 end
	return 1 -- Random3 / Electric
end

local function buildVendorModel(titleText)
	local model = Instance.new("Model")
	model.Name = titleText or "Vendor"

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.Transparency = 1
	hrp.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 2)
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	local hum = Instance.new("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Health = 0
	hum.MaxHealth = 0
	hum.Parent = model

	model.PrimaryPart = hrp

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VendorPrompt"
	prompt.ActionText = "Open shop"
	prompt.ObjectText = titleText or "Vendor"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = head

	local bb = Instance.new("BillboardGui")
	bb.Name = "TitleBillboard"
	bb.Size = UDim2.new(0, 220, 0, 44)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.new(1,1,1)
	lbl.Text = titleText or "Vendor"
	lbl.Parent = bb

	return model, hrp, head, prompt
end

local function readSpawnMeta(spawnPart)
	local rawType     = spawnPart:GetAttribute("VendorType") or spawnPart.Name or "Random3"
	local vendorType  = normalizeVendorType(rawType)

	local title       = spawnPart:GetAttribute("Title") or spawnPart.Name or vendorType
	local requireSafe = spawnPart:GetAttribute("RequireSafeZone")
	if typeof(requireSafe) ~= "boolean" then requireSafe = true end

	local costSP      = spawnPart:GetAttribute("CostSP")
	if typeof(costSP) ~= "number" then
		costSP = defaultCostFor(vendorType) -- kan være 0 hvis sat som attribute; ellers fallback
	end

	return title, vendorType, costSP, requireSafe
end

local function spawnVendorAt(spawnPart)
	local title, vendorType, costSP, requireSafe = readSpawnMeta(spawnPart)

	local model, hrp, head, prompt = buildVendorModel(title)
	model.Parent = VendorsFolder
	model:PivotTo(spawnPart.CFrame + Vector3.new(0, head.Size.Y + 0.25, 0))
	head.CFrame = model.PrimaryPart.CFrame * CFrame.new(0, 2.5, 0)

	local busy = false
	prompt.Triggered:Connect(function(player)
		if busy then return end
		busy = true

		-- TagFilter kan sættes på spawnPart som Attribute eller StringValue child
		local tagRaw = spawnPart:GetAttribute("TagFilter")
		if not tagRaw then
			local sv = spawnPart:FindFirstChild("TagFilter")
			if sv and sv:IsA("StringValue") then tagRaw = sv.Value end
		end
		local tagFilter = tagRaw and tostring(tagRaw) or ""

		if requireSafe and not player:GetAttribute("ZoneIsSafe") then
			VendorClose:FireClient(player, "You can only shop in safe zones.")
			busy = false
			return
		end

		-- Gem kontekst til serverens tilbuds-bygning
		player:SetAttribute("VendorType", vendorType)
		player:SetAttribute("VendorCost", costSP)         -- kan være 0 (gratis)
		player:SetAttribute("VendorTagFilter", tagFilter) -- NY

		-- Åbn UI
		VendorOpen:FireClient(player, {
			Title = title,
			VendorType = vendorType,   -- "Auras" | "Core3" | "Random3" | "Electric"
			CostSP = costSP,
			RequireSafeZone = requireSafe,
		})

		task.delay(0.25, function() busy = false end)
	end)

	spawnPart.AncestryChanged:Connect(function(_, parent)
		if parent == nil then model:Destroy() end
	end)
end


local function getSpawnParts()
	local results = {}
	local container = workspace:FindFirstChild("VendorSpawns")
	if container then
		for _, inst in ipairs(container:GetChildren()) do
			if inst:IsA("BasePart") then table.insert(results, inst) end
		end
	else
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("BasePart") then
				if inst:GetAttribute("VendorType") ~= nil then
					table.insert(results, inst)
				else
					local n = string.lower(inst.Name)
					if n:find("electric") or n:find("aura") or n:find("core") or n:find("random") or n == "any" then
						table.insert(results, inst)
					end
				end
			end
		end
	end
	return results
end

-- Ryd gamle vendors ved Play Solo
for _, m in ipairs(VendorsFolder:GetChildren()) do
	if m:IsA("Model") then m:Destroy() end
end

for _, part in ipairs(getSpawnParts()) do
	spawnVendorAt(part)
end

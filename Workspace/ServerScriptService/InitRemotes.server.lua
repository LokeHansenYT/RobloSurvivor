-- ServerScriptService/InitRemotes.server.lua
-- Sikrer at alle RemoteEvents/RemoteFunctions findes i ReplicatedStorage.Remotes,
-- så klienter aldrig hænger på WaitForChild. Idempotent: opretter kun hvis mangler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Sørg for en fælles "Remotes" mappe
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

-- Hjælpere
local function ensureEvent(name: string)
	local ev = Remotes:FindFirstChild(name)
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = Remotes
	end
	return ev
end

local function ensureFunction(name: string)
	local rf = Remotes:FindFirstChild(name)
	if not rf then
		rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = Remotes
	end
	return rf
end

-- === Vendors (bruges af VendorShop.client & Vendors.server) ===
ensureEvent("VendorOpen")
ensureEvent("VendorBuy")
ensureEvent("VendorClose")
ensureFunction("VendorGetOffers")    -- <- denne manglede og gav Infinite yield

-- (Valgfri bagudkompatibilitet, kun hvis du stadig har gammel kode der lytter på dem)
-- ensureEvent("EvOpen"); ensureEvent("EvBuy"); ensureEvent("EvClose")
-- ensureEvent("OpenSpendFromVendor")

-- === Shrines UI ===
ensureEvent("ShrineShow")
ensureEvent("ShrineHide")

-- === Horde Mode UI ===
ensureEvent("HordeShow")
ensureEvent("HordeHide")
ensureEvent("HordeUpdate")

-- === Globale events UI
ensureEvent("GlobalEventShow")
ensureEvent("GlobalEventHide")

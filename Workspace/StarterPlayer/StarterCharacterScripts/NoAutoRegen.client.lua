-- StarterPlayerScripts/NoAutoRegen.client.lua
-- Ekstra livrem & seler: slår evt. indsprøjtet “Health” LocalScript fra.

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local function nuke(char)
	task.defer(function()
		-- (1) I karakter-modellen
		local h = char:FindFirstChild("Health")
		if h and h:IsA("LocalScript") then
			h.Disabled = true
			h:Destroy()
		end
		-- (2) I PlayerScripts
		local ps = lp:FindFirstChild("PlayerScripts")
		if ps then
			local hs = ps:FindFirstChild("Health")
			if hs and hs:IsA("LocalScript") then
				hs.Disabled = true
				hs:Destroy()
			end
		end
	end)
end

lp.CharacterAdded:Connect(nuke)
if lp.Character then nuke(lp.Character) end

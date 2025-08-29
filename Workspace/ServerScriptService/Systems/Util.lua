--[[
Util.lua  �  f�lles hj�lpefunktioner (ingen spawner-logik)

Form�l
  � Samle generiske hj�lpefunktioner som flere systemer beh�ver, s� de ikke gentages
  � Helt stateless; ingen sideeffekter

Eksporterer
  � groundYAt(xz: Vector3, extraIgnore: {Instance}?): number
      Raycaster lodret ned for at finde �jordens� Y i verdenen (med fornuftig ignore-liste).
  � placeOnGround(part: BasePart, extraIgnore: {Instance}?)
      Snapt en part til terr�net vha. groundYAt.
  � ringRandomAround(origin: Vector3, minR: number, maxR: number): Vector3
      Giver et punkt i en tilf�ldig vinkel i [minR, maxR] fra origin i XZ.

Antagelser
  � Bruges p� serveren. Ingen antagelser om zones � kan anvendes generelt.
  � �extraIgnore� er valgfri og kan indeholde enemy-model m.m., for at undg� at ray rammer sig selv.

Ikke-m�l
  � Ingen gameplay- eller spawner-politik (ingen zoner, ingen AI).

]]--

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local M = {}

function M.groundYAt(xz: Vector3, extraIgnore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local ignore = {}
	for _,pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(ignore, pl.Character) end
	end
	local ze = Workspace:FindFirstChild("ZoneEnemies")
	if ze then table.insert(ignore, ze) end
	if extraIgnore then
		for _,inst in ipairs(extraIgnore) do table.insert(ignore, inst) end
	end
	params.FilterDescendantsInstances = ignore

	local origin = xz + Vector3.new(0, 500, 0)
	local hit    = Workspace:Raycast(origin, Vector3.new(0,-2000,0), params)
	return (hit and hit.Position.Y) or 0
end

function M.placeOnGround(part: BasePart, extraIgnore)
	local pos = part.Position
	local gy  = M.groundYAt(Vector3.new(pos.X,0,pos.Z), extraIgnore)
	part.CFrame = CFrame.new(pos.X, gy + part.Size.Y*0.5, pos.Z)
end

function M.ringRandomAround(origin: Vector3, minR: number, maxR: number): Vector3
	local a = math.random() * math.pi * 2
	local r = math.random(minR*1000, maxR*1000) / 1000
	return origin + Vector3.new(math.cos(a)*r, 0, math.sin(a)*r)
end

return M

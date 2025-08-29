-- ReplicatedStorage/Shared/EnemyConfig.lua
local EnemyConfig = {
	MoveSpeed = 10,
	MaxHealth = 30,
	XPDropped = 5,
	SpawnRadiusMin = 60,
	SpawnRadiusMax = 90,
	SpawnIntervalStart = 2.5, -- sekunder
	SpawnIntervalMin = 0.6,
	SpawnIntervalRamp = 0.98, -- multiplicator pr. bølge
}
return EnemyConfig

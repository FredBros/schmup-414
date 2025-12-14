extends Resource
class_name WaveData

## The absolute time in seconds from the start of the level when this wave should begin.
@export var start_time: float = 0.0

## A list of squadron spawn events for this wave. All spawns, including single enemies, are now handled as squadrons.
@export var squadron_spawn_events: Array[SquadronSpawnEventData]
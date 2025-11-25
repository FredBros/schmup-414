extends Resource
class_name WaveData

## The absolute time in seconds from the start of the level when this wave should begin.
@export var start_time: float = 0.0

## A list of individual enemy spawn events for this wave.
@export var spawn_events: Array[SpawnEventData]
## A list of squadron spawn events for this wave.
@export var squadron_spawn_events: Array[SquadronSpawnEventData]
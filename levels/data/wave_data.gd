extends Resource
class_name WaveData

## Delay in seconds before this wave starts after the previous one ends.
@export var delay_before_start: float = 3.0

## A list of individual enemy spawn events for this wave.
@export var spawn_events: Array[SpawnEventData]
## A list of squadron spawn events for this wave.
@export var squadron_spawn_events: Array[SquadronSpawnEventData]
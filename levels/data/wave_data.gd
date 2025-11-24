extends Resource
class_name WaveData

## Délai en secondes après la fin de la vague précédente avant de lancer celle-ci.
@export var delay_before_start: float = 2.0
## La liste des groupes d'ennemis à faire apparaître dans cette vague.
@export var spawn_events: Array[SpawnEventData]
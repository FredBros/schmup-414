extends Resource
class_name SquadronSpawnEventData

## The delay in seconds after the wave starts before this squadron is spawned.
@export var spawn_delay: float = 0.0

## The type of enemy to use for the squadron members.
@export var enemy_type_id: String

## The movement pattern for the squadron as a whole (the invisible leader).
@export var behavior_pattern: EnemyBehaviorPattern

## The formation pattern that defines the shape of the squadron.
@export var formation_pattern: FormationPattern

@export_group("Path 2D")
## The NodePath to the Path2D node to follow (only for PATH_2D movement).
@export var movement_path: NodePath

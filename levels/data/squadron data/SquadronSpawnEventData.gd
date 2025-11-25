extends Resource
class_name SquadronSpawnEventData

# We copy the SpawnZone enum here for clarity and self-containment.
## Defines the area where the enemy group will appear.
enum SpawnZone {
	# Top Edge
	FULL_TOP, LEFT_HALF_TOP, RIGHT_HALF_TOP, LEFT_THIRD_TOP, CENTER_THIRD_TOP, RIGHT_THIRD_TOP,
	# Bottom Edge
	FULL_BOTTOM, LEFT_HALF_BOTTOM, RIGHT_HALF_BOTTOM, LEFT_THIRD_BOTTOM, CENTER_THIRD_BOTTOM, RIGHT_THIRD_BOTTOM,
	# Left Edge
	FULL_LEFT, TOP_HALF_LEFT, BOTTOM_HALF_LEFT,
	# Right Edge
	FULL_RIGHT,
	# Special
	EXACT_POINT,
	PATH_START # Spawns at the beginning of the assigned Path2D
}

@export_group("Spawning")
## The area where the squadron will appear.
@export var spawn_zone: SpawnZone = SpawnZone.FULL_TOP
## The exact point where the squadron will spawn (only used if spawn_zone is EXACT_POINT).
@export var spawn_point: Vector2
## Random variation applied to the spawn_point.
@export var spawn_point_variation: Vector2

@export_group("Timing")

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

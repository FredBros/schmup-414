extends Resource
class_name SquadronSpawnEventData

# We copy the SpawnZone enum here for clarity and self-containment.
## Defines the area where the enemy group will appear.
enum SpawnZone {
	# Top Edge
	FULL_TOP, ## Spawns anywhere along the top edge of the screen.
	LEFT_HALF_TOP, ## Spawns on the left half of the top screen edge.
	RIGHT_HALF_TOP, ## Spawns on the right half of the top screen edge.
	LEFT_THIRD_TOP, ## Spawns on the left third of the top screen edge.
	CENTER_THIRD_TOP, ## Spawns on the center third of the top screen edge.
	RIGHT_THIRD_TOP, ## Spawns on the right third of the top screen edge.
	# Bottom Edge
	FULL_BOTTOM, ## Spawns anywhere along the bottom edge of the screen.
	LEFT_HALF_BOTTOM, ## Spawns on the left half of the bottom screen edge.
	RIGHT_HALF_BOTTOM, ## Spawns on the right half of the bottom screen edge.
	LEFT_THIRD_BOTTOM, ## Spawns on the left third of the bottom screen edge.
	CENTER_THIRD_BOTTOM, ## Spawns on the center third of the bottom screen edge.
	RIGHT_THIRD_BOTTOM, ## Spawns on the right third of the bottom screen edge.
	# Left Edge
	FULL_LEFT, ## Spawns anywhere along the left edge of the screen.
	TOP_HALF_LEFT, ## Spawns on the top half of the left screen edge.
	BOTTOM_HALF_LEFT, ## Spawns on the bottom half of the left screen edge.
	# Right Edge
	FULL_RIGHT, ## Spawns anywhere along the right edge of the screen.
	# Special
	EXACT_POINT, ## Spawns at a specific point defined by `spawn_point`.
	PATH_START, # Spawns at the beginning of the assigned Path2D
	# Corners (1/4 of each adjacent edge)
	CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT
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

## A sequence of movement patterns for the squadron. The controller will execute them one after another.
@export var sequential_behavior_patterns: Array[EnemyBehaviorPattern]

## A list of timed shooting patterns to assign to all squadron members.
@export var shooting_patterns: Array[TimedShootingPattern]

## The formation pattern that defines the shape of the squadron.
@export var formation_pattern: FormationPattern

@export_group("Path 2D")
## The NodePath to the Path2D node to follow (only for PATH_2D movement).
@export var movement_path: NodePath

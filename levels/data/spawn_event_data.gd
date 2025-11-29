extends Resource
class_name SpawnEventData

## Defines where on the screen enemies will appear for non-Path2D movements.
## The screen is divided for spawning purposes (e.g., LEFT_THIRD_TOP means the left third of the top edge).
enum SpawnZone {
	# --- Top Edge ---
	FULL_TOP, ## Spawns anywhere along the top edge of the screen.
	LEFT_HALF_TOP, ## Spawns on the left half of the top screen edge.
	RIGHT_HALF_TOP, ## Spawns on the right half of the top screen edge.
	LEFT_THIRD_TOP, ## Spawns on the left third of the top screen edge.
	CENTER_THIRD_TOP, ## Spawns on the center third of the top screen edge.
	RIGHT_THIRD_TOP, ## Spawns on the right third of the top screen edge.
	# --- Bottom Edge ---
	FULL_BOTTOM, ## Spawns anywhere along the bottom edge of the screen.
	LEFT_HALF_BOTTOM, ## Spawns on the left half of the bottom screen edge.
	RIGHT_HALF_BOTTOM, ## Spawns on the right half of the bottom screen edge.
	LEFT_THIRD_BOTTOM, ## Spawns on the left third of the bottom screen edge.
	CENTER_THIRD_BOTTOM, ## Spawns on the center third of the bottom screen edge.
	RIGHT_THIRD_BOTTOM, ## Spawns on the right third of the bottom screen edge.
	# --- Left Edge ---
	FULL_LEFT, ## Spawns anywhere along the left edge of the screen.
	TOP_HALF_LEFT, ## Spawns on the top half of the left screen edge.
	BOTTOM_HALF_LEFT, ## Spawns on the bottom half of the left screen edge.
	# --- Right Edge ---
	FULL_RIGHT, ## Spawns anywhere along the right edge of the screen.
	TOP_HALF_RIGHT, ## Spawns on the top half of the right screen edge.
	BOTTOM_HALF_RIGHT, ## Spawns on the bottom half of the right screen edge.
	# --- Special ---
	EXACT_POINT, ## Spawns at a specific point defined by `spawn_point`, with optional variation.
	# --- Corners (1/4 of each adjacent edge) ---
	CORNER_TOP_LEFT, ## Spawns on the top 1/4 of the left edge OR the left 1/4 of the top edge.
	CORNER_TOP_RIGHT, ## Spawns on the top 1/4 of the right edge OR the right 1/4 of the top edge.
	CORNER_BOTTOM_LEFT, ## Spawns on the bottom 1/4 of the left edge OR the left 1/4 of the bottom edge.
	CORNER_BOTTOM_RIGHT ## Spawns on the bottom 1/4 of the right edge OR the right 1/4 of the bottom edge.
}

## Defines the edge of the screen from which a threat originates. Used for radar systems.
enum SpawnEdge {
	TOP,
	LEFT,
	RIGHT,
	BOTTOM,
	UNKNOWN # [OPTIONNAL] For cases like EXACT_POINT where the edge isn't clear.
}


## Delay in seconds after the wave starts before triggering this event.
@export var spawn_delay: float = 0.0

@export_group("Enemy Configuration")
## The type of enemy to spawn (must match a type_id in the EnemyPoolManager).
@export var enemy_type_id: String = "basic_enemy"
## The behavior pattern to use for these enemies.
@export var behavior_pattern: EnemyBehaviorPattern
## A list of timed shooting patterns to assign to these enemies.
@export var shooting_patterns: Array[TimedShootingPattern]
## The number of enemies to spawn in this group.
@export var count: int = 1
## The time interval between each enemy in this group.
@export var interval: float = 0.5

@export_group("Positioning")
## (Path2D Only) The path to follow if the behavior_pattern is of type PATH_2D.
@export var movement_path: NodePath
## (Path2D Only) Starting point on the path (0.0 = start, 1.0 = end).
@export var path_start_point: float = 0.0
## (Path2D Only) Random variation of the starting point (e.g., 0.1 for +/- 10% of the path).
@export var path_start_randomness: float = 0.0
## (Non-Path2D) Defines the spawn area strategy.
@export var spawn_zone: SpawnZone = SpawnZone.FULL_TOP # Default spawn zone
## (Non-Path2D) The specific point to use when spawn_zone is EXACT_POINT.
@export var spawn_point: Vector2 = Vector2(405, -50)
## (Non-Path2D) Random variation in pixels to apply to the spawn_point (for EXACT_POINT).
@export var spawn_point_variation: Vector2 = Vector2.ZERO
## [Optional] Defines the threat origin for the radar. Only used when SpawnZone is EXACT_POINT.
@export var spawn_edge: SpawnEdge = SpawnEdge.UNKNOWN

# We also need to override the get_spawn_edge function to handle this new property.
func get_spawn_edge() -> SpawnEdge:
	# If the zone is an exact point, we trust the manually set edge.
	if spawn_zone == SpawnZone.EXACT_POINT:
		return spawn_edge
	
	# Otherwise, we deduce the edge from the zone name.
	match spawn_zone:
		SpawnZone.FULL_TOP, \
		SpawnZone.LEFT_HALF_TOP, SpawnZone.RIGHT_HALF_TOP, \
		SpawnZone.LEFT_THIRD_TOP, SpawnZone.CENTER_THIRD_TOP, SpawnZone.RIGHT_THIRD_TOP:
			return SpawnEdge.TOP
			
		SpawnZone.FULL_BOTTOM, \
		SpawnZone.LEFT_HALF_BOTTOM, SpawnZone.RIGHT_HALF_BOTTOM, \
		SpawnZone.LEFT_THIRD_BOTTOM, SpawnZone.CENTER_THIRD_BOTTOM, SpawnZone.RIGHT_THIRD_BOTTOM:
			return SpawnEdge.BOTTOM

		SpawnZone.FULL_LEFT, \
		SpawnZone.TOP_HALF_LEFT, SpawnZone.BOTTOM_HALF_LEFT:
			return SpawnEdge.LEFT

		SpawnZone.FULL_RIGHT, \
		SpawnZone.TOP_HALF_RIGHT, SpawnZone.BOTTOM_HALF_RIGHT:
			return SpawnEdge.RIGHT
	
	return SpawnEdge.UNKNOWN
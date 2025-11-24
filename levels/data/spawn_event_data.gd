extends Resource
class_name SpawnEventData

## Delay in seconds after the wave starts before triggering this event.
@export var spawn_delay: float = 0.0

@export_group("Enemy Configuration")
## The type of enemy to spawn (must match a type_id in the EnemyPoolManager).
@export var enemy_type_id: String = "basic_enemy"
## The behavior pattern to use for these enemies.
@export var behavior_pattern: EnemyBehaviorPattern
## The number of enemies to spawn in this group.
@export var count: int = 1
## The time interval between each enemy in this group.
@export var interval: float = 0.5

@export_group("Positioning")
## The path to follow if the behavior_pattern is of type PATH_2D.
@export var movement_path: NodePath
## Starting point on the path (0.0 = start, 1.0 = end).
@export var path_start_point: float = 0.0
## Random variation of the starting point (e.g., 0.1 for +/- 10% of the path).
@export var path_start_randomness: float = 0.0
## Spawn position for non-Path2D movements (e.g., LINEAR, SINUSOIDAL).
@export var spawn_center: Vector2 = Vector2(405, -50)
@export var spawn_area_width: float = 810.0
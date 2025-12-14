extends Resource
class_name EnemyBehaviorPattern

## Defines the type of movement the enemy will perform.
enum MovementType {
	LINEAR, # Moves in a straight line.
	SINUSOIDAL, # Moves in a sine wave pattern.
	PATH_2D, # Follows a pre-defined Path2D.
	STATIONARY, # Stays at its spawn point.
	HOMING, # Chases the player.
	BOUNCE # Bounces off the screen edges.
}

@export_group("General")
## The type of movement the enemy will perform.
@export var movement_type: MovementType = MovementType.LINEAR
## Duration of this behavior segment in seconds. If 0, it's indefinite (or until the squadron is reclaimed).
@export var duration: float = 0.0

@export_group("Rotation")
## If true, the entire formation shape will rotate to face the direction of movement.
@export var rotate_formation: bool = true
## If true, individual member sprites will rotate to align with the movement direction.
@export var rotate_members: bool = true

@export_group("Linear")
## The constant velocity for the LINEAR movement type.
@export var linear_direction: Vector2 = Vector2.DOWN
@export var linear_speed: float = 150.0

@export_group("Sinusoidal")
## The base velocity for the sinusoidal movement.
@export var sinusoidal_direction: Vector2 = Vector2.DOWN
## The base speed for the sinusoidal movement.
@export var sinusoidal_speed: float = 100.0
## The frequency of the sine wave.
@export var sinusoidal_frequency: float = 2.0
## The amplitude (width) of the sine wave.
@export var sinusoidal_amplitude: float = 50.0

@export_group("Homing")
## The base speed of the homing enemy.
@export var homing_speed: float = 120.0
## How quickly the enemy can turn to face the player (in radians per second).
@export var homing_turn_rate: float = 3.0
## Duration of the homing behavior in seconds. If 0, aims once at spawn. If < 0, homes indefinitely.
@export var homing_duration: float = 3.0

@export_group("Bounce")
## The initial velocity for the BOUNCE movement type.
@export var bounce_initial_direction: Vector2 = Vector2(1, 1)
## The speed for the BOUNCE movement type.
@export var bounce_speed: float = 150.0
## How many times the enemy will bounce before flying off-screen. -1 for infinite.
@export var bounce_count: int = 3

@export_group("Path 2D")
## The NodePath to the Path2D node to follow (only for PATH_2D movement).
@export var movement_path: NodePath
## The speed in pixels/second to travel along the path. If > 0, this is used instead of the global 'duration'.
@export var path_speed: float = 0.0

extends Resource
class_name ShootingPattern

## Defines the fundamental type of shooting behavior.
enum ShotType {
	NONE, ## The enemy does not shoot.
	SINGLE, ## Fires a single projectile at a time.
	BURST, ## Fires a rapid burst of several projectiles.
	SPREAD, ## Fires multiple projectiles simultaneously in an arc.
	SPIRAL ## Fires projectiles while continuously rotating the firing angle.
}


@export_group("General")
## The main type of shooting pattern.
@export var shot_type: ShotType = ShotType.NONE
## The projectile scene to be fired.
@export var projectile_scene: PackedScene
## Delay in seconds after the enemy activates before the first shot is fired.
@export var initial_delay: float = 1.0
## Cooldown in seconds between each shot or volley.
@export var cooldown: float = 2.0
## If true, the pattern will aim at the player.
@export var aimed: bool = false


@export_group("Burst Properties", "burst_")
## (Burst) The number of projectiles to fire in a single burst.
@export var burst_count: int = 3
## (Burst) The time delay in seconds between each projectile within a burst.
@export var burst_interval: float = 0.1


@export_group("Spread Properties", "spread_")
## (Spread) The number of projectiles to fire in a single spread.
@export var spread_count: int = 5
## (Spread) The total angle in degrees for the arc of projectiles.
@export var spread_angle: float = 90.0


@export_group("Spiral Properties", "spiral_")
## (Spiral) The speed at which the firing angle rotates, in degrees per second.
@export var spiral_rotation_speed: float = 180.0
## (Spiral) The time delay between each projectile in the spiral.
@export var spiral_interval: float = 0.05
extends Resource
class_name TimedShootingPattern

## A wrapper that assigns timing information to a ShootingPattern.

## The actual shooting pattern to use.
@export var pattern: ShootingPattern

## The time in seconds after the enemy spawns that this pattern should become active.
@export var start_time: float = 0.0

## The time in seconds after the enemy spawns that this pattern should stop.
## If set to 0, the pattern will continue indefinitely after it has started.
@export var end_time: float = 0.0
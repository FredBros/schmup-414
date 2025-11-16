extends Node

class_name Health

signal damaged(damage: int, source: Node)
signal died(source: Node)
signal about_to_die(source: Node)
signal invulnerability_started(source: Node)
signal invulnerability_ended(source: Node)

@export var max_health: int = 3
var current_health: int = 0
@export var invulnerability_duration: float = 0.5
var invulnerable: bool = false

func _ready() -> void:
	current_health = max_health
	SignalManager.emit_signal("health_changed", get_parent(), current_health, max_health)

func take_damage(damage: int, source: Node) -> void:
	if current_health <= 0:
		return

	# Ignore damage if currently invulnerable
	if invulnerable:
		return
	
	current_health -= damage
	emit_signal("damaged", damage, source)
	SignalManager.emit_signal("health_changed", get_parent(), current_health, max_health)
	
	if current_health <= 0:
		# Allow other systems (lives manager) to react and possibly prevent the death
		# by setting the prevent_death flag on this Health instance.
		emit_signal("about_to_die", source)

		if not self.prevent_death:
			emit_signal("died", source)
			die()

	# Start invulnerability frame if configured.
	if invulnerability_duration > 0.0 and not invulnerable:
		invulnerable = true
		emit_signal("invulnerability_started", source)
		await get_tree().create_timer(invulnerability_duration).timeout
		invulnerable = false
		emit_signal("invulnerability_ended", source)

func die() -> void:
	# Par défaut: demander à la scène de nettoyer l'entité
	get_parent().call_deferred("queue_free")

var prevent_death: bool = false

func clear_prevent_death() -> void:
	# Helper used by systems like Lives that want to temporarily prevent death
	# but ensure the flag is cleared after the death-check completes.
	prevent_death = false

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func get_health_percentage() -> float:
	return float(current_health) / float(max_health) * 100.0

func increase_current_health(amount: int) -> void:
	current_health = min(current_health + amount, max_health)

func increase_max_health(amount: int) -> void:
	max_health += amount

extends Node

class_name Health

signal damaged(damage: int, source: Node)
signal died(source: Node)

@export var max_health: int = 3
var current_health: int = 0

func _ready() -> void:
	current_health = max_health
	SignalManager.emit_signal("health_changed", get_parent(), current_health, max_health)

func take_damage(damage: int, source: Node) -> void:
	if current_health <= 0:
		return
	
	current_health -= damage
	emit_signal("damaged", damage, source)
	SignalManager.emit_signal("health_changed", get_parent(), current_health, max_health)
	
	if current_health <= 0:
		emit_signal("died", source)
		die()

func die() -> void:
	# Par défaut: demander à la scène de nettoyer l'entité
	get_parent().call_deferred("queue_free")

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

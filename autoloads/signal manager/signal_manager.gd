extends Node


signal damage_applied(target: Node, damage: int, source: Node)
signal target_died(target: Node, source: Node)
signal health_changed(entity: Node, current_health: int, max_health: int)
signal player_died()
signal entity_damaged(entity: Node, damage: int, source: Node)


func _ready() -> void:
	pass
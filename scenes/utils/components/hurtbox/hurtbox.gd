extends Area2D

@onready var health: Node = null

func _ready() -> void:
	add_to_group("Hurtbox")
	area_entered.connect(_on_area_entered)
	health = get_parent().get_node_or_null("Health")
	if health == null:
		push_error("Hurtbox: No Health node found in parent.")

func _on_area_entered(_area: Area2D) -> void:
	# La logique de dégâts est maintenant gérée par la bullet elle-même
	# Le Hurtbox sert uniquement de zone de collision
	pass

func take_damage(damage: int, source: Node) -> void:
	"""Méthode appelée par les bullets pour appliquer des dégâts"""
	if health and health.has_method("take_damage"):
		health.take_damage(damage, source)
		SignalManager.emit_signal("entity_damaged", get_parent(), damage, source)
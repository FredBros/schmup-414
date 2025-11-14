extends Area2D

@export var damage: int = 1

func _ready() -> void:
	add_to_group("Hitbox")

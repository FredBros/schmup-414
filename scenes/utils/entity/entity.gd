extends CharacterBody2D

class_name Entity

@onready var health_node: Node = $Health

func _ready() -> void:
	if health_node:
		health_node.connect("damaged", Callable(self, "_on_damaged"))
		health_node.connect("died", Callable(self, "_on_die"))

func _on_damaged(_damage: int, _source: Node) -> void:
	# À implémenter dans les classes dérivées
	pass

func _on_die(_source: Node) -> void:
	# À implémenter dans les classes dérivées
	pass
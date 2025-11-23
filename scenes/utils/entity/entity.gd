extends Node2D

class_name Entity

# Utiliser find_child pour trouver le noeud Health de manière robuste.
# Cela fonctionne que "Health" soit un enfant direct (comme dans Player)
# ou un enfant d'un autre noeud (comme dans Enemy).
@onready var health_node: Node = find_child("Health", true, false)

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
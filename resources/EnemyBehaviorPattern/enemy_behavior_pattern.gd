@tool
extends Resource
class_name EnemyBehaviorPattern


# --- Mouvement ---
enum MovementType {
	LINEAR, # Mouvement en ligne droite (comportement par défaut)
	SINUSOIDAL, # Mouvement sinusoïdal sur l'axe X tout en avançant
	PATH_2D # Suivi d'un Path2D (à implémenter)
}
@export var movement_type: MovementType = MovementType.LINEAR

## Pour le mouvement SINUSOIDAL : amplitude et fréquence de l'onde.
@export_group("Sinusoidal Movement")
@export var sine_amplitude: float = 50.0
@export var sine_frequency: float = 1.0

## Pour le mouvement PATH_2D : le chemin à suivre.
@export_group("Path2D Movement")
@export var path: NodePath
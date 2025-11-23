@tool
extends Node2D

## La taille de la zone de jeu à visualiser.
@export var game_size: Vector2 = Vector2(512, 720)
## La couleur du rectangle de délimitation.
@export var debug_color: Color = Color(0, 1, 1, 0.5)


func _draw() -> void:
	# Cette fonction est appelée par le moteur pour dessiner des formes personnalisées.
	# On dessine un rectangle qui commence au point (0,0) et qui a la taille de notre zone de jeu.
	# Le 'false' à la fin signifie que le rectangle n'est pas rempli.
	draw_rect(Rect2(Vector2.ZERO, game_size), debug_color, false, 2.0)
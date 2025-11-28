extends Node

## Un singleton pour stocker les dimensions de la zone de jeu.

# Définissez ici la taille de votre zone de jeu.
# Doit correspondre à la taille de votre "Gamearea" dans MainUI.
const WIDTH: int = 810
const HEIGHT: int = 1080

# Un Rect2 représentant la zone de jeu.
const RECT := Rect2(0, 0, WIDTH, HEIGHT)

@tool
extends Resource
class_name PoolConfig

## Un identifiant unique pour ce type d'ennemi (ex: "zapper", "cruiser").
@export var type_id: String
## La scène PackedScene de l'ennemi à mettre en réserve.
@export var scene: PackedScene
## Le nombre d'instances à créer et à garder en réserve.
@export var size: int = 20
## Le temps de vie en secondes avant qu'un ennemi soit automatiquement rappelé. Mettre à 0 pour une durée de vie infinie.
@export var lifetime: float = 6.0
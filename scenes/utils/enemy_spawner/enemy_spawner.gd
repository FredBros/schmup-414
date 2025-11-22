extends Node2D

## Le type d'ennemi à faire apparaître (doit correspondre à un `type_id` dans l'EnemyPoolManager).
@export var enemy_type_id: String = "basic_enemy"
## La largeur de la zone d'apparition.
@export var spawn_width := 512.0
## Le nombre d'ennemis à faire apparaître par seconde.
@export var spawn_rate: float = 1.0
## Si coché, le spawner commencera à fonctionner automatiquement.
@export var autostart: bool = true

@onready var _spawn_timer: Timer = $SpawnTimer
var _enemy_pool_manager: EnemyPoolManager

func _ready() -> void:
	# Trouve le manager de pool d'ennemis dans la scène.
	# On utilise les groupes pour une approche robuste qui ne dépend pas de la structure de la scène.
	var managers = get_tree().get_nodes_in_group("EnemyPoolManager")
	if not managers.is_empty():
		_enemy_pool_manager = managers[0]
	
	if not _enemy_pool_manager:
		push_error("EnemySpawner n'a pas pu trouver de noeud dans le groupe 'EnemyPoolManager'. Assurez-vous qu'un EnemyPoolManager existe dans la scène et qu'il est dans ce groupe.")
		return
		
	_spawn_timer.wait_time = 1.0 / max(0.01, spawn_rate)
	if autostart:
		_spawn_timer.start()

func _on_spawn_timeout() -> void:
	if not _enemy_pool_manager:
		return

	# 1. Demander un ennemi au pool
	var enemy: Enemy = _enemy_pool_manager.get_enemy(enemy_type_id)
	if not enemy:
		push_warning("Le spawner n'a pas pu obtenir d'ennemi de type '%s' du pool." % enemy_type_id)
		return

	# 2. Positionner l'ennemi
	var x_pos = randf_range(0, spawn_width)
	enemy.global_position = global_position + Vector2(x_pos, 0)
	
	# 3. Activer l'ennemi pour qu'il commence sa vie
	enemy.activate()
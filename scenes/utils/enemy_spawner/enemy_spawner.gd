extends Node2D

## Le type d'ennemi à faire apparaître (doit correspondre à un `type_id` dans l'EnemyPoolManager).
@export var enemy_type_id: String = "basic_enemy"
## La largeur de la zone d'apparition, en pixels.
@export var spawn_width := 810.0
## Le nombre d'ennemis à faire apparaître par seconde.
@export var spawn_rate: float = 1.0
## Si coché, le spawner commencera à fonctionner automatiquement.
@export var autostart: bool = true
## Le pattern de comportement à assigner aux ennemis créés par ce spawner.
@export var behavior_pattern: EnemyBehaviorPattern
## Si vrai, active les logs détaillés dans la console pour le débogage.
@export var debug_mode: bool = false

@onready var _spawn_timer: Timer = $SpawnTimer
@onready var _movement_path: Path2D = get_node_or_null("MovementPath")
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

	# 2. Positionner l'ennemi. La logique dépend du pattern.
	if behavior_pattern and behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.PATH_2D:
		if _movement_path:
			# Pour un Path2D, on ne positionne pas l'ennemi directement.
			if debug_mode: print("--- SPAWNER: Attempting Path2D logic for enemy: ", enemy.name)
			if debug_mode: print("--- SPAWNER: Children of enemy before get_node: ", enemy.get_children())
			# On accède à la référence directe du PathFollower de l'ennemi.
			var path_follower = enemy.get_node("PathFollower")
			if not path_follower:
				if debug_mode: print("--- SPAWNER: FAILED to find 'PathFollower' as a direct child.")
				push_error("L'ennemi '%s' n'a pas de noeud PathFollower." % enemy.name)
				return
				
			if debug_mode: print("--- SPAWNER: SUCCESS! Found PathFollower: ", path_follower)
			if debug_mode: print("--- SPAWNER: PathFollower's current parent: ", path_follower.get_parent())
			# On le détache de son parent actuel (l'ennemi).
			path_follower.get_parent().remove_child(path_follower)
			# On l'attache au Path2D.
			_movement_path.add_child(path_follower) # L'attacher au Path2D
			if debug_mode: print("--- SPAWNER: PathFollower moved. New parent: ", path_follower.get_parent())
		else:
			push_warning("Le pattern PATH_2D est utilisé, mais aucun noeud 'MovementPath' n'a été trouvé comme enfant du spawner.")
			# Fallback sur un positionnement simple
			enemy.global_position = global_position
	else:
		# Pour les autres mouvements, on positionne l'ennemi sur une ligne.
		var x_pos = randf_range(0, spawn_width)
		enemy.global_position = global_position + Vector2(x_pos, 0)
	
	# 3. Activer l'ennemi pour qu'il commence sa vie
	enemy.activate()
	
	# 4. Assigner le pattern de comportement
	if behavior_pattern:
		enemy.set_behavior_pattern(behavior_pattern)
	else:
		# S'il n'y a pas de pattern, on s'assure que l'ennemi n'en a pas d'ancien
		enemy.set_behavior_pattern(null)

extends Node2D

## If true, enables detailed logs in the console for debugging.
@export var debug_mode: bool = false

var _enemy_pool_manager: EnemyPoolManager

func _ready() -> void:
	# The spawner listens for orders from the LevelSequencer.
	# Note: Make sure your LevelSequencer is in the "LevelSequencer" group.
	var sequencers = get_tree().get_nodes_in_group("LevelSequencer")
	if not sequencers.is_empty():
		sequencers[0].request_spawn.connect(_on_spawn_requested)
	else:
		push_warning("EnemySpawner: No node found in the 'LevelSequencer' group. The spawner will not receive any orders.")
	
	# Find the enemy pool manager.
	var managers = get_tree().get_nodes_in_group("EnemyPoolManager")
	if not managers.is_empty():
		_enemy_pool_manager = managers[0]

func _on_spawn_requested(event_data: SpawnEventData) -> void:
	if not _enemy_pool_manager: return
	
	for i in range(event_data.count):
		var enemy: Enemy = _enemy_pool_manager.get_enemy(event_data.enemy_type_id)
		if not enemy:
			push_warning("Spawner: The pool for '%s' is empty." % event_data.enemy_type_id)
			continue
		
		# Apply the behavior pattern
		enemy.set_behavior_pattern(event_data.behavior_pattern)
		
		# Position the enemy
		if event_data.behavior_pattern and event_data.behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.PATH_2D:
			var path_node = get_node_or_null(event_data.movement_path)
			if path_node and path_node is Path2D:
				var path_follower = enemy.get_node("PathFollower")
				path_follower.get_parent().remove_child(path_follower)
				path_node.add_child(path_follower)
				
				var start_offset = event_data.path_start_point + randf_range(-event_data.path_start_randomness, event_data.path_start_randomness)
				path_follower.progress_ratio = clamp(start_offset, 0.0, 1.0)
			else:
				push_warning("Spawner: Path2D not found at path: %s" % event_data.movement_path)
		else:
			# Positioning for non-Path2D movements
			# The spawn area is centered on spawn_center.x and has a width of spawn_area_width.
			var half_width = event_data.spawn_area_width / 2.0
			var x_pos = randf_range(event_data.spawn_center.x - half_width, event_data.spawn_center.x + half_width)
			enemy.global_position = Vector2(x_pos, event_data.spawn_center.y)
		
		enemy.activate()
		
		# Wait for the interval before spawning the next one in the group
		if event_data.interval > 0:
			await get_tree().create_timer(event_data.interval).timeout

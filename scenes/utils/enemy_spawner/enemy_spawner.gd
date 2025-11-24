extends Node2D

## If true, enables detailed logs in the console for debugging.
@export var debug_mode: bool = false

var _enemy_pool_manager: EnemyPoolManager
var _screen_size: Vector2

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
		
	_screen_size = get_viewport_rect().size

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
			# Positioning for non-Path2D movements based on SpawnZone
			var spawn_pos := Vector2.ZERO
			var spawn_offset = 50.0 # Default distance outside the screen
			
			match event_data.spawn_zone:
				# --- Top Edge Spawns ---
				SpawnEventData.SpawnZone.FULL_TOP:
					spawn_pos.x = randf_range(0, _screen_size.x)
					spawn_pos.y = - spawn_offset
				SpawnEventData.SpawnZone.LEFT_HALF_TOP:
					spawn_pos.x = randf_range(0, _screen_size.x / 2.0)
					spawn_pos.y = - spawn_offset
				SpawnEventData.SpawnZone.RIGHT_HALF_TOP:
					spawn_pos.x = randf_range(_screen_size.x / 2.0, _screen_size.x)
					spawn_pos.y = - spawn_offset
				SpawnEventData.SpawnZone.LEFT_THIRD_TOP:
					spawn_pos.x = randf_range(0, _screen_size.x / 3.0)
					spawn_pos.y = - spawn_offset
				SpawnEventData.SpawnZone.CENTER_THIRD_TOP:
					spawn_pos.x = randf_range(_screen_size.x / 3.0, _screen_size.x * 2.0 / 3.0)
					spawn_pos.y = - spawn_offset
				SpawnEventData.SpawnZone.RIGHT_THIRD_TOP:
					spawn_pos.x = randf_range(_screen_size.x * 2.0 / 3.0, _screen_size.x)
					spawn_pos.y = - spawn_offset
				# --- Bottom Edge Spawns ---
				SpawnEventData.SpawnZone.FULL_BOTTOM:
					spawn_pos.x = randf_range(0, _screen_size.x)
					spawn_pos.y = _screen_size.y + spawn_offset
				SpawnEventData.SpawnZone.LEFT_HALF_BOTTOM:
					spawn_pos.x = randf_range(0, _screen_size.x / 2.0)
					spawn_pos.y = _screen_size.y + spawn_offset
				SpawnEventData.SpawnZone.RIGHT_HALF_BOTTOM:
					spawn_pos.x = randf_range(_screen_size.x / 2.0, _screen_size.x)
					spawn_pos.y = _screen_size.y + spawn_offset
				SpawnEventData.SpawnZone.LEFT_THIRD_BOTTOM:
					spawn_pos.x = randf_range(0, _screen_size.x / 3.0)
					spawn_pos.y = _screen_size.y + spawn_offset
				SpawnEventData.SpawnZone.CENTER_THIRD_BOTTOM:
					spawn_pos.x = randf_range(_screen_size.x / 3.0, _screen_size.x * 2.0 / 3.0)
					spawn_pos.y = _screen_size.y + spawn_offset
				SpawnEventData.SpawnZone.RIGHT_THIRD_BOTTOM:
					spawn_pos.x = randf_range(_screen_size.x * 2.0 / 3.0, _screen_size.x)
					spawn_pos.y = _screen_size.y + spawn_offset
				# --- Left Edge Spawns ---
				SpawnEventData.SpawnZone.FULL_LEFT:
					spawn_pos.x = - spawn_offset
					spawn_pos.y = randf_range(0, _screen_size.y)
				SpawnEventData.SpawnZone.TOP_HALF_LEFT:
					spawn_pos.x = - spawn_offset
					spawn_pos.y = randf_range(0, _screen_size.y / 2.0)
				SpawnEventData.SpawnZone.BOTTOM_HALF_LEFT:
					spawn_pos.x = - spawn_offset
					spawn_pos.y = randf_range(_screen_size.y / 2.0, _screen_size.y)
				# --- Right Edge Spawns ---
				SpawnEventData.SpawnZone.FULL_RIGHT:
					spawn_pos.x = _screen_size.x + spawn_offset
					spawn_pos.y = randf_range(0, _screen_size.y)
				# --- Special ---
				SpawnEventData.SpawnZone.EXACT_POINT:
					spawn_pos.x = event_data.spawn_point.x + randf_range(-event_data.spawn_point_variation.x, event_data.spawn_point_variation.x)
					spawn_pos.y = event_data.spawn_point.y + randf_range(-event_data.spawn_point_variation.y, event_data.spawn_point_variation.y)
			
			enemy.global_position = spawn_pos
		
		enemy.activate()
		
		# Wait for the interval before spawning the next one in the group
		if event_data.interval > 0:
			await get_tree().create_timer(event_data.interval).timeout

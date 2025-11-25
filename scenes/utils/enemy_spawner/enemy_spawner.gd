extends Node2D

## If true, enables detailed logs in the console for debugging.
@export var debug_mode: bool = false

## The size in pixels for the corner spawn zones.
const CORNER_ZONE_SIZE = 150.0

var _enemy_pool_manager: EnemyPoolManager
var _level_sequencer: Node
var _screen_size: Vector2

func _ready() -> void:
	# The spawner listens for orders from the LevelSequencer.
	# Note: Make sure your LevelSequencer is in the "LevelSequencer" group.
	var sequencers = get_tree().get_nodes_in_group("LevelSequencer")
	if not sequencers.is_empty():
		_level_sequencer = sequencers[0]
		_level_sequencer.request_spawn.connect(_on_spawn_requested)
		_level_sequencer.request_squadron_spawn.connect(_on_squadron_spawn_requested)
	else:
		push_warning("EnemySpawner: No node found in the 'LevelSequencer' group. The spawner will not receive any orders.")
	
	# Find the enemy pool manager.
	var managers = get_tree().get_nodes_in_group("EnemyPoolManager")
	if not managers.is_empty():
		_enemy_pool_manager = managers[0]
		
	_screen_size = get_viewport_rect().size

func _on_squadron_spawn_requested(event_data: SquadronSpawnEventData) -> void:
	if not _enemy_pool_manager: return
	
	# 1. Get a SquadronController from a pool (we'll assume it's pooled like an enemy)
	# For now, we instantiate it. You should create a pool for it later.
	var controller_scene = preload("res://scenes/squadron/squadron_controller.tscn") # Make sure this path is correct
	var controller: SquadronController = controller_scene.instantiate()
	add_child(controller) # Add it to the scene tree
	
	# 2. Configure the controller
	controller.behavior_pattern = event_data.behavior_pattern
	controller.formation_pattern = event_data.formation_pattern
	
	# 3. Determine the spawn position for the controller (the center of the squadron)
	var spawn_pos := Vector2.ZERO
	var spawn_offset = 50.0 # Default distance outside the screen
	
	# Special case for spawning at the start of a path
	if event_data.spawn_zone == SquadronSpawnEventData.SpawnZone.PATH_START:
		var path_node = get_node_or_null(event_data.movement_path)
		if path_node and path_node is Path2D:
			# Temporarily add a PathFollower to get the start position
			var temp_follower = PathFollow2D.new()
			path_node.add_child(temp_follower)
			temp_follower.progress_ratio = 0.0
			spawn_pos = temp_follower.global_position
			temp_follower.queue_free() # Clean up the temporary node
		else:
			push_warning("Spawner: PATH_START spawn zone selected for squadron, but Path2D not found at path: %s. Spawning at top." % event_data.movement_path)
			spawn_pos = Vector2(_screen_size.x / 2.0, -spawn_offset) # Fallback
	else:
		# Logic for all other spawn zones (copied from _on_spawn_requested)
		match event_data.spawn_zone:
			# --- Top Edge Spawns ---
			SquadronSpawnEventData.SpawnZone.FULL_TOP:
				spawn_pos.x = randf_range(0, _screen_size.x)
				spawn_pos.y = - spawn_offset
			SquadronSpawnEventData.SpawnZone.LEFT_HALF_TOP:
				spawn_pos.x = randf_range(0, _screen_size.x / 2.0)
				spawn_pos.y = - spawn_offset
			SquadronSpawnEventData.SpawnZone.RIGHT_HALF_TOP:
				spawn_pos.x = randf_range(_screen_size.x / 2.0, _screen_size.x)
				spawn_pos.y = - spawn_offset
			SquadronSpawnEventData.SpawnZone.LEFT_THIRD_TOP:
				spawn_pos.x = randf_range(0, _screen_size.x / 3.0)
				spawn_pos.y = - spawn_offset
			SquadronSpawnEventData.SpawnZone.CENTER_THIRD_TOP:
				spawn_pos.x = randf_range(_screen_size.x / 3.0, _screen_size.x * 2.0 / 3.0)
				spawn_pos.y = - spawn_offset
			SquadronSpawnEventData.SpawnZone.RIGHT_THIRD_TOP:
				spawn_pos.x = randf_range(_screen_size.x * 2.0 / 3.0, _screen_size.x)
				spawn_pos.y = - spawn_offset
			# --- Bottom Edge Spawns ---
			SquadronSpawnEventData.SpawnZone.FULL_BOTTOM:
				spawn_pos.x = randf_range(0, _screen_size.x)
				spawn_pos.y = _screen_size.y + spawn_offset
			# (You can add the other bottom thirds/halves here if needed)
			# --- Left Edge Spawns ---
			SquadronSpawnEventData.SpawnZone.FULL_LEFT:
				spawn_pos.x = - spawn_offset
				spawn_pos.y = randf_range(0, _screen_size.y)
			SquadronSpawnEventData.SpawnZone.TOP_HALF_LEFT:
				spawn_pos.x = - spawn_offset
				spawn_pos.y = randf_range(0, _screen_size.y / 2.0)
			SquadronSpawnEventData.SpawnZone.BOTTOM_HALF_LEFT:
				spawn_pos.x = - spawn_offset
				spawn_pos.y = randf_range(_screen_size.y / 2.0, _screen_size.y)
			# --- Right Edge Spawns ---
			SquadronSpawnEventData.SpawnZone.FULL_RIGHT:
				spawn_pos.x = _screen_size.x + spawn_offset
				spawn_pos.y = randf_range(0, _screen_size.y)
			# --- Special ---
			SquadronSpawnEventData.SpawnZone.EXACT_POINT:
				spawn_pos.x = event_data.spawn_point.x + randf_range(-event_data.spawn_point_variation.x, event_data.spawn_point_variation.x)
				spawn_pos.y = event_data.spawn_point.y + randf_range(-event_data.spawn_point_variation.y, event_data.spawn_point_variation.y)
			# --- Corners ---
			SquadronSpawnEventData.SpawnZone.CORNER_TOP_LEFT:
				if randf() < 0.5: # Left edge, top quarter
					spawn_pos.x = - spawn_offset
					spawn_pos.y = randf_range(0, CORNER_ZONE_SIZE)
				else: # Top edge, left quarter
					spawn_pos.x = randf_range(0, CORNER_ZONE_SIZE)
					spawn_pos.y = - spawn_offset
			SquadronSpawnEventData.SpawnZone.CORNER_TOP_RIGHT:
				if randf() < 0.5: # Right edge, top quarter
					spawn_pos.x = _screen_size.x + spawn_offset
					spawn_pos.y = randf_range(0, CORNER_ZONE_SIZE)
				else: # Top edge, right quarter
					spawn_pos.x = randf_range(_screen_size.x - CORNER_ZONE_SIZE, _screen_size.x)
					spawn_pos.y = - spawn_offset
			SquadronSpawnEventData.SpawnZone.CORNER_BOTTOM_LEFT:
				if randf() < 0.5: # Left edge, bottom quarter
					spawn_pos.x = - spawn_offset
					spawn_pos.y = randf_range(_screen_size.y - CORNER_ZONE_SIZE, _screen_size.y)
				else: # Bottom edge, left quarter
					spawn_pos.x = randf_range(0, CORNER_ZONE_SIZE)
					spawn_pos.y = _screen_size.y + spawn_offset
			SquadronSpawnEventData.SpawnZone.CORNER_BOTTOM_RIGHT:
				if randf() < 0.5: # Right edge, bottom quarter
					spawn_pos.x = _screen_size.x + spawn_offset
					spawn_pos.y = randf_range(_screen_size.y - CORNER_ZONE_SIZE, _screen_size.y)
				else: # Bottom edge, right quarter
					spawn_pos.x = randf_range(_screen_size.x - CORNER_ZONE_SIZE, _screen_size.x)
					spawn_pos.y = _screen_size.y + spawn_offset
			_: # Fallback for any other non-implemented zone
				spawn_pos.x = randf_range(0, _screen_size.x)
				spawn_pos.y = - spawn_offset
	
	if debug_mode:
		print(
			"[SPAWNER DEBUG] Spawning SQUADRON. Zone: %s, Calculated Position: (%d, %d)" % [
				SquadronSpawnEventData.SpawnZone.keys()[event_data.spawn_zone],
				spawn_pos.x,
				spawn_pos.y
			]
		)

	controller.global_position = spawn_pos
	
	# 3. Spawn and assign members
	var members: Array[Enemy] = []
	for offset in event_data.formation_pattern.member_offsets:
		var enemy: Enemy = _enemy_pool_manager.get_enemy(event_data.enemy_type_id)
		if not enemy:
			push_warning("Spawner: Pool for '%s' is empty while building a squadron." % event_data.enemy_type_id)
			continue
		
		# The enemy's initial position is its final position in the formation.
		enemy.global_position = spawn_pos + offset
		
		# Set a basic behavior pattern for the enemy itself (e.g., STATIONARY)
		# so it doesn't try to move on its own.
		var stationary_pattern = EnemyBehaviorPattern.new()
		stationary_pattern.movement_type = EnemyBehaviorPattern.MovementType.STATIONARY
		enemy.set_behavior_pattern(stationary_pattern)
		
		# Handle Homing for the entire squadron
		if event_data.behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.HOMING:
			var potential_targets: Array[Node2D] = _level_sequencer.get_player_targets()
			if not potential_targets.is_empty():
				# For a squadron, the CONTROLLER targets the player.
				# We can just pick the first player for simplicity.
				var target = potential_targets[0]
				controller.set_target(target)

		enemy.activate()
		members.append(enemy)

	# 4. Assign the members list to the controller and activate it
	controller.members = members
	controller.activate() # You'll need to create this function in the controller

	# 5. Handle Path2D reparenting for the controller
	if event_data.behavior_pattern and event_data.behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.PATH_2D:
		var path_node = get_node_or_null(event_data.movement_path)
		if path_node and path_node is Path2D:
			# We assume the SquadronController scene has a PathFollow2D node named "PathFollower"
			var path_follower = controller.get_node_or_null("PathFollower")
			if path_follower:
				path_follower.get_parent().remove_child(path_follower)
				path_node.add_child(path_follower)
			else:
				push_warning("Spawner: SquadronController scene is missing a 'PathFollower' child node.")
		else:
			push_warning("Spawner: Path2D not found at path for squadron: %s" % event_data.movement_path)

func _on_spawn_requested(event_data: SpawnEventData) -> void:
	if not _enemy_pool_manager: return
	
	for i in range(event_data.count):
		var enemy: Enemy = _enemy_pool_manager.get_enemy(event_data.enemy_type_id)
		if not enemy:
			push_warning("Spawner: The pool for '%s' is empty." % event_data.enemy_type_id)
			continue
		
		# Apply the behavior pattern
		enemy.set_behavior_pattern(event_data.behavior_pattern)
		
		# If the pattern is HOMING, inject the player target from the sequencer.
		if event_data.behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.HOMING:
			if is_instance_valid(_level_sequencer) and _level_sequencer.has_method("get_player_targets"):
				var potential_targets: Array[Node2D] = _level_sequencer.get_player_targets()
				
				if not potential_targets.is_empty():
					var chosen_target: Node2D = null
					
					if potential_targets.size() == 1:
						# If there's only one player, the choice is easy.
						chosen_target = potential_targets[0]
					else:
						# Find the closest player to the enemy's spawn position.
						var closest_dist_sq = INF
						for target in potential_targets:
							if is_instance_valid(target):
								var dist_sq = enemy.global_position.distance_squared_to(target.global_position)
								if dist_sq < closest_dist_sq:
									closest_dist_sq = dist_sq
									chosen_target = target
					
					if is_instance_valid(chosen_target):
						enemy.set_target(chosen_target)
					else:
						push_warning("EnemySpawner: Could not find a valid closest player for Homing enemy.")
				else:
					push_warning("EnemySpawner: get_player_targets() returned an empty array.")
			else:
				push_warning("EnemySpawner: _level_sequencer is not valid or does not have get_player_targets().")
		
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
				# --- Corners ---
				SpawnEventData.SpawnZone.CORNER_TOP_LEFT:
					if randf() < 0.5: # Left edge, top quarter
						spawn_pos.x = - spawn_offset
						spawn_pos.y = randf_range(0, CORNER_ZONE_SIZE)
					else: # Top edge, left quarter
						spawn_pos.x = randf_range(0, CORNER_ZONE_SIZE)
						spawn_pos.y = - spawn_offset
				SpawnEventData.SpawnZone.CORNER_TOP_RIGHT:
					if randf() < 0.5: # Right edge, top quarter
						spawn_pos.x = _screen_size.x + spawn_offset
						spawn_pos.y = randf_range(0, CORNER_ZONE_SIZE)
					else: # Top edge, right quarter
						spawn_pos.x = randf_range(_screen_size.x - CORNER_ZONE_SIZE, _screen_size.x)
						spawn_pos.y = - spawn_offset
				SpawnEventData.SpawnZone.CORNER_BOTTOM_LEFT:
					if randf() < 0.5: # Left edge, bottom quarter
						spawn_pos.x = - spawn_offset
						spawn_pos.y = randf_range(_screen_size.y - CORNER_ZONE_SIZE, _screen_size.y)
					else: # Bottom edge, left quarter
						spawn_pos.x = randf_range(0, CORNER_ZONE_SIZE)
						spawn_pos.y = _screen_size.y + spawn_offset
				SpawnEventData.SpawnZone.CORNER_BOTTOM_RIGHT:
					if randf() < 0.5: # Right edge, bottom quarter
						spawn_pos.x = _screen_size.x + spawn_offset
						spawn_pos.y = randf_range(_screen_size.y - CORNER_ZONE_SIZE, _screen_size.y)
					else: # Bottom edge, right quarter
						spawn_pos.x = randf_range(_screen_size.x - CORNER_ZONE_SIZE, _screen_size.x)
						spawn_pos.y = _screen_size.y + spawn_offset
			
			enemy.global_position = spawn_pos
		
		enemy.activate()
		
		# Wait for the interval before spawning the next one in the group
		if event_data.interval > 0:
			await get_tree().create_timer(event_data.interval).timeout

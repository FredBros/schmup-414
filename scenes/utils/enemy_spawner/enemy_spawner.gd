extends Node2D

## If true, enables detailed logs in the console for debugging.
@export var debug_mode: bool = false

## The size in pixels for the corner spawn zones.
const CORNER_ZONE_SIZE = 150.0

var _enemy_pool_manager: EnemyPoolManager
var _squadron_pool_manager: SquadronControllerPoolManager
var _level_sequencer: Node
var _screen_size: Vector2

func _ready() -> void:
	# The spawner listens for orders from the LevelSequencer.
	# Note: Make sure your LevelSequencer is in the "LevelSequencer" group.
	var sequencers = get_tree().get_nodes_in_group("LevelSequencer")
	if not sequencers.is_empty():
		_level_sequencer = sequencers[0]
		_level_sequencer.request_squadron_spawn.connect(_on_squadron_spawn_requested)
	else:
		push_warning("EnemySpawner: No node found in the 'LevelSequencer' group. The spawner will not receive any orders.")
	
	# Find the enemy pool manager.
	var managers = get_tree().get_nodes_in_group("EnemyPoolManager")
	if not managers.is_empty():
		_enemy_pool_manager = managers[0]
	
	# Find the squadron controller pool manager.
	_squadron_pool_manager = get_node("/root/squadron_controller_pool_manager")
		
	_screen_size = get_viewport_rect().size

func _on_squadron_spawn_requested(event_data: SquadronSpawnEventData) -> void:
	if not _enemy_pool_manager or not _squadron_pool_manager: return
	
	# 1. Get a SquadronController from the pool.
	var controller: SquadronController = _squadron_pool_manager.get_controller()

	if debug_mode:
		print("[SPAWNER DEBUG] Spawner's parent is: ", get_parent().name, ". Adding controller there.")

	# Reparent the controller from its pool to the main scene ('World').
	controller.reparent(get_parent())
	
	# 2. Configure the controller
	controller.sequential_behavior_patterns = event_data.sequential_behavior_patterns # Utiliser la liste des patterns
	controller.formation_pattern = event_data.formation_pattern
	controller.debug_mode = self.debug_mode # Pass the debug flag
	controller.level_sequencer = _level_sequencer # Passer la référence au LevelSequencer pour le homing
	
	# Apply custom turn speed if defined in the event data.
	# If turn_speed is < 0, the controller will use its own default value.
	if event_data.turn_speed >= 0:
		controller.turn_speed = event_data.turn_speed
	
	# 3. Determine the spawn position for the controller (the center of the squadron)
	var spawn_pos := Vector2.ZERO
	var spawn_offset = 50.0 # Default distance outside the screen
	
	# Special case for spawning at the start of a path
	if event_data.spawn_zone == SquadronSpawnEventData.SpawnZone.PATH_START:
		if not event_data.sequential_behavior_patterns.is_empty():
			var first_pattern: EnemyBehaviorPattern = event_data.sequential_behavior_patterns[0]
			var path_node = get_node_or_null(first_pattern.movement_path)
			if path_node and path_node is Path2D:
				# Temporarily add a PathFollower to get the start position
				var temp_follower = PathFollow2D.new()
				path_node.add_child(temp_follower)
				temp_follower.progress_ratio = 0.0
				spawn_pos = temp_follower.global_position
				temp_follower.queue_free() # Clean up the temporary node
			else:
				push_warning("Spawner: PATH_START spawn zone selected, but Path2D not found at path: %s. Spawning at top." % first_pattern.movement_path)
				spawn_pos = Vector2(_screen_size.x / 2.0, -spawn_offset) # Fallback
		else:
			push_warning("Spawner: PATH_START spawn zone selected, but sequential_behavior_patterns is empty. Spawning at top.")
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
		
		if debug_mode:
			print(
				"[SPAWNER DEBUG] Got enemy '%s' from pool. Is inside tree: %s. Parent: %s" % [
					enemy.name, enemy.is_inside_tree(), "null" if not enemy.get_parent() else enemy.get_parent().name
				]
			)
		
		# Reparent the enemy from the pool manager to be a child of the controller.
		# This simplifies rotation and positioning immensely.
		enemy.reparent(controller)
		
		# The controller will be responsible for activating and positioning the member.
		# We just pass the shooting patterns.
		if not event_data.shooting_patterns.is_empty():
			enemy.set_shooting_patterns(event_data.shooting_patterns)
		
		members.append(enemy)

	# 4. Assign the members list to the controller and activate it
	controller.members = members
	controller.activate() # You'll need to create this function in the controller

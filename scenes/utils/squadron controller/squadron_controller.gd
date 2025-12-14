# File: res://scenes/utils/squadron controller/squadron_controller.gd
# This script should be attached to a Node2D node.

extends Node2D

class_name SquadronController

## Emitted when the controller has finished its lifecycle and should be returned to the pool.
signal reclaimed(controller)

var sequential_behavior_patterns: Array[EnemyBehaviorPattern] = [] # La séquence complète de comportements
var formation_pattern: FormationPattern
var members: Array[Enemy] = []

var _is_reclaimed := false

@onready var _path_follower: PathFollow2D = $PathFollower
var level_sequencer: LevelSequencer # Référence au LevelSequencer pour obtenir les cibles (Homing)
var _player: Node2D # Target for homing

# State variables for specific movement patterns
var velocity: Vector2 = Vector2.ZERO
var _current_behavior_pattern: EnemyBehaviorPattern # Le pattern de comportement actif du segment actuel
var _current_behavior_index: int = 0 # L'index du pattern de comportement actuel dans la séquence
var _current_segment_age: float = 0.0 # L'âge (durée) du segment de comportement actuel
var _sinusoidal_time: float = 0.0
var _bounces_left: int = 0
var _age: float = 0.0

# This will be set by the spawner.
var debug_mode := false

## Speed at which the squadron turns to align with its direction (in radians/sec).
@export var turn_speed: float = 4.0

func activate() -> void:
	"""Activates the controller, resetting its state and making it process."""
	_is_reclaimed = false
	_age = 0.0
	_current_behavior_index = 0
	_current_segment_age = 0.0
	_sinusoidal_time = 0.0
	
	set_physics_process(true)
	
	# Apply the first pattern and immediately update positions once.
	_apply_current_segment_pattern()
	
	_update_members(0.0) # Initial placement without advancing time.
	
	_activate_and_show_members()

func _apply_current_segment_pattern() -> void:
	"""Applique les paramètres du pattern de comportement actuel."""
	if sequential_behavior_patterns.is_empty():
		push_warning("SquadronController: No sequential behavior patterns defined. Reclaiming.")
		_reclaim()
		return

	if _current_behavior_index >= sequential_behavior_patterns.size():
		_reclaim() # Tous les segments sont terminés
		return

	_current_behavior_pattern = sequential_behavior_patterns[_current_behavior_index]
	
	if debug_mode:
		print("[CONTROLLER DEBUG] Activating controller '%s'. Applying segment %d: %s" % [name, _current_behavior_index, EnemyBehaviorPattern.MovementType.keys()[_current_behavior_pattern.movement_type]])

	# Réinitialiser les variables d'état spécifiques aux types de mouvement pour le nouveau segment
	_sinusoidal_time = 0.0 # Réinitialiser pour un nouveau segment sinusoidal
	_bounces_left = 0 # Réinitialiser pour un nouveau segment de rebond

	if _current_behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.BOUNCE:
		velocity = _current_behavior_pattern.bounce_initial_direction.normalized() * _current_behavior_pattern.bounce_speed
		_bounces_left = _current_behavior_pattern.bounce_count
	else:
		velocity = Vector2.ZERO # Réinitialiser la vélocité pour les autres types, elle sera calculée dans _physics_process

	# Gérer le reparenting du Path2D pour le contrôleur si ce segment est Path2D
	if _current_behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.PATH_2D:
		var path_node = get_node_or_null(_current_behavior_pattern.movement_path)
		if path_node and path_node is Path2D:
			if is_instance_valid(_path_follower) and _path_follower.get_parent() != path_node:
				var old_parent = _path_follower.get_parent()
				if old_parent: old_parent.remove_child(_path_follower)
				path_node.add_child(_path_follower)
				_path_follower.progress_ratio = 0.0 # Commencer au début du chemin
		else:
			push_warning("SquadronController: PATH_2D segment specified, but Path2D not found at path: %s" % _current_behavior_pattern.movement_path)
	elif is_instance_valid(_path_follower) and _path_follower.get_parent() != self:
		# Si le segment précédent était Path2D, reparenter PathFollower à soi-même
		var old_parent = _path_follower.get_parent()
		if old_parent: old_parent.remove_child(_path_follower)
		add_child(_path_follower)

func _activate_and_show_members() -> void:
	"""Activates member logic and makes them visible. Called after initial placement."""
	if not formation_pattern: return
	
	for member in members:
		if is_instance_valid(member):
			# Activate internal logic. This sets `is_squadron_member` to true
			# and `set_physics_process(false)`.
			member.activate_logic_only()
			
			# Now that it's in the correct starting position, make it visible.
			# We use call_deferred to make the member visible on the next idle frame.
			# This ensures all positioning is finalized before the enemy is drawn, preventing a one-frame visual glitch.
			member.call_deferred("make_visible")


func set_target(target: Node2D) -> void:
	"""Sets the target for the entire squadron (e.g., for Homing)."""
	_player = target
	for member in members:
		if is_instance_valid(member):
			member.set_target(target)

func deactivate() -> void:
	"""Deactivates the controller and its members for pooling."""
	set_physics_process(false)
	
	# Deactivate and reclaim all members
	for member in members:
		if is_instance_valid(member):
			member.deactivate() # Prepare for pooling
			# The enemy pool manager will handle the actual reclaiming

	members.clear()
	
	# Reset PathFollower if it was reparented
	if is_instance_valid(_path_follower) and _path_follower.get_parent() != self:
		var old_parent = _path_follower.get_parent()
		if old_parent: old_parent.remove_child(_path_follower)
		_path_follower.name = "PathFollower"
		add_child(_path_follower) # Reparent back to self
	
	_current_behavior_pattern = null # Clear current pattern


func _physics_process(delta: float) -> void:
	if not _current_behavior_pattern: # Pas de pattern actif, ou récupéré
		return
	
	_current_segment_age += delta
	_age += delta # Garder une trace de l'âge total si nécessaire pour d'autres choses

	_calculate_velocity(delta)
	
	_update_members(delta)

	# Mettre à jour global_position uniquement si ce n'est pas un mouvement PATH_2D
	if _current_behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.PATH_2D:
		# For Path2D, the controller's position is driven by its PathFollower2D child.
		self.global_position = _path_follower.global_position
		# The controller itself does not rotate. Members will orient themselves.
	else:
		global_position += velocity * delta
		# Rotation is now handled by individual members.
	
	# --- Logique de transition de segment ---
	# Si le segment actuel a une durée définie et que cette durée est écoulée
	if _current_behavior_pattern.duration > 0 and _current_segment_age >= _current_behavior_pattern.duration:
		_current_behavior_index += 1 # Passer au segment suivant
		_current_segment_age = 0.0 # Réinitialiser l'âge du segment
		if _current_behavior_index < sequential_behavior_patterns.size():
			_apply_current_segment_pattern() # Appliquer les paramètres du prochain segment
		else:
			_reclaim() # Tous les segments sont terminés, récupérer le contrôleur

func _calculate_velocity(delta: float) -> void:
	"""Calculates the squadron's velocity based on the current behavior pattern."""
	if not _current_behavior_pattern: return
	
	match _current_behavior_pattern.movement_type:
		EnemyBehaviorPattern.MovementType.LINEAR:
			velocity = _current_behavior_pattern.linear_direction.normalized() * _current_behavior_pattern.linear_speed

		EnemyBehaviorPattern.MovementType.SINUSOIDAL:
			_sinusoidal_time += delta
			var direction = _current_behavior_pattern.sinusoidal_direction.normalized()
			var speed = _current_behavior_pattern.sinusoidal_speed
			var frequency = _current_behavior_pattern.sinusoidal_frequency
			var amplitude = _current_behavior_pattern.sinusoidal_amplitude
			
			velocity = direction * speed
			velocity += direction.orthogonal() * cos(_sinusoidal_time * frequency) * amplitude

		EnemyBehaviorPattern.MovementType.HOMING:
			# Acquire a random target only if we don't have a valid one already.
			# This prevents the squadron from switching targets every frame.
			if not is_instance_valid(_player) and is_instance_valid(level_sequencer) and level_sequencer.has_method("get_player_targets"):
				var potential_targets: Array[Node2D] = level_sequencer.get_player_targets()
				if not potential_targets.is_empty():
					set_target(potential_targets.pick_random()) # Target a random player from the list
			
			var homing_active = true
			if _current_behavior_pattern.homing_duration >= 0 and _current_segment_age >= _current_behavior_pattern.homing_duration:
				homing_active = false
			
			if homing_active and is_instance_valid(_player):
				var direction_to_player = global_position.direction_to(_player.global_position)
				var target_velocity = direction_to_player * _current_behavior_pattern.homing_speed
				# Rotate current velocity towards the player direction using slerp for smooth turning.
				velocity = velocity.slerp(target_velocity, _current_behavior_pattern.homing_turn_rate * delta)
			# If homing is not active or player is invalid, the squadron continues in its last direction.

		EnemyBehaviorPattern.MovementType.BOUNCE:
			if _bounces_left != 0:
				if (global_position.x <= GameArea.RECT.position.x and velocity.x < 0) or \
				   (global_position.x >= GameArea.RECT.end.x and velocity.x > 0):
					velocity.x *= -1
					if _bounces_left > 0: _bounces_left -= 1 # Décrémente si non infini

		EnemyBehaviorPattern.MovementType.PATH_2D:
			var path_node = get_node_or_null(_current_behavior_pattern.movement_path)
			if not (path_node and path_node is Path2D):
				return # Path not valid, warning is printed elsewhere.

			var total_duration: float = 0.0
			
			# New: Use path_speed to calculate duration if available
			if _current_behavior_pattern.path_speed > 0:
				var path_length = path_node.curve.get_baked_length()
				if path_length > 0:
					total_duration = path_length / _current_behavior_pattern.path_speed
			# Fallback to the global duration property if path_speed is not set
			elif _current_behavior_pattern.duration > 0:
				total_duration = _current_behavior_pattern.duration
			else:
				total_duration = 10.0 # Default duration if nothing is set
			
			if total_duration > 0:
				_path_follower.progress_ratio = min(1.0, _current_segment_age / total_duration)
			
			# Also calculate a velocity vector for member rotation
			if path_node.curve.get_point_count() > 1:
				# To get a reliable direction vector, we can compare the position between two close points on the path.
				var current_progress = _path_follower.progress
				var next_progress = current_progress + 1.0 # a small step forward
				var current_pos = path_node.curve.sample_baked(current_progress)
				var next_pos = path_node.curve.sample_baked(next_progress)
				velocity = (next_pos - current_pos).normalized() * (_current_behavior_pattern.path_speed if _current_behavior_pattern.path_speed > 0 else 150.0)
		
		EnemyBehaviorPattern.MovementType.STATIONARY:
			velocity = Vector2.ZERO

func _update_members(delta: float) -> void:
	"""Updates the position and logic of all squadron members."""
	if not formation_pattern: return
	
	for i in range(members.size()):
		var member = members[i]
		if is_instance_valid(member):
			# 1. Update position based on formation offset.
			var offset = formation_pattern.member_offsets[i]
			var final_offset = offset
			var final_member_rotation = 0.0
			
			# 2. Calculate rotation if any rotation is enabled and there's movement.
			if _current_behavior_pattern and (_current_behavior_pattern.rotate_formation or _current_behavior_pattern.rotate_members):
				var rotation_target_direction = velocity
				
				if rotation_target_direction.length_squared() > 0.001:
					var target_angle = rotation_target_direction.angle()
					
					# --- Formation Rotation ---
					# The V-formation points down (90 deg). We want to align this "front" with the target_angle.
					# The rotation to apply is the difference between the target and the base orientation.
					var formation_base_angle = PI / 2 # Formation points down by default.
					var formation_rotation = target_angle - formation_base_angle
					if _current_behavior_pattern.rotate_formation:
						final_offset = offset.rotated(formation_rotation)
					
					# --- Member Sprite Rotation ---
					# The sprite points up (-90 deg). We want to align this "front" with the target_angle.
					var sprite_base_angle = - PI / 2 # Sprite points up by default.
					if _current_behavior_pattern.rotate_members:
						final_member_rotation = target_angle - sprite_base_angle
			
			# Apply final calculated position and rotation
			member.global_position = self.global_position + final_offset
			member.rotation = final_member_rotation
			
			# 2. Manually update the member's shooting logic.
			if delta > 0:
				member.update_shooting_only(delta)


func _reclaim() -> void:
	"""Safely emits the reclaimed signal, only once."""
	if _is_reclaimed:
		return
	_is_reclaimed = true
	reclaimed.emit(self)


func _on_member_reclaimed(member: Enemy) -> void:
	"""Called when a member enemy is reclaimed (e.g., destroyed)."""
	# Optional: Check if all members are gone to reclaim the controller early.
	var all_gone = true
	for m in members:
		if is_instance_valid(m) and not m._is_reclaimed:
			all_gone = false
			break
	if all_gone:
		_reclaim()

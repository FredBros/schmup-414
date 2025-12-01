# Fichier : res://scenes/squadron/squadron_controller.gd
# Ce script doit être attaché à un nœud Node2D.

# Fichier : res://scenes/squadron/squadron_controller.gd
# Ce script doit être attaché à un nœud Node2D.

extends Node2D

class_name SquadronController

## Emitted when the controller has finished its lifecycle and should be returned to the pool.
signal reclaimed(controller)

var behavior_pattern: EnemyBehaviorPattern
var formation_pattern: FormationPattern
var members: Array[Enemy] = []

var _is_reclaimed := false

@onready var _path_follower: PathFollow2D = $PathFollower

# State variables for specific movement patterns
var velocity: Vector2 = Vector2.ZERO
var _sinusoidal_time: float = 0.0
var _bounces_left: int = 0
var _age: float = 0.0

# This will be set by the spawner.
var debug_mode := false

func activate() -> void:
	"""Activates the controller, resetting its state and making it process."""
	_is_reclaimed = false
	_age = 0.0
	_sinusoidal_time = 0.0
	
	if debug_mode:
		print("[CONTROLLER DEBUG] Activating controller '%s' with %d members." % [name, members.size()])
	
	# Make the controller itself visible. This is the missing piece.
	visible = true
	
	set_physics_process(true)
	# Make all members visible
	for member in members:
		if is_instance_valid(member):
			member.make_visible()
	
	if behavior_pattern and behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.BOUNCE:
		velocity = behavior_pattern.bounce_initial_direction.normalized() * behavior_pattern.bounce_speed
		_bounces_left = behavior_pattern.bounce_count


func set_target(target: Node2D) -> void:
	"""Sets the target for the entire squadron (e.g., for Homing)."""
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
		add_child(_path_follower)


func _physics_process(delta: float) -> void:
	if not behavior_pattern:
		return

	# --- Movement Logic ---
	match behavior_pattern.movement_type:
		EnemyBehaviorPattern.MovementType.LINEAR:
			velocity = behavior_pattern.linear_direction.normalized() * behavior_pattern.linear_speed

		EnemyBehaviorPattern.MovementType.SINUSOIDAL:
			_sinusoidal_time += delta
			var direction = behavior_pattern.sinusoidal_direction.normalized()
			var speed = behavior_pattern.sinusoidal_speed
			var frequency = behavior_pattern.sinusoidal_frequency
			var amplitude = behavior_pattern.sinusoidal_amplitude
			
			velocity = direction * speed
			velocity += direction.orthogonal() * cos(_sinusoidal_time * frequency) * amplitude

		EnemyBehaviorPattern.MovementType.STATIONARY:
			velocity = Vector2.ZERO

		EnemyBehaviorPattern.MovementType.HOMING:
			# Homing for squadrons is handled by the individual members,
			# so the controller itself might just move linearly or stay stationary.
			# We'll assume a simple linear downward movement as a default.
			velocity = Vector2.DOWN * 50 # Example speed

		EnemyBehaviorPattern.MovementType.BOUNCE:
			if _bounces_left != 0:
				if (global_position.x <= GameArea.RECT.position.x and velocity.x < 0) or \
				   (global_position.x >= GameArea.RECT.end.x and velocity.x > 0):
					velocity.x *= -1
					if _bounces_left > 0: _bounces_left -= 1
				
				if (global_position.y <= GameArea.RECT.position.y and velocity.y < 0) or \
				   (global_position.y >= GameArea.RECT.end.y and velocity.y > 0):
					velocity.y *= -1
					if _bounces_left > 0: _bounces_left -= 1

		EnemyBehaviorPattern.MovementType.PATH_2D:
			if behavior_pattern.lifetime > 0:
				_path_follower.progress_ratio = _age / behavior_pattern.lifetime
			return # PathFollower handles movement, so we skip move_and_slide

	global_position += velocity * delta
	
	# --- Member Positioning ---
	if formation_pattern:
		for i in range(members.size()):
			var member = members[i]
			if is_instance_valid(member):
				var offset = formation_pattern.member_offsets[i]
				member.global_position = self.global_position + offset
				if debug_mode and Engine.get_physics_frames() % 60 == 0: # Print once per second
					print(
						"[CONTROLLER DEBUG] Member %d position set to (%d, %d)" % [
							i, member.global_position.x, member.global_position.y
						]
					)

	# --- Lifetime & Reclaim Logic ---
	# Increment age and reclaim if lifetime is exceeded.
	_age += delta
	if behavior_pattern.lifetime > 0 and _age >= behavior_pattern.lifetime:
		_reclaim()


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

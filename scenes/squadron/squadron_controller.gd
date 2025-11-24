extends Node2D
class_name SquadronController

var behavior_pattern: EnemyBehaviorPattern
var formation_pattern: FormationPattern
var members: Array[Enemy] = []

var _player: Node2D # Target for homing
var velocity: Vector2 # We still need to track velocity for non-Path2D movements
var _sinusoidal_time: float = 0.0
var _age: float = 0.0
var _bounces_left: int = 0
var _screen_size: Vector2

# A permanent reference to the PathFollower node, established before it gets reparented.
@onready var _path_follower: PathFollow2D = $PathFollower

# --- Lifecycle Functions ---

func _ready() -> void:
	_screen_size = get_viewport_rect().size
	# The controller itself should not process physics if it's just a container for a PathFollower

func set_target(target: Node2D) -> void:
	"""Sets the target for the squadron to home in on."""
	_player = target

func activate():
	set_physics_process(true)
	_age = 0.0 # Reset age on activation
	
	# Initialize state based on behavior pattern
	if behavior_pattern and behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.BOUNCE:
		velocity = behavior_pattern.bounce_initial_direction.normalized() * behavior_pattern.bounce_speed
		_bounces_left = behavior_pattern.bounce_count

func deactivate():
	set_physics_process(false)
	# Reclaim all members
	for member in members:
		if is_instance_valid(member):
			member._reclaim() # Call the internal reclaim method
	# Reclaim self (assuming it's pooled)
	queue_free() # For now, we just remove it.

func _physics_process(delta: float) -> void:
	if not behavior_pattern:
		return

	# Special case for Path2D: The controller's position IS the PathFollower's position.
	if behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.PATH_2D:
		if is_instance_valid(_path_follower):
			# We must actively drive the progress of the PathFollower.
			# It will traverse the path over its configured lifetime.
			if behavior_pattern.lifetime > 0:
				_path_follower.progress_ratio = _age / behavior_pattern.lifetime
			else:
				push_warning("SquadronController: Path2D movement requires a 'lifetime' > 0 in its EnemyBehaviorPattern, but it is 0. The squadron will not move.")

			self.global_position = _path_follower.global_position
		# We skip the rest of the physics logic for Path2D
	else:
		# --- Standard movement logic for other patterns ---
		# 1. Move the controller itself (logic copied & adapted from enemy.gd)
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
				var homing_active = true
				if behavior_pattern.homing_duration >= 0 and _age >= behavior_pattern.homing_duration:
					homing_active = false
				
				if homing_active:
					if is_instance_valid(_player):
						var direction_to_player = global_position.direction_to(_player.global_position)
						var target_velocity = direction_to_player * behavior_pattern.homing_speed
						velocity = velocity.slerp(target_velocity, behavior_pattern.homing_turn_rate * delta)
					else:
						# Fallback if target is lost
						velocity = velocity.slerp(Vector2.DOWN * behavior_pattern.homing_speed, behavior_pattern.homing_turn_rate * delta)

			EnemyBehaviorPattern.MovementType.BOUNCE:
				if _bounces_left != 0:
					if (global_position.x <= 0 and velocity.x < 0) or \
					   (global_position.x >= _screen_size.x and velocity.x > 0):
						velocity.x *= -1
						if _bounces_left > 0: _bounces_left -= 1
					
					if (global_position.y <= 0 and velocity.y < 0) or \
					   (global_position.y >= _screen_size.y and velocity.y > 0):
						velocity.y *= -1
						if _bounces_left > 0: _bounces_left -= 1

			# Path2D movement will be handled by a PathFollower, not here.
		
		global_position += velocity * delta

	# 2. Update member positions
	# The lerp factor determines how "tight" the formation is.
	var formation_tightness = 0.1 # Value between 0 and 1
	for i in range(members.size()):
		var enemy = members[i]
		if is_instance_valid(enemy) and i < formation_pattern.member_offsets.size():
			var offset = formation_pattern.member_offsets[i]
			var target_pos = self.global_position + offset
			# The enemy smoothly moves towards its designated spot in the formation
			enemy.global_position = enemy.global_position.lerp(target_pos, formation_tightness)

	# 3. Check for deactivation
	_age += delta
	if behavior_pattern.lifetime > 0 and _age >= behavior_pattern.lifetime:
		deactivate()

	# Also check if all members are gone
	if members.all(func(m): return not is_instance_valid(m)):
		deactivate()

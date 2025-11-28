extends "res://scenes/utils/entity/entity.gd"

class_name Enemy

## Signal émis lorsque l'ennemi doit être retourné au pool.
signal reclaimed(enemy)

@export_group("Shooting")
@export var shooting_pattern: ShootingPattern
@export_group("Debugging")
@export var debug_mode: bool = false

@onready var _path_follower: PathFollow2D = $PathFollower

# --- Movement Pattern Variables ---
var _behavior_pattern: EnemyBehaviorPattern
var _player: Node2D # Target for homing

# State variables for specific movement patterns
var _sinusoidal_time: float = 0.0
var _bounces_left: int = 0
var _age: float = 0.0
var _is_reclaimed := false
# --- End Movement Pattern Variables ---

# --- Shooting Pattern Variables ---
var _is_shooting_active := false
var _shoot_cooldown_timer: float = 0.0

# State for burst shots
var _burst_shots_left: int = 0
var _burst_interval_timer: float = 0.0

# State for spiral shots
var _spiral_angle: float = 0.0


func _ready() -> void:
	add_to_group("Enemies")

func set_behavior_pattern(pattern: EnemyBehaviorPattern) -> void:
	"""Définit le pattern de comportement que cet ennemi doit suivre."""
	_behavior_pattern = pattern

func set_target(target: Node2D) -> void:
	"""Définit la cible que l'ennemi doit poursuivre (pour le Homing)."""
	print("[ENEMY DEBUG] set_target called with: ", target)
	_player = target


func activate(new_global_position: Vector2) -> void: # Note: cette fonction devient 'async' à cause de 'await'
	"""Active l'ennemi, le rend visible, réinitialise son état et démarre ses comportements."""
	# La visibilité est maintenant gérée par le spawner ou le squadron_controller
	# pour éviter un flash à la position (0,0) avant le positionnement final.
	# L'ennemi est donc invisible par défaut à l'activation.
	visible = false
	# On applique la position AVANT toute autre logique, en particulier avant le 'await'.
	# C'est la garantie que la position est correcte dès le début.
	self.global_position = new_global_position
	_is_reclaimed = false
	# --- Reset state variables ---
	_age = 0.0 # Reset lifetime counter
	velocity = Vector2.ZERO # Reset velocity on activation
	_is_shooting_active = false
	set_physics_process(true)
	# Réactiver les collisions (supposant que le Hurtbox gère la collision principale)
	var hurtbox = find_child("Hurtbox", true, false)
	if hurtbox:
		hurtbox.get_node("CollisionShape2D").set_deferred("disabled", false)
		
	# --- Initialize state based on behavior pattern ---
	_sinusoidal_time = 0.0
	if _behavior_pattern and _behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.BOUNCE:
		velocity = _behavior_pattern.bounce_initial_direction.normalized() * _behavior_pattern.bounce_speed
		_bounces_left = _behavior_pattern.bounce_count
	# Special case for "fire-and-forget" homing
	elif _behavior_pattern and _behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.HOMING and _behavior_pattern.homing_duration == 0:
		if is_instance_valid(_player):
			var direction_to_player = global_position.direction_to(_player.global_position)
			velocity = direction_to_player * _behavior_pattern.homing_speed
	
	# Reset health
	health = max_health

	# Initialize shooting pattern
	if shooting_pattern and shooting_pattern.shot_type != ShootingPattern.ShotType.NONE:
		# On attend un frame pour s'assurer que la position de l'ennemi est bien mise à jour
		# avant d'activer le tir. Cela évite que le premier tir parte de la mauvaise position.
		await get_tree().physics_frame
		_is_shooting_active = true
		_shoot_cooldown_timer = shooting_pattern.initial_delay
		_burst_shots_left = 0 # Ensure burst is reset


func deactivate() -> void:
	"""Désactive l'ennemi, le cache et arrête ses comportements pour le pooling."""
	visible = false
	set_physics_process(false)
	# Désactiver les collisions
	var hurtbox = find_child("Hurtbox", true, false)
	if hurtbox:
		hurtbox.get_node("CollisionShape2D").set_deferred("disabled", true)

	# Arrêter le tir
	_is_shooting_active = false
	# Si le PathFollower a été reparenté, on le récupère pour le pooling.
	# On utilise notre référence permanente _path_follower.
	if is_instance_valid(_path_follower) and _path_follower.get_parent() != self:
		var old_parent = _path_follower.get_parent()
		if old_parent: old_parent.remove_child(_path_follower)
		_path_follower.name = "PathFollower"
		add_child(_path_follower)


func make_visible() -> void:
	"""Rend l'ennemi visible. Typiquement appelé par le spawner après le positionnement."""
	if debug_mode:
		print("[%s] MAKE_VISIBLE called. Current visibility: %s" % [name, visible])
	visible = true


func _physics_process(delta: float) -> void:
	if not _behavior_pattern:
		return

	# --- Shooting Logic ---
	_handle_shooting(delta)
	# --- Movement Logic ---
	match _behavior_pattern.movement_type:
		EnemyBehaviorPattern.MovementType.LINEAR:
			velocity = _behavior_pattern.linear_direction.normalized() * _behavior_pattern.linear_speed

		EnemyBehaviorPattern.MovementType.SINUSOIDAL:
			_sinusoidal_time += delta
			var direction = _behavior_pattern.sinusoidal_direction.normalized()
			var speed = _behavior_pattern.sinusoidal_speed
			var frequency = _behavior_pattern.sinusoidal_frequency
			var amplitude = _behavior_pattern.sinusoidal_amplitude
			
			velocity = direction * speed
			# We use the perpendicular of the velocity direction for the sine wave axis
			velocity += direction.orthogonal() * cos(_sinusoidal_time * frequency) * amplitude

		EnemyBehaviorPattern.MovementType.STATIONARY:
			velocity = Vector2.ZERO

		EnemyBehaviorPattern.MovementType.HOMING:
			# --- HOMING DEBUG START ---
			var homing_active = true
			if _behavior_pattern.homing_duration >= 0 and _age >= _behavior_pattern.homing_duration:
				homing_active = false
			
			print("[HOMING DEBUG] Active: %s (Age: %.2f / Duration: %.2f)" % [homing_active, _age, _behavior_pattern.homing_duration])

			if homing_active:
				if is_instance_valid(_player):
					var direction_to_player = global_position.direction_to(_player.global_position)
					var target_velocity = direction_to_player * _behavior_pattern.homing_speed
					# Rotate current velocity towards the player direction
					velocity = velocity.slerp(target_velocity, _behavior_pattern.homing_turn_rate * delta)
				else:
					print("[HOMING DEBUG] Target `_player` is NOT valid. Using fallback.")
					# Si la cible devient invalide (ex: joueur détruit), on continue tout droit.
					# Le slerp vers le bas est un fallback si la vélocité initiale était nulle.
					velocity = velocity.slerp(Vector2.DOWN * _behavior_pattern.homing_speed, _behavior_pattern.homing_turn_rate * delta)
			# --- HOMING DEBUG END ---
		
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
			# Fait progresser l'ennemi le long du chemin en se basant sur sa durée de vie.
			# Quand _age atteint lifetime, progress_ratio atteint 1.0.
			if _behavior_pattern.rotate_to_movement:
				_path_follower.rotates = true
			
			if _behavior_pattern.lifetime > 0:
				_path_follower.progress_ratio = _age / _behavior_pattern.lifetime
			
			# For Path2D, velocity is not used, but rotation needs to be set from the follower.
			self.rotation = _path_follower.rotation + PI / 2
			return # move_and_slide is not needed for PathFollower2D

	move_and_slide()
	
	# Rotate the enemy to face its movement direction, if enabled.
	if _behavior_pattern.rotate_to_movement:
		# Only rotate if there is a velocity to avoid snapping to a default angle.
		if velocity.length_squared() > 0:
			# velocity.angle() gives the angle for pointing right (X-axis).
			# We add PI/2 (90 degrees) because our sprites point up (Y-axis).
			rotation = velocity.angle() + PI / 2

	# Increment age and reclaim if lifetime is exceeded.
	_age += delta
	if _behavior_pattern and _behavior_pattern.lifetime > 0 and _age >= _behavior_pattern.lifetime:
		_reclaim()


func _handle_shooting(delta: float) -> void:
	if not _is_shooting_active:
		if debug_mode:
			# Ce message ne devrait apparaître qu'une seule fois au début si le tir est désactivé.
			print("[%s] _handle_shooting: SKIPPING (shooting not active)" % name)
		return

	# --- Burst Logic ---
	# If a burst is in progress, prioritize it.
	if _burst_shots_left > 0:
		_burst_interval_timer -= delta
		if _burst_interval_timer <= 0:
			_fire_projectile(_get_shot_direction())
			_burst_shots_left -= 1
			if _burst_shots_left > 0:
				_burst_interval_timer = shooting_pattern.burst_interval
		return # Don't process main cooldown while bursting

	# --- Main Cooldown Logic ---
	_shoot_cooldown_timer -= delta
	if _shoot_cooldown_timer <= 0:
		if debug_mode:
			print("[%s] _handle_shooting: Cooldown finished. Calling _execute_shot()" % name)
		_execute_shot()
		_shoot_cooldown_timer = shooting_pattern.cooldown # Reset for next shot


func _execute_shot() -> void:
	if not shooting_pattern or shooting_pattern.projectile_scene == null:
		return
	if debug_mode:
		print("[%s] _execute_shot: Executing shot of type %s" % [name, ShootingPattern.ShotType.keys()[shooting_pattern.shot_type]])

	var direction = _get_shot_direction()

	match shooting_pattern.shot_type:
		ShootingPattern.ShotType.SINGLE:
			_fire_projectile(direction)

		ShootingPattern.ShotType.BURST:
			# Fire the first shot immediately, then start the burst sequence.
			_fire_projectile(direction)
			_burst_shots_left = shooting_pattern.burst_count - 1
			if _burst_shots_left > 0:
				_burst_interval_timer = shooting_pattern.burst_interval

		ShootingPattern.ShotType.SPREAD:
			var total_angle = deg_to_rad(shooting_pattern.spread_angle)
			var angle_step = total_angle / (shooting_pattern.spread_count - 1) if shooting_pattern.spread_count > 1 else 0
			var start_angle = direction.angle() - total_angle / 2.0

			for i in range(shooting_pattern.spread_count):
				var shot_angle = start_angle + i * angle_step
				_fire_projectile(Vector2.from_angle(shot_angle))

		ShootingPattern.ShotType.SPIRAL:
			# For spiral, we use a persistent angle that we rotate over time.
			var shot_angle = deg_to_rad(_spiral_angle)
			_fire_projectile(Vector2.from_angle(shot_angle))
			# The spiral interval is handled by the main cooldown for simplicity here.
			# For a denser spiral, you could use a separate timer like for bursts.

	# Update spiral angle for the next shot, regardless of type (it only affects spiral)
	_spiral_angle += shooting_pattern.spiral_rotation_speed * shooting_pattern.cooldown


func _get_shot_direction() -> Vector2:
	"""Determines the base direction for a shot (aimed or forward)."""
	if shooting_pattern.aimed and is_instance_valid(_player):
		return global_position.direction_to(_player.global_position)
	else:
		# Si le tir n'est pas visé, les ennemis tirent généralement vers le bas (Y positif dans Godot).
		return Vector2.DOWN


func _fire_projectile(direction: Vector2) -> void:
	"""Instantiates and fires a single projectile."""
	if not shooting_pattern or not shooting_pattern.projectile_scene:
		push_warning("Attempted to fire but shooting_pattern or its projectile_scene is not set.")
		return
	if debug_mode:
		print("[%s] _fire_projectile: Attempting to get bullet from pool..." % name)

	# Get a bullet from the global pool instead of instantiating a new one.
	var bullet = EnemyBulletPool.get_bullet()
	if not is_instance_valid(bullet):
		push_error("EnemyBulletPool returned an invalid bullet instance.")
		if debug_mode:
			print("[%s] _fire_projectile: FAILED to get bullet from pool." % name)
		return
	if debug_mode:
		print("[%s] _fire_projectile: SUCCESS, got bullet instance: %s" % [name, bullet])
	
	# On utilise la position globale du PathFollower (qui contient le sprite)
	# CORRECTION: Le PathFollower est reparenté. La source de vérité est la position
	# de l'ennemi lui-même (self), après avoir attendu un physics_frame.
	bullet.global_position = self.global_position
	bullet.rotation = direction.angle()

	# Add the bullet to the main scene tree ('world') AFTER setting its position.
	# This ensures it appears at the correct location on its first frame.
	# CORRECTION : Ne JAMAIS ajouter à get_tree().root. Les objets de jeu doivent
	# vivre dans le même conteneur. On suppose que le parent de l'ennemi est le 'World'.
	# Si l'ennemi est dans une escadrille, get_parent() est le World.
	get_parent().add_child(bullet)
	if debug_mode:
		print("[%s] _fire_projectile: Activating bullet at position %s" % [name, bullet.global_position])
	bullet.activate() # Active la balle après l'avoir positionnée
	# The bullet script itself should read its BulletData and set its velocity.
	# Example: bullet.velocity = direction * bullet_data.speed


func _on_die(_source: Node) -> void:
	_reclaim()

func _reclaim() -> void:
	"""Émet le signal `reclaimed` de manière sécurisée, une seule fois."""
	if _is_reclaimed:
		return
	_is_reclaimed = true
	reclaimed.emit(self)
	

func _on_damaged(_damage: int, _source: Node) -> void:
	pass

func _on_screen_exited() -> void:
	"""Appelé lorsque l'ennemi sort de l'écran."""
	# On ne supprime l'ennemi que si sa durée de vie est infinie (lifetime <= 0).
	# Si une lifetime est définie, c'est elle qui a la priorité pour la suppression,
	# ce qui permet à l'ennemi de sortir et de rentrer à l'écran.
	if _behavior_pattern and _behavior_pattern.lifetime <= 0:
		_reclaim()

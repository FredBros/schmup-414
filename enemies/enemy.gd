extends "res://scenes/utils/entity/entity.gd"

class_name Enemy

## Signal émis lorsque l'ennemi doit être retourné au pool.
signal reclaimed(enemy)

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

## Classe interne pour gérer l'état d'un seul pattern de tir actif.
class ActiveShootingPatternState:
	var timed_pattern: TimedShootingPattern
	var cooldown_timer: float = 0.0
	var burst_shots_left: int = 0
	var burst_interval_timer: float = 0.0
	var spiral_angle: float = 0.0 # Angle de départ pour ce pattern en spirale

	func _init(p: TimedShootingPattern):
		timed_pattern = p
		cooldown_timer = p.pattern.initial_delay

# --- Shooting Pattern Variables ---
var _timed_shooting_patterns: Array[TimedShootingPattern] = []
var _active_pattern_states: Array[ActiveShootingPatternState] = []

func _ready() -> void:
	add_to_group("Enemies")

func set_behavior_pattern(pattern: EnemyBehaviorPattern) -> void:
	"""Définit le pattern de comportement que cet ennemi doit suivre."""
	_behavior_pattern = pattern

func set_shooting_patterns(patterns: Array[TimedShootingPattern]) -> void:
	"""Définit la liste des patterns de tir que cet ennemi doit utiliser."""
	_timed_shooting_patterns = patterns
	_active_pattern_states.clear()

func set_target(target: Node2D) -> void:
	"""Définit la cible que l'ennemi doit poursuivre (pour le Homing)."""
	print("[ENEMY DEBUG] set_target called with: ", target)
	_player = target


func activate(new_global_position: Vector2) -> void: # Note: cette fonction devient 'async' à cause de 'await'
	"""Active l'ennemi, le rend visible, réinitialise son état et démarre ses comportements."""
	# La visibilité est maintenant gérée par le spawner ou le squadron_controller
	# L'ennemi est invisible par défaut (propriété de la scène ou via deactivate()).
	# On applique la position AVANT toute autre logique.
	# C'est la garantie que la position est correcte dès le début.
	self.global_position = new_global_position
	_is_reclaimed = false
	# --- Reset state variables ---
	_age = 0.0 # Reset lifetime counter
	velocity = Vector2.ZERO # Reset velocity on activation
	# La logique de tir est maintenant gérée par la liste _active_pattern_states
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

	# L'initialisation des patterns de tir est maintenant gérée dans set_shooting_patterns.
	# On attend juste un frame pour s'assurer que la position est correcte avant que
	# le premier _physics_process ne déclenche potentiellement un tir.
	# await get_tree().physics_frame # On enlève l'await qui complique la logique.


func deactivate() -> void:
	"""Désactive l'ennemi, le cache et arrête ses comportements pour le pooling."""
	visible = false
	set_physics_process(false)
	# Désactiver les collisions
	var hurtbox = find_child("Hurtbox", true, false)
	if hurtbox:
		hurtbox.get_node("CollisionShape2D").set_deferred("disabled", true)

	# Arrêter le tir
	_active_pattern_states.clear()
	_timed_shooting_patterns.clear()

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
			
			# For Path2D, we update the enemy's position and rotation from the follower.
			self.global_position = _path_follower.global_position
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
	# --- Gérer l'activation/désactivation des patterns en fonction du temps ---
	# On itère à l'envers pour pouvoir supprimer des éléments sans problème.
	for i in range(_active_pattern_states.size() - 1, -1, -1):
		var state = _active_pattern_states[i]
		# Si le pattern a un end_time défini et que l'âge de l'ennemi le dépasse, on le supprime.
		if state.timed_pattern.end_time > 0 and _age >= state.timed_pattern.end_time:
			_active_pattern_states.remove_at(i)
			continue # Passe au suivant
	
	# Vérifier si de nouveaux patterns doivent être activés.
	for timed_pattern in _timed_shooting_patterns:
		# Si l'âge est dans l'intervalle de temps du pattern...
		if _age >= timed_pattern.start_time:
			# ...et qu'il n'est pas déjà actif...
			if not _is_pattern_active(timed_pattern.pattern):
				# ...on l'active.
				_active_pattern_states.append(ActiveShootingPatternState.new(timed_pattern))


	# Boucle sur chaque pattern de tir actif et gère son état indépendamment.
	for state in _active_pattern_states:
		# --- Burst Logic ---
		if state.burst_shots_left > 0:
			state.burst_interval_timer -= delta
			if state.burst_interval_timer <= 0:
				_fire_projectile(_get_shot_direction(state.timed_pattern.pattern), state.timed_pattern.pattern)
				state.burst_shots_left -= 1
				if state.burst_shots_left > 0:
					state.burst_interval_timer = state.timed_pattern.pattern.burst_interval
			continue # Ne pas traiter le cooldown principal pendant une rafale

		# --- Main Cooldown Logic ---
		state.cooldown_timer -= delta
		if state.cooldown_timer <= 0:
			_execute_shot(state)
			state.cooldown_timer = state.timed_pattern.pattern.cooldown # Réinitialiser pour le prochain tir


func _execute_shot(state: ActiveShootingPatternState) -> void:
	if not state.timed_pattern.pattern or state.timed_pattern.pattern.projectile_scene == null:
		return

	var direction = _get_shot_direction(state.timed_pattern.pattern)

	match state.timed_pattern.pattern.shot_type:
		ShootingPattern.ShotType.SINGLE:
			_fire_projectile(direction, state.timed_pattern.pattern)

		ShootingPattern.ShotType.BURST:
			# Fire the first shot immediately, then start the burst sequence.
			_fire_projectile(direction, state.timed_pattern.pattern)
			state.burst_shots_left = state.timed_pattern.pattern.burst_count - 1
			if state.burst_shots_left > 0:
				state.burst_interval_timer = state.timed_pattern.pattern.burst_interval

		ShootingPattern.ShotType.SPREAD:
			var total_angle = deg_to_rad(state.timed_pattern.pattern.spread_angle)
			var angle_step = total_angle / (state.timed_pattern.pattern.spread_count - 1) if state.timed_pattern.pattern.spread_count > 1 else 0
			var start_angle = direction.angle() - total_angle / 2.0

			for i in range(state.timed_pattern.pattern.spread_count):
				var shot_angle = start_angle + i * angle_step
				_fire_projectile(Vector2.from_angle(shot_angle), state.timed_pattern.pattern)

		ShootingPattern.ShotType.SPIRAL:
			# For spiral, we use a persistent angle that we rotate over time.
			var shot_angle = deg_to_rad(state.spiral_angle)
			_fire_projectile(Vector2.from_angle(shot_angle), state.timed_pattern.pattern)
			# The spiral interval is handled by the main cooldown for simplicity here.
			# For a denser spiral, you could use a separate timer like for bursts.

	# Mettre à jour l'angle de la spirale pour le prochain tir de CE pattern.
	state.spiral_angle += state.timed_pattern.pattern.spiral_rotation_speed * state.timed_pattern.pattern.cooldown


func _is_pattern_active(pattern_to_check: ShootingPattern) -> bool:
	"""Vérifie si un pattern de tir donné est déjà dans la liste des états actifs."""
	for state in _active_pattern_states:
		if state.timed_pattern.pattern == pattern_to_check:
			return true
	return false

func _get_shot_direction(pattern: ShootingPattern) -> Vector2:
	"""Determines the base direction for a shot (aimed or forward)."""
	if pattern.aimed and is_instance_valid(_player):
		return global_position.direction_to(_player.global_position)
	else:
		# Si le tir n'est pas visé, les ennemis tirent généralement vers le bas (Y positif dans Godot).
		return Vector2.DOWN


func _fire_projectile(direction: Vector2, pattern: ShootingPattern) -> void:
	"""Instantiates and fires a single projectile."""
	if not pattern or not pattern.projectile_scene:
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

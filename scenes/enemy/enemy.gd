extends "res://scenes/utils/entity/entity.gd"

class_name Enemy

## Signal émis lorsque l'ennemi doit être retourné au pool.
signal reclaimed(enemy)

@export_group("Combat")
@export var bullet_scene: PackedScene = preload("res://scenes/bullet/bullet prefab/bullet.tscn")
@export var bullet_data_resource: BulletData # Must be assigned in the inspector

var _is_reclaimed := false

## Référence mise en cache au BulletManager pour éviter les appels répétés à get_node.
@onready var _bullet_manager: Node = get_node_or_null("BulletManager")
@onready var _path_follower: PathFollow2D = $PathFollower

# --- Movement Pattern Variables ---
var _behavior_pattern: EnemyBehaviorPattern
var _screen_size: Vector2
var _player: Node2D # Target for homing

# State variables for specific movement patterns
var _sinusoidal_time: float = 0.0
var _bounces_left: int = 0
var _age: float = 0.0
# --- End Movement Pattern Variables ---


func _ready() -> void:
	add_to_group("Enemies")
	_screen_size = get_viewport_rect().size

func set_behavior_pattern(pattern: EnemyBehaviorPattern) -> void:
	"""Définit le pattern de comportement que cet ennemi doit suivre."""
	_behavior_pattern = pattern

func set_target(target: Node2D) -> void:
	"""Définit la cible que l'ennemi doit poursuivre (pour le Homing)."""
	print("[ENEMY DEBUG] set_target called with: ", target)
	_player = target


func activate() -> void:
	"""Active l'ennemi, le rend visible, réinitialise son état et démarre ses comportements."""
	visible = true
	_is_reclaimed = false
	# --- Reset state variables ---
	_age = 0.0 # Reset lifetime counter
	velocity = Vector2.ZERO # Reset velocity on activation
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

	# Configurer et démarrer le tir automatique
	if _bullet_manager and bullet_data_resource:
		_bullet_manager.default_bullet_data = bullet_data_resource
		_bullet_manager.auto_fire_rate = bullet_data_resource.fire_rate
		_bullet_manager.default_bullet_direction = Vector2.DOWN
		_bullet_manager.start_auto_fire()


func deactivate() -> void:
	"""Désactive l'ennemi, le cache et arrête ses comportements pour le pooling."""
	visible = false
	set_physics_process(false)
	# Désactiver les collisions
	var hurtbox = find_child("Hurtbox", true, false)
	if hurtbox:
		hurtbox.get_node("CollisionShape2D").set_deferred("disabled", true)

	# Arrêter le tir
	if _bullet_manager:
		_bullet_manager.stop_auto_fire()
		
	# Si le PathFollower a été reparenté, on le récupère pour le pooling.
	# On utilise notre référence permanente _path_follower.
	if is_instance_valid(_path_follower) and _path_follower.get_parent() != self:
		var old_parent = _path_follower.get_parent()
		if old_parent: old_parent.remove_child(_path_follower)
		_path_follower.name = "PathFollower"
		add_child(_path_follower)


func _physics_process(delta: float) -> void:
	if not _behavior_pattern:
		return

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
				if (global_position.x <= 0 and velocity.x < 0) or \
				   (global_position.x >= _screen_size.x and velocity.x > 0):
					velocity.x *= -1
					if _bounces_left > 0: _bounces_left -= 1
				
				if (global_position.y <= 0 and velocity.y < 0) or \
				   (global_position.y >= _screen_size.y and velocity.y > 0):
					velocity.y *= -1
					if _bounces_left > 0: _bounces_left -= 1

		EnemyBehaviorPattern.MovementType.PATH_2D:
			# Fait progresser l'ennemi le long du chemin en se basant sur sa durée de vie.
			# Quand _age atteint lifetime, progress_ratio atteint 1.0.
			if _behavior_pattern.lifetime > 0:
				_path_follower.progress_ratio = _age / _behavior_pattern.lifetime
			return # move_and_slide is not needed for PathFollower2D

	move_and_slide()
	
	# Increment age and reclaim if lifetime is exceeded.
	_age += delta
	if _behavior_pattern and _behavior_pattern.lifetime > 0 and _age >= _behavior_pattern.lifetime:
		_reclaim()

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

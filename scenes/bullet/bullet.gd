extends Area2D
class_name Bullet

## Signal emitted when the bullet should be returned to the pool.
signal reclaimed

enum TargetType {
	PLAYER,
	ENEMIES
}
var target_type: TargetType
## The base speed of the bullet in pixels per second. This is typically set by a BulletData resource.
@export var speed := 700.0
## The amount of damage the bullet inflicts. This is typically set by a BulletData resource.
@export var damage: int = 1

var velocity := Vector2.ZERO

# Homing properties
var _is_setup_done := false
var _homing_target: Node2D = null
var _homing_time_left: float = 0.0
var _homing_strength: float = 0.0

# Curve properties
var _is_curved := false
var _curve_amplitude: float = 0.0
var _curve_frequency: float = 0.0
var _curve_time: float = 0.0 # Tracks time for the sine function

var _life_timer: Timer
var _is_reclaimed := false


func activate() -> void:
	"""Activates the bullet, making it visible and processed."""
	visible = true
	_is_reclaimed = false # Reset the reclaimed flag on activation
	set_process(true)
	get_node("CollisionShape2D").set_deferred("disabled", false)


func deactivate() -> void:
	"""Deactivates the bullet, hiding it and stopping its processing. Resets its state."""
	visible = false
	set_process(false)
	get_node("CollisionShape2D").set_deferred("disabled", true)
	
	# Reset state for reuse
	velocity = Vector2.ZERO
	position = Vector2.ZERO # Move it off-screen or to origin
	
	_is_setup_done = false
	_homing_target = null
	_homing_time_left = 0.0
	
	_is_curved = false
	_curve_time = 0.0
	
	# Stop any active timer
	if is_instance_valid(_life_timer) and not _life_timer.is_stopped():
		# It's crucial to disconnect before stopping to prevent a final timeout signal
		# from firing in the same frame if the timer is at its end.
		if _life_timer.timeout.is_connected(_reclaim):
			_life_timer.timeout.disconnect(_reclaim)
		_life_timer.stop()

	# Clear any remaining metadata
	for meta in get_meta_list():
		remove_meta(meta)


func _ready() -> void:
	add_to_group("Bullets")
	area_entered.connect(_on_area_entered)

func setup(data: BulletData) -> void:
	"""Configure la balle en utilisant une ressource BulletData."""
	if not data:
		push_error("Bullet.setup: BulletData est null.")
		return

	# Appliquer les statistiques de base
	self.damage = data.damage
	self.speed = data.speed

	# Définir la cible (PLAYER ou ENEMIES)
	if data.is_player_bullet:
		self.target_type = TargetType.ENEMIES
	else:
		self.target_type = TargetType.PLAYER

	# Appliquer l'apparence et la collision
	var sprite_node = get_node_or_null("AnimatedSprite2D")
	if not sprite_node:
		sprite_node = get_node_or_null("Sprite2D")
	if sprite_node:
		data.apply_to_sprite(sprite_node)
	data.apply_collision(self)

	# Configurer la durée de vie de la balle
	if data.life_duration > 0:
		if not _life_timer:
			# Create the timer only once
			_life_timer = Timer.new()
			_life_timer.one_shot = true
			add_child(_life_timer)

		# Disconnect any previous connection to be safe, then reconnect.
		# This ensures the connection is always valid for pooled objects.
		if _life_timer.timeout.is_connected(_reclaim):
			_life_timer.timeout.disconnect(_reclaim)
		# We connect to our safe _reclaim method instead of directly emitting.
		_life_timer.timeout.connect(_reclaim)
		_life_timer.wait_time = data.life_duration
		_life_timer.start()
		
	# Lire les métadonnées pour le guidage (homing)
	if has_meta("homing_target"):
		print("[HOMING_DEBUG] Bullet.setup: 'homing_target' meta detected.")
		var target_node = get_meta("homing_target")
		if is_instance_valid(target_node):
			_homing_target = target_node
			_homing_time_left = get_meta("homing_time", 0.0)
			_homing_strength = get_meta("homing_strength", 1.0)
			print("[HOMING_DEBUG] Bullet.setup: Homing enabled. Target: ", _homing_target.name, ", Time: ", _homing_time_left)

	# Lire les métadonnées pour le mouvement courbé (curved)
	if has_meta("curve_frequency"):
		_is_curved = true
		_curve_frequency = get_meta("curve_frequency", 1.0)
		_curve_amplitude = get_meta("curve_amplitude", 10.0)
		# Supprimer les prints de debug pour le homing si on est en curved
		if _is_curved: set_meta("homing_target", null)

			
	_is_setup_done = true

func _process(delta: float) -> void:
	# Default velocity for player bullet (if not set by a manager)
	# This runs only once after setup is complete.
	if _is_setup_done and velocity == Vector2.ZERO:
		velocity = Vector2(0, -speed) # Default to moving up
		_is_setup_done = false # Prevent this block from running again

	# Homing logic (ne s'exécute pas si _is_curved est vrai)
	if is_instance_valid(_homing_target) and _homing_time_left > 0:
		print("[HOMING_DEBUG] Bullet.process: Homing active. Time left: ", _homing_time_left)
		# 1. Get current direction and target direction (normalized vectors)
		var current_direction = velocity.normalized()
		var target_direction = (_homing_target.global_position - global_position).normalized()
		# 2. Rotate the current direction towards the target direction
		var new_direction = current_direction.slerp(target_direction, _homing_strength * delta)
		# 3. Apply the new direction to the velocity, preserving speed
		velocity = new_direction * speed
		_homing_time_left -= delta

	# Curved movement logic
	if _is_curved:
		_curve_time += delta
		# Mouvement de base en ligne droite
		var forward_movement = velocity * delta
		# Calcul du décalage latéral sinusoïdal
		var side_direction = velocity.normalized().orthogonal()
		var last_offset = sin((_curve_time - delta) * _curve_frequency) * _curve_amplitude
		var current_offset = sin(_curve_time * _curve_frequency) * _curve_amplitude
		var side_movement = side_direction * (current_offset - last_offset)
		
		position += forward_movement + side_movement
	else:
		# Standard linear movement for all other patterns
		position += velocity * delta
		
	var viewport = get_viewport_rect()
	if position.y < -20 or position.y > viewport.size.y + 20 or position.x < -20 or position.x > viewport.size.x + 20:
		_reclaim()

func _on_area_entered(area: Area2D) -> void:
	# On veut collisionner avec les Hurtboxes
	if area.is_in_group("Hurtbox"):
		var target = area.get_parent()
		if not is_instance_valid(target): # If target is invalid (e.g., already destroyed)
			_reclaim()
			return
		
		# Vérifier si la bullet touche le bon type de cible
		var should_damage = false
		
		if target_type == TargetType.ENEMIES and target.is_in_group("Enemies"):
			should_damage = true
		elif target_type == TargetType.PLAYER and target.is_in_group("Player"):
			should_damage = true
		
		if should_damage:
			# Demander au Hurtbox d'appliquer les dégâts
			if area.has_method("take_damage"):
				area.take_damage(damage, self)
			_reclaim() # La balle est retournée au pool après avoir touché une cible valide

func _reclaim() -> void:
	"""
	Safely emits the reclaimed signal, ensuring it only happens once.
	"""
	if _is_reclaimed:
		return
	_is_reclaimed = true
	reclaimed.emit(self)


func _notification(what: int) -> void:
	# This is a safety net. If the bullet is being destroyed for any reason
	# (e.g., scene change), ensure it tries to reclaim itself.
	if what == NOTIFICATION_PREDELETE:
		_reclaim()

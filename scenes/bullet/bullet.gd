extends Area2D
class_name Bullet

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
		var timer = Timer.new()
		timer.wait_time = data.life_duration
		timer.one_shot = true
		timer.timeout.connect(queue_free)
		add_child(timer)
		timer.start()
		
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
		call_deferred("queue_free")

func _on_area_entered(area: Area2D) -> void:
	# On veut collisionner avec les Hurtboxes
	if area.is_in_group("Hurtbox"):
		var target = area.get_parent()
		if not is_instance_valid(target):
			call_deferred("queue_free")
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
			call_deferred("queue_free") # La balle se détruit uniquement après avoir touché une cible valide

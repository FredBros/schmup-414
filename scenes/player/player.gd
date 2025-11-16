extends "res://scenes/utils/entity/entity.gd"

signal movement_updated(velocity: Vector2)
signal boost_changed(active: bool, strength: float)
signal shoot_pressed()
signal player_hurt()

@export var speed := 350.0
@export var shoot_cooldown := 0.25
@export var bullet_scene: PackedScene = preload("res://scenes/bullet/Bullet.tscn")
@export var boost_strength := 1.0
@export var vel_smoothing := 5.0 # larger -> faster smoothing; 0 disables
@export var enable_velocity_smoothing := true
@export var smooth_x_only := true
@export var snap_to_zero_on_release := true
@export var snap_threshold := 10.0 # if horizontal speed under this when releasing, snap to 0

var _can_shoot := true
var _half_width := 0.0
var _half_height := 0.0
var _is_boosting := false
@onready var _sprite: Sprite2D = $Sprite2D
var _flash_running: bool = false

func _ready() -> void:
	add_to_group("Player")
	
	# Calculer les dimensions du collider une fois pour toutes
	# Connect to Health invulnerability signals for visual feedback
	var _health_node = $Health
	if _health_node:
		_health_node.connect("invulnerability_started", Callable(self, "_on_invulnerability_started"))
		_health_node.connect("invulnerability_ended", Callable(self, "_on_invulnerability_ended"))
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape:
		_half_width = collision_shape.shape.extents.x if collision_shape.shape is RectangleShape2D else collision_shape.shape.radius
		_half_height = collision_shape.shape.extents.y if collision_shape.shape is RectangleShape2D else collision_shape.shape.radius


func _physics_process(_delta: float) -> void:
	_handle_movement()
	# Gestion du boost : on booste en appuyant sur move_up
	var boost_now := Input.is_action_pressed("move_up")
	if boost_now != _is_boosting:
		emit_signal("boost_changed", boost_now, boost_strength)
		_is_boosting = boost_now


	# Notifier la vélocité à l'AnimationManager
	emit_signal("movement_updated", velocity)
	if Input.is_action_pressed("shoot") and _can_shoot:
		_shoot()
		_can_shoot = false
		await get_tree().create_timer(shoot_cooldown).timeout
		_can_shoot = true

func _handle_movement() -> void:
	var dir := Vector2.ZERO
	dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	# Compute the target velocity from input
	var target := Vector2.ZERO
	if dir.length() > 0:
		dir = dir.normalized()
		target = dir * speed

	# Smooth velocity to avoid rapid toggles around the DEADZONE
	if enable_velocity_smoothing and vel_smoothing > 0.0:
		# lerp factor scaled by delta, clamped to [0,1]. This approximates
		# an exponential low-pass filter with tuning via vel_smoothing.
		var delta := get_physics_process_delta_time()
		var t: float = clamp(vel_smoothing * delta, 0.0, 1.0)

		# Optional: smoothing only on horizontal axis (recommended for side-scrolling
		# or shmup left/right controls). Vertical component remains instantaneous.
		if smooth_x_only:
			# Quick path for release: snap to zero if almost stopped to avoid long delay
			if target == Vector2.ZERO and snap_to_zero_on_release and abs(velocity.x) < snap_threshold:
				velocity.x = 0.0
			else:
				# If the difference is large, accept target immediately (no float),
				# otherwise perform smoothing to reduce micro-bounces.
				if abs(target.x - velocity.x) > snap_threshold:
					velocity.x = target.x
				else:
					velocity.x = lerp(velocity.x, target.x, t)
			# No smoothing on Y
			velocity.y = target.y
		else:
			# Two-axis smoothing
			if target == Vector2.ZERO and snap_to_zero_on_release and velocity.length() < snap_threshold:
				velocity = Vector2.ZERO
			else:
				velocity = velocity.lerp(target, t)
	else:
		velocity = target

	# Apply velocity in physics
	move_and_slide()
	
	# Limiter la position dans la zone de jeu (512x720)
	position.x = clamp(position.x, _half_width, 512 - _half_width)
	position.y = clamp(position.y, _half_height, 720 - _half_height)

func _shoot() -> void:
	emit_signal("shoot_pressed")
	var bullet = bullet_scene.instantiate()
	bullet.position = global_position + Vector2(0, -16)
	bullet.target_type = 1 # TargetType.ENEMIES
	get_parent().get_node("Bullets").add_child(bullet)


func _on_damaged(_damage: int, _source: Node) -> void:
	# Mettre à jour UI ou effets visuels
	emit_signal("player_hurt")
	# Optional: start a minor camera shake or particle burst here
	pass

func _on_invulnerability_started(_source: Node) -> void:
	# Start shader flash loop
	if _flash_running:
		return
	_flash_running = true
	_start_flash_loop()

func _on_invulnerability_ended(_source: Node) -> void:
	# Stop flashing
	_flash_running = false
	if _sprite and _sprite.material and _sprite.material is ShaderMaterial:
		_sprite.material.set_shader_parameter("flash", 0.0)

func _start_flash_loop() -> void:
	if not _sprite or not _sprite.material or not (_sprite.material is ShaderMaterial):
		return
	var mat := _sprite.material as ShaderMaterial
	# Repeated short flashes while invulnerable. Tune timings as needed.
	while _flash_running:
		mat.set_shader_parameter("flash", 1.0)
		await get_tree().create_timer(0.08).timeout
		mat.set_shader_parameter("flash", 0.0)
		await get_tree().create_timer(0.08).timeout

func _on_die(_source: Node) -> void:
	# Game over logique
	SignalManager.emit_signal("player_died")
	call_deferred("queue_free")

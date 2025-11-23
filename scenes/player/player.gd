extends CharacterBody2D

signal movement_updated(velocity: Vector2, input_dir: Vector2)
signal boost_changed(active: bool, strength: float)
signal shoot_pressed()
signal player_hurt()

@export var speed := 350.0
@export var shoot_cooldown := 0.25
@export var bullet_scene: PackedScene = preload("res://scenes/bullet/bullet prefab/bullet.tscn")
@export var boost_strength := 1.0
@export var vel_smoothing := 5.0 # larger -> faster smoothing; 0 disables
@export var enable_velocity_smoothing := true
@export var smooth_x_only := true
@export var snap_to_zero_on_release := true
@export var snap_threshold := 10.0 # if horizontal speed under this when releasing, snap to 0

@export var acceleration := 2000.0 # how fast velocity accelerates towards target (pixels/sec^2)
@export var friction := 1500.0 # deceleration when no input (pixels/sec^2)

# Focus mode reduces speed and acceleration when held (use action 'focus_mode')
@export var focus_speed_multiplier := 0.6
@export var focus_accel_multiplier := 0.6

var _can_shoot := true
var _half_width := 0.0
var _half_height := 0.0
var _is_boosting := false
@onready var _sprite: Sprite2D = $Sprite2D
var _flash_running: bool = false
@export var flash_intensity := 0.5 # 0 = no flash, 1 = full flash (white)
@export var tilt_max_deg := 10.0 # max sprite tilt in degrees when moving at full speed
@export var tilt_lerp := 0.15 # interpolation factor for tilt smoothing (0-1)
var _tilt_current := 0.0
var _last_input_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("Player")
	
	# Calculer les dimensions du collider une fois pour toutes
	# Connect to Health invulnerability signals for visual feedback
	var _health_node = $Health
	if _health_node:
		_health_node.connect("invulnerability_started", Callable(self, "_on_invulnerability_started"))
		_health_node.connect("invulnerability_ended", Callable(self, "_on_invulnerability_ended"))
		_health_node.connect("damaged", Callable(self, "_on_damaged"))
		_health_node.connect("died", Callable(self, "_on_die"))
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


	# Notifier la vélocité et l'intention de mouvement à l'AnimationManager
	emit_signal("movement_updated", velocity, _last_input_dir)
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
	var focus_active := Input.is_action_pressed("focus_mode")

	var cur_speed := speed * (focus_speed_multiplier if focus_active else 1.0)
	if dir.length() > 0:
		_last_input_dir = dir
		dir = dir.normalized()
		target = dir * cur_speed
	else:
		_last_input_dir = Vector2.ZERO

	# If acceleration is set, use physics-style acceleration + friction
	if acceleration > 0.0:
		var delta := get_physics_process_delta_time()
		var cur_accel := acceleration * (focus_accel_multiplier if focus_active else 1.0)

		if target != Vector2.ZERO:
			# Accelerate toward the target velocity
			velocity = velocity.move_toward(target, cur_accel * delta)
		else:
			# No input: apply friction to slow down
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	# Smooth velocity to avoid rapid toggles around the DEADZONE
	elif enable_velocity_smoothing and vel_smoothing > 0.0:
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
	
	# Limiter la position dans la zone de jeu (810x1080)
	position.x = clamp(position.x, _half_width, 810 - _half_width)
	position.y = clamp(position.y, _half_height, 1080 - _half_height)

	# Sprite tilt for feel (tilt is based on normalized horizontal speed)
	if _sprite:
		var target_tilt = 0.0
		# Use current speed (focus modifier) when computing target tilt so the
		# tilt scales correctly in Focus mode.
		# reuse focus_active and cur_speed computed earlier in this function
		if cur_speed > 0:
			target_tilt = velocity.x / cur_speed * tilt_max_deg
		# Smooth toward the target tilt
		_tilt_current = lerp(_tilt_current, target_tilt, tilt_lerp)
		# Clamp final tilt to defined bounds to avoid extreme rotations
		_tilt_current = clamp(_tilt_current, -tilt_max_deg, tilt_max_deg)
		_sprite.rotation_degrees = _tilt_current

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

func _on_invulnerability_started() -> void:
	# Start shader flash loop
	if _flash_running:
		return
	_flash_running = true
	_start_flash_loop()

func _on_invulnerability_ended() -> void:
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
		mat.set_shader_parameter("flash", flash_intensity)
		await get_tree().create_timer(0.08).timeout
		mat.set_shader_parameter("flash", 0.0)
		await get_tree().create_timer(0.08).timeout

func _on_die(_source: Node) -> void:
	# Game over logique
	SignalManager.emit_signal("player_died")
	call_deferred("queue_free")

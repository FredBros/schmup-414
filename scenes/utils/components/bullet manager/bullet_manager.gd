extends Node2D

@export var bullet_scene: PackedScene = preload("res://scenes/bullet/bullet prefab/bullet.tscn")
@export var auto_fire_enabled: bool = false
@export var auto_fire_rate: float = 1.0 # shots per second
@export var default_bullet_data: Resource
@export var default_bullet_direction := Vector2.DOWN


# Optional parent container that holds all bullets (great for pooling later)
@export var bullets_container_path: NodePath

func _ready() -> void:
	if not bullet_scene:
		push_error("BulletManager: bullet_scene is not set. Set 'bullet_scene' in the inspector.")
	# auto fire helper
	if has_node("AutoFireTimer"):
		$AutoFireTimer.wait_time = 1.0
		$AutoFireTimer.one_shot = false

func _process(_delta: float) -> void:
	pass


func start_auto_fire(bullet_data: Resource = null, direction: Vector2 = Vector2.ZERO) -> void:
	if bullet_data:
		default_bullet_data = bullet_data
	if direction != Vector2.ZERO:
		default_bullet_direction = direction
	if not has_node("AutoFireTimer"):
		var t = Timer.new()
		t.name = "AutoFireTimer"
		t.one_shot = false
		add_child(t)
		t.connect("timeout", Callable(self, "_on_auto_fire_timeout"))
	$AutoFireTimer.wait_time = 1.0 / max(0.0001, auto_fire_rate)
	$AutoFireTimer.start()

func stop_auto_fire() -> void:
	if has_node("AutoFireTimer"):
		$AutoFireTimer.stop()

func _on_auto_fire_timeout() -> void:
	if not default_bullet_data:
		return
	spawn_bullet(self, default_bullet_data, global_position, default_bullet_direction)

func _get_bullets_container() -> Node:
	# prefer an explicit path; fallback to group lookup
	if has_node(bullets_container_path):
		return get_node(bullets_container_path)
	var containers := get_tree().get_nodes_in_group("BulletsContainer")
	if containers.size() > 0:
		return containers[0]
	return self

func spawn_bullet(_spawner: Node, bullet_data: Resource, at_pos: Vector2, direction: Vector2 = Vector2.ZERO, options := {}):
	"""Spawn a bullet using the specified BulletData resource.

	owner: node that spawns the bullet (usually an enemy or player)
	bullet_data: BulletData resource describing the bullet
	position: global position for the bullet
	direction: initial travel direction (Vector2). If zero, the bullet will attempt to aim at 'target' or fall back to down.
	options: optional dictionary (target, override params)
	"""
	if not bullet_scene:
		push_error("BulletManager.spawn_bullet: no bullet_scene set")
		return null

	# Prefer bullet_data param; if null, try the spawner's bullet_data_resource; fallback to manager default
	var effective_data := bullet_data
	if effective_data == null and _spawner and _object_has_property(_spawner, "bullet_data_resource"):
		effective_data = _spawner.bullet_data_resource
	if effective_data == null:
		effective_data = default_bullet_data
	if not effective_data:
		push_error("BulletManager.spawn_bullet: missing BulletData resource (param/spawner/default)")
		return null

	var bullets_parent = _get_bullets_container()
	var b = bullet_scene.instantiate()
	bullets_parent.add_child(b)
	b.global_position = at_pos

	# Basic stats
	if effective_data.has_method("apply_to_sprite"):
		# Prefer AnimatedSprite2D then Sprite2D
		var sprite_node := b.get_node_or_null("AnimatedSprite2D")
		if sprite_node == null:
			sprite_node = b.get_node_or_null("Sprite2D")
		if sprite_node:
			bullet_data.apply_to_sprite(sprite_node)

		# Apply collision from resource (prefab/shape/preset)
		if bullet_data.has_method("apply_collision"):
			bullet_data.apply_collision(b)

	# Prefer type safe bullet access via class_name Bullet when available
	# The Bullet type is defined in scenes/bullet/bullet.gd; import it if present
	var is_bullet := b is Bullet
	if is_bullet or b.has_method("set"):
		# set fields if they exist
		if is_bullet:
			b.damage = effective_data.damage
			b.speed = effective_data.speed
		else:
			if _object_has_property(b, "damage"):
				b.damage = effective_data.damage
			if _object_has_property(b, "speed"):
				b.speed = effective_data.speed

	# target_type: choose the opponent by default
	# bullet.gd defines enum TargetType { PLAYER, ENEMIES }
	if _object_has_property(b, "target_type") and _object_has_property(b, "TargetType"):
		if effective_data.is_player_bullet:
			b.target_type = b.TargetType.ENEMIES
		else:
			b.target_type = b.TargetType.PLAYER

	# match patterns
	match effective_data.pattern:
		BulletData.Pattern.STRAIGHT, BulletData.Pattern.AIMED, BulletData.Pattern.SPREAD, BulletData.Pattern.HOMING, BulletData.Pattern.CURVED:
			# call specific handler
			match bullet_data.pattern:
				BulletData.Pattern.STRAIGHT:
					_pattern_straight(b, effective_data, direction, options)
				BulletData.Pattern.AIMED:
					_pattern_aimed(b, effective_data, _spawner, options)
				BulletData.Pattern.SPREAD:
					_pattern_spread(b, effective_data, direction, options)
				BulletData.Pattern.HOMING:
					_pattern_homing(b, effective_data, _spawner, options)
				BulletData.Pattern.CURVED:
					_pattern_curved(b, effective_data, direction, options)
		_:
			_pattern_straight(b, effective_data, direction, options)

	return b

func _spawn_bullet_instance(bullet_data: Resource, pos: Vector2, _dir: Vector2, bullets_parent: Node) -> Node:
	var inst = bullet_scene.instantiate()
	bullets_parent.add_child(inst)
	inst.global_position = pos
	if _object_has_property(inst, "damage"):
		inst.damage = bullet_data.damage
	if _object_has_property(inst, "speed"):
		inst.speed = bullet_data.speed
	return inst


func _object_has_property(obj: Object, prop_name: String) -> bool:
	"""Safely checks whether an object has a property with the specified name.

	Godot 4 removed `has_variable` from some objects; this helper inspects the
	`get_property_list()` for a property with the given name. This is safe and
	works with both typed scripts and exported properties.
	"""
	if obj == null:
		return false
	for p in obj.get_property_list():
		if p.name == prop_name:
			return true
	return false

func _pattern_straight(bullet, data, direction: Vector2, _options := {}) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	bullet.velocity = direction.normalized() * data.speed

func _pattern_aimed(bullet, data, _spawner: Node, options := {}) -> void:
	var target = options.get("target", null)
	if target == null:
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			target = players[0]
	if target:
		var dir = (target.global_position - bullet.global_position).normalized()
		bullet.velocity = dir * data.speed
	else:
		_pattern_straight(bullet, data, Vector2.DOWN)

func _pattern_spread(bullet, data, direction: Vector2, _options := {}) -> void:
	# spawn multiple bullets (bullet passed is the first one)
	var count = max(1, data.spread_count)
	var half = (count - 1) / 2.0
	var parent = _get_bullets_container()
	for i in range(count):
		var angle_deg = (i - half) * data.spread_angle_deg
		var angle = deg_to_rad(angle_deg)
		var dir = (direction if direction != Vector2.ZERO else Vector2.DOWN).rotated(angle).normalized()
		if i == 0:
			bullet.velocity = dir * data.speed
		else:
			var newb = _spawn_bullet_instance(data, bullet.global_position, dir, parent)
			newb.velocity = dir * data.speed

func _pattern_homing(bullet, data, _spawner: Node, options := {}) -> void:
	# store homing parameters on the bullet for the bullet script to use
	bullet.set_meta("homing_target", options.get("target", null))
	bullet.set_meta("homing_time", data.homing_duration)
	bullet.set_meta("homing_strength", data.homing_strength)
	# initial direction: straight
	_pattern_straight(bullet, data, options.get("initial_dir", Vector2.DOWN))

func _pattern_curved(bullet, data, direction: Vector2, _options := {}) -> void:
	# store curve params; the bullet script will use them
	bullet.set_meta("curve_frequency", data.curve_frequency)
	bullet.set_meta("curve_amplitude", data.curve_amplitude)
	_pattern_straight(bullet, data, direction)

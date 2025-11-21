extends Node2D

## [Optional] The bullet scene to instantiate.
## If left empty, 'res://scenes/bullet/bullet prefab/bullet.tscn' will be loaded by default.
## Only set this if this manager needs to use a custom bullet scene.
@export var bullet_scene: PackedScene
## [Optional] If true, the manager will start shooting automatically when ready.
## This is often overridden by external scripts (e.g., an Enemy) calling start_auto_fire() directly.
@export var auto_fire_enabled: bool = false
## [Optional] The default rate of fire in shots per second.
## Used as a fallback if not specified in a BulletData resource or by the calling script.
@export var auto_fire_rate: float = 1.0 # shots per second
## [Optional] The default BulletData resource to use for firing.
## Serves as a fallback if no other data is provided.
## Scripts like Enemy.gd will typically override this with their own resource.
@export var default_bullet_data: Resource
## [Optional] The default direction for bullets fired by this manager.
@export var default_bullet_direction := Vector2.DOWN
## [Optional] If true, enables detailed logging to the console for debugging purposes.
@export var debug_logs: bool = false

var _bullet_pool: BulletPool


func _ready() -> void:
	if not bullet_scene:
		bullet_scene = load("res://scenes/bullet/bullet prefab/bullet.tscn")
	if not bullet_scene:
		push_error("BulletManager: bullet_scene is not set. Set 'bullet_scene' in the inspector.")
	# auto fire helper
	if has_node("AutoFireTimer"):
		$AutoFireTimer.wait_time = 1.0
		$AutoFireTimer.one_shot = false
		
	# Find the BulletPool in the scene tree
	var pools = get_tree().get_nodes_in_group("BulletPool")
	if pools.size() > 0:
		_bullet_pool = pools[0]
		print("[BulletManager] BulletPool found.", _bullet_pool)
	else:
		push_error("BulletManager: Could not find a node in the 'BulletPool' group. Please add a BulletPool to your main scene.")

func _process(_delta: float) -> void:
	pass


func start_auto_fire(bullet_data: Resource = null, direction: Vector2 = Vector2.ZERO) -> void:
	if bullet_data:
		default_bullet_data = bullet_data
		# If the bullet data resource defines a fire_rate, prefer it for auto_fire
		if _object_has_property(default_bullet_data, "fire_rate"):
			var fr = float(default_bullet_data.fire_rate)
			if fr > 0.0:
				auto_fire_rate = fr
	if direction != Vector2.ZERO:
		default_bullet_direction = direction
	if not has_node("AutoFireTimer"):
		var t = Timer.new()
		t.name = "AutoFireTimer"
		t.one_shot = false
		add_child(t)
		t.connect("timeout", Callable(self, "_on_auto_fire_timeout"))
	$AutoFireTimer.wait_time = 1.0 / max(0.0001, auto_fire_rate)
	if debug_logs:
		print("BulletManager.start_auto_fire: auto_fire_rate=", auto_fire_rate, " wait_time=", $AutoFireTimer.wait_time)
	$AutoFireTimer.start()

func stop_auto_fire() -> void:
	if has_node("AutoFireTimer"):
		$AutoFireTimer.stop()

func _on_auto_fire_timeout() -> void:
	if not default_bullet_data:
		return
	if debug_logs:
		print("BulletManager._on_auto_fire_timeout: spawning bullet at", global_position, "dir=", default_bullet_direction)
	spawn_bullet.call_deferred(self, default_bullet_data, global_position, default_bullet_direction)

func _get_bullets_container() -> Node:
	# Recherche un conteneur de balles unique dans l'arbre de la scène.
	var containers := get_tree().get_nodes_in_group("BulletsContainer")
	if containers.size() > 0:
		return containers[0]
	
	push_error("BulletManager: Impossible de trouver un nœud dans le groupe 'BulletsContainer'. Veuillez en ajouter un à votre scène principale.")
	return null

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
	if not bullets_parent:
		# L'erreur a déjà été affichée dans _get_bullets_container, on arrête ici.
		return null
		
	var b: Bullet
	if is_instance_valid(_bullet_pool):
		b = _bullet_pool.get_bullet()
	else:
		# Fallback to instantiating if pool is not found (error already shown)
		print("[BulletManager] Bullet instantiated without pool.")
		b = bullet_scene.instantiate()
		bullets_parent.add_child(b)
	
	# --- CRITICAL CHANGE ---
	# Setup and activate the bullet IMMEDIATELY after getting it from the pool.
	# This prevents race conditions with `await` in patterns.
	if b.has_method("setup"):
		b.global_position = at_pos
		b.setup(effective_data)
		# We activate it later, after the pattern is chosen.
	else:
		push_error("BulletManager: La scène de balle n'a pas de méthode 'setup'.")
		# Return the bullet to the pool if it's unusable
		if is_instance_valid(_bullet_pool): _bullet_pool._on_bullet_reclaimed(b)
		return null

	# match patterns
	match effective_data.pattern:
		BulletData.Pattern.STRAIGHT: _pattern_straight(b, effective_data, direction)
		BulletData.Pattern.AIMED: _pattern_aimed(b, effective_data, _spawner, options)
		BulletData.Pattern.SPREAD: await _pattern_spread(b, effective_data, _spawner, direction, options)
		BulletData.Pattern.HOMING: _pattern_homing(b, effective_data, _spawner, options)
		BulletData.Pattern.CURVED: _pattern_curved(b, effective_data, direction)
		_: _pattern_straight(b, effective_data, direction)
	
	# Activate the bullet now that its velocity and state are set by the pattern.
	b.activate()

	# Debug output for testing in-game/editor
	if debug_logs:
		var spawner_name := "<none>"
		if _spawner:
			spawner_name = _spawner.name
		var pattern_name := str(effective_data.pattern)
		print("BulletManager.spawn_bullet => spawner=", spawner_name, ", data=", effective_data, ", pos=", at_pos, ", dir=", direction, ", pattern=", pattern_name)

	return b


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


func _pattern_straight(bullet, data, direction: Vector2) -> void:
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


func _pattern_spread(bullet, data, _spawner: Node, direction: Vector2, options := {}) -> void:
	# This function is responsible for spawning multiple bullets in a fan shape.
	# The 'bullet' parameter is the first bullet, already instantiated by spawn_bullet.
	var count = max(1, data.spread_count)
	if count <= 1:
		# If spread count is 1, just behave like a straight bullet.
		_pattern_straight(bullet, data, direction)
		return

	# Determine the central direction of the spread based on the BulletData's target_direction
	var base_dir = _get_base_direction(data, bullet.global_position, direction)
	# Apply arc offset
	base_dir = base_dir.rotated(deg_to_rad(data.spread_arc_offset_deg))
	
	var half = (float(count) - 1.0) / 2.0
	var base_speed = data.speed
	
	for i in range(count):
		var angle_deg: float
		# If there's more than one bullet, distribute them across the arc.
		if count > 1:
			var angle_step = data.spread_arc_angle_deg / (count - 1)
			angle_deg = (float(i) - half) * angle_step
		else:
			# If there's only one bullet, its angle is 0 (it goes straight).
			angle_deg = 0.0
			
		# Apply angle randomness
		var random_angle = randf_range(-data.spread_angle_randomness, data.spread_angle_randomness)
		var angle = deg_to_rad(angle_deg + random_angle)
		var final_dir = base_dir.rotated(angle)
		
		# Apply speed randomness by creating a temporary copy of the data
		var temp_data = data.duplicate()
		var random_speed = base_speed + randf_range(-data.spread_speed_randomness, data.spread_speed_randomness)
		temp_data.speed = max(0, random_speed)
		
		if i == 0:
			# Configure the first bullet that was already created for us.
			# Its setup was already done in spawn_bullet. We just set its velocity.
			_pattern_straight(bullet, temp_data, final_dir)
		else:
			# For all other bullets, we must instantiate and configure them manually.
			_spawn_simple_bullet(temp_data, bullet.global_position, final_dir)

		# Handle burst delay
		if data.spread_burst_delay > 0 and i < count - 1:
			await get_tree().create_timer(data.spread_burst_delay).timeout
			

func _pattern_homing(bullet, data, _spawner: Node, options := {}) -> void:
	# store homing parameters on the bullet for the bullet script to use
	var target = options.get("target", null)
	
	# If no target is provided, and the bullet is not from the player, automatically target the player.
	if not target and not data.is_player_bullet:
		if debug_logs: print("[HOMING_DEBUG] Manager: No target provided, searching for Player.")
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			target = players[0]
			if debug_logs: print("[HOMING_DEBUG] Manager: Player found: ", target)
		else:
			if debug_logs: print("[HOMING_DEBUG] Manager: No Player found in group 'Player'.")
			
	bullet.set_meta("homing_target", target)
	bullet.set_meta("homing_time", data.homing_duration)
	bullet.set_meta("homing_strength", data.homing_strength)
	if debug_logs: print("[HOMING_DEBUG] Manager: Meta set on bullet: target=", target, ", time=", data.homing_duration, ", strength=", data.homing_strength)
	
	# Set an initial non-aimed direction. The homing logic in bullet.gd will handle the aiming.
	# We avoid calling _pattern_straight directly to prevent it from auto-aiming.
	var initial_dir = options.get("initial_dir", Vector2.DOWN)
	if initial_dir == Vector2.ZERO: initial_dir = Vector2.DOWN
	bullet.velocity = initial_dir.normalized() * data.speed
	if debug_logs: print("[HOMING_DEBUG] Manager: Initial velocity set to: ", bullet.velocity)


func _pattern_curved(bullet, data, direction: Vector2) -> void:
	# store curve params; the bullet script will use them
	bullet.set_meta("curve_frequency", data.curve_frequency)
	bullet.set_meta("curve_amplitude", data.curve_amplitude)
	_pattern_straight(bullet, data, direction)

func _get_base_direction(data: BulletData, from_pos: Vector2, spawner_dir: Vector2) -> Vector2:
	"""
	Calculates the initial direction vector based on the target_direction enum in BulletData.
	"""
	match data.target_direction:
		BulletData.TargetDirection.AIM_PLAYER:
			var players = get_tree().get_nodes_in_group("Player")
			if players.size() > 0:
				var target = players[0]
				return (target.global_position - from_pos).normalized()
			# Fallback if no player found
			return Vector2.DOWN
		
		BulletData.TargetDirection.SCREEN_CENTER:
			var screen_center = get_viewport().get_visible_rect().size / 2.0
			return (screen_center - from_pos).normalized()
			
		BulletData.TargetDirection.FIXED_DOWN:
			return Vector2.DOWN
			
		BulletData.TargetDirection.SPAWNER_FORWARD:
			return spawner_dir if spawner_dir != Vector2.ZERO else Vector2.DOWN

	# Default fallback
	return spawner_dir if spawner_dir != Vector2.ZERO else Vector2.DOWN

func _spawn_simple_bullet(bullet_data: Resource, at_pos: Vector2, direction: Vector2) -> Node:
	"""
	Helper function to instantiate, parent, and configure a single bullet.
	This is a lightweight version of spawn_bullet, used internally by patterns like SPREAD
	to avoid recursive loops. It only handles the STRAIGHT pattern.
	"""
	var bullets_parent = _get_bullets_container()
	if not bullets_parent:
		return null
		
	var b: Bullet
	if is_instance_valid(_bullet_pool):
		b = _bullet_pool.get_bullet()
	else:
		b = bullet_scene.instantiate()
		bullets_parent.add_child(b)
	
	if b.has_method("setup"):
		b.global_position = at_pos
		b.setup(bullet_data) # Setup first
		_pattern_straight(b, bullet_data, direction) # Then set velocity
		b.activate() # Then activate
	else:
		push_error("BulletManager: La scène de balle n'a pas de méthode 'setup'.")
		if is_instance_valid(_bullet_pool): _bullet_pool._on_bullet_reclaimed(b)
		
	return b

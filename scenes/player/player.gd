extends "res://scenes/utils/entity/entity.gd"

@export var speed := 350.0
@export var shoot_cooldown := 0.25
@export var bullet_scene: PackedScene = preload("res://scenes/bullet/Bullet.tscn")

var _can_shoot := true
var _half_width := 0.0
var _half_height := 0.0

func _ready() -> void:
	add_to_group("Player")
	
	# Calculer les dimensions du collider une fois pour toutes
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape:
		_half_width = collision_shape.shape.extents.x if collision_shape.shape is RectangleShape2D else collision_shape.shape.radius
		_half_height = collision_shape.shape.extents.y if collision_shape.shape is RectangleShape2D else collision_shape.shape.radius


func _physics_process(_delta: float) -> void:
	_handle_movement()
	
	if Input.is_action_pressed("shoot") and _can_shoot:
		_shoot()
		_can_shoot = false
		await get_tree().create_timer(shoot_cooldown).timeout
		_can_shoot = true

func _handle_movement() -> void:
	var dir := Vector2.ZERO
	dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if dir.length() > 0:
		dir = dir.normalized()
		velocity = dir * speed
		move_and_slide()
	
	# Limiter la position dans la zone de jeu (512x720)
	position.x = clamp(position.x, _half_width, 512 - _half_width)
	position.y = clamp(position.y, _half_height, 720 - _half_height)

func _shoot() -> void:
	var bullet = bullet_scene.instantiate()
	bullet.position = global_position + Vector2(0, -16)
	bullet.target_type = 1 # TargetType.ENEMIES
	get_parent().get_node("Bullets").add_child(bullet)


func _on_damaged(_damage: int, _source: Node) -> void:
	# Mettre à jour UI ou effets visuels
	pass

func _on_die(_source: Node) -> void:
	# Game over logique
	SignalManager.emit_signal("player_died")
	call_deferred("queue_free")

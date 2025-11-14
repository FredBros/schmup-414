extends "res://scenes/utils/entity/entity.gd"

@export var speed := 120.0
@export var shoot_cooldown := 2.0
@export var bullet_scene: PackedScene = preload("res://scenes/bullet/Bullet.tscn")

var _can_shoot := true

func _ready() -> void:
	add_to_group("Enemies")
	
	# Démarrer le tir automatique
	_start_shooting()

func _physics_process(delta: float) -> void:
	position.y += speed * delta
	if position.y > get_viewport().size.y + 20:
		queue_free()

func _start_shooting() -> void:
	while is_instance_valid(self):
		if _can_shoot:
			_shoot()
		await get_tree().create_timer(shoot_cooldown).timeout

func _shoot() -> void:
	if not is_instance_valid(self):
		return
	
	var bullet = bullet_scene.instantiate()
	bullet.position = global_position + Vector2(0, 16)
	bullet.target_type = 0 # TargetType.PLAYER
	bullet.speed = 400.0
	bullet.velocity = Vector2(0, bullet.speed)
	
	# Ajouter au node Bullets du monde
	var bullets_node = get_tree().get_first_node_in_group("BulletsContainer")
	if bullets_node:
		bullets_node.add_child(bullet)
	else:
		get_parent().add_child(bullet)

func _on_damaged(_damage: int, _source: Node) -> void:
	pass

func _on_die(_source: Node) -> void:
	queue_free()
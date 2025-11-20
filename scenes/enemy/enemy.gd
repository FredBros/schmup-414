extends "res://scenes/utils/entity/entity.gd"

@export var speed := 120.0
@export var shoot_cooldown := 2.0
@export var bullet_scene: PackedScene
@export var bullet_data_resource: BulletData

var _can_shoot := true

func _ready() -> void:
	add_to_group("Enemies")
	
	if not bullet_scene:
		bullet_scene = load("res://scenes/bullet/bullet prefab/bullet.tscn")
	
	if not bullet_data_resource:
		bullet_data_resource = load("res://scenes/bullet/bullet prefab/basic_bullet.tres")
	
	# Démarrer le tir automatique via le BulletManager si configuré
	var bm := get_node_or_null("BulletManager")
	if bm:
		# Configure the manager default bullet data and fire rate from enemy settings
		if bullet_data_resource:
			bm.default_bullet_data = bullet_data_resource
			# Prefer the BulletData-specified fire_rate if present
			if bullet_data_resource.fire_rate > 0.0:
				bm.auto_fire_rate = bullet_data_resource.fire_rate
			else:
				bm.auto_fire_rate = 1.0 / max(0.0001, shoot_cooldown)
		else:
			# No bullet resource: fall back to enemy shoot_cooldown
			bm.auto_fire_rate = 1.0 / max(0.0001, shoot_cooldown)
		bm.default_bullet_direction = Vector2(0, 1)
		if bm.debug_logs:
			print("Enemy._ready: shoot_cooldown=", shoot_cooldown, ", bm.auto_fire_rate=", bm.auto_fire_rate)
		bm.start_auto_fire()

func _physics_process(delta: float) -> void:
	position.y += speed * delta
	if position.y > get_viewport().size.y + 20:
		queue_free()

func _on_damaged(_damage: int, _source: Node) -> void:
	pass

func _on_die(_source: Node) -> void:
	queue_free()

extends "res://scenes/utils/entity/entity.gd"

class_name Enemy

## Signal émis lorsque l'ennemi doit être retourné au pool.
signal reclaimed(enemy)

@export var speed := 120.0
@export var shoot_cooldown := 2.0
@export var bullet_scene: PackedScene
@export var bullet_data_resource: BulletData

var _is_reclaimed := false

## Référence mise en cache au BulletManager pour éviter les appels répétés à get_node.
@onready var _bullet_manager: Node = get_node_or_null("BulletManager")
## Référence mise en cache au composant Health.
@onready var _health_component: Node = get_node_or_null("Health")
var _lifetime_timer: Timer

# --- Variables de comportement ---
var _behavior_pattern: EnemyBehaviorPattern
var _time_alive: float = 0.0
var _start_pos: Vector2


func _ready() -> void:
	add_to_group("Enemies")
	
	if not bullet_scene:
		bullet_scene = load("res://scenes/bullet/bullet prefab/bullet.tscn")
	
	if not bullet_data_resource:
		bullet_data_resource = load("res://scenes/bullet/bullet prefab/basic_bullet.tres")

	# Créer le timer de durée de vie s'il n'existe pas
	if not has_node("LifetimeTimer"):
		_lifetime_timer = Timer.new()
		_lifetime_timer.name = "LifetimeTimer"
		_lifetime_timer.one_shot = true
		add_child(_lifetime_timer)
		_lifetime_timer.timeout.connect(_reclaim)
	else:
		_lifetime_timer = get_node("LifetimeTimer")

func set_behavior_pattern(pattern: EnemyBehaviorPattern) -> void:
	"""Définit le pattern de comportement que cet ennemi doit suivre."""
	_behavior_pattern = pattern


func activate() -> void:
	"""Active l'ennemi, le rend visible, réinitialise son état et démarre ses comportements."""
	visible = true
	_is_reclaimed = false
	set_physics_process(true)
	# Réactiver les collisions (supposant que le Hurtbox gère la collision principale)
	var hurtbox = find_child("Hurtbox", true, false)
	if hurtbox:
		hurtbox.get_node("CollisionShape2D").set_deferred("disabled", false)
		
	# Initialiser les variables de comportement
	_time_alive = 0.0
	_start_pos = global_position

	# Demander au composant Health de se réinitialiser lui-même.
	if _health_component and _health_component.has_method("reset"):
		_health_component.reset()

	# Configurer et démarrer le tir automatique
	if _bullet_manager:
		if bullet_data_resource:
			_bullet_manager.default_bullet_data = bullet_data_resource
			if bullet_data_resource.fire_rate > 0.0:
				_bullet_manager.auto_fire_rate = bullet_data_resource.fire_rate
			else:
				_bullet_manager.auto_fire_rate = 1.0 / max(0.0001, shoot_cooldown)
		else:
			_bullet_manager.auto_fire_rate = 1.0 / max(0.0001, shoot_cooldown)
		_bullet_manager.default_bullet_direction = Vector2.DOWN
		_bullet_manager.start_auto_fire()
		
	# Démarrer le timer de durée de vie
	var lifetime = get_meta("pool_lifetime", 0.0)
	if lifetime > 0.0:
		_lifetime_timer.wait_time = lifetime
		_lifetime_timer.start()


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
		
	# Arrêter le timer de durée de vie pour éviter qu'il ne se déclenche dans le pool
	_lifetime_timer.stop()


func _physics_process(delta: float) -> void:
	_time_alive += delta
	
	if not _behavior_pattern:
		# Comportement par défaut si aucun pattern n'est défini
		position.y += speed * delta
		return

	match _behavior_pattern.movement_type:
		EnemyBehaviorPattern.MovementType.LINEAR:
			position.y += speed * delta
			
		EnemyBehaviorPattern.MovementType.SINUSOIDAL:
			# Mouvement vertical de base
			position.y += speed * delta
			# Mouvement horizontal sinusoïdal
			var offset_x = sin(_time_alive * _behavior_pattern.sine_frequency) * _behavior_pattern.sine_amplitude
			position.x = _start_pos.x + offset_x
			
		EnemyBehaviorPattern.MovementType.PATH_2D:
			# La logique pour suivre un Path2D sera ajoutée ici.
			# Pour l'instant, il ne fait rien pour ce type.
			position.y += speed * delta # Comportement de repli


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

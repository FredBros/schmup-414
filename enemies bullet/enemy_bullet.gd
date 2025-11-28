extends Area2D
class_name EnemyBullet

## Signal émis lorsque la balle a terminé son cycle de vie et doit être retournée au pool.
signal reclaimed(bullet)

## The data resource that defines this bullet's properties.
## This MUST be assigned in the editor for the bullet scene to work.
@export var bullet_data: BulletData

var velocity: Vector2 = Vector2.ZERO
var _is_reclaimed: bool = false
var _life_timer: Timer

func _ready() -> void:
	# Créer un Timer permanent pour gérer la durée de vie.
	# Cela évite de créer des timers anonymes qui ne sont jamais détruits.
	_life_timer = Timer.new()
	_life_timer.one_shot = true
	_life_timer.timeout.connect(_reclaim)
	add_child(_life_timer)
	
	# Les balles du pool commencent désactivées.
	deactivate()


func activate() -> void:
	"""Active la balle, la rendant visible et mobile."""
	print("[%s] ACTIVATE called." % name)
	_is_reclaimed = false
	visible = true
	set_physics_process(true)
	get_node("CollisionShape2D").disabled = false
	
	if not bullet_data:
		push_error("EnemyBullet scene is missing its 'bullet_data' resource. It will not function.")
		_reclaim() # Utilise le système de pooling pour se désactiver
		return

	# Apply visual properties from the data resource to the sprite
	bullet_data.apply_to_sprite(get_node("Sprite2D"))

	# Set velocity based on the bullet's rotation (set by the spawner) and data.
	# The bullet is spawned with a rotation pointing in its direction of travel.
	# Vector2.RIGHT.rotated(rotation) gives us the direction vector.
	velocity = Vector2.RIGHT.rotated(rotation) * bullet_data.speed
	print("[%s] Velocity set to: %s" % [name, velocity])

	# If a lifetime is set, create a timer to self-destruct.
	# On démarre notre timer permanent au lieu d'en créer un nouveau.
	if bullet_data.life_duration > 0:
		_life_timer.start(bullet_data.life_duration)

func deactivate() -> void:
	"""Désactive la balle pour la retourner au pool."""
	visible = false
	set_physics_process(false)
	# Désactive la collision pour éviter les interactions fantômes.
	get_node("CollisionShape2D").set_deferred("disabled", true)
	# CORRECTION : On arrête le timer pour éviter qu'il ne se déclenche
	# pendant que la balle est inactive dans le pool (le bug du "Timer Fantôme").
	_life_timer.stop()


func _physics_process(delta: float) -> void:
	# Move the bullet every frame.
	global_position += velocity * delta


func _on_area_entered(area: Area2D) -> void:
	# This signal is connected from the Area2D node in the editor.
	# We assume the player's hurtbox is an Area2D.
	# The collision layers/masks should be set up so this only triggers for the player.
	if area is Hurtbox and area.is_player_hurtbox:
		area.take_damage(bullet_data.damage, self)
		_reclaim() # Reclaim the bullet ONLY after it hits a valid target.


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	# This signal is connected from the VisibleOnScreenNotifier2D node.
	_reclaim() # Ne pas détruire, mais retourner au pool.

func _reclaim() -> void:
	"""Émet le signal pour être retourné au pool."""
	if _is_reclaimed:
		return
	_is_reclaimed = true
	# On émet le signal de manière différée pour s'assurer que toutes les opérations
	# qui en découlent (reparenting, désactivation de la collision) se produisent
	# en dehors du cycle de physique, ce qui évite les erreurs.
	reclaimed.emit.call_deferred(self)
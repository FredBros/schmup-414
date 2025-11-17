extends Area2D
class_name Bullet

enum TargetType {
	PLAYER,
	ENEMIES
}
var target_type: TargetType
@export var speed := 700.0
@export var damage: int = 1

var velocity := Vector2.ZERO

func _ready() -> void:
	add_to_group("Bullets")
	# Si velocity n'a pas été définie (cas du joueur), utiliser la vitesse par défaut vers le haut
	if velocity == Vector2.ZERO:
		velocity = Vector2(0, -speed)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
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
			call_deferred("queue_free")

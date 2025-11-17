@tool
extends Resource

# Resource that describes a bullet type and parameters.
# Use instances of this resource to configure how an enemy/player spawns bullets.
# Attach .tres files to enemies or pass the resource to BulletManager.spawn_bullet

class_name BulletData

@export_group("Appearance")
# General appearance 
@export_subgroup("Sprite")
@export var sprite: Texture2D
# SpriteSheet / frame selection
@export var sprite_hframes: int = 1
@export var sprite_vframes: int = 1
@export var sprite_frame: int = 0
@export_subgroup("Animation ")
# Animated sprites
@export var sprite_frames: SpriteFrames
@export var animation_name: String = "default"

@export_group("Damage - Physics")
@export var damage: int = 1
@export var speed: float = 700.0
@export var fire_rate: float = 1.0 # tirs/sec (useful for enemies, optional)
@export var life_duration: float = 5.0 # secondes avant suppression

@export_group("Behavior")
# Team: if true this bullet belongs to player; else to enemies.
@export var is_player_bullet: bool = false

# Behaviour patterns
enum Pattern {
	STRAIGHT,
	AIMED,
	SPREAD,
	HOMING,
	CURVED,
}

@export var pattern: Pattern = Pattern.STRAIGHT

@export_group("Spread")
# Spread parameters
@export var spread_count: int = 3
@export var spread_angle_deg: float = 15.0

@export_group("Homing")
# Homing parameters
@export var homing_duration: float = 1.0 # s pendant lequel ça homing
@export var homing_strength: float = 3.0 # vitesse d'interpolation

@export_group("Curved / Curve")
# Curved (sine lateral offset)
@export var curve_frequency: float = 3.0
@export var curve_amplitude: float = 28.0

@export_group("Display")
# Optional sprite tinting / z-index / collision shape override
@export var modulate: Color = Color.WHITE
@export var z_index_offset: int = 0

@export_group("CollisionShape")
# Collision shape presets (circle radii in pixels)
enum CollisionSize {
	VERY_SMALL = 6, ## 6 px
	SMALL = 10, ## 10 px
	MEDIUM = 14, ## 14 px
	LARGE = 20, ## 20 px
	VERY_LARGE = 28, ## 28 px
}
@export var collision_preset: CollisionSize = CollisionSize.SMALL
@export var collision_custom_radius: int = 10
# Optional override: a PackedScene that contains a CollisionShape2D (or a node with a CollisionShape2D child)
@export var collision_prefab_scene: PackedScene
@export var collision_shape_override: Shape2D

# Optional custom script that will be instantiated (script.new()) and called to modify
# the collision node: it should implement 'apply_to_collision(collision_node)' if needed.
@export var collision_behavior_script: GDScript

# Helpful debug name
@export var display_name: String = ""


func _get_property_list() -> Array:
	# make display name more visible in the inspector
	# (no custom dropdown; revert to default)
	# make display name more visible in the inspector
	return []

func _to_string() -> String:
	return display_name if display_name != "" else "BulletData(dmg=%s, speed=%s)".format([damage, speed])

func apply_to_sprite(node: Node) -> void:
	"""
	Apply this BulletData sprite/animation to the provided node.
	If the node is an AnimatedSprite2D and `sprite_frames` is provided, it will set frames and play.
	Otherwise if node is a Sprite2D and `sprite` is provided, it will set the texture and frame.
	"""
	if not is_instance_valid(node):
		return

	# Prefer Animation (AnimatedSprite2D) when frames exist
	if sprite_frames and node is AnimatedSprite2D:
		node.frames = sprite_frames
		if animation_name != "":
			node.animation = animation_name
		node.play()
		return

	# Fallback to a Sprite2D
	if sprite and node is Sprite2D:
		node.texture = sprite
		node.hframes = sprite_hframes
		node.vframes = sprite_vframes
		node.frame = sprite_frame
		node.modulate = modulate
		node.z_index += z_index_offset


func apply_collision(node: Node) -> void:
	"""
	Apply collision info from the resource to the provided node or CollisionShape2D.
	The node may be the Bullet root; the helper will look for an existing CollisionShape2D
	child (node name `CollisionShape2D`) or will accept the node if it is itself a CollisionShape2D.
	If `collision_prefab_scene` is provided we prefer to use that scene's CollisionShape2D.
	If `collision_behavior_script` is provided, it will be instantiated and its
	`apply_to_collision(collision_node)` method called (if present).
	"""
	if not is_instance_valid(node):
		return

	var cs: CollisionShape2D = null
	if node is CollisionShape2D:
		cs = node
	else:
		cs = node.get_node_or_null("CollisionShape2D")
		if not cs:
			# search for any CollisionShape2D child
			for c in node.get_children():
				if c is CollisionShape2D:
					cs = c
					break

	if not cs:
		return

	# Apply prefab override if set
	if collision_prefab_scene:
		var prefab_inst = collision_prefab_scene.instantiate()
		# look for a CollisionShape2D on prefab. If it is a plain CollisionShape2D, use its shape
		if prefab_inst is CollisionShape2D:
			cs.shape = prefab_inst.shape.duplicate()
			prefab_inst.queue_free()
			# else, search in prefab for child CollisionShape2D
		else:
			var found = prefab_inst.get_node_or_null("CollisionShape2D")
			if found:
				# If the found collision node carries a script, duplicate the node to keep it
				if found.get_script() != null:
					var dup = found.duplicate(true)
					cs.get_parent().add_child(dup)
					dup.position = cs.position
					dup.name = cs.name
					cs.queue_free()
					prefab_inst.queue_free()
					return
				else:
					cs.shape = found.shape.duplicate()
			prefab_inst.queue_free()
			# end prefab branch
		
	# Next: if no prefab scene, check a lightweight shape override
	elif collision_shape_override:
		cs.shape = collision_shape_override.duplicate()
	
	else:
		# Default to a circle shape using the preset unless custom radius provided
		# collision_preset is an enum whose value equals the radius in pixels
		var radius = int(collision_preset)
		if collision_custom_radius > 0:
			radius = collision_custom_radius
		var circle = CircleShape2D.new()
		circle.radius = float(radius)
		cs.shape = circle

	# Apply optional behavior script
	if collision_behavior_script:
		var inst = collision_behavior_script.new()
		if inst and inst.has_method("apply_to_collision"):
			inst.apply_to_collision(cs)

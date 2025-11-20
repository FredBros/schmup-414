@tool
extends Resource

# Resource that describes a bullet type and parameters.
# Use instances of this resource to configure how an enemy/player spawns bullets.
# Attach .tres files to enemies or pass the resource to BulletManager.spawn_bullet

class_name BulletData

@export_group("Appearance")
# General appearance 
@export_subgroup("Static Sprite")
## [Optional] The texture for a non-animated bullet.
@export var sprite: Texture2D
## [Optional] Number of horizontal frames in the static sprite sheet.
@export var sprite_hframes: int = 1
## [Optional] Number of vertical frames in the static sprite sheet.
@export var sprite_vframes: int = 1
## [Optional] The specific frame to display from the static sprite sheet.
@export var sprite_frame: int = 0
@export_subgroup("Animated Sprite")
## [Optional] The SpriteFrames resource for an animated bullet.
## If set, this will be used instead of the static sprite.
@export var sprite_frames: SpriteFrames
## The name of the animation to play from the SpriteFrames resource.
@export var animation_name: String = "default"

@export_group("Damage - Physics")
## The amount of damage the bullet inflicts upon hitting a valid target.
@export var damage: int = 1
## The base speed of the bullet in pixels per second.
@export var speed: float = 400.0
## The rate of fire in shots per second.
## This value is used by the BulletManager's auto-fire feature.
## If set to 0, the `shoot_cooldown` on the enemy script will be used as a fallback.
@export var fire_rate: float = 1.0
## The duration in seconds before the bullet is automatically destroyed.
## Set to 0 for no time-based destruction.
@export var life_duration: float = 5.0 # secondes avant suppression

@export_group("Behavior")
# Team: if true this bullet belongs to player; else to enemies.
## If true, this bullet is fired by the player and targets enemies.
## If false, it's fired by an enemy and targets the player.
@export var is_player_bullet: bool = false

# Behaviour patterns
enum Pattern {
	STRAIGHT,
	AIMED,
	SPREAD,
	HOMING,
	CURVED,
}

## The movement pattern the bullet will follow.
@export var pattern: Pattern = Pattern.STRAIGHT

## Defines the primary direction or target for the bullet pattern.
enum TargetDirection {
	## Fires in the direction provided by the spawner (e.g., enemy's forward direction). This is the default.
	SPAWNER_FORWARD,
	## Aims at the player's current position at the moment of firing.
	AIM_PLAYER,
	## Aims towards the center of the game screen.
	SCREEN_CENTER,
	## Always fires straight down (0, 1), regardless of spawner direction.
	FIXED_DOWN,
}
## The primary aiming strategy for the bullet pattern.
## Used by patterns like SPREAD to determine their central axis.
@export var target_direction: TargetDirection = TargetDirection.SPAWNER_FORWARD

@export_group("Spread")
# Spread parameters
## The total number of bullets to fire in a single spread burst.
@export var spread_count: int = 3
## The total angle in degrees for the entire spread arc. Bullets will be evenly distributed within this arc.
@export var spread_arc_angle_deg: float = 30.0
## [Optional] Shifts the entire spread arc by a certain number of degrees.
## Useful for creating rotating patterns.
@export var spread_arc_offset_deg: float = 0.0
## [Optional] Adds a random variation in degrees to each bullet's angle. 0 = no randomness.
@export var spread_angle_randomness: float = 0.0
## [Optional] Adds a random variation to each bullet's speed. 0 = no randomness.
@export var spread_speed_randomness: float = 0.0
## [Optional] Delay in seconds between each bullet in the spread. 0 = all at once.
@export var spread_burst_delay: float = 0.0

@export_group("Homing")
# Homing parameters
## The duration in seconds during which the bullet will actively seek its target.
@export var homing_duration: float = 1.0 # s pendant lequel ça homing
## The turning speed of the bullet. Higher values result in sharper turns.
@export var homing_strength: float = 3.0 # vitesse d'interpolation

@export_group("Curved / Curve")
# Curved (sine lateral offset)
## The frequency of the sine wave. Higher values result in more oscillations.
@export var curve_frequency: float = 3.0
## The amplitude of the sine wave in pixels. This is the maximum distance the bullet will deviate from its central axis.
@export var curve_amplitude: float = 28.0

@export_group("Display")
# Optional sprite tinting / z-index / collision shape override
## [Optional] Tints the bullet's sprite with the specified color.
@export var modulate: Color = Color.WHITE
## [Optional] An offset added to the bullet's z_index for sorting.
@export var z_index_offset: int = 0

@export_group("CollisionShape")
# Collision shape presets (circle radii in pixels)
enum CollisionSize {
	VERY_SMALL = 6,
	SMALL = 10,
	MEDIUM = 14,
	LARGE = 20,
	VERY_LARGE = 28,
}
## A preset for the bullet's collision shape radius.
## Ignored if a custom radius or prefab is provided.
@export var collision_preset: CollisionSize = CollisionSize.SMALL
## [Optional] A custom radius in pixels for the collision shape.
## Overrides the preset.
@export var collision_custom_radius: int = 0
## [Optional] A scene containing a CollisionShape2D to use instead of a basic circle.
## Overrides presets and custom radius.
@export var collision_prefab_scene: PackedScene
## [Optional] A Shape2D resource to use for the collision shape.
## Overrides presets and custom radius, but is overridden by the prefab scene.
@export var collision_shape_override: Shape2D

## [Optional] A custom script to attach to the collision shape for special behaviors.
## The script should implement an 'apply_to_collision(collision_node)' method.
@export var collision_behavior_script: GDScript

# Helpful debug name
## [Optional] A friendly name for this resource, used for debugging and logging.
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

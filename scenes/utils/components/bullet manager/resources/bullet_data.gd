@tool
extends Resource

# Resource that describes a bullet type and parameters.
# Use instances of this resource to configure how an enemy/player spawns bullets.
# Attach .tres files to enemies or pass the resource to BulletManager.spawn_bullet

class_name BulletData

@export_group("Appearance / Damage / Physics")
# General appearance / damage / physics
@export var sprite: Texture2D
@export_group("Animation / Sprite")
# Animated sprites
@export var sprite_frames: SpriteFrames
@export var animation_name: String = "default"
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

# Helpful debug name
@export var display_name: String = ""

# SpriteSheet / frame selection
@export var sprite_hframes: int = 1
@export var sprite_vframes: int = 1
@export var sprite_frame: int = 0


func _get_property_list() -> Array:
	# make display name more visible in the inspector
	# (no custom dropdown; revert to default)
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

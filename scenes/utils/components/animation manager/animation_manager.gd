extends Node2D
class_name AnimationManager

signal state_changed(state_name: String)

# Nœuds à configurer (paths exportables si besoin)
@export var animation_tree_path: NodePath = NodePath("AnimationTree")
@export var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var dust_top_path: NodePath = NodePath("DustTop") # optionnel, GPUParticles2D

# Variables internes
var _anim_tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _velocity: Vector2 = Vector2.ZERO
var _boost_active: bool = false
var _boost_strength: float = 1.0
var _dust_top: GPUParticles2D = null

const DEADZONE := 0.1

func _ready() -> void:
	_anim_tree = get_node_or_null(animation_tree_path) as AnimationTree
	if not _anim_tree:
		push_error("AnimationManager: AnimationTree not found at path %s" % str(animation_tree_path))
		return
	_anim_tree.active = true

	_playback = _anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if not _playback:
		push_error("AnimationManager: Playback not found sur l'AnimationTree.")
		return

	var ap = get_node_or_null(animation_player_path) as AnimationPlayer
	if ap:
		ap.connect("animation_finished", Callable(self, "_on_animation_finished"))

	if has_node(dust_top_path):
		_dust_top = get_node(dust_top_path) as GPUParticles2D
		if _dust_top:
			_dust_top.emitting = false

	if _anim_tree.has_parameter("parameters/Boost/Active"):
		_anim_tree.set("parameters/Boost/Active", false)
	if _anim_tree.has_parameter("parameters/Boost/Strength"):
		_anim_tree.set("parameters/Boost/Strength", 1.0)

func set_velocity(velocity: Vector2) -> void:
	_velocity = velocity
	_update_state()

func set_boost(active: bool, strength: float = 1.0) -> void:
	_boost_active = active
	_boost_strength = strength
	if _anim_tree and _anim_tree.has_parameter("parameters/Boost/Active"):
		_anim_tree.set("parameters/Boost/Active", active)
	if _anim_tree and _anim_tree.has_parameter("parameters/Boost/Strength"):
		_anim_tree.set("parameters/Boost/Strength", strength)

func trigger_top() -> void:
	travel("Top")
	if _dust_top:
		_dust_top.emitting = true

func trigger_hurted() -> void:
	travel("Hurted")

func trigger_shoot() -> void:
	travel("Shoot")

func set_raw_state(state_name: String) -> void:
	travel(state_name)

func _update_state() -> void:
	if not _playback:
		return
	var speed := _velocity.length()
	if speed <= DEADZONE:
		travel("Idle")
		return

	if _velocity.x < -DEADZONE:
		travel("To_Left")
	elif _velocity.x > DEADZONE:
		travel("To_Right")
	else:
		travel("Idle")

	if _boost_active:
		if _anim_tree and _anim_tree.has_parameter("parameters/Boost/Strength"):
			_anim_tree.set("parameters/Boost/Strength", _boost_strength)
		if _anim_tree and _anim_tree.has_parameter("parameters/Boost/Active"):
			_anim_tree.set("parameters/Boost/Active", true)

func travel(state_name: String) -> void:
	if not _playback:
		return
	if _playback.get_current_node() == state_name:
		return
	_playback.travel(state_name)
	emit_signal("state_changed", state_name)

func _on_animation_finished(anim_name: String) -> void:
	# Après des animations ponctuelles (Top/Hurted/Shoot), revenir à l’état courant en fonction de la velocity
	if anim_name in ["Top", "Hurted", "Shoot"]:
		_update_state()
		if anim_name == "Top" and _dust_top:
			_dust_top.emitting = false

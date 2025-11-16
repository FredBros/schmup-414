extends Node
class_name AnimationManager

signal state_changed(state_name: String)

# Nœuds à configurer (paths exportables si besoin)
# AnimationTree removed — we drive locomotion via AnimationPlayer now
@export var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var dust_top_path: NodePath = NodePath("DustTop") # optionnel, GPUParticles2D

# Variables internes
# AnimationTree removed — no longer used
var _velocity: Vector2 = Vector2.ZERO
var _last_input_dir: Vector2 = Vector2.ZERO
var _boost_active: bool = false
var _boost_strength: float = 1.0
var _dust_top: CPUParticles2D = null
var _animation_player: AnimationPlayer = null
@export var debug := true
 # legacy debug var; removed (we use state machine debug prints)
var _debug_frame_counter: int = 0
var _last_state_change_frame: int = 0
@export var state_change_cooldown_frames: int = 3
enum State {
	IDLE,
	LEFT,
	RIGHT,
}

enum Phase {
	ENTER,
	STEADY,
	EXIT
}

var _state: State = State.IDLE
var _phase: Phase = Phase.STEADY

const DEADZONE := 0.1

func _ready() -> void:
	# No AnimationTree required — use only AnimationPlayer for animations
	_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	if _animation_player:
		_animation_player.connect("animation_finished", Callable(self, "_on_animation_finished"))

	if has_node(dust_top_path):
		_dust_top = get_node(dust_top_path) as CPUParticles2D
		if _dust_top:
			_dust_top.emitting = false

	# If you previously used Boost parameters on AnimationTree, prefer using
	# a dedicated animation in AnimationPlayer or manipulate particle nodes.

	# Connect to parent signals (player) so player emits and manager listens
		# Debug: list animations available in AnimationPlayer (helps to spot missing states)
		if debug and _animation_player:
			# get_animation_list exists in Godot 4 to inspect available animations
			if _animation_player.has_method("get_animation_list"):
				var anims = _animation_player.get_animation_list()
				print("AnimationManager: available animation names: %s" % str(anims))
	var parent_node = get_parent()
	if parent_node:
		if parent_node.has_signal("movement_updated"):
			parent_node.connect("movement_updated", Callable(self, "_on_parent_movement"))
		if parent_node.has_signal("boost_changed"):
			parent_node.connect("boost_changed", Callable(self, "_on_parent_boost"))
		if parent_node.has_signal("shoot_pressed"):
			parent_node.connect("shoot_pressed", Callable(self, "_on_parent_shoot"))
		if parent_node.has_signal("player_hurt"):
			parent_node.connect("player_hurt", Callable(self, "_on_parent_hurt"))


func set_velocity(velocity: Vector2) -> void:
	_velocity = velocity
	_update_state()

func _get_state_name(s: int) -> String:
	match s:
		State.IDLE:
			return "Idle"
		State.LEFT:
			return "Left"
		State.RIGHT:
			return "Right"
	return "Unknown"

func _request_state(target: int) -> void:
	# Small frame-based cooldown to avoid flapping
	# Only debounce if the requested state is the same as the current state
	# (this avoids blocking real state changes when the player switches direction quickly).
	if target == _state and _debug_frame_counter - _last_state_change_frame < state_change_cooldown_frames:
		if debug:
			print("AnimationManager: request_state('%s') debounced" % _get_state_name(target))
		return

	# Decide transient states for enter/exit
	match target:
		State.IDLE:
			if _state == State.IDLE:
				return
			# If we are currently in LEFT/RIGHT, play the exit (backwards To_Left/To_Right)
			if _state == State.LEFT or _state == State.RIGHT:
				_phase = Phase.EXIT
				# Re-run enter hook for the current state with EXIT phase -> will play backwards
				_on_state_enter(_state, 0)
				return
			# Fallback: just set to Idle
			_do_state_change(State.IDLE)
		State.LEFT:
			if _state == State.LEFT and _phase == Phase.STEADY:
				return
			_do_state_change(State.LEFT)
		State.RIGHT:
			if _state == State.RIGHT and _phase == Phase.STEADY:
				return
			_do_state_change(State.RIGHT)
		_:
			_do_state_change(target)

func _do_state_change(new_state: int) -> void:
	var prev_state := _state
	var prev_phase := _phase
	# Exit hook
	# Only log when state really changes (avoid spam 'Right' -> 'Right')
	if debug and (prev_state != new_state or prev_phase != _phase):
		print("AnimationManager: state change request '%s' -> '%s'" % [_get_state_name(prev_state), _get_state_name(new_state)])
	_on_state_exit(prev_state, new_state)
	_state = new_state as State
	# default phase is enter for different state
	if prev_state != _state:
		_phase = Phase.ENTER
	_last_state_change_frame = _debug_frame_counter
	# Enter hook
	_on_state_enter(new_state, prev_state)
	emit_signal("state_changed", _get_state_name(new_state))

func _on_state_enter(state_idx: int, _from_state: int) -> void:
	if not _animation_player:
		return
	match state_idx:
		State.IDLE:
			if _animation_player.has_animation("Idle"):
				_animation_player.play("Idle")
		State.LEFT:
			# Entering LEFT -> play To_Left then Left
			if _phase == Phase.ENTER:
				if _animation_player.has_animation("To_Left"):
					_animation_player.play("To_Left")
				else:
					# fallback directly to steady
					_phase = Phase.STEADY
					if _animation_player.has_animation("Left"):
						_animation_player.play("Left")
			elif _phase == Phase.STEADY:
				if _animation_player.has_animation("Left"):
					_animation_player.play("Left")
			elif _phase == Phase.EXIT:
				# Exit -> play To_Left in reverse
				if _animation_player.has_animation("To_Left"):
					_animation_player.play_backwards("To_Left")
				else:
					_do_state_change(State.IDLE)
		State.RIGHT:
			if _phase == Phase.ENTER:
				if _animation_player.has_animation("To_Right"):
					_animation_player.play("To_Right")
				else:
					_phase = Phase.STEADY
					if _animation_player.has_animation("Right"):
						_animation_player.play("Right")
			elif _phase == Phase.STEADY:
				if _animation_player.has_animation("Right"):
					_animation_player.play("Right")
			elif _phase == Phase.EXIT:
				if _animation_player.has_animation("To_Right"):
					_animation_player.play_backwards("To_Right")
				else:
					_do_state_change(State.IDLE)

func _on_state_exit(state_idx: int, _to_state: int) -> void:
	# We keep this hook for effects (particles, etc) and to cancel anything in progress.
	if state_idx == State.LEFT and _dust_top:
		# no-op for now, placeholder
		pass

func set_boost(active: bool, strength: float = 1.0) -> void:
	_boost_active = active
	_boost_strength = strength
	# Toggle particles for top boost if available. This does not interfere
	# with the locomotion animations (Idle/Left/Right) so the ship stays
	# in its current base state while boost is active.
	if _dust_top:
		_dust_top.emitting = active

func trigger_top() -> void:
	# 'Top' is a one-shot overlay animation handled directly on AnimationPlayer
	play_one_shot("Top")
	if _dust_top:
		_dust_top.emitting = true

func trigger_hurted() -> void:
	# Prefer one-shot animation via AnimationPlayer (overlay) if available
	play_one_shot("Hurted")
	return

func trigger_shoot() -> void:
	# Prefer one-shot animation via AnimationPlayer (overlay) if available
	play_one_shot("Shoot")
	return

 # Legacy: previously allowed external forcing of state; no longer used in SHRUP design (use firing events)
 # func set_raw_state(state_name: String) -> void:
#     (travel() removed — use the code-driven state machine methods instead)

func play_one_shot(anim_name: String) -> void:
	# Play an animation on AnimationPlayer, used for non-state overlays (shoot/hurt)
	if _animation_player and _animation_player.has_animation(anim_name):
		if debug:
			print("AnimationManager: play one-shot '" + anim_name + "'")
		_animation_player.play(anim_name)
	else:
		if debug:
			print("AnimationManager: one-shot '" + anim_name + "' not found (skipping)")

func _update_state() -> void:
	# No raw override: state decisions are all based on velocity.x only
	# (move_down will no longer force Idle)
	# We don't require AnimationTree playback for our code-driven state machine.
	# Idle is based only on horizontal velocity (x), vertical doesn't matter
	var h_speed: float = abs(float(_velocity.x))
	# Always increment the frame counter so the debounce mechanism works
	# irrespective of debug mode. Only print logs when debug is enabled.
	_debug_frame_counter += 1
	if debug:
		# Debug helper: log the velocity and current playback state to trace unexpected transitions
		var current_state: String = _get_state_name(_state)
		# Print occasionally (approx every 60 frames)
		if _debug_frame_counter % 60 == 0:
			print("AnimationManager: debug state=%s velocity=%s h_speed=%f" % [current_state, _velocity, h_speed])
	if h_speed <= DEADZONE:
		# If horizontal velocity is small, still check raw horizontal input
		# because diagonal movement (up+right / up+left) may reduce h_speed
		# but the player still intends to move horizontally; read actions
		var raw_h := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		# Also consider player's raw input direction (intent) to avoid missing diagonals
		if _last_input_dir.x > DEADZONE:
			_request_state(State.RIGHT)
			return
		elif _last_input_dir.x < -DEADZONE:
			_request_state(State.LEFT)
			return
		if raw_h > DEADZONE:
			_request_state(State.RIGHT)
			return
		elif raw_h < -DEADZONE:
			_request_state(State.LEFT)
			return

		# No horizontal input -> Idle
		_request_state(State.IDLE)
		return

	# Prefer raw input intent if present: this helps with quick diagonal
	# changes where the horizontal velocity may lag or be reduced.
	if abs(_last_input_dir.x) > DEADZONE:
		if _last_input_dir.x < 0:
			_request_state(State.LEFT)
		else:
			_request_state(State.RIGHT)
		return

	if _velocity.x < -DEADZONE:
		_request_state(State.LEFT)
	elif _velocity.x > DEADZONE:
		_request_state(State.RIGHT)

	if _boost_active:
		# If you used Boost / parameters in AnimationTree, replace with your
		# own logic (animation overlay, parameter, particle control).
		if _animation_player and _animation_player.has_animation("Boost"):
			_animation_player.play("Boost")

# Note: legacy 'travel' helper removed — this manager now uses a simple
# code-driven state machine (IDLE/LEFT/RIGHT) and AnimationPlayer overlays.

func _on_animation_finished(anim_name: String) -> void:
	# Après des animations ponctuelles (Top/Hurted/Shoot), revenir à l’état courant en fonction de la velocity
	if anim_name in ["Top", "Hurted", "Shoot"]:
		_update_state()
		if anim_name == "Top" and _dust_top:
			_dust_top.emitting = false

	# Auto-transition for To_Left/To_Right -> Left/Right
	if anim_name == "To_Left":
		# End of enter transition -> switch to steady LEFT
		if _state == State.LEFT and _phase == Phase.ENTER:
			_phase = Phase.STEADY
			# play steady animation
			_on_state_enter(State.LEFT, 0)
			return
		# End of exit -> go to Idle
		if _state == State.LEFT and _phase == Phase.EXIT:
			_do_state_change(State.IDLE)
			return
	if anim_name == "To_Right":
		if _state == State.RIGHT and _phase == Phase.ENTER:
			_phase = Phase.STEADY
			_on_state_enter(State.RIGHT, 0)
			return
		if _state == State.RIGHT and _phase == Phase.EXIT:
			_do_state_change(State.IDLE)
			return

func _on_parent_movement(velocity: Vector2, input_dir: Vector2) -> void:
	_last_input_dir = input_dir
	set_velocity(velocity)

func _on_parent_boost(active: bool, strength: float) -> void:
	set_boost(active, strength)

func _on_parent_shoot() -> void:
	trigger_shoot()

func _on_parent_hurt() -> void:
	trigger_hurted()

# Removed raw override handler: move_down no longer forces Idle or other states.

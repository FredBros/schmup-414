# File: res://scenes/utils/squadron controller/squadron_controller.gd
# This script should be attached to a Node2D node.

extends Node2D

class_name SquadronController

## Emitted when the controller has finished its lifecycle and should be returned to the pool.
signal reclaimed(controller)

var sequential_behavior_patterns: Array[EnemyBehaviorPattern] = [] # La séquence complète de comportements
var formation_pattern: FormationPattern
var members: Array[Enemy] = []

var _is_reclaimed := false

@onready var _path_follower: PathFollow2D = $PathFollower
var level_sequencer: LevelSequencer # Référence au LevelSequencer pour obtenir les cibles (Homing)

# State variables for specific movement patterns
var velocity: Vector2 = Vector2.ZERO
var _current_behavior_pattern: EnemyBehaviorPattern # Le pattern de comportement actif du segment actuel
var _current_behavior_index: int = 0 # L'index du pattern de comportement actuel dans la séquence
var _current_segment_age: float = 0.0 # L'âge (durée) du segment de comportement actuel
var _sinusoidal_time: float = 0.0
var _bounces_left: int = 0
var _age: float = 0.0

# This will be set by the spawner.
var debug_mode := false

## Speed at which the squadron turns to align with its direction (in radians/sec).
@export var turn_speed: float = 4.0

func activate() -> void:
	"""Activates the controller, resetting its state and making it process."""
	_is_reclaimed = false
	_age = 0.0
	_current_behavior_index = 0
	_current_segment_age = 0.0
	_sinusoidal_time = 0.0
	
	
	# Make the controller itself visible. This is the missing piece.
	visible = true
	
	set_physics_process(true)
	# Make all members visible
	for member in members:
		if is_instance_valid(member):
			member.make_visible()
	
	_apply_current_segment_pattern() # Appliquer le premier segment de comportement

func _apply_current_segment_pattern() -> void:
	"""Applique les paramètres du pattern de comportement actuel."""
	if sequential_behavior_patterns.is_empty():
		push_warning("SquadronController: No sequential behavior patterns defined. Reclaiming.")
		_reclaim()
		return

	if _current_behavior_index >= sequential_behavior_patterns.size():
		_reclaim() # Tous les segments sont terminés
		return

	_current_behavior_pattern = sequential_behavior_patterns[_current_behavior_index]
	
	if debug_mode:
		print("[CONTROLLER DEBUG] Activating controller '%s'. Applying segment %d: %s" % [name, _current_behavior_index, EnemyBehaviorPattern.MovementType.keys()[_current_behavior_pattern.movement_type]])

	# Réinitialiser les variables d'état spécifiques aux types de mouvement pour le nouveau segment
	_sinusoidal_time = 0.0 # Réinitialiser pour un nouveau segment sinusoidal
	_bounces_left = 0 # Réinitialiser pour un nouveau segment de rebond

	if _current_behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.BOUNCE:
		velocity = _current_behavior_pattern.bounce_initial_direction.normalized() * _current_behavior_pattern.bounce_speed
		_bounces_left = _current_behavior_pattern.bounce_count
	else:
		velocity = Vector2.ZERO # Réinitialiser la vélocité pour les autres types, elle sera calculée dans _physics_process

	# Gérer le reparenting du Path2D pour le contrôleur si ce segment est Path2D
	if _current_behavior_pattern.movement_type == EnemyBehaviorPattern.MovementType.PATH_2D:
		var path_node = get_node_or_null(_current_behavior_pattern.movement_path)
		if path_node and path_node is Path2D:
			if is_instance_valid(_path_follower) and _path_follower.get_parent() != path_node:
				var old_parent = _path_follower.get_parent()
				if old_parent: old_parent.remove_child(_path_follower)
				path_node.add_child(_path_follower)
				_path_follower.progress_ratio = 0.0 # Commencer au début du chemin
		else:
			push_warning("SquadronController: PATH_2D segment specified, but Path2D not found at path: %s" % _current_behavior_pattern.movement_path)
	elif is_instance_valid(_path_follower) and _path_follower.get_parent() != self:
		# Si le segment précédent était Path2D, reparenter PathFollower à soi-même
		var old_parent = _path_follower.get_parent()
		if old_parent: old_parent.remove_child(_path_follower)
		add_child(_path_follower)

func set_target(target: Node2D) -> void:
	"""Sets the target for the entire squadron (e.g., for Homing)."""
	for member in members:
		if is_instance_valid(member):
			member.set_target(target)

func deactivate() -> void:
	"""Deactivates the controller and its members for pooling."""
	set_physics_process(false)
	
	# Deactivate and reclaim all members
	for member in members:
		if is_instance_valid(member):
			member.deactivate() # Prepare for pooling
			# The enemy pool manager will handle the actual reclaiming

	members.clear()
	
	# Reset PathFollower if it was reparented
	if is_instance_valid(_path_follower) and _path_follower.get_parent() != self:
		var old_parent = _path_follower.get_parent()
		if old_parent: old_parent.remove_child(_path_follower)
		_path_follower.name = "PathFollower"
		add_child(_path_follower) # Reparent back to self
	
	_current_behavior_pattern = null # Clear current pattern


func _physics_process(delta: float) -> void:
	if not _current_behavior_pattern: # Pas de pattern actif, ou récupéré
		return
	
	_current_segment_age += delta
	_age += delta # Garder une trace de l'âge total si nécessaire pour d'autres choses

	# --- Movement Logic ---
	match _current_behavior_pattern.movement_type:
		EnemyBehaviorPattern.MovementType.LINEAR:
			velocity = _current_behavior_pattern.linear_direction.normalized() * _current_behavior_pattern.linear_speed

		EnemyBehaviorPattern.MovementType.SINUSOIDAL:
			_sinusoidal_time += delta
			var direction = _current_behavior_pattern.sinusoidal_direction.normalized()
			var speed = _current_behavior_pattern.sinusoidal_speed
			var frequency = _current_behavior_pattern.sinusoidal_frequency
			var amplitude = _current_behavior_pattern.sinusoidal_amplitude
			
			velocity = direction * speed
			velocity += direction.orthogonal() * cos(_sinusoidal_time * frequency) * amplitude

		EnemyBehaviorPattern.MovementType.STATIONARY:
			velocity = Vector2.ZERO
			# Si STATIONARY est le dernier segment et n'a pas de durée, il restera indéfiniment.

		EnemyBehaviorPattern.MovementType.HOMING:
			# Pour le homing, le contrôleur lui-même peut avoir un mouvement de base (ex: linéaire)
			# ou rester stationnaire, tandis que les membres ciblent le joueur.
			# Ici, nous allons simplement le faire descendre si aucun autre mouvement n'est défini.
			velocity = _current_behavior_pattern.linear_direction.normalized() * _current_behavior_pattern.linear_speed
			if _current_behavior_pattern.linear_speed == 0:
				velocity = Vector2.DOWN * 50 # Fallback si pas de vitesse linéaire définie
			
			# Assurez-vous que les membres ont une cible si ce segment est HOMING
			if is_instance_valid(level_sequencer) and level_sequencer.has_method("get_player_targets"):
				var potential_targets: Array[Node2D] = level_sequencer.get_player_targets()
				if not potential_targets.is_empty():
					set_target(potential_targets[0]) # Cible le premier joueur pour l'escadron

		EnemyBehaviorPattern.MovementType.BOUNCE:
			if _bounces_left != 0:
				if (global_position.x <= GameArea.RECT.position.x and velocity.x < 0) or \
				   (global_position.x >= GameArea.RECT.end.x and velocity.x > 0):
					velocity.x *= -1
					if _bounces_left > 0: _bounces_left -= 1 # Décrémente si non infini

		EnemyBehaviorPattern.MovementType.PATH_2D:
			if _current_behavior_pattern.duration > 0:
				_path_follower.progress_ratio = _current_segment_age / _current_behavior_pattern.duration
			else:
				# Si pas de durée définie, le PathFollower avance à une vitesse par défaut
				_path_follower.progress_ratio = min(1.0, _path_follower.progress_ratio + delta / 10.0) # Exemple de vitesse par défaut
			pass # PathFollower gère le mouvement, donc on saute la mise à jour de global_position ci-dessous

	# Mettre à jour global_position uniquement si ce n'est pas un mouvement PATH_2D
	if _current_behavior_pattern.movement_type != EnemyBehaviorPattern.MovementType.PATH_2D:
		global_position += velocity * delta
	
	# --- Rotation Logic: Rotate the controller itself ---
	if _current_behavior_pattern.rotate_to_movement and velocity.length_squared() > 0:
		# We rotate the controller itself. This is the single source of truth for rotation.
		# Calculate the target angle based on velocity.
		var target_angle = velocity.angle() + PI / 2
		
		# Instead of jumping to the target angle, we interpolate the current angle towards it.
		self.rotation = lerp_angle(self.rotation, target_angle, turn_speed * delta)
	
	# --- Member Positioning ---
	if formation_pattern:
		for i in range(members.size()):
			var member = members[i]
			if is_instance_valid(member):
				# The member's local position is its fixed formation offset.
				# The controller's movement and rotation will handle the rest.
				var offset = formation_pattern.member_offsets[i]
				member.position = offset
				
				# The member's local rotation should be zero. It inherits rotation from the controller.
				member.rotation = 0

				if debug_mode and Engine.get_physics_frames() % 60 == 0: # Print once per second
					print(
						"[CONTROLLER DEBUG] Member %d position set to (%d, %d)" % [
							i, member.global_position.x, member.global_position.y
						]
					)

	# --- Logique de transition de segment ---
	# Si le segment actuel a une durée définie et que cette durée est écoulée
	if _current_behavior_pattern.duration > 0 and _current_segment_age >= _current_behavior_pattern.duration:
		_current_behavior_index += 1 # Passer au segment suivant
		_current_segment_age = 0.0 # Réinitialiser l'âge du segment
		if _current_behavior_index < sequential_behavior_patterns.size():
			_apply_current_segment_pattern() # Appliquer les paramètres du prochain segment
		else:
			_reclaim() # Tous les segments sont terminés, récupérer le contrôleur


func _reclaim() -> void:
	"""Safely emits the reclaimed signal, only once."""
	if _is_reclaimed:
		return
	_is_reclaimed = true
	reclaimed.emit(self)


func _on_member_reclaimed(member: Enemy) -> void:
	"""Called when a member enemy is reclaimed (e.g., destroyed)."""
	# Optional: Check if all members are gone to reclaim the controller early.
	var all_gone = true
	for m in members:
		if is_instance_valid(m) and not m._is_reclaimed:
			all_gone = false
			break
	if all_gone:
		_reclaim()

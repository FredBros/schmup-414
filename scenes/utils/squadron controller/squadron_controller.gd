# Fichier : res://scenes/squadron/squadron_controller.gd
# Ce script doit être attaché à un nœud Node2D.

extends Node2D

class_name SquadronController

var behavior_pattern: EnemyBehaviorPattern
var formation_pattern: FormationPattern
var members: Array[Enemy] = []
var target: Node2D

var _age: float = 0.0

@onready var path_follower: PathFollow2D = $PathFollower

# --- Fonctions de cycle de vie ---

func _ready() -> void:
	# Le contrôleur est inactif par défaut jusqu'à ce que 'activate' soit appelé.
	set_physics_process(false)

func set_target(new_target: Node2D) -> void:
	target = new_target

func activate() -> void:
	# On allume le moteur du contrôleur.
	set_physics_process(true)

func deactivate() -> void:
	set_physics_process(false)
	# CORRECTION : Ordonner à tous les membres de se désactiver.
	# C'est le rôle du contrôleur de gérer le cycle de vie de son escadrille.
	for enemy in members:
		if is_instance_valid(enemy):
			enemy._reclaim() # On appelle la fonction de nettoyage de l'ennemi.
			
	# Une fois les ordres donnés, le contrôleur peut se supprimer.
	queue_free()

# --- Moteur principal ---

func _physics_process(delta: float) -> void:
	if not behavior_pattern or not formation_pattern:
		return

	# 1. Mettre à jour la position du contrôleur (le centre de l'escadrille)
	var velocity = Vector2.ZERO
	match behavior_pattern.movement_type:
		EnemyBehaviorPattern.MovementType.LINEAR:
			velocity = behavior_pattern.linear_direction.normalized() * behavior_pattern.linear_speed
			global_position += velocity * delta
		
		EnemyBehaviorPattern.MovementType.PATH_2D:
			# Pour un chemin, c'est le PathFollower qui dicte la position.
			if behavior_pattern.lifetime > 0:
				path_follower.progress_ratio = _age / behavior_pattern.lifetime
			self.global_position = path_follower.global_position
		
		# Ajoutez ici d'autres types de mouvement (SINUSOIDAL, HOMING, etc.)
		# en manipulant directement 'global_position' ou une 'velocity'.

	# 2. Mettre à jour la position des membres et les rendre visibles
	var all_members_gone = true
	for i in range(members.size()):
		var enemy = members[i]
		if is_instance_valid(enemy):
			all_members_gone = false # Il reste au moins un membre valide
			var offset = formation_pattern.member_offsets[i]
			
			# On force la position de l'ennemi.
			enemy.global_position = self.global_position + offset
			
			# On le rend visible s'il ne l'est pas.
			if not enemy.visible:
				enemy.make_visible()
	
	# 3. Vérifier les conditions de fin de vie
	_age += delta
	if behavior_pattern.lifetime > 0 and _age >= behavior_pattern.lifetime:
		deactivate()
	
	if all_members_gone:
		deactivate()

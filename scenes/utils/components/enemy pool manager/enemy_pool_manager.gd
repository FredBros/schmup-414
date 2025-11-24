extends Node

class_name EnemyPoolManager

## La liste des configurations de pools à créer au démarrage.
## Remplissez ce tableau dans l'inspecteur avec des ressources PoolConfig.
@export var pools_to_create: Array[PoolConfig]
## Si vrai, active les logs détaillés dans la console pour le débogage.
@export var debug_mode: bool = false

## Dictionnaire qui contiendra les pools d'ennemis.
## Clé: String (type_id), Valeur: Array[Enemy]
var _pools: Dictionary = {}


func _ready() -> void:
	add_to_group("EnemyPoolManager") # Pour un accès facile depuis d'autres scripts
	
	for config in pools_to_create:
		if not config or not config.scene:
			push_warning("Configuration de pool invalide ou scène manquante.")
			continue
		
		if debug_mode:
			print("[POOL_MANAGER] Création du pool pour le type '", config.type_id, "' avec ", config.size, " ennemis.")
		
		var new_pool: Array[Enemy] = []
		for i in range(config.size):
			var enemy: Enemy = config.scene.instantiate()
			# Attacher un métadata pour savoir à quel pool il appartient
			enemy.set_meta("pool_type", config.type_id)
			enemy.reclaimed.connect(_on_enemy_reclaimed)
			add_child(enemy)
			enemy.deactivate()
			new_pool.append(enemy)
			
		_pools[config.type_id] = new_pool


func get_enemy(type_id: String) -> Enemy:
	"""
	Récupère un ennemi inactif du pool correspondant au type_id.
	"""
	if not _pools.has(type_id):
		push_error("Aucun pool trouvé pour le type d'ennemi : '%s'" % type_id)
		return null
	
	var pool: Array[Enemy] = _pools[type_id]
	if pool.is_empty():
		# Fallback: si le pool est vide, on en crée un nouveau à la volée.
		if debug_mode:
			push_warning("Le pool pour '%s' est vide. Envisagez d'augmenter sa taille. Création d'une nouvelle instance." % type_id)
		var config = pools_to_create.filter(func(c): return c.type_id == type_id)[0]
		var enemy: Enemy = config.scene.instantiate()
		enemy.set_meta("pool_type", config.type_id) # On garde le type pour le retour au pool
		enemy.reclaimed.connect(_on_enemy_reclaimed)
		add_child(enemy)
		return enemy
		
	var enemy = pool.pop_back()
	if debug_mode:
		print("[POOL_MANAGER] Ennemi de type '", type_id, "' récupéré. Taille du pool restante: ", pool.size())
		
	return enemy


func _on_enemy_reclaimed(enemy: Enemy) -> void:
	"""Récupère un ennemi et le remet dans son pool d'origine."""
	var type_id: String = enemy.get_meta("pool_type", "")
	if _pools.has(type_id):
		enemy.deactivate()
		var pool: Array[Enemy] = _pools[type_id]
		pool.append(enemy)
		if debug_mode:
			print("[POOL_MANAGER] Ennemi de type '", type_id, "' retourné au pool. Nouvelle taille: ", pool.size())
	else:
		# Si l'ennemi n'appartient à aucun pool connu, on le supprime.
		if debug_mode:
			push_warning("Ennemi réclamé de type inconnu '%s'. Suppression de l'instance." % type_id)
		enemy.queue_free()

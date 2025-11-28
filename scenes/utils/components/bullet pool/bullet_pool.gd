extends Node

class_name BulletPool

## The number of bullets to pre-instantiate and keep in the pool.
@export var pool_size: int = 200
## The bullet scene to be used for the pool.
@export var bullet_scene: PackedScene
## If true, enables detailed logging to the console for debugging purposes.
@export var debug_mode: bool = false

var _pool: Array[Node] = []


func _ready() -> void:
	if not bullet_scene:
		push_error("BulletPool: 'bullet_scene' is not set. Please assign a bullet scene in the inspector.")
		return
		
	if debug_mode:
		print("[POOL_DEBUG] Initializing BulletPool, populating with ", pool_size, " bullets...")
	# Pre-load the pool with bullets
	for i in range(pool_size):
		var bullet = bullet_scene.instantiate()
		bullet.reclaimed.connect(_on_bullet_reclaimed)
		add_child(bullet) # Keep the bullets as children of the pool
		bullet.deactivate() # Start deactivated
		_pool.append(bullet)
	if debug_mode:
		print("[POOL_DEBUG] Pool populated. Total bullets: ", _pool.size())


func get_bullet() -> Node:
	"""
	Retrieves an inactive bullet from the pool.
	If the pool is empty, it creates a new one as a fallback (with a warning).
	"""
	if _pool.is_empty():
		if debug_mode:
			print("[POOL_DEBUG] POOL EMPTY! Fallback to instantiate.")
		push_warning("BulletPool is empty! Consider increasing pool_size. Creating a new bullet on the fly.")
		var new_bullet = bullet_scene.instantiate()
		new_bullet.reclaimed.connect(_on_bullet_reclaimed)
		# Ne pas l'ajouter en enfant ici, le tireur s'en chargera.
		return new_bullet
		
	var bullet = _pool.pop_back()
	# On s'assure que la balle n'a plus de parent avant de la retourner.
	if is_instance_valid(bullet) and bullet.get_parent() == self:
		remove_child(bullet)
	if debug_mode:
		print("[POOL_DEBUG] Bullet retrieved from pool. Pool size now: ", _pool.size())
	return bullet


func _on_bullet_reclaimed(bullet: Node) -> void:
	"""
	Receives a bullet that has finished its lifecycle and returns it to the pool.
	"""
	# Reparent the bullet back to the pool to keep it in the scene tree
	# but out of the main game world.
	if is_instance_valid(bullet) and bullet.get_parent() != self:
		bullet.get_parent().remove_child(bullet)
		add_child(bullet)
		
	bullet.deactivate()
	_pool.append(bullet)
	if debug_mode:
		print("[POOL_DEBUG] Bullet reclaimed. Pool size now: ", _pool.size())

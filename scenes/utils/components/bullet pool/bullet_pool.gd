extends Node

class_name BulletPool

## The number of bullets to pre-instantiate and keep in the pool.
@export var pool_size: int = 200
## The bullet scene to be used for the pool.
@export var bullet_scene: PackedScene
## If true, enables detailed logging to the console for debugging purposes.
@export var debug_mode: bool = false

var _pool: Array[Bullet] = []


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


func get_bullet() -> Bullet:
	"""
	Retrieves an inactive bullet from the pool.
	If the pool is empty, it creates a new one as a fallback (with a warning).
	"""
	if _pool.is_empty():
		if debug_mode:
			print("[POOL_DEBUG] POOL EMPTY! Fallback to instantiate.")
		push_warning("BulletPool is empty! Consider increasing pool_size. Creating a new bullet on the fly.")
		var bullet = bullet_scene.instantiate()
		bullet.reclaimed.connect(_on_bullet_reclaimed)
		add_child(bullet)
		return bullet
		
	var bullet = _pool.pop_back()
	if debug_mode:
		print("[POOL_DEBUG] Bullet retrieved from pool. Pool size now: ", _pool.size())
	return bullet


func _on_bullet_reclaimed(bullet: Bullet) -> void:
	"""
	Receives a bullet that has finished its lifecycle and returns it to the pool.
	"""
	bullet.deactivate()
	_pool.append(bullet)
	if debug_mode:
		print("[POOL_DEBUG] Bullet reclaimed. Pool size now: ", _pool.size())

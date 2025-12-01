extends Node

class_name SquadronControllerPoolManager

## The initial number of controllers to create in the pool.
@export var pool_size: int = 20

var _pool: Array[SquadronController] = []

# We load the scene directly in the script because this is an Autoload singleton.
const CONTROLLER_SCENE: PackedScene = preload("res://scenes/utils/squadron controller/squadron_controller.tscn")


func _ready() -> void:
	if not CONTROLLER_SCENE:
		push_error("SquadronControllerPoolManager: CONTROLLER_SCENE could not be preloaded. Check the path.")
		return

	for i in range(pool_size):
		var controller: SquadronController = CONTROLLER_SCENE.instantiate()
		controller.name = "SquadronController_%d" % i
		controller.reclaimed.connect(reclaim_controller)
		add_child(controller) # Add the controller to the scene tree as a child of the pool manager.
		controller.deactivate() # Make sure it's inactive and invisible.
		_pool.append(controller) # Then add it to our available list.


func get_controller() -> SquadronController:
	"""
	Retrieves a SquadronController from the pool.
	If the pool is empty, it instantiates a new one as a fallback.
	"""
	if _pool.is_empty(): # Fallback in case the pool runs dry
		push_warning("SquadronControllerPoolManager: Pool is empty. Instantiating a new fallback controller. Consider increasing pool_size.")
		var controller: SquadronController = CONTROLLER_SCENE.instantiate()
		add_child(controller) # Also add the fallback to the tree so it can be reparented.
		controller.reclaimed.connect(reclaim_controller)
		return controller
	
	var controller: SquadronController = _pool.pop_back()
	return controller


func reclaim_controller(controller: SquadronController) -> void:
	"""Returns a SquadronController to the pool after deactivating it."""
	if not is_instance_valid(controller):
		return
	
	controller.deactivate()
	# Reparent the controller back to the pool manager to keep it in the scene tree.
	controller.reparent(self)
	_pool.push_back(controller)
extends Node



signal damage_applied(target: Node, damage: int, source: Node)
signal target_died(target: Node, source: Node)

var _signal_manager: Object = null
var health_manager_node : Node = null
var entity : Node = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	entity = owner
	health_manager_node = get_node_or_null("/root/HealthManager")
	if health_manager_node == null:
		push_error("HealthManager node not found in the scene tree.")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func apply_damage(target: Node, damage: int, source: Node) -> void:
	if not is_instance_valid(target):
		return

	SignalManager.emit_signal("entity_damaged", target, damage, source)
	

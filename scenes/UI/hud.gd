extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalManager.entity_damaged.connect(_on_entity_damaged)
	SignalManager.player_died.connect(_on_player_died)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_entity_damaged(_entity: Node, _damage: int, _source: Node) -> void:
	# Gérer l'affichage des dégâts appliqués
	pass

func _on_player_died() -> void:
	# Gérer le game over
	pass

extends Control

@onready var progress_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	# Se connecter au signal de changement de santé
	SignalManager.health_changed.connect(_on_health_changed)

func _on_health_changed(entity: Node, current_health: int, max_health: int) -> void:
	# Ne mettre à jour que pour le joueur
	if entity.is_in_group("Player"):
		if progress_bar:
			progress_bar.value = float(current_health) / float(max_health) * 100.0

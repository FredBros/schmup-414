extends Node2D


@onready var level_sequencer: LevelSequencer = $LevelSequencer # Assurez-vous que le chemin est correct

func _ready() -> void:
	# ... autre code d'initialisation ...

	# Démarrer le niveau !
	if level_sequencer:
		level_sequencer.start_level()

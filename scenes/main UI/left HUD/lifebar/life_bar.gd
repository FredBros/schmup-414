extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var lives_container: HBoxContainer = $Lives
@onready var life_icon_texture: Texture2D = preload("res://scenes/main UI/left HUD/lifebar/life-icon.png")

func _ready() -> void:
	# Se connecter au signal de changement de santé
	SignalManager.health_changed.connect(_on_health_changed)
	SignalManager.lives_changed.connect(_on_lives_changed)
	SignalManager.life_lost.connect(_on_life_lost)

	# Clear any default icons
	_update_lives_display(0)

func _on_health_changed(entity: Node, current_health: int, max_health: int) -> void:
	# Ne mettre à jour que pour le joueur
	if entity.is_in_group("Player"):
		if progress_bar:
			progress_bar.value = float(current_health) / float(max_health) * 100.0

func _on_lives_changed(entity: Node, remaining_lives: int) -> void:
	if entity.is_in_group("Player"):
		_update_lives_display(remaining_lives)

func _on_life_lost(entity: Node, remaining_lives: int) -> void:
	# small effect placeholder — e.g. play sound or animate
	if entity.is_in_group("Player"):
		# for now just update display too
		_update_lives_display(remaining_lives)

func _update_lives_display(remaining_lives: int) -> void:
	# clear children and add one label per life
	for child in lives_container.get_children():
		child.queue_free()

	# If there are no lives, don't add icons — the `Lives` container has a
	# `custom_minimum_size` reserved so the HUD doesn't shift upward.
	if remaining_lives <= 0:
		return

	# Otherwise add one icon per remaining life
	for i in range(remaining_lives):
		var icon = TextureRect.new()
		icon.texture = life_icon_texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(18, 18)
		lives_container.add_child(icon)

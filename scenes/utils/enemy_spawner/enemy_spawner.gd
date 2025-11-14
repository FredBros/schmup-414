extends Node2D

@export var width := 512
@export var enemy_scene: PackedScene = preload("res://scenes/enemy/enemy.tscn")
var _spawn_timer: Timer
func _ready() -> void:
	randomize()
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = 1.2
	_spawn_timer.autostart = true
	_spawn_timer.one_shot = false
	add_child(_spawn_timer)
	_spawn_timer.connect("timeout", _on_spawn_timeout)

func _on_spawn_timeout() -> void:
	var enemy = enemy_scene.instantiate()
	var x = randf_range(20, width - 20)
	enemy.position = Vector2(x, -20)
	add_child(enemy)


func _process(delta: float) -> void:
	# Scroll vertical (simule le défilement)
	pass
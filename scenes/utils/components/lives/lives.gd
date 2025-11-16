extends Node
class_name Lives

@export var initial_lives := 2

var lives_left: int
var _health: Health = null

func _ready() -> void:
	lives_left = initial_lives
	if get_parent().has_node("Health"):
		_health = get_parent().get_node("Health") as Health
		# connect to about_to_die which allows us to prevent default death
		_health.connect("about_to_die", Callable(self, "_on_about_to_die"))
	else:
		# try finding health in children - sometimes the order changes in the scene
		_health = get_parent().get_node_or_null("Health") as Health
		if _health:
			_health.connect("about_to_die", Callable(self, "_on_about_to_die"))
	# Broadcast initial number of lives
	SignalManager.emit_signal("lives_changed", get_parent(), lives_left)

func _on_about_to_die(_source: Node) -> void:
	# If we have lives, consume one and prevent death
	if lives_left > 0 and _health:
		lives_left -= 1
		# Prevent Health from dying — reset to full
		# Temporarily prevent the death in Health; we call a deferred clear so
		# Health won't be allowed to die while the about_to_die handlers run.
		_health.prevent_death = true
		_health.current_health = _health.max_health
		# Broadcast the lost life and updated lives count
		SignalManager.emit_signal("life_lost", get_parent(), lives_left)
		SignalManager.emit_signal("lives_changed", get_parent(), lives_left)
		# Reset prevent_death for future events (deferred so it stays true
		# long enough for Health's check after signals to finish)
		_health.call_deferred("clear_prevent_death")
		# Also emit health_changed so UI updates
		SignalManager.emit_signal("health_changed", get_parent(), _health.current_health, _health.max_health)
		return
	# otherwise no lives left => do nothing and death proceeds

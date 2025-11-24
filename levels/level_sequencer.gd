extends Node
class_name LevelSequencer

## Emitted to request the spawn of an enemy group.
signal request_spawn(event_data: SpawnEventData)
## Emitted to request the spawn of a squadron.
signal request_squadron_spawn(event_data: SquadronSpawnEventData)

## The level data "sheet music" to be played.
@export var level_data: LevelData
## The list of player nodes. This MUST be assigned in the editor.
@export var players: Array[Node2D]

var _current_wave_index := -1
var _time_since_wave_start := 0.0
var _time_until_next_wave := 0.0
var _events_queue: Array = [] # Can now hold both SpawnEventData and SquadronSpawnEventData
var _is_running := false

func _ready() -> void:
	# Critical check: Ensure the player has been assigned in the editor.
	if players.is_empty():
		push_error("LevelSequencer: The 'players' array has not been assigned in the editor or is empty. Homing enemies will not work.")
		_is_running = false # Stop the sequencer from running to prevent further errors.
		return

# This function will be called by the EnemySpawner.
func get_player_targets() -> Array[Node2D]:
	return players

func start_level():
	if not level_data:
		push_error("LevelSequencer: No LevelData assigned.")
		return
	_current_wave_index = -1
	_time_until_next_wave = 0.0
	_is_running = true
	print("SEQUENCER: Starting level...") # Kept as is, already in English
	_advance_to_next_wave()

func _process(delta: float) -> void:
	if not _is_running:
		return

	if _current_wave_index >= level_data.waves.size():
		# All waves are finished
		_is_running = false
		print("SEQUENCER: LEVEL COMPLETE") # Kept as is
		return

	# If we are waiting between two waves
	if _time_until_next_wave > 0:
		_time_until_next_wave -= delta
		if _time_until_next_wave <= 0:
			_advance_to_next_wave()
		return # Do nothing else while waiting

	_time_since_wave_start += delta # Advance the current wave's timer

	# Trigger scheduled spawn events
	var i = 0
	while i < _events_queue.size():
		var event: Resource = _events_queue[i]
		if _time_since_wave_start >= event.spawn_delay:
			if event is SpawnEventData:
				# This is where you could trigger a radar warning in the future.
				var edge = event.get_spawn_edge()
				print("RADAR (Future): Threat incoming from ", SpawnEventData.SpawnEdge.keys()[edge])
				
				print("SEQUENCER: Emitting spawn request for event in wave ", _current_wave_index) # Kept as is
				request_spawn.emit(event)
			elif event is SquadronSpawnEventData:
				print("SEQUENCER: Emitting spawn request for SQUADRON in wave ", _current_wave_index)
				request_squadron_spawn.emit(event)

			_events_queue.remove_at(i)
		else:
			i += 1
			
	# Si la vague actuelle est terminée (plus d'événements en attente)
	# et qu'on n'attend pas déjà la vague suivante, on déclenche la transition.
	# If the current wave is finished (no more events in queue)
	# and we are not already waiting for the next wave, trigger the transition.
	if _events_queue.is_empty() and _time_until_next_wave <= 0:
		print("SEQUENCER: Wave ", _current_wave_index, " finished. Preparing for next wave.") # Kept as is
		# Prepare the delay for the next wave, but don't advance yet
		if _current_wave_index < level_data.waves.size():
			_time_until_next_wave = level_data.waves[_current_wave_index].delay_before_start
			print("SEQUENCER: Waiting for ", _time_until_next_wave, " seconds.") # Kept as is
			# If the delay is 0, advance immediately
			if _time_until_next_wave <= 0:
				_advance_to_next_wave()


func _advance_to_next_wave():
	_current_wave_index += 1
	if _current_wave_index < level_data.waves.size():
		print("SEQUENCER: Advancing to wave ", _current_wave_index) # Kept as is
		var current_wave = level_data.waves[_current_wave_index]
		# Combine both individual and squadron events into one queue
		var events = current_wave.spawn_events + current_wave.squadron_spawn_events
		# Sort events by their spawn delay for clean processing
		events.sort_custom(func(a, b): return a.spawn_delay < b.spawn_delay)
		_events_queue = events
		_time_since_wave_start = 0.0
	else:
		print("SEQUENCER: No more waves to advance to.") # Kept as is
		# The _process loop will handle level completion
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

var _level_time: float = 0.0
var _next_wave_index: int = 0
var _active_events: Array = [] # Events from currently active waves
var _sorted_waves: Array[WaveData] = []
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
	
	# Prepare for timeline playback
	_level_time = 0.0
	_next_wave_index = 0
	_active_events.clear()
	
	# Sort waves by their start time to process them chronologically
	_sorted_waves = level_data.waves.duplicate()
	_sorted_waves.sort_custom(func(a, b): return a.start_time < b.start_time)
	
	_is_running = true
	print("SEQUENCER: Starting level timeline...")

func _process(delta: float) -> void:
	if not _is_running:
		return

	_level_time += delta

	# 1. Check if it's time to trigger the next wave(s)
	while _next_wave_index < _sorted_waves.size() and _level_time >= _sorted_waves[_next_wave_index].start_time:
		_trigger_wave(_next_wave_index)
		_next_wave_index += 1

	# 2. Process active spawn events
	# We iterate backwards to safely remove items from the array while iterating.
	for i in range(_active_events.size() - 1, -1, -1):
		var event_info: Dictionary = _active_events[i]
		if _level_time >= event_info.absolute_spawn_time:
			var event_data = event_info.data
			if event_data is SpawnEventData:
				#print("SEQUENCER: Emitting spawn request for event.")
				request_spawn.emit(event_data)
			elif event_data is SquadronSpawnEventData:
				#print("SEQUENCER: Emitting spawn request for SQUADRON.")
				request_squadron_spawn.emit(event_data)
			
			_active_events.remove_at(i)
	
	# 3. Check for level completion
	if _next_wave_index >= _sorted_waves.size() and _active_events.is_empty():
		_is_running = false
		print("SEQUENCER: LEVEL COMPLETE (Timeline finished)")
		return


func _trigger_wave(wave_index: int):
	var wave_data = _sorted_waves[wave_index]
	print("SEQUENCER: Triggering Wave %d at level time %.2f" % [wave_index, _level_time])
	
	var all_events = wave_data.spawn_events + wave_data.squadron_spawn_events
	for event_data in all_events:
		var event_info = {
			"absolute_spawn_time": wave_data.start_time + event_data.spawn_delay,
			"data": event_data
		}
		# Instead of appending and re-sorting the whole list, we insert the new event
		# at the correct position to keep the list sorted. This is much more efficient.
		var inserted = false
		for i in range(_active_events.size()):
			if event_info.absolute_spawn_time < _active_events[i].absolute_spawn_time:
				_active_events.insert(i, event_info)
				inserted = true
				break
		if not inserted:
			_active_events.append(event_info)

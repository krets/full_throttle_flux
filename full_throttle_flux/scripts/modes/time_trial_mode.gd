extends ModeBase
class_name TimeTrialMode

## Time Trial Mode
## Assembles track and ship, then coordinates with RaceManager for race flow.
## Uses existing RaceManager for timing, lap tracking, and leaderboards.

# ============================================================================
# MODE CONFIGURATION
# ============================================================================

@export var num_laps: int = 3

# ============================================================================
# ADDITIONAL SCENE REFERENCES
# ============================================================================

var pause_menu_instance: Node
var results_screen_instance: Node
var now_playing_instance: Node

# ============================================================================
# PACKED SCENES FOR UI
# ============================================================================

@export var pause_menu_scene: PackedScene
@export var results_screen_scene: PackedScene
@export var now_playing_scene: PackedScene

# ============================================================================
# OVERRIDES
# ============================================================================

func get_mode_id() -> String:
	return "time_trial"

func get_hud_config() -> Dictionary:
	return {
		"show_speedometer": true,
		"show_lap_timer": true,
		"show_lap_counter": true,
		"show_countdown": true,
	}

# ============================================================================
# SETUP
# ============================================================================

func _ready() -> void:
	# Don't auto-setup, wait for explicit call
	pass

func setup_race() -> void:
	# Configure RaceManager for time trial
	RaceManager.set_mode(RaceManager.RaceMode.TIME_TRIAL)
	RaceManager.total_laps = num_laps
	RaceManager.reset_race()
	
	# Get lap count from track profile if available
	var track_profile = GameManager.get_selected_track()
	if track_profile:
		num_laps = track_profile.default_laps
		RaceManager.total_laps = num_laps
	
	# Call parent setup (loads track, spawns ship, etc.)
	await super.setup_race()
	
	# Setup additional UI
	_setup_pause_menu()
	_setup_results_screen()
	_setup_now_playing()
	
	# Connect RaceManager signals
	_connect_race_signals()

func _connect_race_signals() -> void:
	# Disconnect any existing connections first
	if RaceManager.race_started.is_connected(_on_race_manager_started):
		RaceManager.race_started.disconnect(_on_race_manager_started)
	if RaceManager.countdown_tick.is_connected(_on_countdown_tick):
		RaceManager.countdown_tick.disconnect(_on_countdown_tick)
	if RaceManager.race_finished.is_connected(_on_race_manager_finished):
		RaceManager.race_finished.disconnect(_on_race_manager_finished)
	if RaceManager.lap_completed.is_connected(_on_lap_completed):
		RaceManager.lap_completed.disconnect(_on_lap_completed)
	
	# Connect signals
	RaceManager.race_started.connect(_on_race_manager_started)
	RaceManager.countdown_tick.connect(_on_countdown_tick)
	RaceManager.race_finished.connect(_on_race_manager_finished)
	RaceManager.lap_completed.connect(_on_lap_completed)

# ============================================================================
# UI SETUP
# ============================================================================

func _setup_pause_menu() -> void:
	if pause_menu_scene:
		pause_menu_instance = pause_menu_scene.instantiate()
	else:
		var path = "res://scenes/pause_menu.tscn"
		if ResourceLoader.exists(path):
			pause_menu_instance = load(path).instantiate()
	
	if pause_menu_instance:
		add_child(pause_menu_instance)

func _setup_results_screen() -> void:
	if results_screen_scene:
		results_screen_instance = results_screen_scene.instantiate()
	else:
		var path = "res://scenes/results_screen.tscn"
		if ResourceLoader.exists(path):
			results_screen_instance = load(path).instantiate()
	
	if results_screen_instance:
		add_child(results_screen_instance)

func _setup_now_playing() -> void:
	if now_playing_scene:
		now_playing_instance = now_playing_scene.instantiate()
	else:
		var path = "res://scenes/now_playing_display.tscn"
		if ResourceLoader.exists(path):
			now_playing_instance = load(path).instantiate()
	
	if now_playing_instance:
		add_child(now_playing_instance)

# ============================================================================
# RACE FLOW
# ============================================================================

func start_countdown() -> void:
	print("TimeTrialMode: Starting countdown via RaceManager")
	# Use RaceManager's countdown instead of our own
	RaceManager.start_countdown()

func _do_countdown() -> void:
	# Override to do nothing - RaceManager handles countdown
	pass

func _on_countdown_tick(number: int) -> void:
	print("TimeTrialMode: Countdown %d" % number)
	
	# Keep ship locked during countdown
	if ship_instance and ship_instance.has_method("lock_controls"):
		if number > 0:
			ship_instance.lock_controls()
			# Hold ship in place
			ship_instance.velocity = Vector3.ZERO

func _on_race_manager_started() -> void:
	print("TimeTrialMode: Race started!")
	is_race_active = true
	
	# Unlock ship
	if ship_instance and ship_instance.has_method("unlock_controls"):
		ship_instance.unlock_controls()
	
	# Start music
	MusicPlaylistManager.start_race_music()
	
	race_started.emit()

func _on_lap_completed(lap_number: int, lap_time: float) -> void:
	print("TimeTrialMode: Lap %d completed in %.3f" % [lap_number, lap_time])
	
	# Play lap complete sound
	if lap_number < num_laps:
		AudioManager.play_lap_complete()
	
	# Final lap warning
	if lap_number == num_laps - 1:
		AudioManager.play_final_lap()

func _on_race_manager_finished(total_time: float, best_lap: float) -> void:
	print("TimeTrialMode: Race finished! Total: %.3f, Best lap: %.3f" % [total_time, best_lap])
	is_race_active = false
	
	# Lock ship
	if ship_instance and ship_instance.has_method("lock_controls"):
		ship_instance.lock_controls()
	
	# Play finish sound
	AudioManager.play_race_finish()
	
	# Fade out music
	MusicPlaylistManager.fade_out()
	
	# Results are handled by ResultsScreen listening to RaceManager
	
	race_finished.emit({
		"total_time": total_time,
		"best_lap": best_lap,
		"lap_times": RaceManager.lap_times.duplicate()
	})

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	if not is_race_active:
		return
	
	# Handle pause
	if event.is_action_pressed("ui_cancel"):
		if RaceManager.is_racing() and pause_menu_instance:
			if pause_menu_instance.has_method("show_pause"):
				pause_menu_instance.show_pause()
			get_viewport().set_input_as_handled()

# ============================================================================
# CLEANUP
# ============================================================================

func cleanup() -> void:
	# Disconnect signals
	if RaceManager.race_started.is_connected(_on_race_manager_started):
		RaceManager.race_started.disconnect(_on_race_manager_started)
	if RaceManager.countdown_tick.is_connected(_on_countdown_tick):
		RaceManager.countdown_tick.disconnect(_on_countdown_tick)
	if RaceManager.race_finished.is_connected(_on_race_manager_finished):
		RaceManager.race_finished.disconnect(_on_race_manager_finished)
	if RaceManager.lap_completed.is_connected(_on_lap_completed):
		RaceManager.lap_completed.disconnect(_on_lap_completed)
	
	# Cleanup additional UI
	if pause_menu_instance:
		pause_menu_instance.queue_free()
	if results_screen_instance:
		results_screen_instance.queue_free()
	if now_playing_instance:
		now_playing_instance.queue_free()
	
	# Call parent cleanup
	super.cleanup()

extends ModeBase
class_name EndlessMode

## Endless Mode
## Race continuously until player quits. Tracks lap count and best lap time.
## Player ends session via pause menu.

# ============================================================================
# UI INSTANCES
# ============================================================================

var race_hud: CanvasLayer
var debug_hud: CanvasLayer
var pause_menu: CanvasLayer
var results_screen: CanvasLayer
var now_playing_display: Node

# ============================================================================
# SCRIPTS (loaded once)
# ============================================================================

var hud_race_script: Script
var debug_hud_script: Script
var pause_menu_script: Script
var results_screen_script: Script

# ============================================================================
# OVERRIDES
# ============================================================================

func get_mode_id() -> String:
	return "endless"

func get_hud_config() -> Dictionary:
	return {
		"show_speedometer": true,
		"show_lap_timer": true,
		"show_lap_counter": true,  # Shows "LAP X" without total
		"show_countdown": true,
		"show_mode_label": true,  # Show "ENDLESS" indicator
	}

# ============================================================================
# SETUP
# ============================================================================

func _ready() -> void:
	# Preload scripts
	_load_ui_scripts()

func _load_ui_scripts() -> void:
	hud_race_script = load("res://scripts/hud_race.gd")
	debug_hud_script = load("res://scripts/debug_hud.gd")
	pause_menu_script = load("res://scripts/pause_menu.gd")
	results_screen_script = load("res://scripts/results_screen.gd")

func setup_race() -> void:
	# Configure RaceManager for endless mode
	RaceManager.set_mode(RaceManager.RaceMode.ENDLESS)
	RaceManager.total_laps = 999999  # Effectively infinite
	RaceManager.reset_race()
	
	# Call parent setup (loads track, spawns ship, camera)
	await super.setup_race()
	
	# Setup our UI elements
	_setup_race_hud()
	_setup_debug_hud()
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
	if RaceManager.lap_completed.is_connected(_on_lap_completed):
		RaceManager.lap_completed.disconnect(_on_lap_completed)
	if RaceManager.endless_finished.is_connected(_on_endless_finished):
		RaceManager.endless_finished.disconnect(_on_endless_finished)
	
	# Connect signals
	RaceManager.race_started.connect(_on_race_manager_started)
	RaceManager.countdown_tick.connect(_on_countdown_tick)
	RaceManager.lap_completed.connect(_on_lap_completed)
	RaceManager.endless_finished.connect(_on_endless_finished)

# ============================================================================
# UI SETUP (creates nodes inline like time_trial_01.tscn)
# ============================================================================

func _setup_race_hud() -> void:
	# Remove parent's HUD if it loaded one
	if hud_instance:
		hud_instance.queue_free()
		hud_instance = null
	
	# Create HUD CanvasLayer with script
	race_hud = CanvasLayer.new()
	race_hud.name = "HUD"
	
	if hud_race_script:
		race_hud.set_script(hud_race_script)
	
	add_child(race_hud)
	
	# Connect to ship
	if ship_instance and "ship" in race_hud:
		race_hud.ship = ship_instance
	
	print("EndlessMode: Race HUD created")

func _setup_debug_hud() -> void:
	debug_hud = CanvasLayer.new()
	debug_hud.name = "DebugHUD"
	
	if debug_hud_script:
		debug_hud.set_script(debug_hud_script)
	
	add_child(debug_hud)
	
	# Connect to ship
	if ship_instance and "ship" in debug_hud:
		debug_hud.ship = ship_instance
	
	print("EndlessMode: Debug HUD created")

func _setup_pause_menu() -> void:
	pause_menu = CanvasLayer.new()
	pause_menu.name = "PauseMenu"
	
	if pause_menu_script:
		pause_menu.set_script(pause_menu_script)
	
	add_child(pause_menu)
	
	# Connect debug_hud reference if the script expects it
	if debug_hud and "debug_hud" in pause_menu:
		pause_menu.debug_hud = debug_hud
	
	print("EndlessMode: Pause menu created")

func _setup_results_screen() -> void:
	results_screen = CanvasLayer.new()
	results_screen.name = "ResultsScreen"
	
	if results_screen_script:
		results_screen.set_script(results_screen_script)
	
	add_child(results_screen)
	
	print("EndlessMode: Results screen created")

func _setup_now_playing() -> void:
	var now_playing_path = "res://scenes/now_playing_display.tscn"
	if ResourceLoader.exists(now_playing_path):
		var scene = load(now_playing_path)
		now_playing_display = scene.instantiate()
		add_child(now_playing_display)
		print("EndlessMode: Now playing display created")

# ============================================================================
# RACE FLOW
# ============================================================================

func start_countdown() -> void:
	print("EndlessMode: Starting countdown via RaceManager")
	RaceManager.start_countdown()

func _do_countdown() -> void:
	# Override to do nothing - RaceManager handles countdown
	pass

func _on_countdown_tick(number: int) -> void:
	print("EndlessMode: Countdown %d" % number)
	
	# Keep ship locked during countdown
	if ship_instance and ship_instance.has_method("lock_controls"):
		if number > 0:
			ship_instance.lock_controls()
			ship_instance.velocity = Vector3.ZERO

func _on_race_manager_started() -> void:
	print("EndlessMode: Race started!")
	is_race_active = true
	
	# Unlock ship
	if ship_instance and ship_instance.has_method("unlock_controls"):
		ship_instance.unlock_controls()
	
	# Start music
	MusicPlaylistManager.start_race_music()
	
	race_started.emit()

func _on_lap_completed(lap_number: int, lap_time: float) -> void:
	print("EndlessMode: Lap %d completed in %.3f" % [lap_number, lap_time])
	
	# Play lap complete sound
	AudioManager.play_lap_complete()

func _on_endless_finished(total_laps: int, total_time: float, best_lap: float) -> void:
	print("EndlessMode: Session ended! Laps: %d, Total: %.3f, Best lap: %.3f" % [total_laps, total_time, best_lap])
	is_race_active = false
	
	# Lock ship
	if ship_instance and ship_instance.has_method("lock_controls"):
		ship_instance.lock_controls()
	
	# Play finish sound
	AudioManager.play_race_finish()
	
	# Fade out music
	MusicPlaylistManager.stop_music(true)
	
	# Results are handled by ResultsScreen listening to RaceManager
	
	race_finished.emit({
		"total_laps": total_laps,
		"total_time": total_time,
		"best_lap": best_lap,
		"all_lap_times": RaceManager.endless_all_lap_times.duplicate()
	})

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	if not is_race_active:
		return
	
	# Handle pause
	if event.is_action_pressed("ui_cancel"):
		if RaceManager.is_racing() and pause_menu:
			if pause_menu.has_method("show_pause"):
				pause_menu.show_pause()
			get_viewport().set_input_as_handled()

# ============================================================================
# PUBLIC API
# ============================================================================

func end_session() -> void:
	"""Called when player wants to end their endless session (from pause menu)."""
	RaceManager.finish_endless()

# ============================================================================
# CLEANUP
# ============================================================================

func cleanup() -> void:
	# Disconnect signals
	if RaceManager.race_started.is_connected(_on_race_manager_started):
		RaceManager.race_started.disconnect(_on_race_manager_started)
	if RaceManager.countdown_tick.is_connected(_on_countdown_tick):
		RaceManager.countdown_tick.disconnect(_on_countdown_tick)
	if RaceManager.lap_completed.is_connected(_on_lap_completed):
		RaceManager.lap_completed.disconnect(_on_lap_completed)
	if RaceManager.endless_finished.is_connected(_on_endless_finished):
		RaceManager.endless_finished.disconnect(_on_endless_finished)
	
	# Cleanup UI
	if race_hud:
		race_hud.queue_free()
	if debug_hud:
		debug_hud.queue_free()
	if pause_menu:
		pause_menu.queue_free()
	if results_screen:
		results_screen.queue_free()
	if now_playing_display:
		now_playing_display.queue_free()
	
	# Call parent cleanup
	super.cleanup()

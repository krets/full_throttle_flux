extends Node
class_name RaceLauncher

## Race Launcher
## Entry point for starting races. Creates the appropriate mode controller
## based on GameManager selections and sets up the race.
##
## Usage from main menu:
##   GameManager.select_ship_by_id("default_racer")
##   GameManager.select_track_by_id("test_circuit")
##   GameManager.select_mode("time_trial")
##   get_tree().change_scene_to_file("res://scenes/race_launcher.tscn")

# ============================================================================
# ENVIRONMENT (optional - can be overridden by track)
# ============================================================================

@export var default_environment: Environment
@export var default_sun_color: Color = Color(1, 0.95, 0.9)

# ============================================================================
# MODE INSTANCES
# ============================================================================

var current_mode: ModeBase

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("RaceLauncher: Starting...")
	
	# Verify we have valid selections
	if not GameManager.has_valid_selection():
		push_error("RaceLauncher: No valid selection in GameManager!")
		_return_to_menu()
		return
	
	# Setup environment
	_setup_environment()
	
	# Create and setup the mode
	await _create_mode()
	
	# Start the race after a brief delay
	await get_tree().create_timer(0.5).timeout
	
	if current_mode:
		current_mode.start_countdown()

func _setup_environment() -> void:
	# Add WorldEnvironment if not present
	if default_environment:
		var world_env = WorldEnvironment.new()
		world_env.environment = default_environment
		add_child(world_env)
	else:
		# Create default environment
		var env = Environment.new()
		env.background_mode = Environment.BG_SKY
		
		var sky_material = ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color(0.05, 0.05, 0.15)
		sky_material.sky_horizon_color = Color(0.2, 0.15, 0.3)
		sky_material.ground_bottom_color = Color(0.02, 0.02, 0.05)
		sky_material.ground_horizon_color = Color(0.2, 0.15, 0.3)
		
		var sky = Sky.new()
		sky.sky_material = sky_material
		env.sky = sky
		
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_color = Color(0.25, 0.25, 0.35)
		env.ambient_light_energy = 0.4
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.2
		
		var world_env = WorldEnvironment.new()
		world_env.environment = env
		add_child(world_env)
	
	# Add directional light
	var sun = DirectionalLight3D.new()
	sun.light_color = default_sun_color
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.rotation_degrees = Vector3(-30, -30, 0)
	sun.position = Vector3(0, 50, 0)
	add_child(sun)

func _create_mode() -> void:
	var mode_id = GameManager.get_selected_mode()
	
	match mode_id:
		"time_trial":
			current_mode = TimeTrialMode.new()
			print("RaceLauncher: Created TimeTrialMode")
		"endless":
			current_mode = EndlessMode.new()
			print("RaceLauncher: Created EndlessMode")
		_:
			push_error("RaceLauncher: Unknown mode: %s" % mode_id)
			_return_to_menu()
			return
	
	add_child(current_mode)
	
	# Setup the race (async)
	await current_mode.setup_race()
	
	print("RaceLauncher: Mode created and setup complete")

# ============================================================================
# NAVIGATION
# ============================================================================

func _return_to_menu() -> void:
	print("RaceLauncher: Returning to main menu")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func restart_race() -> void:
	"""Restart current race with same selections."""
	print("RaceLauncher: Restarting race...")
	if current_mode:
		current_mode.cleanup()
		current_mode.queue_free()
		current_mode = null
	
	RaceManager.reset_race()
	
	await get_tree().create_timer(0.1).timeout
	await _create_mode()
	
	await get_tree().create_timer(0.5).timeout
	if current_mode:
		current_mode.start_countdown()

func quit_to_menu() -> void:
	"""Clean up and return to main menu."""
	if current_mode:
		current_mode.cleanup()
	_return_to_menu()

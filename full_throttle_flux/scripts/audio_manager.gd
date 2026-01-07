extends Node

## Global Audio Manager Singleton
## Handles UI sounds and sound effects
## NOTE: Music playback is now handled by MusicPlaylistManager

# ============================================================================
# AUDIO BUS NAMES
# ============================================================================

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"

# ============================================================================
# UI SOUND PATHS
# ============================================================================

const SFX_UI_HOVER := "res://sounds/ui/ui_hover.wav"
const SFX_UI_SELECT := "res://sounds/ui/ui_select.wav"
const SFX_UI_BACK := "res://sounds/ui/ui_back.wav"
const SFX_UI_PAUSE := "res://sounds/ui/ui_pause.wav"
const SFX_UI_RESUME := "res://sounds/ui/ui_resume.wav"
const SFX_UI_KEYSTROKE := "res://sounds/ui/ui_keystroke.wav"

# ============================================================================
# RACE SOUND PATHS
# ============================================================================

const SFX_COUNTDOWN_BEEP := "res://sounds/race/countdown_beep.wav"
const SFX_COUNTDOWN_GO := "res://sounds/race/countdown_go.wav"
const SFX_LAP_COMPLETE := "res://sounds/race/lap_complete.wav"
const SFX_FINAL_LAP := "res://sounds/race/final_lap.wav"
const SFX_RACE_FINISH := "res://sounds/race/race_finish.wav"
const SFX_WRONG_WAY := "res://sounds/race/wrong_way.wav"
const SFX_NEW_RECORD := "res://sounds/race/new_record.wav"
const SFX_LINE_CROSS := "res://sounds/ambient/line_cross.wav"

# ============================================================================
# SETTINGS
# ============================================================================

@export_group("Volume Settings")
@export_range(0.0, 1.0) var master_volume := 1.0:
	set(value):
		master_volume = value
		_update_bus_volume(BUS_MASTER, value)

@export_range(0.0, 1.0) var sfx_volume := 1.0:
	set(value):
		sfx_volume = value
		_update_bus_volume(BUS_SFX, value)

@export_range(0.0, 1.0) var ui_volume := 0.8:
	set(value):
		ui_volume = value
		_update_bus_volume(BUS_UI, value)

# ============================================================================
# AUDIO PLAYERS
# ============================================================================

var _ui_player_pool: Array[AudioStreamPlayer] = []
var _sfx_player_pool: Array[AudioStreamPlayer] = []

const UI_POOL_SIZE := 4
const SFX_POOL_SIZE := 8

# Preloaded sounds cache
var _sound_cache: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Audio works even when paused
	_setup_audio_buses()
	_create_sound_pools()
	_preload_ui_sounds()

func _setup_audio_buses() -> void:
	# Create audio buses if they don't exist
	# Note: In production, you'd set these up in the Audio Bus Layout editor
	# For now, we'll work with the default Master bus
	pass

func _create_sound_pools() -> void:
	# UI sound pool
	for i in range(UI_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.name = "UIPlayer_%d" % i
		player.bus = BUS_MASTER
		add_child(player)
		_ui_player_pool.append(player)
	
	# SFX sound pool (for non-positional sounds)
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = BUS_MASTER
		add_child(player)
		_sfx_player_pool.append(player)

func _preload_ui_sounds() -> void:
	# Preload commonly used UI sounds
	_preload_sound(SFX_UI_HOVER)
	_preload_sound(SFX_UI_SELECT)
	_preload_sound(SFX_UI_BACK)
	_preload_sound(SFX_UI_PAUSE)
	_preload_sound(SFX_UI_RESUME)
	_preload_sound(SFX_UI_KEYSTROKE)

func _preload_sound(path: String) -> void:
	if ResourceLoader.exists(path):
		_sound_cache[path] = load(path)

# ============================================================================
# SOUND EFFECTS
# ============================================================================

func play_ui_sound(path: String, volume_db := 0.0, pitch := 1.0) -> void:
	_play_from_pool(_ui_player_pool, path, volume_db, pitch)

func play_sfx(path: String, volume_db := 0.0, pitch := 1.0) -> void:
	_play_from_pool(_sfx_player_pool, path, volume_db, pitch)

func _play_from_pool(pool: Array[AudioStreamPlayer], path: String, volume_db: float, pitch: float) -> void:
	var stream: AudioStream
	
	# Check cache first
	if path in _sound_cache:
		stream = _sound_cache[path]
	elif ResourceLoader.exists(path):
		stream = load(path)
		_sound_cache[path] = stream
	else:
		print("AudioManager: Sound file not found: ", path)
		return
	
	# Find available player in pool
	for player in pool:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = pitch
			player.play()
			return
	
	# All players busy, use first one (interrupting it)
	pool[0].stream = stream
	pool[0].volume_db = volume_db
	pool[0].pitch_scale = pitch
	pool[0].play()

# ============================================================================
# CONVENIENCE METHODS FOR UI SOUNDS
# ============================================================================

func play_hover() -> void:
	play_ui_sound(SFX_UI_HOVER, -6.0)

func play_select() -> void:
	play_ui_sound(SFX_UI_SELECT)

func play_back() -> void:
	play_ui_sound(SFX_UI_BACK)

func play_pause() -> void:
	play_ui_sound(SFX_UI_PAUSE)

func play_resume() -> void:
	play_ui_sound(SFX_UI_RESUME)

func play_keystroke() -> void:
	play_ui_sound(SFX_UI_KEYSTROKE, -3.0, randf_range(0.95, 1.05))

# ============================================================================
# CONVENIENCE METHODS FOR RACE SOUNDS
# ============================================================================

func play_countdown_beep() -> void:
	play_sfx(SFX_COUNTDOWN_BEEP)

func play_countdown_go() -> void:
	play_sfx(SFX_COUNTDOWN_GO, 3.0)

func play_lap_complete() -> void:
	play_sfx(SFX_LAP_COMPLETE)

func play_final_lap() -> void:
	play_sfx(SFX_FINAL_LAP, 3.0)

func play_race_finish() -> void:
	play_sfx(SFX_RACE_FINISH)

func play_wrong_way() -> void:
	play_sfx(SFX_WRONG_WAY)

func play_new_record() -> void:
	play_sfx(SFX_NEW_RECORD)

func play_line_cross() -> void:
	play_sfx(SFX_LINE_CROSS, -3.0)

# ============================================================================
# VOLUME HELPERS
# ============================================================================

func _update_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		var db = linear_to_db(linear_volume) if linear_volume > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func _linear_to_db(linear: float) -> float:
	if linear <= 0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

# ============================================================================
# DEPRECATED MUSIC SHORTCUTS
# Music is now handled by MusicPlaylistManager
# These functions are kept as no-ops for backward compatibility
# ============================================================================

func play_menu_music() -> void:
	# DEPRECATED: Use MusicPlaylistManager.start_menu_music() instead
	pass

func play_race_music() -> void:
	# DEPRECATED: Use MusicPlaylistManager.start_race_music() instead
	pass

func play_results_music() -> void:
	# DEPRECATED: Music continues from race via MusicPlaylistManager
	pass

func stop_music(_fade_out := true) -> void:
	# DEPRECATED: Use MusicPlaylistManager.stop_music() instead
	pass

func pause_music() -> void:
	# DEPRECATED: Use MusicPlaylistManager.pause_music() instead
	pass

func resume_music() -> void:
	# DEPRECATED: Use MusicPlaylistManager.resume_music() instead
	pass

func is_music_playing() -> bool:
	# DEPRECATED: Use MusicPlaylistManager.is_playing() instead
	return false

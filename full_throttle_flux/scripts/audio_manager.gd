extends Node

## Global Audio Manager Singleton
## Handles music playback, transitions, UI sounds, and global volume control

# ============================================================================
# AUDIO BUS NAMES
# ============================================================================

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"

# ============================================================================
# MUSIC PATHS
# ============================================================================

const MUSIC_MENU := "res://music/menu_theme.ogg"
const MUSIC_RACE := "res://music/race_track_01.ogg"
const MUSIC_RESULTS := "res://music/results_theme.ogg"

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

@export_range(0.0, 1.0) var music_volume := 0.7:
	set(value):
		music_volume = value
		_update_bus_volume(BUS_MUSIC, value)

@export_range(0.0, 1.0) var sfx_volume := 1.0:
	set(value):
		sfx_volume = value
		_update_bus_volume(BUS_SFX, value)

@export_range(0.0, 1.0) var ui_volume := 0.8:
	set(value):
		ui_volume = value
		_update_bus_volume(BUS_UI, value)

@export_group("Music Settings")
@export var music_crossfade_time := 1.0
## Target volume for music in dB (0 = full, -6 = half perceived loudness)
@export var music_volume_db := -15.0

# ============================================================================
# AUDIO PLAYERS
# ============================================================================

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
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
	_create_music_players()
	_create_sound_pools()
	_preload_ui_sounds()

func _setup_audio_buses() -> void:
	# Create audio buses if they don't exist
	# Note: In production, you'd set these up in the Audio Bus Layout editor
	# For now, we'll work with the default Master bus
	pass

func _create_music_players() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.name = "MusicPlayerA"
	_music_player_a.bus = BUS_MASTER  # Use Master until Music bus is created
	_music_player_a.volume_db = music_volume_db
	add_child(_music_player_a)
	
	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.name = "MusicPlayerB"
	_music_player_b.bus = BUS_MASTER
	_music_player_b.volume_db = music_volume_db
	add_child(_music_player_b)
	
	_active_music_player = _music_player_a

## Set music volume in dB (0.0 = full, -6.0 = half, -12.0 = quarter)
func set_music_volume_db(volume_db: float) -> void:
	music_volume_db = volume_db
	_music_player_a.volume_db = volume_db
	_music_player_b.volume_db = volume_db

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
# MUSIC CONTROL
# ============================================================================

func play_music(path: String, crossfade := true) -> void:
	if not ResourceLoader.exists(path):
		print("AudioManager: Music file not found: ", path)
		# Stop current music since we can't play the new one
		stop_music(crossfade)
		return
	
	var stream = load(path) as AudioStream
	if not stream:
		stop_music(crossfade)
		return
	
	if crossfade and _active_music_player.playing:
		_crossfade_to(stream)
	else:
		_active_music_player.stream = stream
		_active_music_player.volume_db = music_volume_db
		_active_music_player.play()

func _crossfade_to(new_stream: AudioStream) -> void:
	var old_player = _active_music_player
	var new_player = _music_player_b if _active_music_player == _music_player_a else _music_player_a
	
	new_player.stream = new_stream
	new_player.volume_db = -80.0
	new_player.play()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(old_player, "volume_db", -80.0, music_crossfade_time)
	tween.tween_property(new_player, "volume_db", music_volume_db, music_crossfade_time)
	tween.set_parallel(false)
	tween.tween_callback(func(): old_player.stop())
	
	_active_music_player = new_player

func stop_music(fade_out := true) -> void:
	if not _active_music_player.playing:
		return
	
	if fade_out:
		var tween = create_tween()
		tween.tween_property(_active_music_player, "volume_db", -80.0, music_crossfade_time)
		tween.tween_callback(func(): _active_music_player.stop(); _active_music_player.volume_db = music_volume_db)
	else:
		_active_music_player.stop()

func pause_music() -> void:
	_active_music_player.stream_paused = true

func resume_music() -> void:
	_active_music_player.stream_paused = false

func is_music_playing() -> bool:
	return _active_music_player.playing and not _active_music_player.stream_paused

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
# MUSIC SHORTCUTS
# ============================================================================

func play_menu_music() -> void:
	play_music(MUSIC_MENU)

func play_race_music() -> void:
	play_music(MUSIC_RACE)

func play_results_music() -> void:
	play_music(MUSIC_RESULTS)

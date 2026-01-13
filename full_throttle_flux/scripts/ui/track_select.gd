extends Control
class_name TrackSelect

## Track Selection Screen
## Displays available tracks and stores selection in GameManager
## Flow: Main Menu → Track Select → Ship Select → Race

# ============================================================================
# UI REFERENCES
# ============================================================================

var title_label: Label
var track_container: VBoxContainer
var track_buttons: Array[Button] = []
var back_button: Button
var description_label: Label

# ============================================================================
# STATE
# ============================================================================

var available_tracks: Array[TrackProfile] = []
var selected_index: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	available_tracks = GameManager.get_tracks_for_mode(GameManager.get_selected_mode())
	_create_ui()
	_populate_tracks()
	_setup_focus()

func _create_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Title
	title_label = Label.new()
	title_label.text = "SELECT TRACK"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(1920/2 - 400, 80)
	title_label.size = Vector2(800, 80)
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	add_child(title_label)
	
	# Track button container
	track_container = VBoxContainer.new()
	track_container.position = Vector2(1920/2 - 250, 200)
	track_container.size = Vector2(500, 500)
	track_container.add_theme_constant_override("separation", 20)
	add_child(track_container)
	
	# Description panel
	var desc_panel = PanelContainer.new()
	desc_panel.position = Vector2(1920/2 - 400, 700)
	desc_panel.size = Vector2(800, 120)
	add_child(desc_panel)
	
	description_label = Label.new()
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 22)
	description_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_panel.add_child(description_label)
	
	# Back button
	back_button = Button.new()
	back_button.text = "← BACK"
	back_button.position = Vector2(100, 950)
	back_button.size = Vector2(200, 50)
	back_button.add_theme_font_size_override("font_size", 24)
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.pressed.connect(_on_back_pressed)
	back_button.focus_entered.connect(_on_button_focus)
	add_child(back_button)

func _populate_tracks() -> void:
	# Clear existing buttons
	for btn in track_buttons:
		btn.queue_free()
	track_buttons.clear()
	
	# Create button for each track
	for i in range(available_tracks.size()):
		var track = available_tracks[i]
		var btn = Button.new()
		btn.text = track.display_name
		btn.custom_minimum_size = Vector2(500, 70)
		btn.add_theme_font_size_override("font_size", 32)
		btn.focus_mode = Control.FOCUS_ALL
		
		# Store index for callback
		btn.pressed.connect(_on_track_selected.bind(i))
		btn.focus_entered.connect(_on_track_focused.bind(i))
		
		track_container.add_child(btn)
		track_buttons.append(btn)
	
	# Show first track description
	if available_tracks.size() > 0:
		_update_description(0)

func _setup_focus() -> void:
	if track_buttons.is_empty():
		return
	
	# Set up vertical navigation between track buttons
	for i in range(track_buttons.size()):
		var btn = track_buttons[i]
		
		if i > 0:
			btn.focus_neighbor_top = track_buttons[i - 1].get_path()
		else:
			btn.focus_neighbor_top = back_button.get_path()
		
		if i < track_buttons.size() - 1:
			btn.focus_neighbor_bottom = track_buttons[i + 1].get_path()
		else:
			btn.focus_neighbor_bottom = back_button.get_path()
	
	# Back button navigation
	back_button.focus_neighbor_top = track_buttons[-1].get_path()
	back_button.focus_neighbor_bottom = track_buttons[0].get_path()
	
	# Initial focus
	track_buttons[0].grab_focus()

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_track_focused(index: int) -> void:
	AudioManager.play_hover()
	selected_index = index
	_update_description(index)

func _on_track_selected(index: int) -> void:
	AudioManager.play_select()
	
	var track = available_tracks[index]
	GameManager.select_track(track)
	
	print("TrackSelect: Selected %s" % track.display_name)
	
	# Proceed to ship select
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scenes/ui/ship_select.tscn")

func _on_back_pressed() -> void:
	AudioManager.play_select()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_button_focus() -> void:
	AudioManager.play_hover()
	description_label.text = ""

func _update_description(index: int) -> void:
	var track = available_tracks[index]
	var difficulty_stars = "★".repeat(track.difficulty) + "☆".repeat(5 - track.difficulty)
	description_label.text = "%s\nDifficulty: %s | Laps: %d" % [track.description, difficulty_stars, track.default_laps]

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

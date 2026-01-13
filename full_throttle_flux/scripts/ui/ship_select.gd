extends Control
class_name ShipSelect

## Ship Selection Screen
## Displays available ships and stores selection in GameManager
## Flow: Main Menu → Track Select → Ship Select → Race

# ============================================================================
# UI REFERENCES
# ============================================================================

var title_label: Label
var ship_container: VBoxContainer
var ship_buttons: Array[Button] = []
var back_button: Button
var description_label: Label
var stats_container: VBoxContainer

# ============================================================================
# STATE
# ============================================================================

var available_ships: Array[ShipProfile] = []
var selected_index: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	available_ships = GameManager.get_ships_for_mode(GameManager.get_selected_mode())
	_create_ui()
	_populate_ships()
	_setup_focus()

func _create_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Title
	title_label = Label.new()
	title_label.text = "SELECT SHIP"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(1920/2 - 400, 80)
	title_label.size = Vector2(800, 80)
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	add_child(title_label)
	
	# Ship button container (left side)
	ship_container = VBoxContainer.new()
	ship_container.position = Vector2(300, 200)
	ship_container.size = Vector2(500, 500)
	ship_container.add_theme_constant_override("separation", 20)
	add_child(ship_container)
	
	# Stats panel (right side)
	var stats_panel = PanelContainer.new()
	stats_panel.position = Vector2(1000, 200)
	stats_panel.size = Vector2(600, 400)
	add_child(stats_panel)
	
	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 15)
	stats_panel.add_child(stats_container)
	
	# Description panel (bottom)
	var desc_panel = PanelContainer.new()
	desc_panel.position = Vector2(1920/2 - 400, 750)
	desc_panel.size = Vector2(800, 100)
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

func _populate_ships() -> void:
	# Clear existing buttons
	for btn in ship_buttons:
		btn.queue_free()
	ship_buttons.clear()
	
	# Create button for each ship
	for i in range(available_ships.size()):
		var ship = available_ships[i]
		var btn = Button.new()
		btn.text = ship.display_name
		btn.custom_minimum_size = Vector2(500, 70)
		btn.add_theme_font_size_override("font_size", 32)
		btn.focus_mode = Control.FOCUS_ALL
		
		# Store index for callback
		btn.pressed.connect(_on_ship_selected.bind(i))
		btn.focus_entered.connect(_on_ship_focused.bind(i))
		
		ship_container.add_child(btn)
		ship_buttons.append(btn)
	
	# Show first ship stats
	if available_ships.size() > 0:
		_update_ship_info(0)

func _setup_focus() -> void:
	if ship_buttons.is_empty():
		return
	
	# Set up vertical navigation between ship buttons
	for i in range(ship_buttons.size()):
		var btn = ship_buttons[i]
		
		if i > 0:
			btn.focus_neighbor_top = ship_buttons[i - 1].get_path()
		else:
			btn.focus_neighbor_top = back_button.get_path()
		
		if i < ship_buttons.size() - 1:
			btn.focus_neighbor_bottom = ship_buttons[i + 1].get_path()
		else:
			btn.focus_neighbor_bottom = back_button.get_path()
	
	# Back button navigation
	back_button.focus_neighbor_top = ship_buttons[-1].get_path()
	back_button.focus_neighbor_bottom = ship_buttons[0].get_path()
	
	# Initial focus
	ship_buttons[0].grab_focus()

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_ship_focused(index: int) -> void:
	AudioManager.play_hover()
	selected_index = index
	_update_ship_info(index)

func _on_ship_selected(index: int) -> void:
	AudioManager.play_select()
	
	var ship = available_ships[index]
	GameManager.select_ship(ship)
	
	print("ShipSelect: Selected %s" % ship.display_name)
	
	# Fade out menu music
	MusicPlaylistManager.fade_out_for_race()
	
	# Proceed to race
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scenes/race_launcher.tscn")

func _on_back_pressed() -> void:
	AudioManager.play_select()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/ui/track_select.tscn")

func _on_button_focus() -> void:
	AudioManager.play_hover()
	_clear_stats()
	description_label.text = ""

func _update_ship_info(index: int) -> void:
	var ship = available_ships[index]
	description_label.text = ship.description
	_update_stats(ship)

func _clear_stats() -> void:
	for child in stats_container.get_children():
		child.queue_free()

func _update_stats(ship: ShipProfile) -> void:
	_clear_stats()
	
	# Title
	var title = Label.new()
	title.text = ship.display_name
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	stats_container.add_child(title)
	
	# Manufacturer
	var mfg = Label.new()
	mfg.text = "by %s" % ship.manufacturer
	mfg.add_theme_font_size_override("font_size", 20)
	mfg.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	stats_container.add_child(mfg)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	stats_container.add_child(spacer)
	
	# Stats bars
	_add_stat_bar("SPEED", ship.max_speed, 80.0, 180.0)
	_add_stat_bar("THRUST", ship.thrust_power, 40.0, 100.0)
	_add_stat_bar("GRIP", ship.grip, 2.0, 6.0)
	_add_stat_bar("STEERING", ship.steer_speed, 0.8, 2.0)

func _add_stat_bar(label_text: String, value: float, min_val: float, max_val: float) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(550, 35)
	stats_container.add_child(row)
	
	# Label
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 30)
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)
	
	# Bar background
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.custom_minimum_size = Vector2(300, 25)
	row.add_child(bar_bg)
	
	# Bar fill
	var normalized = clamp((value - min_val) / (max_val - min_val), 0.0, 1.0)
	var bar_fill = ColorRect.new()
	bar_fill.color = _get_stat_color(normalized)
	bar_fill.size = Vector2(300 * normalized, 25)
	bar_fill.position = Vector2.ZERO
	bar_bg.add_child(bar_fill)
	
	# Value label
	var val_label = Label.new()
	val_label.text = "%.0f" % value
	val_label.custom_minimum_size = Vector2(60, 30)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 18)
	row.add_child(val_label)

func _get_stat_color(normalized: float) -> Color:
	if normalized < 0.33:
		return Color(0.8, 0.3, 0.3)  # Red-ish
	elif normalized < 0.66:
		return Color(0.8, 0.7, 0.2)  # Yellow-ish
	else:
		return Color(0.3, 0.8, 0.4)  # Green-ish

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

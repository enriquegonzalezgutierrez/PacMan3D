# ==============================================================================
# Description: Standalone System Settings Panel UI.
#              Provides interactive sliders for Master, Music, and SFX volumes, 
#              featuring automatic dynamic audio bus generation and encrypted 
#              persistence on disk.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted entirely from MainMenu, managing 
#                strictly its own sliders, AudioServer buses, and disk saving.
#              - OCP Compliance: Persistent settings are structurally isolated, 
#                enabling future addition of options (e.g., graphics toggle) 
#                without breaking the audio routing.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name SettingsPanel

# Signal to notify parents when the panel is closed
signal closed()

const SETTINGS_PATH : String = "user://settings.dat"
const ENCRYPTION_KEY : String = "PacMan3D_SecureSettingsKey_9903"

# UI Slider Components
var master_slider : HSlider
var music_slider : HSlider
var sfx_slider : HSlider
var back_button : Button

# Cached Audio Bus Indexes in AudioServer
var bus_master_idx : int = 0
var bus_music_idx : int = 0
var bus_sfx_idx : int = 0

func _ready() -> void:
	# Enforce settings configuration during pause states
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_audio_buses_exist()
	_build_ui()
	_load_and_apply_settings()

# Programmatically constructs the missing BGM/SFX audio channels on boot (DIP Compliance)
func _ensure_audio_buses_exist() -> void:
	bus_master_idx = AudioServer.get_bus_index("Master")
	
	# Verify and compile "Music" bus dynamically
	bus_music_idx = AudioServer.get_bus_index("Music")
	if bus_music_idx == -1:
		AudioServer.add_bus()
		bus_music_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_music_idx, "Music")
		
	# Verify and compile "SFX" bus dynamically
	bus_sfx_idx = AudioServer.get_bus_index("SFX")
	if bus_sfx_idx == -1:
		AudioServer.add_bus()
		bus_sfx_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_sfx_idx, "SFX")

# Programmatically builds the cyber-retro settings box layout
func _build_ui() -> void:
	# Dark semi-transparent background overlay blocking gameplay interaction
	var background_dim := ColorRect.new()
	background_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	add_child(background_dim)
	background_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var root_panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.01, 0.01, 0.02, 0.95)
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.border_color = Color(0.0, 0.8, 1.0) # Glowing neon cyan border
	panel_style.set_corner_radius_all(15)
	panel_style.content_margin_left = 64
	panel_style.content_margin_right = 64
	panel_style.content_margin_top = 48
	panel_style.content_margin_bottom = 48
	root_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(root_panel)
	
	root_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 32)
	root_panel.add_child(main_vbox)
	
	# Title
	var title_label := Label.new()
	title_label.text = "SYSTEM SETTINGS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.add_theme_color_override("font_outline_color", Color(0,0,0))
	main_vbox.add_child(title_label)
	
	# Grid aligned slider controls
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 24)
	main_vbox.add_child(grid)
	
	var create_slider_row = func(label_text: String) -> HSlider:
		var lbl := Label.new()
		lbl.text = label_text
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		grid.add_child(lbl)
		
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(300, 42)
		grid.add_child(slider)
		return slider
		
	# 1. Master Row
	master_slider = create_slider_row.call("MASTER VOLUME")
	master_slider.value_changed.connect(func(val): _set_bus_volume(bus_master_idx, val))
	
	# 2. Music Row
	music_slider = create_slider_row.call("MUSIC VOLUME")
	music_slider.value_changed.connect(func(val): _set_bus_volume(bus_music_idx, val))
	
	# 3. SFX Row
	sfx_slider = create_slider_row.call("SFX VOLUME")
	sfx_slider.value_changed.connect(func(val): _set_bus_volume(bus_sfx_idx, val))
	
	# Back Button
	back_button = Button.new()
	back_button.text = "SAVE & CLOSE"
	back_button.add_theme_font_size_override("font_size", 32)
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	btn_style.border_width_left = 3
	btn_style.border_width_top = 3
	btn_style.border_width_right = 3
	btn_style.border_width_bottom = 3
	btn_style.border_color = Color(0.3, 0.3, 0.3)
	btn_style.set_corner_radius_all(12)
	btn_style.content_margin_top = 16
	btn_style.content_margin_bottom = 16
	
	var btn_style_hover := btn_style.duplicate()
	btn_style_hover.border_color = Color(1.0, 1.0, 0.0)
	btn_style_hover.bg_color = Color(0.18, 0.18, 0.0, 0.9)
	
	back_button.add_theme_stylebox_override("normal", btn_style)
	back_button.add_theme_stylebox_override("hover", btn_style_hover)
	back_button.add_theme_stylebox_override("focus", btn_style_hover)
	back_button.add_theme_stylebox_override("pressed", btn_style_hover)
	
	back_button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	back_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.0))
	back_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.0))
	
	main_vbox.add_child(back_button)
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()

# Helper to set the volume on the targeted bus dynamically
func _set_bus_volume(bus_idx: int, linear_val: float) -> void:
	if linear_val <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		# Convert standard linear slider range (0.0 - 1.0) to natural logarithmic decibels (db)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))

# Loads, decrypts, and applies saved volume configurations from disk
func _load_and_apply_settings() -> void:
	var master_vol := 0.8
	var music_vol := 0.7
	var sfx_vol := 0.8
	
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open_encrypted_with_pass(SETTINGS_PATH, FileAccess.READ, ENCRYPTION_KEY)
		if file:
			master_vol = file.get_float()
			music_vol = file.get_float()
			sfx_vol = file.get_float()
			file.close()
			
	# Apply loaded values to the GUI sliders
	master_slider.value = master_vol
	music_slider.value = music_vol
	sfx_slider.value = sfx_vol
	
	# Apply to the AudioServer buses
	_set_bus_volume(bus_master_idx, master_vol)
	_set_bus_volume(bus_music_idx, music_vol)
	_set_bus_volume(bus_sfx_idx, sfx_vol)

# Encrypts and writes current volume configurations to disk
func _save_settings() -> void:
	var file := FileAccess.open_encrypted_with_pass(SETTINGS_PATH, FileAccess.WRITE, ENCRYPTION_KEY)
	if file:
		file.store_float(master_slider.value)
		file.store_float(music_slider.value)
		file.store_float(sfx_slider.value)
		file.close()

func _on_back_pressed() -> void:
	_save_settings()
	closed.emit()
	queue_free() # Self-destroy panel

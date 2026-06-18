# ==============================================================================
# Description: Procedural Main Menu component.
#              Constructs the title, button layouts (Start, Settings, Exit), 
#              and coordinates BGM playbacks on the targeted "Music" bus.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted the settings panel into its own class. 
#                The MainMenu is solely responsible for booting screens and focus 
#                routing.
#              - DIP Compliance: Restores user audio configurations dynamically 
#                on startup via AudioServer without hardcoded singletons.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name MainMenu

signal start_game_requested()

# Internal UI Components
var menu_bg : TextureRect
var menu_title : Label
var start_button : Button
var settings_button : Button
var exit_button : Button
var menu_bgm : AudioStreamPlayer

func _ready() -> void:
	# Enforce processing during pause states
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 1. Load and restore user volume preferences instantly on launch (DIP Compliance)
	_load_initial_audio_volumes()
	
	# 2. Compile title screen UI
	_build_ui()

# Loads user settings silently on startup to ensure correct volumes out-of-the-box
func _load_initial_audio_volumes() -> void:
	var master_vol := 0.8
	var music_vol := 0.7
	var sfx_vol := 0.8
	
	# Settings path matching the SettingsPanel constants
	if FileAccess.file_exists("user://settings.dat"):
		var file = FileAccess.open_encrypted_with_pass("user://settings.dat", FileAccess.READ, "PacMan3D_SecureSettingsKey_9903")
		if file:
			master_vol = file.get_float()
			music_vol = file.get_float()
			sfx_vol = file.get_float()
			file.close()
			
	# Dynamically obtain or compile engine buses
	var master_idx = AudioServer.get_bus_index("Master")
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx == -1:
		AudioServer.add_bus()
		music_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_idx, "Music")
		
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		AudioServer.add_bus()
		sfx_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		
	var apply_vol = func(bus_idx: int, linear_val: float):
		if linear_val <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))
			
	apply_vol.call(master_idx, master_vol)
	apply_vol.call(music_idx, music_vol)
	apply_vol.call(sfx_idx, sfx_vol)

# Programmatically builds the Main Menu title overlay
func _build_ui() -> void:
	# 1. Menu Background
	menu_bg = TextureRect.new()
	menu_bg.texture = load("res://assets/ui/images/main_menu_bg.png")
	menu_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(menu_bg)
	menu_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var darken_overlay := ColorRect.new()
	darken_overlay.color = Color(0.0, 0.0, 0.0, 0.45)
	menu_bg.add_child(darken_overlay)
	darken_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 2. Glowing Title (Enlarged to 110px for 1080p presence)
	menu_title = Label.new()
	menu_title.text = "PAC-MAN 3D"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 110)
	menu_title.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0)) 
	menu_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 1.0)) 
	menu_title.add_theme_constant_override("outline_size", 16)
	menu_bg.add_child(menu_title)
	
	menu_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	menu_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_title.offset_top = 120
	
	# Container for vertical button alignment
	var button_container := VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 32)
	menu_bg.add_child(button_container)
	
	button_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	button_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	button_container.offset_top = 100
	
	# --- STYLING BUTTON THEMES PROCEDURALLY ---
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = Color(0.3, 0.3, 0.3)
	style_normal.set_corner_radius_all(12)
	style_normal.content_margin_left = 64
	style_normal.content_margin_right = 64
	style_normal.content_margin_top = 28
	style_normal.content_margin_bottom = 28
	
	var style_focus_hover := StyleBoxFlat.new()
	style_focus_hover.bg_color = Color(0.18, 0.18, 0.0, 0.9) 
	style_focus_hover.border_width_left = 4
	style_focus_hover.border_width_top = 4
	style_focus_hover.border_width_right = 4
	style_focus_hover.border_width_bottom = 4
	style_focus_hover.border_color = Color(1.0, 1.0, 0.0) 
	style_focus_hover.set_corner_radius_all(12)
	style_focus_hover.content_margin_left = 64
	style_focus_hover.content_margin_right = 64
	style_focus_hover.content_margin_top = 28
	style_focus_hover.content_margin_bottom = 28
	
	# 3. Start Game Button
	start_button = Button.new()
	start_button.text = "START GAME"
	start_button.add_theme_font_size_override("font_size", 54)
	start_button.add_theme_stylebox_override("normal", style_normal)
	start_button.add_theme_stylebox_override("hover", style_focus_hover)
	start_button.add_theme_stylebox_override("focus", style_focus_hover) 
	start_button.add_theme_stylebox_override("pressed", style_focus_hover)
	start_button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	start_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.0))
	start_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.0))
	button_container.add_child(start_button)
	start_button.pressed.connect(_on_start_pressed)
	
	# 4. Settings Button (SRP Compliance)
	settings_button = Button.new()
	settings_button.text = "SETTINGS"
	settings_button.add_theme_font_size_override("font_size", 48)
	settings_button.add_theme_stylebox_override("normal", style_normal)
	settings_button.add_theme_stylebox_override("hover", style_focus_hover)
	settings_button.add_theme_stylebox_override("focus", style_focus_hover) 
	settings_button.add_theme_stylebox_override("pressed", style_focus_hover)
	settings_button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	settings_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.0))
	settings_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.0))
	button_container.add_child(settings_button)
	settings_button.pressed.connect(_on_settings_pressed)
	
	# 5. Exit Button (Hidden on iOS/Web where programmatic exit is blocked)
	if not OS.has_feature("web") and not OS.has_feature("ios"):
		exit_button = Button.new()
		exit_button.text = "EXIT"
		exit_button.add_theme_font_size_override("font_size", 48)
		exit_button.add_theme_stylebox_override("normal", style_normal)
		exit_button.add_theme_stylebox_override("hover", style_focus_hover)
		exit_button.add_theme_stylebox_override("focus", style_focus_hover)
		exit_button.add_theme_stylebox_override("pressed", style_focus_hover)
		exit_button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		exit_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.0))
		exit_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.0))
		button_container.add_child(exit_button)
		exit_button.pressed.connect(func(): get_tree().quit())
	
	start_button.grab_focus()
	
	# 6. Menu BGM Player
	menu_bgm = AudioStreamPlayer.new()
	menu_bgm.stream = load("res://assets/audio/bgm/main_menu_bgm.mp3")
	menu_bgm.volume_db = -8.0
	
	# --- SPECIFIC BUS ROUTING (DIP Compliance) ---
	# Assign menu background soundtrack to the programmatically generated Music bus
	menu_bgm.bus = "Music"
	
	menu_bgm.autoplay = true
	add_child(menu_bgm)
	menu_bgm.play()

# Triggered when Start Game is clicked
func _on_start_pressed() -> void:
	menu_title.visible = false
	start_button.visible = false
	settings_button.visible = false
	if is_instance_valid(exit_button):
		exit_button.visible = false
		
	if menu_bgm:
		menu_bgm.stop()
		
	start_game_requested.emit()
	queue_free()

# Instantiates and overlays the SettingsPanel dynamically (SRP/UX Focus Compliance)
func _on_settings_pressed() -> void:
	# Disable main menu buttons to prevent clicks behind the settings panel
	start_button.disabled = true
	settings_button.disabled = true
	if is_instance_valid(exit_button):
		exit_button.disabled = true
		
	var panel = SettingsPanel.new()
	add_child(panel)
	
	# Ensure the settings modal renders in front of title text
	move_child(panel, -1)
	
	# Re-enable menu buttons and grab focus back once panel is closed and deleted
	panel.closed.connect(func():
		start_button.disabled = false
		settings_button.disabled = false
		if is_instance_valid(exit_button):
			exit_button.disabled = false
		settings_button.grab_focus()
	)

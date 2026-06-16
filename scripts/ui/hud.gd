# ==============================================================================
# Description: HUD and Main Menu manager. Programmatically constructs the full
#              main menu (background, title, buttons, audio) on startup.
#              SOLID Refactoring:
#              - SRP: Orchestrates both HUD labels and the procedural main menu.
#              - DIP: The menu BGM stream is loaded dynamically.
#              - UX Update: Added full keyboard navigation support and custom 
#                glowing focus/hover styleboxes for arcade-style button selections.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name HUD

# Signals to notify coordinators of game start (DIP Compliance)
signal start_game()

# HUD Components
var score_label : Label
var lives_label : Label
var status_overlay : ColorRect
var status_label : Label
var minimap : Minimap2D

# Main Menu Components (Procedural UI)
var menu_bg : TextureRect
var menu_title : Label
var start_button : Button
var exit_button : Button
var menu_bgm : AudioStreamPlayer

func _ready() -> void:
	_build_hud_elements()
	_build_main_menu() 
	
	# Connect to global GameManager signals safely
	if GameManager:
		GameManager.score_changed.connect(_on_score_changed)
		GameManager.lives_changed.connect(_on_lives_changed)
		GameManager.game_over.connect(_on_game_over)
		GameManager.victory.connect(_on_victory)
		
		# Pull initial data values directly on startup
		_on_score_changed(GameManager.score)
		_on_lives_changed(GameManager.lives)

# Programmatically constructs the HUD layout tree
func _build_hud_elements() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 1. Score Label Setup
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.visible = false
	add_child(score_label)
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	score_label.offset_left = 24
	score_label.offset_top = 24
	
	# 2. Lives Label Setup
	lives_label = Label.new()
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lives_label.add_theme_font_size_override("font_size", 28)
	lives_label.visible = false
	add_child(lives_label)
	
	lives_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lives_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lives_label.offset_left = -224
	lives_label.offset_right = -24
	lives_label.offset_top = 24
	
	# 3. Minimap 2D Setup
	minimap = Minimap2D.new()
	minimap.visible = false
	add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	minimap.offset_left = -204
	minimap.offset_top = -204
	minimap.offset_right = -24
	minimap.offset_bottom = -24
	
	# 4. Status Full-Screen Overlay
	status_overlay = ColorRect.new()
	status_overlay.color = Color(0.0, 0.0, 0.0, 0.75) 
	status_overlay.visible = false
	add_child(status_overlay)
	status_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 5. Status Text inside the overlay
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 48)
	status_overlay.add_child(status_label)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status_label.grow_vertical = GROW_DIRECTION_BOTH

# Programmatically builds the full-screen Main Menu overlay
func _build_main_menu() -> void:
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
	
	# 2. Glowing Title
	menu_title = Label.new()
	menu_title.text = "PAC-MAN 3D"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 72)
	menu_title.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0)) 
	menu_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 1.0)) 
	menu_title.add_theme_constant_override("outline_size", 14)
	menu_bg.add_child(menu_title)
	
	menu_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	menu_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_title.offset_top = 100
	
	# Container for vertical button alignment
	var button_container := VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 24)
	menu_bg.add_child(button_container)
	
	button_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	button_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	button_container.offset_top = 80
	
	# --- STYLING BUTTON THEMES PROCEDURALLY (SRP Compliance) ---
	# Normal button style: dark, clean gray border
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.3, 0.3, 0.3)
	style_normal.set_corner_radius_all(6)
	style_normal.content_margin_left = 32
	style_normal.content_margin_right = 32
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12
	
	# Focus and Hover button style: Glowing arcade yellow neons
	var style_focus_hover := StyleBoxFlat.new()
	style_focus_hover.bg_color = Color(0.18, 0.18, 0.0, 0.9) # Dark yellow hint
	style_focus_hover.border_width_left = 3
	style_focus_hover.border_width_top = 3
	style_focus_hover.border_width_right = 3
	style_focus_hover.border_width_bottom = 3
	style_focus_hover.border_color = Color(1.0, 1.0, 0.0) # Glowing neon yellow border
	style_focus_hover.set_corner_radius_all(6)
	style_focus_hover.content_margin_left = 32
	style_focus_hover.content_margin_right = 32
	style_focus_hover.content_margin_top = 12
	style_focus_hover.content_margin_bottom = 12
	
	# 3. Start Game Button
	start_button = Button.new()
	start_button.text = "START GAME"
	start_button.add_theme_font_size_override("font_size", 28)
	
	# Apply style overrides
	start_button.add_theme_stylebox_override("normal", style_normal)
	start_button.add_theme_stylebox_override("hover", style_focus_hover)
	start_button.add_theme_stylebox_override("focus", style_focus_hover) # Keyboard focus matches mouse hover
	start_button.add_theme_stylebox_override("pressed", style_focus_hover)
	
	# Apply color highlights
	start_button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	start_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.0))
	start_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.0))
	
	button_container.add_child(start_button)
	start_button.pressed.connect(_on_start_game_pressed)
	
	# 4. Exit Button
	exit_button = Button.new()
	exit_button.text = "EXIT"
	exit_button.add_theme_font_size_override("font_size", 24)
	
	# Apply same style overrides
	exit_button.add_theme_stylebox_override("normal", style_normal)
	exit_button.add_theme_stylebox_override("hover", style_focus_hover)
	exit_button.add_theme_stylebox_override("focus", style_focus_hover)
	exit_button.add_theme_stylebox_override("pressed", style_focus_hover)
	
	# Apply same color highlights
	exit_button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	exit_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.0))
	exit_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.0))
	
	button_container.add_child(exit_button)
	exit_button.pressed.connect(func(): get_tree().quit())
	
	# KEYBOARD ACCESSIBILITY FOCUS GRAB: Focus start button immediately
	start_button.grab_focus()
	
	# 5. Menu BGM Player
	menu_bgm = AudioStreamPlayer.new()
	menu_bgm.stream = load("res://assets/audio/bgm/main_menu_bgm.mp3")
	menu_bgm.volume_db = -8.0
	menu_bgm.autoplay = true
	add_child(menu_bgm)
	menu_bgm.play()

# Button Callback: Clears the menu overlays, starts BGM, and signals LevelManager to build map
func _on_start_game_pressed() -> void:
	# Stop and clean menu audio
	if menu_bgm:
		menu_bgm.stop()
		menu_bgm.queue_free()
		
	# Destroy menu overlays
	if menu_bg:
		menu_bg.queue_free()
		
	# Make core HUD gameplay widgets visible
	score_label.visible = true
	lives_label.visible = true
	minimap.visible = true
	
	# Notify orchestrators that the player has initiated the game (DIP Compliance)
	start_game.emit()

func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE: %d" % new_score

func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "LIVES: %d" % new_lives

func _on_game_over() -> void:
	status_label.text = "GAME OVER\nPress R to Restart"
	status_overlay.visible = true
	get_tree().paused = true

func _on_victory() -> void:
	status_label.text = "VICTORY!\nPress R to Restart"
	status_overlay.visible = true
	get_tree().paused = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_R and event.is_pressed():
		if status_overlay.visible:
			get_tree().paused = false
			if GameManager:
				GameManager.reset_game()
			get_tree().reload_current_scene()

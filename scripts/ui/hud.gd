# ==============================================================================
# Description: HUD Orchestrator. 
#              Responsible exclusively for updating numeric gameplay indicators 
#              (Score, High-Score, Lives), the Minimap, and managing the active 
#              UI layers. 
#              SOLID Refactoring:
#              - SRP Compliance: Extracted Main Menu, Joystick, and Overlays into 
#                dedicated single-responsibility classes. The HUD no longer acts 
#                as a God Class.
#              - DIP Compliance: Communicates with GameManager and sub-components 
#                strictly via signals and public APIs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name HUD

# Signal to notify the LevelManager to build the 3D world
signal start_game()

# UI Components
var score_label : Label
var high_score_label : Label 
var lives_label : Label
var minimap : Minimap2D

# External Component References
var status_overlay : StatusOverlay
var main_menu : MainMenu
var mobile_controls : VirtualJoystick

# Platform Context
var is_mobile : bool = false

func _ready() -> void:
	# Enforce HUD processing during pause states
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web")
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_build_base_hud_elements()
	_instantiate_status_overlay()
	
	# Connect to global GameManager signals (DIP Compliance)
	if GameManager:
		GameManager.score_changed.connect(_on_score_changed)
		GameManager.lives_changed.connect(_on_lives_changed)
		GameManager.high_score_changed.connect(_on_high_score_changed)
		
		GameManager.game_over.connect(_on_game_over)
		GameManager.victory.connect(_on_victory_transition)
		
		# Autoload race condition fix: Sync values immediately
		_on_score_changed(GameManager.score)
		_on_high_score_changed(GameManager.high_score)
		_on_lives_changed(GameManager.lives)
	
	# Determine startup state: Procedural Generation or Main Menu?
	if GameManager and GameManager.is_game_started:
		_start_active_gameplay_ui()
	else:
		_instantiate_main_menu()

# Programmatically constructs the top layout (Score, Record, Lives, Minimap)
func _build_base_hud_elements() -> void:
	# 1. Score Label Setup (Top-Left)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 42)
	score_label.add_theme_constant_override("outline_size", 10)
	score_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 1.0))
	score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	score_label.visible = false
	add_child(score_label)
	
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	score_label.offset_left = 64
	score_label.offset_top = 64
	
	# 2. High-Score Label Setup (Center-Top)
	high_score_label = Label.new()
	high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	high_score_label.add_theme_font_size_override("font_size", 42)
	high_score_label.add_theme_constant_override("outline_size", 10)
	high_score_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 1.0))
	high_score_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	high_score_label.visible = false
	add_child(high_score_label)
	
	high_score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	high_score_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	high_score_label.offset_top = 64
	
	# 3. Lives Label Setup (Top-Right)
	lives_label = Label.new()
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lives_label.add_theme_font_size_override("font_size", 42)
	lives_label.add_theme_constant_override("outline_size", 10)
	lives_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 1.0))
	lives_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	lives_label.visible = false
	add_child(lives_label)
	
	lives_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lives_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lives_label.offset_left = -450
	lives_label.offset_right = -64
	lives_label.offset_top = 64
	
	# 4. Minimap 2D Setup
	minimap = Minimap2D.new()
	var map_dim = 280
	minimap.map_size = Vector2(map_dim, map_dim) 
	minimap.visible = false
	add_child(minimap)
	
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	var right_margin = -32
	minimap.offset_left = -map_dim + right_margin
	minimap.offset_right = right_margin
	
	if is_mobile:
		# Shift minimap upwards to clear the giant mobile jump button
		var bottom_margin = -280 
		minimap.offset_top = -map_dim + bottom_margin
		minimap.offset_bottom = bottom_margin
	else:
		var bottom_margin = -32 
		minimap.offset_top = -map_dim + bottom_margin
		minimap.offset_bottom = bottom_margin

# Composes the external StatusOverlay component (SRP Compliance)
func _instantiate_status_overlay() -> void:
	status_overlay = StatusOverlay.new()
	add_child(status_overlay)
	# Push overlay to the bottom of the tree so it renders on top of everything
	move_child(status_overlay, -1)

# Composes the external MainMenu component (SRP Compliance)
func _instantiate_main_menu() -> void:
	main_menu = MainMenu.new()
	add_child(main_menu)
	main_menu.start_game_requested.connect(_on_menu_start_game_requested)
	
	# Ensure the status overlay stays on top of the newly added menu
	move_child(status_overlay, -1)

# Composes the external VirtualJoystick and Mobile controls (SRP Compliance)
func _instantiate_mobile_controls() -> void:
	if not is_mobile: return
	
	mobile_controls = VirtualJoystick.new()
	add_child(mobile_controls)
	
	var viewport_size = get_viewport_rect().size
	mobile_controls.position = Vector2(100.0, viewport_size.y - 420.0)
	
	# Instantiate enlarged 220px Jump Button
	var jump_btn = TouchScreenButton.new()
	jump_btn.action = "ui_select"
	
	var create_tex = func(color: Color) -> GradientTexture2D:
		var tex := GradientTexture2D.new()
		tex.width = 220
		tex.height = 220
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		var grad := Gradient.new()
		grad.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
		grad.offsets = PackedFloat32Array([0.75, 1.0])
		tex.gradient = grad
		return tex
		
	jump_btn.texture_normal = create_tex.call(Color(1.0, 1.0, 1.0, 0.35))
	jump_btn.texture_pressed = create_tex.call(Color(1.0, 1.0, 0.0, 0.65))
	
	var jump_label := Label.new()
	jump_label.text = "JUMP"
	jump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jump_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jump_label.add_theme_font_size_override("font_size", 34)
	jump_label.add_theme_constant_override("outline_size", 10)
	jump_label.add_theme_color_override("font_outline_color", Color(0,0,0))
	jump_btn.add_child(jump_label)
	jump_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	add_child(jump_btn)
	jump_btn.position = Vector2(viewport_size.x - 320.0, viewport_size.y - 320.0)

# Triggers when main menu Start is clicked
func _on_menu_start_game_requested() -> void:
	if GameManager:
		GameManager.is_game_started = true
		
	# Instantly show generation status
	status_overlay.show_status("GENERATING SYSTEM...\nPLEASE WAIT", true)
	
	# Physical wait to guarantee GPU clears the menu and draws the overlay
	await get_tree().create_timer(0.05).timeout
	
	_start_active_gameplay_ui()

# Activates all standard gameplay UI elements
func _start_active_gameplay_ui() -> void:
	score_label.visible = true
	high_score_label.visible = true
	lives_label.visible = true
	minimap.visible = true
	
	_instantiate_mobile_controls()
	
	# Smooth cinematic fade transition on level load
	status_overlay.fade_in_from_black()
	
	# Instruct LevelManager to assemble the 3D map
	call_deferred("emit_start_game_signal")

func emit_start_game_signal() -> void:
	start_game.emit()

# Public API used by LevelManager to hide loader once 3D world is built
func hide_status_overlay() -> void:
	if status_overlay:
		status_overlay.hide_status()

# --- NOTIFICATION SIGNAL CALLBACKS ---

func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE\n%06d" % new_score

func _on_high_score_changed(new_high_score: int) -> void:
	high_score_label.text = "HI-SCORE\n%06d" % new_high_score

func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "LIVES\n%d" % new_lives

func _on_game_over() -> void:
	var msg = "GAME OVER\nTap to Restart" if is_mobile else "GAME OVER\nPress R to Restart"
	status_overlay.show_status(msg, false)
	get_tree().paused = true

func _on_victory_transition() -> void:
	var next_level_idx : int = GameManager.current_level + 1
	var msg = "LEVEL CLEARED!\nPREPARING LEVEL %02d..." % next_level_idx if GameManager.has_next_level() else "VICTORY!\nLOADING FINALE CREDITS..."
	status_overlay.show_status(msg, false)

# Global Scene Restart Inputs
func _input(event: InputEvent) -> void:
	var is_restart_triggered = false
	
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_R and status_overlay.is_active():
			is_restart_triggered = true
		elif event.keycode == KEY_N and not status_overlay.is_active():
			if GameManager: GameManager.victory.emit() # Cheat key
			
	elif event is InputEventScreenTouch and event.pressed and status_overlay.is_active():
		is_restart_triggered = true
			
	if is_restart_triggered:
		get_tree().paused = false
		if GameManager: GameManager.reset_game()
		get_tree().reload_current_scene()

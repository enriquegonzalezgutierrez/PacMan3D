# ==============================================================================
# Description: HUD and Tournament UI Orchestrator. 
#              Responsible for updating gameplay indicators, the 2D Minimap, 
#              and managing the classic arcade letter-wheel initials input 
#              and Top 5 Leaderboard display on Game Over.
#              SOLID Refactoring:
#              - SRP Compliance: Coordinates independent sub-views (Minimap, 
#                StatusOverlay, LetterEntryWheel, MainMenu) without containing 
#                any physics, sorting, or data packing logic itself.
#              - DIP Compliance: Submits data and receives state signals through 
#                abstract public APIs and event bindings.
#              - Input State Clamping: Tracks game over states explicitly to prevent 
#                accidental touchscreen taps during victory transitions from 
#                triggering Partida Reset and level rollbacks.
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

# Internal State Tracking to prevent victory transition touch conflicts
var is_game_over_active : bool = false

func _ready() -> void:
	# Enforce HUD processing during pause states (Game Over blocks physics but not UI)
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web")
	is_game_over_active = false
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_build_hud_elements()
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
func _build_hud_elements() -> void:
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
		var bottom_margin = -280 
		minimap.offset_top = -map_dim + bottom_margin
		minimap.offset_bottom = bottom_margin
	else:
		var bottom_margin = -32 
		minimap.offset_top = -map_dim + bottom_margin
		minimap.offset_bottom = bottom_margin

func _instantiate_status_overlay() -> void:
	status_overlay = StatusOverlay.new()
	add_child(status_overlay)
	move_child(status_overlay, -1)

func _instantiate_main_menu() -> void:
	main_menu = MainMenu.new()
	add_child(main_menu)
	main_menu.start_game_requested.connect(_on_menu_start_game_requested)
	move_child(status_overlay, -1)

func _instantiate_mobile_controls() -> void:
	if not is_mobile: return
	
	mobile_controls = VirtualJoystick.new()
	add_child(mobile_controls)
	
	var viewport_size = get_viewport_rect().size
	mobile_controls.position = Vector2(100.0, viewport_size.y - 420.0)
	
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

func _on_menu_start_game_requested() -> void:
	if GameManager:
		GameManager.is_game_started = true
		
	status_overlay.show_status("GENERATING SYSTEM...\nPLEASE WAIT", true)
	await get_tree().create_timer(0.05).timeout
	_start_active_gameplay_ui()

func _start_active_gameplay_ui() -> void:
	score_label.visible = true
	high_score_label.visible = true
	lives_label.visible = true
	minimap.visible = true
	is_game_over_active = false
	
	_instantiate_mobile_controls()
	status_overlay.fade_in_from_black()
	call_deferred("emit_start_game_signal")

func emit_start_game_signal() -> void:
	start_game.emit()

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


# --- TOURNAMENT GAME OVER WORKFLOW (SOLID Integration) ---

func _on_game_over() -> void:
	# Enable game over state to allow inputs
	is_game_over_active = true
	
	# Check if the score qualifies for the local Top 5
	if GameManager and GameManager.qualifies_for_leaderboard():
		_instantiate_letter_entry_wheel()
	else:
		_show_tournament_leaderboard_overlay()

# Programmatically configures and attaches the LetterEntryWheel modal
func _instantiate_letter_entry_wheel() -> void:
	var wheel = LetterEntryWheel.new()
	add_child(wheel)
	wheel.initials_submitted.connect(_on_initials_submitted)
	
	# Push behind status overlay so it is clean but ahead of HUD labels
	move_child(wheel, get_child_count() - 2)

# Callback: Submits high score, updates records, and triggers leaderboard overlay
func _on_initials_submitted(initials: String) -> void:
	if GameManager:
		GameManager.submit_leaderboard_entry(initials)
	
	_show_tournament_leaderboard_overlay()

# Formats and displays the Top 5 High Score Board on the StatusOverlay
func _show_tournament_leaderboard_overlay() -> void:
	var board_text = "TOURNAMENT LEADERBOARD\n"
	board_text += "======================\n\n"
	
	if GameManager and not GameManager.leaderboard_cache.is_empty():
		var idx = 1
		for entry in GameManager.leaderboard_cache:
			# Monospaced-style tabulator spacing using pad_zeros for immaculate look
			board_text += "%d.  %-4s   %06d\n" % [idx, entry["name"], entry["score"]]
			idx += 1
	else:
		board_text += "No records loaded.\n"
		
	board_text += "\n\n"
	board_text += "Tap to Restart" if is_mobile else "Press R to Restart"
	
	status_overlay.show_status(board_text, false)
	get_tree().paused = true # Safely freeze the execution loop now

func _on_victory_transition() -> void:
	# Ensure the transition is protected from accidental touchscreen inputs
	is_game_over_active = false
	
	var next_level_idx : int = GameManager.current_level + 1
	var msg = "LEVEL CLEARED!\nPREPARING LEVEL %02d..." % next_level_idx if GameManager.has_next_level() else "VICTORY!\nLOADING FINALE CREDITS..."
	status_overlay.show_status(msg, false)

# Global Scene Restart Inputs
func _input(event: InputEvent) -> void:
	var is_restart_triggered = false
	
	if event is InputEventKey and event.is_pressed():
		# 1. PC: Allow restart only if we are in a true Game Over state (and not in victory transition)
		if event.keycode == KEY_R and status_overlay.is_active() and is_game_over_active:
			is_restart_triggered = true
		elif event.keycode == KEY_N and not status_overlay.is_active():
			if GameManager: GameManager.victory.emit() # Cheat key
			
	# 2. Android: Tap to restart allowed ONLY when game over state is active
	elif event is InputEventScreenTouch and event.pressed and status_overlay.is_active() and is_game_over_active:
		is_restart_triggered = true
			
	if is_restart_triggered:
		get_tree().paused = false
		is_game_over_active = false
		if GameManager: GameManager.reset_game()
		get_tree().reload_current_scene()

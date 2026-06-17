# ==============================================================================
# Description: HUD and Main Menu manager. Programmatically constructs the full
#              main menu, styled retro HUD nodes, and coordinates dynamic 
#              progression screen overlays.
#              Phase 2 Updates:
#              - AUTOMATED PROGRESSION COMPLIANCE: Connected GameManager's victory 
#                signal to display an elegant "LEVEL CLEARED! LOADING..." overlay 
#                during the 2-second transition, preventing freeze illusions.
#              - FULL HD SCALING: Re-proportioned all typography, offsets, buttons, 
#                and panel sizes (Minimap increased to 280x280, titles to 110px, 
#                and HUD indicators to 42px) to look majestic on 1080p viewports.
#              Phase 3 Updates:
#              - HIGH-SCORE INDICATOR: Integrated a centralized, real-time updated 
#                high-score (HI-SCORE) display panel positioned symmetrically 
#                at the center-top of the screen.
#              - AUTOLOAD RACE CONDITION FIX: Synchronized HUD values directly 
#                with GameManager on startup to guarantee values are printed 
#                immediately when the game starts.
#              Phase 4 Updates:
#              - WILD RIFT STYLE JOYSTICK: Replaced the rigid 4-button D-Pad with a 
#                procedural, multi-touch 360-degree analog Virtual Joystick.
#              - MASSIVE CONTROL SCALING: Increased Joystick diameter to 320px 
#                (knob 130px) and JUMP button to 220px to ensure premium ergonomic 
#                comfort and accessibility on high-DPI modern mobile viewports.
#              - SYSTEM GENERATION LOADING OVERLAY: Added hide_status_overlay() API 
#                and deferred frame yielding (await process_frame) to force Godot 
#                to render the "PLEASE WAIT" banner before blocking the thread to build.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name HUD

# Signals to notify coordinators of game start (DIP Compliance)
signal start_game()

# HUD Components
var score_label : Label
var high_score_label : Label # Phase 3 Record Label
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

# Mobile Virtual Controls (Phase 4)
var mobile_controls_container : Control
var is_mobile : bool = false

# Cinematic transition variables
var fade_overlay : ColorRect
var fade_alpha : float = 1.0

func _ready() -> void:
	# Enforce HUD processing during pause states (captures inputs globally)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web")
	
	_build_hud_elements()
	_build_mobile_controls()
	
	# Setup scene load fade-in effect
	fade_alpha = 1.0
	
	# Listen for progression, records and fail-state transitions globally (DIP Compliance)
	if GameManager:
		GameManager.game_over.connect(_on_game_over)
		GameManager.victory.connect(_on_victory_transition_triggered)
		GameManager.high_score_changed.connect(_on_high_score_changed)
		
		# --- AUTOLOAD RACE CONDITION FIX (Phase 3) ---
		_on_score_changed(GameManager.score)
		_on_high_score_changed(GameManager.high_score)
		_on_lives_changed(GameManager.lives)
	
	if GameManager and GameManager.is_game_started:
		# Automate gameplay startup on progression reload (completely bypasses main menu)
		score_label.visible = true
		high_score_label.visible = true
		lives_label.visible = true
		if not is_mobile:
			minimap.visible = true
		if is_instance_valid(mobile_controls_container):
			mobile_controls_container.visible = true
			
		call_deferred("emit_start_game_signal")
	else:
		# Fresh game boot: construct the main menu overlay normally
		_build_main_menu()

func _process(delta: float) -> void:
	# Smoothly fade out the black screen overlay on scene load (procedural juice)
	if is_instance_valid(fade_overlay) and fade_overlay.visible:
		fade_alpha -= delta * 1.5 # Fades out in exactly 0.6 seconds
		if fade_alpha <= 0.0:
			fade_overlay.visible = false
			fade_overlay.queue_free()
		else:
			fade_overlay.color.a = fade_alpha

# Defer start_game signal until the current frame's node mutations are fully processed
func emit_start_game_signal() -> void:
	start_game.emit()

# Programmatically constructs the HUD layout tree
func _build_hud_elements() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 1. Score Label Setup (Arcade 1UP Style - Scaled for 1080p)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 42)
	score_label.add_theme_constant_override("outline_size", 10)
	score_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 1.0)) # Retro Blue Outline
	score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0)) # White score
	score_label.visible = false
	add_child(score_label)
	
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	score_label.offset_left = 64
	score_label.offset_top = 64
	
	# 2. High-Score Label Setup (Centralized Symmetrical Arcade Style - Phase 3)
	high_score_label = Label.new()
	high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	high_score_label.add_theme_font_size_override("font_size", 42)
	high_score_label.add_theme_constant_override("outline_size", 10)
	high_score_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 1.0)) # Retro Blue Outline
	high_score_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0)) # Vibrant Gold Record
	high_score_label.visible = false
	add_child(high_score_label)
	
	high_score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	high_score_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	high_score_label.offset_top = 64
	
	# 3. Lives Label Setup (Symmetric Stacked Style - Scaled for 1080p)
	lives_label = Label.new()
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lives_label.add_theme_font_size_override("font_size", 42)
	lives_label.add_theme_constant_override("outline_size", 10)
	lives_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 1.0)) # Retro Blue Outline
	lives_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3)) # Vibrant Red Lives
	lives_label.visible = false
	add_child(lives_label)
	
	lives_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lives_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lives_label.offset_left = -450
	lives_label.offset_right = -64
	lives_label.offset_top = 64
	
	# 4. Minimap 2D Setup (Enlarged to 280x280 for Full HD readability)
	minimap = Minimap2D.new()
	minimap.map_size = Vector2(280, 280) # Sized up elegantly
	minimap.visible = false
	add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	minimap.offset_left = -304
	minimap.offset_top = -304
	minimap.offset_right = -24
	minimap.offset_bottom = -24
	
	# 5. Status Full-Screen Overlay
	status_overlay = ColorRect.new()
	status_overlay.color = Color(0.0, 0.0, 0.0, 0.75) 
	status_overlay.visible = false
	add_child(status_overlay)
	status_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 6. Status Text inside the overlay
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 54) # Large clear text
	status_overlay.add_child(status_label)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# 7. Fade Overlay Setup (Cinematic Transition - Sits on top of everything)
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0) # Start fully black
	add_child(fade_overlay)
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Procedurally builds the massive virtual analog stick and enlarged touch buttons (Phase 4)
func _build_mobile_controls() -> void:
	if not is_mobile:
		return
		
	mobile_controls_container = Control.new()
	mobile_controls_container.visible = false
	add_child(mobile_controls_container)
	mobile_controls_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var viewport_size = get_viewport_rect().size
	
	# 1. Instantiate the procedural 360-degree analog Virtual Joystick (Sized up massively to 320px)
	var joystick := VirtualJoystick.new()
	mobile_controls_container.add_child(joystick)
	
	# Position at bottom-left corner with comfortable thumb clearances
	joystick.position = Vector2(100.0, viewport_size.y - 420.0)
	
	# 2. Helper to procedurally generate a gorgeous, semi-transparent glowing circular touch texture for JUMP
	var create_touch_texture = func(color: Color, size_px: int) -> GradientTexture2D:
		var tex := GradientTexture2D.new()
		tex.width = size_px
		tex.height = size_px
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		
		var grad := Gradient.new()
		grad.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
		grad.offsets = PackedFloat32Array([0.75, 1.0])
		tex.gradient = grad
		return tex
		
	# Compile JUMP visual textures (Sized up massively to 220px)
	var jump_size_px : int = 220
	var normal_texture = create_touch_texture.call(Color(1.0, 1.0, 1.0, 0.35), jump_size_px) # Translucent White
	var pressed_texture = create_touch_texture.call(Color(1.0, 1.0, 0.0, 0.65), jump_size_px) # Glowing Yellow
	
	# 3. Instantiate the enlarged JUMP button
	var jump_btn = TouchScreenButton.new()
	jump_btn.action = "ui_select"
	jump_btn.texture_normal = normal_texture
	jump_btn.texture_pressed = pressed_texture
	
	var jump_label := Label.new()
	jump_label.text = "JUMP"
	jump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jump_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jump_label.add_theme_font_size_override("font_size", 34) # Larger readable text
	jump_label.add_theme_constant_override("outline_size", 10)
	jump_label.add_theme_color_override("font_outline_color", Color(0,0,0))
	
	jump_btn.add_child(jump_label)
	jump_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	mobile_controls_container.add_child(jump_btn)
	# Positioned symmetrically at the bottom-right corner
	jump_btn.position = Vector2(viewport_size.x - 320.0, viewport_size.y - 320.0)

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
	
	# --- STYLING BUTTON THEMES PROCEDURALLY (Sized up for Full HD touch/click target) ---
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = Color(0.3, 0.3, 0.3)
	style_normal.set_corner_radius_all(10)
	style_normal.content_margin_left = 48
	style_normal.content_margin_right = 48
	style_normal.content_margin_top = 18
	style_normal.content_margin_bottom = 18
	
	var style_focus_hover := StyleBoxFlat.new()
	style_focus_hover.bg_color = Color(0.18, 0.18, 0.0, 0.9) 
	style_focus_hover.border_width_left = 4
	style_focus_hover.border_width_top = 4
	style_focus_hover.border_width_right = 4
	style_focus_hover.border_width_bottom = 4
	style_focus_hover.border_color = Color(1.0, 1.0, 0.0) 
	style_focus_hover.set_corner_radius_all(10)
	style_focus_hover.content_margin_left = 48
	style_focus_hover.content_margin_right = 48
	style_focus_hover.content_margin_top = 18
	style_focus_hover.content_margin_bottom = 18
	
	# 3. Start Game Button (Sized up to 36px)
	start_button = Button.new()
	start_button.text = "START GAME"
	start_button.add_theme_font_size_override("font_size", 36)
	
	start_button.add_theme_stylebox_override("normal", style_normal)
	start_button.add_theme_stylebox_override("hover", style_focus_hover)
	start_button.add_theme_stylebox_override("focus", style_focus_hover) 
	start_button.add_theme_stylebox_override("pressed", style_focus_hover)
	
	start_button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	start_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.0))
	start_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.0))
	
	button_container.add_child(start_button)
	start_button.pressed.connect(_on_start_game_pressed)
	
	# 4. Exit Button (Hidden on iOS/Web where programmatic exit is blocked)
	if not OS.has_feature("web") and not OS.has_feature("ios"):
		exit_button = Button.new()
		exit_button.text = "EXIT"
		exit_button.add_theme_font_size_override("font_size", 32)
		
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
	
	# 5. Menu BGM Player
	menu_bgm = AudioStreamPlayer.new()
	menu_bgm.stream = load("res://assets/audio/bgm/main_menu_bgm.mp3")
	menu_bgm.volume_db = -8.0
	menu_bgm.autoplay = true
	add_child(menu_bgm)
	menu_bgm.play()

# Button Callback: Clears the menu overlays, starts BGM, and signals LevelManager to build map
func _on_start_game_pressed() -> void:
	if GameManager:
		GameManager.is_game_started = true
		
	if menu_bgm:
		menu_bgm.stop()
		menu_bgm.queue_free()
		
	if menu_bg:
		menu_bg.queue_free()
		
	score_label.visible = true
	high_score_label.visible = true
	lives_label.visible = true
	
	if not is_mobile:
		minimap.visible = true
	if is_instance_valid(mobile_controls_container):
		mobile_controls_container.visible = true
		
	# --- PHASE 4: INITIAL GENERATION LOADING SCREEN ---
	# Display a beautiful loading overlay before block generation triggers
	status_label.text = "GENERATING SYSTEM...\nPLEASE WAIT"
	status_overlay.visible = true
	
	# Force Godot to yield and physically render the loading overlay to the screen 
	# on PC and Mobile BEFORE starting the heavy 3D construction thread! (SRP/UX Compliance)
	await get_tree().process_frame
	
	start_game.emit()

# Public API to safely hide the status overlay once level building completes
func hide_status_overlay() -> void:
	if is_instance_valid(status_overlay):
		status_overlay.visible = false

# Stacked Score output zero-padded to 6 digits (Arcade standard)
func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE\n%06d" % new_score

# Dynamic High-Score output (Phase 3 compliance)
func _on_high_score_changed(new_high_score: int) -> void:
	high_score_label.text = "HI-SCORE\n%06d" % new_high_score

# Stacked Lives output
func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "LIVES\n%d" % new_lives

# Only triggers when all 3 lives are lost
func _on_game_over() -> void:
	var msg = "GAME OVER\nTap to Restart" if is_mobile else "GAME OVER\nPress R to Restart"
	status_label.text = msg
	status_overlay.visible = true
	get_tree().paused = true

# Displays a gorgeous neon status notification during the 2-second automated transition (Phase 2 Compliance)
func _on_victory_transition_triggered() -> void:
	var next_level_idx : int = GameManager.current_level + 1
	if GameManager.has_next_level():
		status_label.text = "LEVEL CLEARED!\nPREPARING LEVEL %02d..." % next_level_idx
	else:
		status_label.text = "VICTORY!\nLOADING FINALE CREDITS..."
		
	status_overlay.visible = true

# Listens for both physical keyboard events AND mobile screen touches
func _input(event: InputEvent) -> void:
	# Ignore input if status overlay isn't visible (unless cheating)
	var is_restart_triggered = false
	
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_R and status_overlay.visible:
			is_restart_triggered = true
		# RESTORE PC CHEAT KEY: Pressing 'N' emits victory globally (Phase 2 Compliance)
		elif event.keycode == KEY_N and not status_overlay.visible:
			if GameManager:
				GameManager.victory.emit()
			
	elif event is InputEventScreenTouch and event.pressed and status_overlay.visible:
		# On mobile, any tap during Game Over resets
		is_restart_triggered = true
			
	if is_restart_triggered:
		get_tree().paused = false
		if GameManager:
			GameManager.reset_game()
		get_tree().reload_current_scene()


# ==============================================================================
# --- PHASE 4: HELPER NESTED CLASS - PROSTHETIC VIRTUAL ANALOG JOYSTICK ---
# Programmatically draws and maps a 360-degree floating analog stick, simulating 
# standard key action presses inside the native Godot Input registry.
# ==============================================================================
class VirtualJoystick extends Control:
	var base_radius : float = 160.0 # Sized up significantly for 1080p high-DPI thumb comfort
	var knob_radius : float = 65.0 # Enlarged central knob
	var is_dragging : bool = false
	var touch_id : int = -1
	
	var base_center : Vector2
	var knob_pos : Vector2
	
	# Dict to monitor currently simulated pressed actions
	var simulated_actions : Dictionary = {
		"ui_left": false,
		"ui_right": false,
		"ui_up": false,
		"ui_down": false
	}
	
	func _ready() -> void:
		custom_minimum_size = Vector2(320, 320) # Sized up to match new base dimensions
		base_center = Vector2(160, 160)
		knob_pos = base_center
		
	func _draw() -> void:
		# 1. Draw Translucent Base ring
		draw_circle(base_center, base_radius, Color(0.08, 0.08, 0.1, 0.45))
		# Neon cyan thick border
		draw_arc(base_center, base_radius, 0, TAU, 32, Color(0.0, 0.8, 1.0, 0.6), 5.0)
		
		# 2. Draw Translucent Glowing Knob
		draw_circle(knob_pos, knob_radius, Color(1.0, 1.0, 0.0, 0.65)) # Glowing yellow
		# Orange neon border for high-contrast visibility
		draw_arc(knob_pos, knob_radius, 0, TAU, 24, Color(1.0, 0.5, 0.0, 0.8), 3.0)
		
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and not is_dragging:
				is_dragging = true
				touch_id = event.index
				_update_joystick_displacement(event.position)
			elif not event.pressed and event.index == touch_id:
				_reset_joystick_state()
				
		elif event is InputEventScreenDrag and is_dragging and event.index == touch_id:
			_update_joystick_displacement(event.position)
			
	# Calculates 2D offset vector and applies digital simulation mapping
	func _update_joystick_displacement(touch_pos: Vector2) -> void:
		var direction_vector : Vector2 = touch_pos - base_center
		var current_distance : float = direction_vector.length()
		
		# Clamp knob within physical outer base boundary
		if current_distance > base_radius:
			direction_vector = direction_vector.normalized() * base_radius
			
		knob_pos = base_center + direction_vector
		queue_redraw() # Request frame redraw instantly
		
		# Convert continuous analog vector to simulated action presses (0.35 Dead-zone)
		var normalized_ratio : Vector2 = direction_vector / base_radius
		
		_simulate_action("ui_left", normalized_ratio.x < -0.35)
		_simulate_action("ui_right", normalized_ratio.x > 0.35)
		_simulate_action("ui_up", normalized_ratio.y < -0.35)
		_simulate_action("ui_down", normalized_ratio.y > 0.35)
		
	# Restores knob to dead-center and releases all simulated keyboard bindings
	func _reset_joystick_state() -> void:
		is_dragging = false
		touch_id = -1
		knob_pos = base_center
		queue_redraw()
		
		for action in simulated_actions.keys():
			_simulate_action(action, false)
			
	# Safely commits Mock Input states directly into the native Godot Engine Registry
	func _simulate_action(action_name: String, should_press: bool) -> void:
		if simulated_actions[action_name] != should_press:
			simulated_actions[action_name] = should_press
			if should_press:
				Input.action_press(action_name)
			else:
				Input.action_release(action_name)

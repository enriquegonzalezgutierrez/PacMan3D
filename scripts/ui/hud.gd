# ==============================================================================
# Description: HUD manager. Programmatically sets up UI labels for score/lives,
#              overlays, and hosts an integrated responsive 2D Minimap.
#              SOLID Refactoring:
#              - SRP: Removed the inner Minimap2D class and delegated map
#                rendering to the external standalone Minimap2D class.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name HUD

var score_label : Label
var lives_label : Label
var status_overlay : ColorRect
var status_label : Label
var minimap : Minimap2D

func _ready() -> void:
	_build_hud_elements()
	
	# Connect to global GameManager signals safely
	if GameManager:
		GameManager.score_changed.connect(_on_score_changed)
		GameManager.lives_changed.connect(_on_lives_changed)
		GameManager.game_over.connect(_on_game_over)
		GameManager.victory.connect(_on_victory)
		
		# Pull initial data values directly on startup
		_on_score_changed(GameManager.score)
		_on_lives_changed(GameManager.lives)

# Programmatically constructs the layout tree using responsive anchors
func _build_hud_elements() -> void:
	# Make the main HUD control container fill the full screen rect
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 1. Score Label Setup (Top-Left corner preset)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 28)
	add_child(score_label)
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	score_label.offset_left = 24
	score_label.offset_top = 24
	
	# 2. Lives Label Setup (Top-Right corner preset with reverse text grow)
	lives_label = Label.new()
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lives_label.add_theme_font_size_override("font_size", 28)
	add_child(lives_label)
	
	lives_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lives_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lives_label.offset_left = -224
	lives_label.offset_right = -24
	lives_label.offset_top = 24
	
	# 3. Minimap 2D Setup (Instantiates standalone Minimap2D - SRP Compliance)
	minimap = Minimap2D.new()
	add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Size is 180x180 pixels with a 24px margin
	minimap.offset_left = -204
	minimap.offset_top = -204
	minimap.offset_right = -24
	minimap.offset_bottom = -24
	
	# 4. Status Full-Screen Overlay (Fades the screen on win or loss)
	status_overlay = ColorRect.new()
	status_overlay.color = Color(0.0, 0.0, 0.0, 0.75) # Semi-transparent black background
	status_overlay.visible = false
	add_child(status_overlay)
	status_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 5. Status Text inside the overlay (Centered)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 48)
	status_overlay.add_child(status_label)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status_label.grow_vertical = GROW_DIRECTION_BOTH

# Callback: Updates the text whenever points are scored
func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE: %d" % new_score

# Callback: Updates the life counter representation
func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "LIVES: %d" % new_lives

# Callback: Triggers when lives hit 0, pausing gameplay and prompting reset
func _on_game_over() -> void:
	status_label.text = "GAME OVER\nPress R to Restart"
	status_overlay.visible = true
	get_tree().paused = true

# Callback: Triggers when all pellets are cleared, pausing and prompting reset
func _on_victory() -> void:
	status_label.text = "VICTORY!\nPress R to Restart"
	status_overlay.visible = true
	get_tree().paused = true

# Listens for keyboard inputs to handle restarts
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_R and event.is_pressed():
		if status_overlay.visible:
			get_tree().paused = false
			if GameManager:
				GameManager.reset_game()
			get_tree().reload_current_scene()

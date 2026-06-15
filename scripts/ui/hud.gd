# ==============================================================================
# Description: HUD manager. Programmatically sets up UI labels for score/lives,
#              overlays, and hosts an integrated responsive 2D Minimap.
#              Fixes the half-cell offset calculation for perfect alignment.
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
	
	# 3. Minimap 2D Setup (Bottom-Right corner preset)
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


# ==============================================================================
# Inner Class: Procedural 2D Vectorial Minimap Node
# ==============================================================================
class Minimap2D extends Control:
	
	# Dimensions of the drawn minimap
	var map_size := Vector2(180, 180)
	
	func _ready() -> void:
		custom_minimum_size = map_size
		
	func _process(_delta: float) -> void:
		# Redraw every frame to update moving entity positions
		queue_redraw()
		
	func _draw() -> void:
		# Ensure we have active map data loaded in GameManager before drawing
		if not GameManager or GameManager.level_layout.is_empty():
			return
			
		var gw : float = float(GameManager.grid_width)
		var gh : float = float(GameManager.grid_height)
		
		var cell_w : float = map_size.x / gw
		var cell_h : float = map_size.y / gh
		
		# Draw semi-transparent background
		draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.0, 0.0, 0.0, 0.6))
		
		# 1. Draw Static Layout (Walls & Portals)
		for z in range(int(gh)):
			var row : Array = GameManager.level_layout[z]
			for x in range(int(gw)):
				var cell_type : int = int(row[x])
				var rect := Rect2(x * cell_w, z * cell_h, cell_w, cell_h)
				
				if cell_type == 1:
					# Draw blue wall blocks
					draw_rect(rect, Color(0.0, 0.0, 0.6))
				elif cell_type == 6 or cell_type == 7:
					# Draw portal locations in neon green
					draw_rect(rect, Color(0.0, 1.0, 0.2))
					
		# 3D to 2D coordinate converter Lambda
		# Precise math to map centered 3D coordinates back to 0-based grid indices and center them in 2D cell space
		var offset_x : float = (gw * 2.0 / 2.0) - 1.0 # Offset is 20.0
		var offset_z : float = (gh * 2.0 / 2.0) - 1.0 # Offset is 20.0
		
		var to_map = func(pos_3d: Vector3) -> Vector2:
			var grid_x : float = (pos_3d.x + offset_x) / 2.0
			var grid_z : float = (pos_3d.z + offset_z) / 2.0
			# Find the exact center point inside the 2D minimap cell
			var map_x = (grid_x + 0.5) * cell_w
			var map_y = (grid_z + 0.5) * cell_h
			return Vector2(map_x, map_y)
			
		# 2. Draw Pellets dynamically by querying their active nodes
		var pellets = get_tree().get_nodes_in_group("pellets")
		for pellet in pellets:
			if is_instance_valid(pellet) and pellet is Node3D:
				var map_pos = to_map.call(pellet.global_position)
				
				if pellet.is_power_pellet:
					# Larger orange power pellets
					draw_circle(map_pos, 3.5, Color(1.0, 0.5, 0.0))
				else:
					# Small yellow standard pellets
					draw_circle(map_pos, 1.5, Color(1.0, 1.0, 0.0))
					
		# 3. Draw Player
		var player = get_tree().get_first_node_in_group("player") as Node3D
		if is_instance_valid(player):
			var map_pos = to_map.call(player.global_position)
			draw_circle(map_pos, 4.5, Color(1.0, 1.0, 0.0)) # Bright Yellow Pac-Man
			
		# 4. Draw Ghosts
		var ghosts = get_tree().get_nodes_in_group("ghosts")
		for ghost in ghosts:
			if is_instance_valid(ghost) and ghost is Node3D:
				var map_pos = to_map.call(ghost.global_position)
				var color := Color(1.0, 1.0, 1.0)
				
				if ghost is Ghost:
					if ghost.current_state == Ghost.State.FRIGHTENED:
						color = ghost.ghost_material.albedo_color
					else:
						match ghost.ghost_type:
							"Blinky": color = Color(1.0, 0.0, 0.0) # Red
							"Pinky": color = Color(1.0, 0.7, 0.8) # Pink
							"Inky": color = Color(0.0, 1.0, 1.0) # Cyan
							"Clyde": color = Color(1.0, 0.6, 0.0) # Orange
							
				draw_circle(map_pos, 4.0, color)

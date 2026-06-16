# ==============================================================================
# Description: Procedural 2D Vectorial Minimap Node.
#              Draws standard/power pellets, player, and ghosts based on 
#              their active positions mapped from 3D grid space.
#              SOLID Refactoring:
#              - DUCK-TYPING FIX: Updated the pellet rendering loop to safely 
#                verify properties ("is_power_pellet" in pellet) to prevent 
#                crashes when scanning custom utility items like IcePellets.
#              - ICE PELLET RADAR: Ice Pellets are now explicitly recognized and 
#                drawn as Cyan dots on the minimap for strategic visibility.
#              - SRP: Extracted into a standalone class.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name Minimap2D

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
			elif cell_type == 6 or cell_type == 7 or cell_type == 8 or cell_type == 9:
				# Draw portal locations in neon green
				draw_rect(rect, Color(0.0, 1.0, 0.2))
				
	# 3D to 2D coordinate converter Lambda
	# Precise math to map centered 3D coordinates back to 0-based grid indices
	var offset_x : float = (gw * 2.0 / 2.0) - 1.0 
	var offset_z : float = (gh * 2.0 / 2.0) - 1.0 
	
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
			
			# Safely check object types to avoid duck-typing crashes (LSP Compliance)
			if pellet is IcePellet:
				# Ice Pellets drawn as Cyan dots
				draw_circle(map_pos, 3.5, Color(0.0, 0.8, 1.0))
			elif "is_power_pellet" in pellet and pellet.is_power_pellet:
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
				# Safely query the active material depending on the ghost's current state
				var active_mat = ghost.frightened_material if ghost.current_state == Ghost.State.FRIGHTENED else ghost.original_material
				if active_mat:
					color = active_mat.albedo_color
						
			draw_circle(map_pos, 4.0, color)

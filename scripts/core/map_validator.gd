# ==============================================================================
# Description: Refactored Map Validation Engine. Dedicated exclusively to 
#              analysing grid topology, checking 2x2 hollow plazas, flood-fill 
#              connectivity, and dead-ends.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted entirely from LevelManager to isolate 
#                validation metrics from procedural 3D rendering and spawning.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name MapValidator

# Constant matching the physical map scale
const CELL_SIZE : float = 2.0

# Performs exhaustive structural and topological validation of the map array
static func validate_map(layout: Array, width: int, height: int) -> bool:
	# 1. TEST FOR HOLLOW PLAZAS: Scans the grid for any 2x2 empty rooms
	for z in range(height - 1):
		for x in range(width - 1):
			if layout[z][x] != 1 and layout[z][x+1] != 1 and layout[z+1][x] != 1 and layout[z+1][x+1] != 1:
				# Allow exception ONLY inside the Ghost House Foso (rows 11-17, cols 11-18)
				if z >= 11 and z <= 17 and x >= 11 and x <= 18:
					continue
				push_error("MAP ERROR: Large hollow plaza (2x2 or larger) detected at row %d, col %d!" % [z, x])
				_print_error_context(layout, x, z, width, height)
				return false

	# 2. FLOOD FILL CONNECTIVITY TEST: Performs BFS to ensure no pocket regions or blocked corridors exist
	var start_pos := Vector2i(-1, -1)
	var total_walkable_cells : int = 0
	
	for z in range(height):
		for x in range(width):
			if layout[z][x] != 1:
				total_walkable_cells += 1
				if layout[z][x] == 4: # Player Spawn Point
					start_pos = Vector2i(x, z)
					
	if start_pos == Vector2i(-1, -1):
		push_error("MAP ERROR: Player Spawn point (4) not found in the grid matrix!")
		return false
		
	var visited := {}
	var queue : Array[Vector2i] = [start_pos]
	visited[start_pos] = true
	var reachable_count : int = 0
	
	while not queue.is_empty():
		var curr : Vector2i = queue.pop_front()
		reachable_count += 1
		
		var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		for d in dirs:
			var next_cell = curr + d
			
			# Wrap portals around for the connectivity check bounds
			if next_cell.x < 0: next_cell.x = width - 1
			if next_cell.x >= width: next_cell.x = 0
			if next_cell.y < 0: next_cell.y = height - 1
			if next_cell.y >= height: next_cell.y = 0
			
			if layout[next_cell.y][next_cell.x] != 1 and not visited.has(next_cell):
				visited[next_cell] = true
				queue.append(next_cell)
				
	if reachable_count != total_walkable_cells:
		push_error("MAP ERROR: Inaccessible paths or dead regions found! Reachable: %d, Total Walkable: %d" % [reachable_count, total_walkable_cells])
		return false

	# 3. TEST FOR DEAD ENDS: Verifies every single lane tile forms looping paths
	for z in range(1, height - 1):
		for x in range(1, width - 1):
			if layout[z][x] != 1:
				# Skip the foso spawn points
				if layout[z][x] == 5:
					continue
				var open_neighbors : int = 0
				var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
				for d in dirs:
					if layout[z + d.y][x + d.x] != 1:
						open_neighbors += 1
				if open_neighbors <= 1:
					push_error("MAP ERROR: Dead end lane detected at row %d, col %d!" % [z, x])
					_print_error_context(layout, x, z, width, height)
					return false

	print("MAP VALIDATOR SUCCESSFUL: 100% Connected, No Plazas, No Dead Ends!")
	return true

# Helper method to print a gorgeous 3x3 text-art context map centered at the error coordinate
static func _print_error_context(layout: Array, center_x: int, center_z: int, width: int, height: int) -> void:
	var context_string := "\n--- MAP ERROR VISUAL CONTEXT (Centered at Row %d, Col %d) ---\n" % [center_z, center_x]
	
	# Scans the surrounding 3x3 tiles
	for z in range(max(0, center_z - 1), min(height, center_z + 3)):
		var line := "Row %02d:  " % z
		for x in range(max(0, center_x - 1), min(width, center_x + 3)):
			var cell : int = int(layout[z][x])
			var cell_char : String = "W" if cell == 1 else str(cell)
			
			# Enclose the exact offending tile inside brackets for instant visual identification
			if z == center_z and x == center_x:
				line += "[%s]" % cell_char
			else:
				line += " %s " % cell_char
		context_string += line + "\n"
		
	context_string += "------------------------------------------------------------------"
	push_error(context_string)

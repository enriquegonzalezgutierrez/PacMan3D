# ==============================================================================
# Description: Parses the level JSON file, feeds the layout data to the global
#              GameManager, and generates the 3D grid of Pac-Man entities.
#              SOLID Refactoring & Fixes:
#              - MULTI-STYLE PROCEDURAL THEMING: Reads the "rendering_style" 
#                property from the JSON file and procedurally builds the walls 
#                using three distinct mesh layouts (Pipes, Blocks, or Pillars).
#              - DYNAMIC LEVEL COLORS: Reads the "wall_color" hex code from the 
#                JSON file and dynamically tints the pipe materials per level.
#              - DI Container: Preloads and injects player_death.mp3 and BGM.
#              - Map Expansion (OCP): Support added for vertical portals.
#              - Pac-Mania Connected Pipes: Connected cylindrical rails.
#              - Map Quality Validator: Strict mathematical validation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node3D
class_name LevelManager

const CELL_SIZE : float = 2.0
const WALL_HEIGHT : float = 2.0

# Preloaded Audio Resources (DIP Compliance)
var waka_audio_stream : AudioStream = preload("res://assets/audio/sfx/waka_waka.mp3")
var death_audio_stream : AudioStream = preload("res://assets/audio/sfx/player_death.mp3")
var ghost_eaten_audio_stream : AudioStream = preload("res://assets/audio/sfx/ghost_eaten.mp3") 
var bgm_stream : AudioStream = preload("res://assets/audio/bgm/level_1_bgm.mp3") 

# Centralized Materials (SRP Compliance)
var wall_material : StandardMaterial3D
var player_material : StandardMaterial3D
var ghost_frightened_material : StandardMaterial3D
var ghost_materials : Dictionary = {} 

var ghost_types : Array[String] = ["Blinky", "Pinky", "Inky", "Clyde"]
var spawned_ghosts_count : int = 0

var level_data : Dictionary = {}
var map_offset_x : float = 0.0
var map_offset_z : float = 0.0

# Injected entity tracking (SRP Compliance)
var player_instance : Player = null
var bgm_player : AudioStreamPlayer = null

# List to temporarily store portal nodes for the linking pass
var portals_to_link : Array[Dictionary] = []

func _ready() -> void:
	_initialize_materials()
	_connect_game_manager_signals()
	_setup_bgm() 
	
	var hud = get_parent().get_node_or_null("HUD") as HUD
	if hud:
		hud.start_game.connect(_on_start_game)
	else:
		_on_start_game()

# Centralized visual resource creation
func _initialize_materials() -> void:
	# 1. Wall Material (Tube/Pipe Base - Color will be dynamically overwritten by JSON)
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.0, 0.0, 1.0) # Classic Blue default
	wall_material.roughness = 0.2
	wall_material.metallic = 0.1
	
	# 2. Player Material
	player_material = StandardMaterial3D.new()
	player_material.albedo_color = Color(1.0, 1.0, 0.0) # Yellow
	player_material.roughness = 0.1
	player_material.metallic = 0.1
	
	# 3. Ghost Frightened Material
	ghost_frightened_material = StandardMaterial3D.new()
	ghost_frightened_material.albedo_color = Color(0.0, 0.0, 1.0) # Solid Blue
	ghost_frightened_material.emission_enabled = true
	ghost_frightened_material.emission = Color(0.0, 0.2, 0.8) # Glowing neon blue
	
	# 4. Standard Ghost Materials
	var blinky_mat := StandardMaterial3D.new()
	blinky_mat.albedo_color = Color(1.0, 0.0, 0.0) # Red
	ghost_materials["Blinky"] = blinky_mat
	
	var pinky_mat := StandardMaterial3D.new()
	pinky_mat.albedo_color = Color(1.0, 0.7, 0.8) # Pink
	pinky_mat.roughness = 0.4
	ghost_materials["Pinky"] = pinky_mat
	
	var inky_mat := StandardMaterial3D.new()
	inky_mat.albedo_color = Color(0.0, 1.0, 1.0) # Cyan
	ghost_materials["Inky"] = inky_mat
	
	var clyde_mat := StandardMaterial3D.new()
	clyde_mat.albedo_color = Color(1.0, 0.6, 0.0) # Orange
	ghost_materials["Clyde"] = clyde_mat

# Connect LevelManager to receive global signal notifications
func _connect_game_manager_signals() -> void:
	if GameManager:
		GameManager.power_pellet_activated.connect(_on_power_pellet_activated)
		GameManager.player_killed.connect(_on_player_killed)

# Programmatically configures and plays the loop background music
func _setup_bgm() -> void:
	if bgm_stream:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.stream = bgm_stream
		bgm_player.volume_db = -12.0 
		bgm_player.autoplay = true
		add_child(bgm_player)
		bgm_player.play()

# Triggered dynamically when the player clicks START GAME in the HUD Menu
func _on_start_game() -> void:
	if _load_level_data("res://data/level_01.json"):
		_setup_bgm() 
		_build_environment() 

# Loads and parses the JSON level configuration, executing validations
func _load_level_data(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
		
	var file := FileAccess.open(file_path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(content)
	
	if error == OK:
		level_data = json.data
		var layout : Array = level_data.get("layout", [])
		var width : int = int(level_data.get("grid_width", 0))
		var height : int = int(level_data.get("grid_height", 0))
		
		# --- DYNAMIC COLOR INJECTION ---
		if level_data.has("wall_color"):
			wall_material.albedo_color = Color(level_data["wall_color"])
		
		# Validate the map design before spawning resources
		if not _validate_map(layout, width, height):
			push_error("LEVEL LOADING ABORTED: Map validation failed.")
			return false
			
		if GameManager:
			GameManager.level_layout = layout
			GameManager.grid_width = width
			GameManager.grid_height = height
			
		map_offset_x = (float(width) * CELL_SIZE) / 2.0
		map_offset_z = (float(height) * CELL_SIZE) / 2.0
		return true
	return false

# Symmetrical mathematical validator ensuring 100% interconnected corridors
func _validate_map(layout: Array, width: int, height: int) -> bool:
	# 1. TEST FOR HOLLOW PLAZAS
	for z in range(height - 1):
		for x in range(width - 1):
			if layout[z][x] != 1 and layout[z][x+1] != 1 and layout[z+1][x] != 1 and layout[z+1][x+1] != 1:
				# Allow exception ONLY inside the Ghost House Foso
				if z >= 11 and z <= 17 and x >= 11 and x <= 18:
					continue
				push_error("MAP ERROR: Large hollow plaza (2x2 or larger) detected at row %d, col %d!" % [z, x])
				_print_error_context(layout, x, z, width, height)
				return false

	# 2. FLOOD FILL CONNECTIVITY TEST
	var start_pos := Vector2i(-1, -1)
	var total_walkable_cells : int = 0
	
	for z in range(height):
		for x in range(width):
			if layout[z][x] != 1:
				total_walkable_cells += 1
				if layout[z][x] == 4: # Player Spawn
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

	# 3. TEST FOR DEAD ENDS
	for z in range(1, height - 1):
		for x in range(1, width - 1):
			if layout[z][x] != 1:
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

# Helper method to print text-art context map
func _print_error_context(layout: Array, center_x: int, center_z: int, width: int, height: int) -> void:
	var context_string := "\n--- MAP ERROR VISUAL CONTEXT (Centered at Row %d, Col %d) ---\n" % [center_z, center_x]
	
	for z in range(max(0, center_z - 1), min(height, center_z + 3)):
		var line := "Row %02d:  " % z
		for x in range(max(0, center_x - 1), min(width, center_x + 3)):
			var cell : int = int(layout[z][x])
			var cell_char : String = "W" if cell == 1 else str(cell)
			
			if z == center_z and x == center_x:
				line += "[%s]" % cell_char
			else:
				line += " %s " % cell_char
		context_string += line + "\n"
		
	context_string += "------------------------------------------------------------------"
	push_error(context_string)

# Iterates through the layout matrix and spawns the corresponding 3D entities
func _build_environment() -> void:
	var layout : Array = level_data.get("layout", [])
	for z in range(layout.size()):
		var row : Array = layout[z]
		for x in range(row.size()):
			var cell_type : int = int(row[x])
			var pos_x : float = (x * CELL_SIZE) - map_offset_x + (CELL_SIZE / 2.0)
			var pos_z : float = (z * CELL_SIZE) - map_offset_z + (CELL_SIZE / 2.0)
			var world_pos := Vector3(pos_x, 0.0, pos_z)
			
			match cell_type:
				1: _create_wall(world_pos, x, z) 
				2: _create_pellet(world_pos, false)
				3: _create_pellet(world_pos, true)
				4: _spawn_player(world_pos)
				5: _spawn_ghost(world_pos)
				6: _create_portal(world_pos, "Portal_A", "Portal_B")
				7: _create_portal(world_pos, "Portal_B", "Portal_A")
				8: _create_portal(world_pos, "Portal_C", "Portal_D") 
				9: _create_portal(world_pos, "Portal_D", "Portal_C") 

	for link_info in portals_to_link:
		var my_portal : Portal = link_info["portal"]
		var partner_portal = get_node_or_null(link_info["partner_name"]) as Portal
		if partner_portal:
			my_portal.initialize(partner_portal)

# Instantiates procedurally designed wall meshes depending on the active level theme
func _create_wall(pos: Vector3, x: int, z: int) -> void:
	var static_body := StaticBody3D.new()
	var rendering_style : String = level_data.get("rendering_style", "pipes")
	
	match rendering_style:
		"blocks":
			# STYLE A: Classic Solid Neon Arcade Cubes
			var block_mesh := BoxMesh.new()
			block_mesh.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
			
			var block_instance := MeshInstance3D.new()
			block_instance.mesh = block_mesh
			block_instance.material_override = wall_material
			block_instance.position.y = WALL_HEIGHT / 2.0
			static_body.add_child(block_instance)
			
		"pillars":
			# STYLE B: Retro-Futuristic Cylindrical Pillars topped with glowing spheres
			# 1. Main vertical column
			var pillar_mesh := CylinderMesh.new()
			pillar_mesh.top_radius = 0.4
			pillar_mesh.bottom_radius = 0.4
			pillar_mesh.height = WALL_HEIGHT
			pillar_mesh.radial_segments = 12
			
			var pillar_instance := MeshInstance3D.new()
			pillar_instance.mesh = pillar_mesh
			pillar_instance.material_override = wall_material
			pillar_instance.position.y = WALL_HEIGHT / 2.0
			static_body.add_child(pillar_instance)
			
			# 2. Glowing emissive sphere sitting exactly on top
			var sphere_mesh := SphereMesh.new()
			sphere_mesh.radius = 0.55
			sphere_mesh.height = 1.1
			
			var glowing_material := StandardMaterial3D.new()
			glowing_material.albedo_color = wall_material.albedo_color
			glowing_material.emission_enabled = true
			glowing_material.emission = wall_material.albedo_color * 0.6 # Moderate cyber glow
			
			var sphere_instance := MeshInstance3D.new()
			sphere_instance.mesh = sphere_mesh
			sphere_instance.material_override = glowing_material
			sphere_instance.position.y = WALL_HEIGHT
			static_body.add_child(sphere_instance)
			
		_: # "pipes" (Default)
			# STYLE C: connected cylindrical pipeline rails (Pac-Mania Style)
			var has_horizontal : bool = false
			var has_vertical : bool = false
			
			var layout : Array = level_data.get("layout", [])
			var width : int = int(level_data.get("grid_width", 0))
			var height : int = int(level_data.get("grid_height", 0))
			
			if x > 0 and int(layout[z][x - 1]) == 1: has_horizontal = true
			if x < width - 1 and int(layout[z][x + 1]) == 1: has_horizontal = true
			
			if z > 0 and int(layout[z - 1][x]) == 1: has_vertical = true
			if z < height - 1 and int(layout[z + 1][x]) == 1: has_vertical = true
			
			if not has_horizontal and not has_vertical:
				has_horizontal = true
				has_vertical = true
				
			var pipe_mesh := CylinderMesh.new()
			pipe_mesh.top_radius = 0.18 
			pipe_mesh.bottom_radius = 0.18
			pipe_mesh.height = CELL_SIZE 
			pipe_mesh.radial_segments = 12 
			
			var create_pipe = func(offset_y: float, is_horiz: bool) -> MeshInstance3D:
				var pipe_node := MeshInstance3D.new()
				pipe_node.mesh = pipe_mesh
				pipe_node.material_override = wall_material
				pipe_node.position.y = offset_y
				
				if is_horiz:
					pipe_node.rotation_degrees = Vector3(0.0, 0.0, 90.0)
				else:
					pipe_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)
					
				return pipe_node
				
			if has_horizontal:
				static_body.add_child(create_pipe.call(0.5, true))
				static_body.add_child(create_pipe.call(1.5, true))
				
			if has_vertical:
				static_body.add_child(create_pipe.call(0.5, false))
				static_body.add_child(create_pipe.call(1.5, false))
		
	# --- PHYSICAL COLLIDER (Identical across all 3 styles to guarantee consistent physics) ---
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(CELL_SIZE, 20.0, CELL_SIZE)
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = box_shape
	collision_shape.position.y = 10.0 
	static_body.add_child(collision_shape)
	
	static_body.position = pos
	add_child(static_body)

# Instantiates a standard or power pellet and connects its signals
func _create_pellet(pos: Vector3, is_power: bool) -> void:
	var pellet := Pellet.new()
	pellet.is_power_pellet = is_power
	pellet.position = pos
	pellet.position.y = 0.5
	
	pellet.eaten.connect(_on_pellet_eaten)
	add_child(pellet)
	
	if GameManager:
		GameManager.register_pellet()

func _spawn_player(pos: Vector3) -> void:
	player_instance = Player.new()
	player_instance.spawn_position = pos
	player_instance.position = pos
	
	player_instance.initialize(player_material, waka_audio_stream, death_audio_stream)
	player_instance.position.y = player_instance.get_spawn_height_offset()
	
	player_instance.death_completed.connect(_on_player_death_completed)
	add_child(player_instance)

func _spawn_ghost(pos: Vector3) -> void:
	var ghost := Ghost.new()
	
	var ghost_type : String = ghost_types[spawned_ghosts_count % ghost_types.size()]
	spawned_ghosts_count += 1
	
	ghost.position = pos
	
	var strategy : GhostBehavior
	match ghost_type:
		"Blinky": strategy = BlinkyBehavior.new()
		"Pinky": strategy = PinkyBehavior.new()
		"Inky": strategy = InkyBehavior.new()
		"Clyde": strategy = ClydeBehavior.new()
		_: strategy = GhostBehavior.new()
		
	var norm_mat : StandardMaterial3D = ghost_materials.get(ghost_type)
	var layout : Array = level_data.get("layout", [])
	var grid_w : int = int(level_data.get("grid_width", 0))
	var grid_h : int = int(level_data.get("grid_height", 0))
	
	ghost.initialize(ghost_type, strategy, norm_mat, ghost_frightened_material, layout, grid_w, grid_h, ghost_eaten_audio_stream)
	ghost.position.y = ghost.get_spawn_height_offset()
	
	ghost.player_caught.connect(_on_ghost_player_caught)
	add_child(ghost)

func _create_portal(pos: Vector3, my_name: String, partner_name: String) -> void:
	var portal := Portal.new()
	portal.name = my_name
	portal.position = pos
	portal.position.y = 0.8
	add_child(portal)
	
	portals_to_link.append({
		"portal": portal,
		"partner_name": partner_name
	})

func _spawn_floating_score(pos: Vector3) -> void:
	var score_text := FloatingScore3D.new()
	add_child(score_text)
	score_text.global_position = pos + Vector3(0.0, 1.2, 0.0)

# --- SIGNAL ROUTING & GAMEPLAY ORCHESTRATION ---

func _on_pellet_eaten(is_power: bool) -> void:
	if GameManager:
		if is_power:
			GameManager.add_score(40)
			GameManager.activate_power_pellet()
		GameManager.pellet_eaten()

func _on_ghost_player_caught(is_frightened: bool, catch_position: Vector3) -> void:
	if GameManager:
		if is_frightened:
			GameManager.add_score(200)
			_spawn_floating_score(catch_position)
		else:
			for ghost in get_tree().get_nodes_in_group("ghosts"):
				if ghost.has_method("set_frozen"):
					ghost.set_frozen(true)
					
			if bgm_player:
				bgm_player.stream_paused = true
					
			if player_instance:
				player_instance.die()

func _on_player_death_completed() -> void:
	if GameManager:
		GameManager.lose_life()

func _on_power_pellet_activated() -> void:
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if ghost.has_method("activate_frightened_mode"):
			ghost.activate_frightened_mode()

func _on_player_killed() -> void:
	if bgm_player:
		bgm_player.stream_paused = false
		
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if ghost.has_method("reset_to_base"):
			ghost.reset_to_base()

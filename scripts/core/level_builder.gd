# ==============================================================================
# Description: Procedural Level Assembler / 3D Mesh Factory. Hand-crafts 
#              materials, builds wall styles (Pipes, Blocks, Pillars), spawns 
#              gameplay entities, and links portals.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted all 3D visual generation, preloaded 
#                assets, and spawning logic out of LevelManager.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name LevelBuilder

const CELL_SIZE : float = 2.0
const WALL_HEIGHT : float = 2.0

# Preloaded Audio Resources (DIP Compliance)
var waka_audio_stream : AudioStream = preload("res://assets/audio/sfx/waka_waka.mp3")
var death_audio_stream : AudioStream = preload("res://assets/audio/sfx/player_death.mp3")
var ghost_eaten_audio_stream : AudioStream = preload("res://assets/audio/sfx/ghost_eaten.mp3")

# Centralized Materials
var wall_material : StandardMaterial3D
var player_material : StandardMaterial3D
var ghost_frightened_material : StandardMaterial3D
var ghost_materials : Dictionary = {}

var ghost_types : Array[String] = ["Blinky", "Pinky", "Inky", "Clyde"]
var spawned_ghosts_count : int = 0

var parent_node : Node3D = null
var portals_to_link : Array[Dictionary] = []

func _init(parent: Node3D) -> void:
	parent_node = parent
	_initialize_materials()

# Compiles and setups materials procedurally
func _initialize_materials() -> void:
	# 1. Wall Material
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.0, 0.0, 1.0) # Default Blue
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

# Main entry point to compile the 3D environment out of the level JSON data
func build(level_data: Dictionary) -> void:
	if not is_instance_valid(parent_node) or level_data.is_empty():
		return
		
	# Apply dynamic wall color if provided
	if level_data.has("wall_color"):
		wall_material.albedo_color = Color(level_data["wall_color"])
		
	var layout : Array = level_data.get("layout", [])
	var width : int = int(level_data.get("grid_width", 0))
	var height : int = int(level_data.get("grid_height", 0))
	
	var map_offset_x : float = (float(width) * CELL_SIZE) / 2.0
	var map_offset_z : float = (float(height) * CELL_SIZE) / 2.0
	
	for z in range(layout.size()):
		var row : Array = layout[z]
		for x in range(row.size()):
			var cell_type : int = int(row[x])
			var pos_x : float = (x * CELL_SIZE) - map_offset_x + (CELL_SIZE / 2.0)
			var pos_z : float = (z * CELL_SIZE) - map_offset_z + (CELL_SIZE / 2.0)
			var world_pos := Vector3(pos_x, 0.0, pos_z)
			
			match cell_type:
				1: _create_wall(world_pos, x, z, level_data) 
				2: _create_pellet(world_pos, false)
				3: _create_pellet(world_pos, true)
				4: _spawn_player(world_pos)
				5: _spawn_ghost(world_pos, level_data)
				6: _create_portal(world_pos, "Portal_A", "Portal_B")
				7: _create_portal(world_pos, "Portal_B", "Portal_A")
				8: _create_portal(world_pos, "Portal_C", "Portal_D") 
				9: _create_portal(world_pos, "Portal_D", "Portal_C") 

	# Link portals together statically once spawned
	for link_info in portals_to_link:
		var my_portal : Portal = link_info["portal"]
		var partner_portal = parent_node.get_node_or_null(link_info["partner_name"]) as Portal
		if partner_portal:
			my_portal.initialize(partner_portal)

# Instantiates procedurally designed wall meshes depending on the active level theme
func _create_wall(pos: Vector3, x: int, z: int, level_data: Dictionary) -> void:
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
		
	# --- PHYSICAL COLLIDER ---
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(CELL_SIZE, 20.0, CELL_SIZE)
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = box_shape
	collision_shape.position.y = 10.0 
	static_body.add_child(collision_shape)
	
	static_body.position = pos
	parent_node.add_child(static_body)

# Instantiates a standard or power pellet and connects its signals
func _create_pellet(pos: Vector3, is_power: bool) -> void:
	var pellet := Pellet.new()
	pellet.is_power_pellet = is_power
	pellet.position = pos
	pellet.position.y = 0.5
	
	# Link signal back to orchestrator (DIP Compliance)
	if parent_node.has_method("_on_pellet_eaten"):
		pellet.eaten.connect(parent_node._on_pellet_eaten)
		
	parent_node.add_child(pellet)
	
	if GameManager:
		GameManager.register_pellet()

func _spawn_player(pos: Vector3) -> void:
	var player_instance := Player.new()
	player_instance.spawn_position = pos
	player_instance.position = pos
	
	player_instance.initialize(player_material, waka_audio_stream, death_audio_stream)
	player_instance.position.y = player_instance.get_spawn_height_offset()
	
	# Set player reference dynamically on parent and link death logic
	if "player_instance" in parent_node:
		parent_node.player_instance = player_instance
		
	if parent_node.has_method("_on_player_death_completed"):
		player_instance.death_completed.connect(parent_node._on_player_death_completed)
		
	parent_node.add_child(player_instance)
	
	# Spawns independent Camera node (SRP Compliance)
	var camera := DioramaCamera.new()
	parent_node.add_child(camera)

func _spawn_ghost(pos: Vector3, level_data: Dictionary) -> void:
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
	
	# Link dynamic entity callback back to orchestrator (DIP Compliance)
	if parent_node.has_method("_on_ghost_player_caught"):
		ghost.player_caught.connect(parent_node._on_ghost_player_caught)
		
	parent_node.add_child(ghost)

func _create_portal(pos: Vector3, my_name: String, partner_name: String) -> void:
	var portal := Portal.new()
	portal.name = my_name
	portal.position = pos
	portal.position.y = 0.8
	parent_node.add_child(portal)
	
	portals_to_link.append({
		"portal": portal,
		"partner_name": partner_name
	})

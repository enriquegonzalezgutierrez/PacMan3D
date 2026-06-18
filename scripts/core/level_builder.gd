# ==============================================================================
# Description: Procedural Level Assembler / 3D Mesh Factory. Hand-crafts 
#              materials, builds wall styles (Pipes, Blocks, Pillars, Circuits), 
#              spawns gameplay entities, and links portals.
#              SOLID Refactoring:
#              - PROBABILISTIC SPAWNING: Added a 25% chance of spawning a strategic, 
#                frost-blue IcePellet instead of a standard Power Pellet, 
#                maximizing gameplay variety under OCP.
#              - PROCEDURAL LIGHTING: Dynamic OmniLight3D on pillars.
#              - PROCEDURAL WORLD ENVIRONMENT: Dynamically instantiates WorldEnvironment.
#              Phase 2 Updates:
#              - SATIN METALLIC WALLS: Re-engineered wall materials to use brushed 
#                satin metal properties (higher roughness, controlled metalness) 
#                to provide elegant sheen without distracting glare.
#              - CYBER AMBIENT LIGHTING: Configured soft cyber-blue ambient environment 
#                lighting to fill dark shadow corridors.
#              - ALIGNED DIRECTIONAL SUNLIGHT: Programmatically rotated the sunlight 
#                vector to point diagonally down-left-forward, matching the diorama 
#                camera's South-to-North viewport to produce optimal metal reflections.
#              - REFCOUNTED SIGNAL FIX: Removed invalid get_tree() deferred calls 
#                inside RefCounted builder, restoring direct signal bindings.
#              Phase 4 Updates:
#              - CYBER CIRCUITS THEME: Developed a fourth modular maze style ("circuits") 
#                featuring matte obsidian board panels wrapped with glowing, 
#                tint-matched holographic micro-conduits and nodes.
#              - CYBER SPAWN PODS: Instantiates color-matched high-tech glowing 
#                containment pads flat on the foso floor under each ghost's 
#                respective starting spawn coordinate.
#              - SOLID PHYSICAL BLACK FLOOR: Instantiates a massive, matte, deep-black 
#                floor plane underneath the maze to eliminate environmental glares 
#                and visual oversaturation in OpenGL / Compatibility rendering.
#              - WARNING FIX: Replaced obsolete 'specular' parameter with native 
#                Godot 4 'metallic_specular' to prevent engine remapping warnings.
#              - GLOSSY NEON TOY SHELLS (Visual Muddying Fix): Switched Player and 
#                ghost materials from heavy chrome metals to highly saturated, 
#                double-layered glossy toy plastic (0.05 metallic, 0.15 roughness, 
#                1.0 clearcoat) with a 30% cyber-glow emission. This guarantees 
#                vibrant, radiant, non-darkening primary colors under any light.
#              - CLEAN SIGNATURES: Removed unused offset parameters from 
#                _spawn_flat_dark_floor() to prevent compilation warnings.
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
	# 1. Wall Material (Elegant Brushed Satin Metal / Anodized Aluminum)
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.0, 0.0, 1.0) # Default Blue
	wall_material.roughness = 0.28 # Satin gloss, diffuses harsh reflections softly
	wall_material.metallic = 0.85 # Controlled metal look
	wall_material.metallic_specular = 0.5 # Natural specular reflection
	
	# 2. Player Material (Glossy Neon Yellow Toy - Saturated & Double-layered Clearcoat)
	player_material = StandardMaterial3D.new()
	player_material.albedo_color = Color(1.0, 1.0, 0.0) # Pure vibrant electric yellow
	player_material.roughness = 0.15 # Highly polished gloss
	player_material.metallic = 0.05 # Low metal prevents environment blackening
	player_material.clearcoat_enabled = true # Double-layer high-gloss glaze
	player_material.clearcoat = 1.0
	player_material.clearcoat_roughness = 0.08
	player_material.emission_enabled = true
	player_material.emission = Color(1.0, 0.9, 0.0) * 0.30 # 30% internal neon glow
	
	# 3. Ghost Frightened Material
	ghost_frightened_material = StandardMaterial3D.new()
	ghost_frightened_material.albedo_color = Color(0.0, 0.0, 1.0) # Solid Blue
	ghost_frightened_material.emission_enabled = true
	ghost_frightened_material.emission = Color(0.0, 0.2, 0.8) # Glowing neon blue
	
	# 4. Standard Ghost Materials (Glossy Neon Cyber Toys - 30% Emissive)
	var blinky_color := Color(1.0, 0.0, 0.15) # Saturated electric red
	var blinky_mat := StandardMaterial3D.new()
	blinky_mat.albedo_color = blinky_color
	blinky_mat.roughness = 0.15
	blinky_mat.metallic = 0.05
	blinky_mat.clearcoat_enabled = true
	blinky_mat.clearcoat = 1.0
	blinky_mat.clearcoat_roughness = 0.08
	blinky_mat.emission_enabled = true
	blinky_mat.emission = blinky_color * 0.32 # 32% cyber-glow emission
	ghost_materials["Blinky"] = blinky_mat
	
	var pinky_color := Color(1.0, 0.2, 0.6) # Saturated hot pink
	var pinky_mat := StandardMaterial3D.new()
	pinky_mat.albedo_color = pinky_color
	pinky_mat.roughness = 0.15
	pinky_mat.metallic = 0.05
	pinky_mat.clearcoat_enabled = true
	pinky_mat.clearcoat = 1.0
	pinky_mat.clearcoat_roughness = 0.08
	pinky_mat.emission_enabled = true
	pinky_mat.emission = pinky_color * 0.32
	ghost_materials["Pinky"] = pinky_mat
	
	var inky_color := Color(0.0, 0.9, 1.0) # Saturated electric cyan
	var inky_mat := StandardMaterial3D.new()
	inky_mat.albedo_color = inky_color
	inky_mat.roughness = 0.15
	inky_mat.metallic = 0.05
	inky_mat.clearcoat_enabled = true
	inky_mat.clearcoat = 1.0
	inky_mat.clearcoat_roughness = 0.08
	inky_mat.emission_enabled = true
	inky_mat.emission = inky_color * 0.32
	ghost_materials["Inky"] = inky_mat
	
	var clyde_color := Color(1.0, 0.5, 0.0) # Saturated solar orange
	var clyde_mat := StandardMaterial3D.new()
	clyde_mat.albedo_color = clyde_color
	clyde_mat.roughness = 0.15
	clyde_mat.metallic = 0.05
	clyde_mat.clearcoat_enabled = true
	clyde_mat.clearcoat = 1.0
	clyde_mat.clearcoat_roughness = 0.08
	clyde_mat.emission_enabled = true
	clyde_mat.emission = clyde_color * 0.32
	ghost_materials["Clyde"] = clyde_mat

# Main entry point to compile the 3D environment out of the level JSON data
func build(level_data: Dictionary) -> void:
	if not is_instance_valid(parent_node) or level_data.is_empty():
		return
		
	# Apply dynamic wall color if provided
	if level_data.has("wall_color"):
		wall_material.albedo_color = Color(level_data["wall_color"])
		
	# Set up the post-processing Bloom and Glow environment (SRP Compliance)
	_setup_world_environment()
		
	var layout : Array = level_data.get("layout", [])
	var width : int = int(level_data.get("grid_width", 0))
	var height : int = int(level_data.get("grid_height", 0))
	
	var map_offset_x : float = (float(width) * CELL_SIZE) / 2.0
	var map_offset_z : float = (float(height) * CELL_SIZE) / 2.0
	
	# --- SPAWN HIGH-QUALITY MATTE BLACK FLOOR (Phase 4 OpenGL Fix) ---
	_spawn_flat_dark_floor(width, height)
	
	# Gate tracking coordinates (Symmetric center-top doorway of foso)
	var gate_y : int = 12
	var gate_x : int = int(float(width) / 2.0)
	
	for z in range(layout.size()):
		var row : Array = layout[z]
		for x in range(row.size()):
			var cell_type : int = int(row[x])
			var pos_x : float = (x * CELL_SIZE) - map_offset_x + (CELL_SIZE / 2.0)
			var pos_z : float = (z * CELL_SIZE) - map_offset_z + (CELL_SIZE / 2.0)
			var world_pos := Vector3(pos_x, 0.0, pos_z)
			
			# Programmatically spawn the physical Ghost House laser barrier
			if x == gate_x and z == gate_y:
				_create_ghost_house_gate(world_pos)
			
			match cell_type:
				1: _create_wall(world_pos, x, z, level_data) 
				2: _create_pellet(world_pos, false)
				3:
					# balanced 60% power pellet, 20% ice pellet, 20% speed pellet split
					var rand_val : float = randf()
					if rand_val < 0.20:
						_create_ice_pellet(world_pos)
					elif rand_val < 0.40:
						_create_speed_pellet(world_pos)
					else:
						_create_pellet(world_pos, true)
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

# Programmatically configures and attaches a glowing post-processing Bloom world environment
func _setup_world_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env_res := Environment.new()
	
	# --- PHASE 2: CYBER AMBIENT LIGHT FILL (Optimized for OpenGL) ---
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.15, 0.15, 0.22) # Richer cyber blue fill to light metallic shadow sides
	env_res.ambient_light_energy = 1.0 # High-end ambient fill
	
	# Configure high-quality additive Bloom and Glow offsets (Toned down for stability)
	env_res.background_mode = Environment.BG_CLEAR_COLOR
	env_res.background_color = Color(0.01, 0.01, 0.02, 1.0) # Deep retro cyber navy space
	env_res.glow_enabled = true
	env_res.glow_intensity = 0.45 # Softer glowing transitions to eliminate shader lags
	env_res.glow_strength = 0.8
	env_res.glow_bloom = 0.10 # Controlled bloom margins
	env_res.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	world_env.environment = env_res
	parent_node.add_child(world_env)
	
	# --- RESTORED GLOBAL SUNLIGHT (Softened & Aligned with perspective) ---
	var main_node = parent_node.get_parent()
	if is_instance_valid(main_node):
		var dir_light = main_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if is_instance_valid(dir_light):
			dir_light.light_energy = 0.55 # Softened sun to prevent metallic hotspot glares in OpenGL
			dir_light.light_color = Color(1.0, 1.0, 1.0) 
			
			# --- ALIGN SUNLIGHT DIRECTION WITH DIORAMA CAMERA PERSPECTIVE ---
			dir_light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)

# Programmatically spawns a single, massive, dark-matte floor plane under the entire maze (OpenGL / Compatibility Fix)
func _spawn_flat_dark_floor(width: int, height: int) -> void:
	var floor_mesh := BoxMesh.new()
	# Covers the entire map area plus a safe 6-meter border safety margin
	floor_mesh.size = Vector3(float(width) * CELL_SIZE + 6.0, 0.1, float(height) * CELL_SIZE + 6.0)
	
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.01, 0.01, 0.02) # Deep, elegant cyber dark-blue/black floor
	floor_mat.roughness = 0.95 # Completely matte, eliminates any blinding reflections or glare
	floor_mat.metallic = 0.0
	floor_mat.metallic_specular = 0.1 # Fixed: Changed obsolete 'specular' to Godot 4 'metallic_specular'
	floor_mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = floor_mat
	floor_instance.position = Vector3(0.0, -0.05, 0.0) # Sits exactly flat on the floor level
	
	parent_node.add_child(floor_instance)

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
			glowing_material.emission = wall_material.albedo_color * 0.65 
			
			var sphere_instance := MeshInstance3D.new()
			sphere_instance.mesh = sphere_mesh
			sphere_instance.material_override = glowing_material
			sphere_instance.position.y = WALL_HEIGHT
			static_body.add_child(sphere_instance)
			
		"circuits":
			# STYLE D: Holographic Cyber Circuit Boards (Phase 4)
			# 1. Base Silicon Matte Panel (Obsidian Slate Color)
			var base_mesh := BoxMesh.new()
			base_mesh.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
			
			var dark_mat := StandardMaterial3D.new()
			dark_mat.albedo_color = Color(0.04, 0.04, 0.06) # Matte Obsidian black
			dark_mat.roughness = 0.8
			dark_mat.metallic = 0.3
			
			var base_instance := MeshInstance3D.new()
			base_instance.mesh = base_mesh
			base_instance.material_override = dark_mat
			base_instance.position.y = WALL_HEIGHT / 2.0
			static_body.add_child(base_instance)
			
			# 2. Glowing Holographic Circuit Tracks (Dynamic level tint color matched)
			var track_mat := StandardMaterial3D.new()
			track_mat.albedo_color = wall_material.albedo_color
			track_mat.emission_enabled = true
			track_mat.emission = wall_material.albedo_color * 0.8 # Cyber bloom emissive glow
			track_mat.roughness = 0.1
			
			# Horizontal wrapping data bus track
			var horiz_mesh := BoxMesh.new()
			horiz_mesh.size = Vector3(CELL_SIZE + 0.03, 0.08, CELL_SIZE + 0.03) # Protrudes slightly out
			
			var horiz_line := MeshInstance3D.new()
			horiz_line.mesh = horiz_mesh
			horiz_line.material_override = track_mat
			horiz_line.position.y = WALL_HEIGHT * 0.65 # Symmetrical top third line
			static_body.add_child(horiz_line)
			
			# Vertical Corner Nodes (Square pillars at the corners that connect continuous boards)
			var node_mesh := BoxMesh.new()
			node_mesh.size = Vector3(0.08, WALL_HEIGHT + 0.02, 0.08) # Protrudes outwards on X/Z
			
			var corner_offsets : Array[Vector3] = [
				Vector3(-CELL_SIZE/2.0, WALL_HEIGHT/2.0, -CELL_SIZE/2.0),
				Vector3(CELL_SIZE/2.0, WALL_HEIGHT/2.0, -CELL_SIZE/2.0),
				Vector3(-CELL_SIZE/2.0, WALL_HEIGHT/2.0, CELL_SIZE/2.0),
				Vector3(CELL_SIZE/2.0, WALL_HEIGHT/2.0, CELL_SIZE/2.0)
			]
			
			for offset in corner_offsets:
				var node_line := MeshInstance3D.new()
				node_line.mesh = node_mesh
				node_line.material_override = track_mat
				node_line.position = offset
				static_body.add_child(node_line)
			
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

# Programmatically constructs a physical one-way laser gate for the foso (Phase 3)
func _create_ghost_house_gate(pos: Vector3) -> void:
	var static_body := StaticBody3D.new()
	static_body.name = "GhostHouseGate"
	
	# Exists on Layer 4 (value 8) - Ghost House Gate
	static_body.collision_layer = 8
	static_body.collision_mask = 0 # Static bodies do not need to scan other masks
	
	# Collision box matches grid cell dimensions (CELL_SIZE x CELL_SIZE)
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = box_shape
	collision_shape.position.y = WALL_HEIGHT / 2.0
	static_body.add_child(collision_shape)
	
	# Procedural translucent cyber pink laser sheet (Visual Feedback)
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(CELL_SIZE, 0.05, CELL_SIZE) # Thin flat plate on floor
	mesh_instance.mesh = box_mesh
	
	var laser_mat := StandardMaterial3D.new()
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_mat.albedo_color = Color(1.0, 0.0, 1.0, 0.25) # Transparent magenta
	laser_mat.emission_enabled = true
	laser_mat.emission = Color(1.0, 0.0, 0.6) # Glowing neon pink
	mesh_instance.material_override = laser_mat
	mesh_instance.position.y = 0.025 # Sitting slightly above floor
	static_body.add_child(mesh_instance)
	
	static_body.position = pos
	parent_node.add_child(static_body)

# Programmatically constructs a high-tech glowing containment pad for a ghost (Phase 4)
func _create_ghost_spawn_pad(pos: Vector3, color: Color) -> void:
	var pad_holder := Node3D.new()
	
	# 1. Base Carbon Steel Platform Ring
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.65
	base_mesh.bottom_radius = 0.65
	base_mesh.height = 0.05
	base_mesh.radial_segments = 16
	
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.08, 0.08, 0.1) # Dark tech carbon
	base_mat.roughness = 0.6
	base_mat.metallic = 0.6
	
	var base_instance := MeshInstance3D.new()
	base_instance.mesh = base_mesh
	base_instance.material_override = base_mat
	base_instance.position.y = 0.025 # Flat with floor surface
	pad_holder.add_child(base_instance)
	
	# 2. Glowing Inner Ring (Emissive, dynamically color-matched to the spawning ghost)
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.55
	ring_mesh.bottom_radius = 0.55
	ring_mesh.height = 0.06 # Slightly taller to protrude elegantly
	ring_mesh.radial_segments = 16
	
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = color
	ring_mat.emission_enabled = true
	ring_mat.emission = color * 0.85 # Cyber glow ring
	
	var ring_instance := MeshInstance3D.new()
	ring_instance.mesh = ring_mesh
	ring_instance.material_override = ring_mat
	ring_instance.position.y = 0.03
	pad_holder.add_child(ring_instance)
	
	# 3. Secure Center Core pad where the capsule stands
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.25
	core_mesh.bottom_radius = 0.25
	core_mesh.height = 0.07
	core_mesh.radial_segments = 12
	
	var core_instance := MeshInstance3D.new()
	core_instance.mesh = core_mesh
	core_instance.material_override = base_mat
	core_instance.position.y = 0.035
	pad_holder.add_child(core_instance)
	
	pad_holder.position = pos
	pad_holder.position.y = 0.01 # Lays completely flat on foso floor surface
	parent_node.add_child(pad_holder)

# Instantiates a standard or power pellet and connects its signals
func _create_pellet(pos: Vector3, is_power: bool) -> void:
	var pellet := Pellet.new()
	pellet.is_power_pellet = is_power
	pellet.position = pos
	pellet.position.y = 0.5
	
	# Link signal back to orchestrator directly (DIP/Godot 4 Compliance)
	if parent_node.has_method("_on_pellet_eaten"):
		pellet.eaten.connect(parent_node._on_pellet_eaten)
		
	parent_node.add_child(pellet)
	
	if GameManager:
		GameManager.register_pellet()

# Instantiates the custom Frost-Blue Ice Pellet and connects its signals
func _create_ice_pellet(pos: Vector3) -> void:
	var ice_pellet := IcePellet.new()
	ice_pellet.position = pos
	ice_pellet.position.y = 0.5
	
	# Connect callback directly to LevelManager orchestrator directly (DIP/Godot 4 Compliance)
	if parent_node.has_method("_on_ice_pellet_eaten"):
		ice_pellet.ice_pellet_eaten.connect(parent_node._on_ice_pellet_eaten)
		
	parent_node.add_child(ice_pellet)
	
	if GameManager:
		GameManager.register_pellet()

# Instantiates the custom Lightning Bolt Speed Pellet and connects its signals (Phase 4)
func _create_speed_pellet(pos: Vector3) -> void:
	var speed_pellet := SpeedPellet.new()
	speed_pellet.position = pos
	speed_pellet.position.y = 0.5
	
	# Connect callback directly to LevelManager orchestrator (DIP Compliance)
	if parent_node.has_method("_on_speed_pellet_eaten"):
		speed_pellet.speed_pellet_eaten.connect(parent_node._on_speed_pellet_eaten)
		
	parent_node.add_child(speed_pellet)
	
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
	
	# --- SPAWN HIGH-TECH CONTAINMENT PAD (Phase 4) ---
	_create_ghost_spawn_pad(pos, norm_mat.albedo_color)
	
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

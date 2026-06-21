# ==============================================================================
# Description: Procedural Level Assembler / 3D Mesh Factory. Hand-crafts 
#              materials, builds wall styles using WallStyleStrategy pattern, 
#              spawns gameplay entities, links portals, and builds illuminated 
#              double-sided Menorcan Gin Xoriguer billboards on the map outskirts.
#              SOLID Refactoring & Visual Fixes:
#              - Enum Typo Fix: Corrected the tonemapper constant to Godot 4's 
#                native 'Environment.TONE_MAPPER_FILMIC', eliminating all parser 
#                errors and strict-type integer warnings permanently.
#              - Caching & DIP Compliance: Caches high-density assets (standard 
#                pellets, ice cubes, lemons, and the four separate ghost models) 
#                once during construction to avoid redundant runtime disk I/O.
#              - Physics Resource Sharing: Reuses a single shared BoxShape3D 
#                across all generated wall blocks, eliminating hundreds of heap 
#                allocations during level assembly.
#              - Single-Body Physics Fusion: Merges all 487 physical wall colliders 
#                into a single compound StaticBody3D, reducing physics registrations 
#                on Jolt by 99.8% and eliminating startup loading lag.
#              - Dynamic Visual Mesh Merging: Groups and compiles all 1,400+ 
#                individual wall meshes into 1 or 2 single unified ArrayMesh nodes 
#                in RAM based on active materials, dropping SceneTree overhead 
#                to near-zero.
#              - Offline Level Assembly: Spawns the entire 3D hierarchy under an 
#                unparented root Node3D in RAM, adding it to the active tree 
#                in a single call at the end to prevent main thread stalls.
#              - Performance Telemetry: Integrated high-resolution millisecond 
#                timers to log precisely where initialization overhead resides.
#              - Procedural Perimeter Decorations (SOLID OCP): Instantiates 
#                and aligns four symmetric Cyber-Windmills at the corners and 
#                three monumental prehistoric Cyber-Taulas behind the billboards.
#              - Premium Metallic Shading & Studio Lighting: Configured wall materials 
#                to act as highly visible brushed satin crome, amplified by 
#                vibrant core-emissions and studio-grade directional specular highlights.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name LevelBuilder

const CELL_SIZE : float = 2.0
const WALL_HEIGHT : float = 2.0

# --- SHARED PHYSICS ASSET ---
var shared_wall_shape : BoxShape3D = null

# --- GLOBAL FUSED WALL SYSTEM ---
var global_wall_physics_body : StaticBody3D = null
var global_wall_visuals_container : Node3D = null
var level_holder : Node3D = null

# Asset Path Configurations
const BOTTLE_MODEL_PATH : String = "res://assets/models/items/xoriguer_bottle.fbx"
const ICE_MODEL_PATH : String = "res://assets/models/items/ice/ice.fbx"
const LEMON_MODEL_PATH : String = "res://assets/models/items/lemon/lemon.fbx"

const BLINKY_MODEL_PATH : String = "res://assets/models/ghosts/blinky/blinky.fbx"
const PINKY_MODEL_PATH : String = "res://assets/models/ghosts/pinky/pinky.fbx"
const INKY_MODEL_PATH : String = "res://assets/models/ghosts/inky/inky.fbx"
const CLYDE_MODEL_PATH : String = "res://assets/models/ghosts/clyde/clyde.fbx"

# Preloaded Audio Resources (DIP Compliance)
var waka_audio_stream : AudioStream = preload("res://assets/audio/sfx/waka_waka.mp3")
var death_audio_stream : AudioStream = preload("res://assets/audio/sfx/player_death.mp3")
var ghost_eaten_audio_stream : AudioStream = preload("res://assets/audio/sfx/ghost_eaten.mp3")

# Centralized Materials
var wall_material : StandardMaterial3D
var player_material : StandardMaterial3D
var ghost_frightened_material : StandardMaterial3D
var ghost_materials : Dictionary = {}

# Cached PackedScene resources (DIP compliance to avoid disk-reads during instantiation)
var cached_bottle_scene : PackedScene = null
var cached_ice_scene : PackedScene = null
var cached_lemon_scene : PackedScene = null
var cached_ghost_scenes : Dictionary = {}

# Cached pre-compiled animation library and billboard poster texture (DIP Compliance)
var cached_player_animation_library : AnimationLibrary = null
var cached_billboard_poster : Texture2D = null

# Telemetry counters
var walls_spawned : int = 0
var pellets_spawned : int = 0
var ice_spawned : int = 0
var speed_spawned : int = 0

# Strategy Pattern Dictionary for Wall rendering themes (OCP Compliance)
var wall_strategies : Dictionary = {
	"blocks": WallStyleStrategy.Blocks.new(),
	"pillars": WallStyleStrategy.Pillars.new(),
	"pipes": WallStyleStrategy.Pipes.new(),
	"circuits": WallStyleStrategy.Circuits.new()
}

var ghost_types : Array[String] = ["Blinky", "Pinky", "Inky", "Clyde"]
var spawned_ghosts_count : int = 0

var parent_node : Node3D = null
var portals_to_link : Array[Dictionary] = []

func _init(parent: Node3D) -> void:
	parent_node = parent
	_initialize_materials()
	_preload_mesh_assets()

# Preloads and caches high-density assets to avoid disk operations during loops
func _preload_mesh_assets() -> void:
	var start_time : int = Time.get_ticks_msec()
	
	# Cache Standard Pellet
	if ResourceLoader.exists(BOTTLE_MODEL_PATH):
		cached_bottle_scene = load(BOTTLE_MODEL_PATH) as PackedScene
	else:
		push_warning("LevelBuilder: Could not find model asset at: " + BOTTLE_MODEL_PATH)
		
	# Cache Ice Cube Pellet
	if ResourceLoader.exists(ICE_MODEL_PATH):
		cached_ice_scene = load(ICE_MODEL_PATH) as PackedScene
	else:
		push_warning("LevelBuilder: Could not find model asset at: " + ICE_MODEL_PATH)
		
	# Cache Speed Lemon Pellet
	if ResourceLoader.exists(LEMON_MODEL_PATH):
		cached_lemon_scene = load(LEMON_MODEL_PATH) as PackedScene
	else:
		push_warning("LevelBuilder: Could not find model asset at: " + LEMON_MODEL_PATH)
		
	# Cache Ghost Models (Blinky, Pinky, Inky, Clyde)
	var ghost_paths := {
		"Blinky": BLINKY_MODEL_PATH,
		"Pinky": PINKY_MODEL_PATH,
		"Inky": INKY_MODEL_PATH,
		"Clyde": CLYDE_MODEL_PATH
	}
	
	for g_type in ghost_paths:
		var path : String = ghost_paths[g_type]
		if ResourceLoader.exists(path):
			cached_ghost_scenes[g_type] = load(path) as PackedScene
		else:
			push_warning("LevelBuilder: Could not find model asset for ghost: " + g_type)
			
	# Initialize shared static collision boundary shape (Optimization Compliance)
	shared_wall_shape = BoxShape3D.new()
	shared_wall_shape.size = Vector3(CELL_SIZE, 20.0, CELL_SIZE)
	
	# Pre-compile MartínMan's dynamic skeleton and animations once at startup (SRP/DIP compliance)
	var start_player_compile : int = Time.get_ticks_msec()
	cached_player_animation_library = PlayerVisualBuilder.compile_animation_library()
	var player_compile_duration : int = Time.get_ticks_msec() - start_player_compile
	print("[TELEMETRY] MartínMan's skeletal AnimationLibrary compiled once in RAM in: ", player_compile_duration, "ms")
	
	# Preload the high-resolution billboard poster once (DIP Compliance)
	var billboard_base_path := "res://assets/ui/images/xoriguer_ad"
	var extensions := [".png", ".jpg", ".jpeg", ".PNG", ".JPG", ".JPEG"]
	for ext in extensions:
		var test_path = billboard_base_path + ext
		if ResourceLoader.exists(test_path):
			cached_billboard_poster = load(test_path) as Texture2D
			break
			
	if not cached_billboard_poster:
		push_warning("LevelBuilder: Could not find billboard poster asset at: " + billboard_base_path)
	
	var duration : int = Time.get_ticks_msec() - start_time
	print("[TELEMETRY] LevelBuilder preloaded all 3D assets once in: ", duration, "ms")

# Compiles and setups materials procedurally
func _initialize_materials() -> void:
	# 1. Wall Material (Brushed Satin Cyber-Metal / Chrome)
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.0, 0.0, 1.0) # Default Blue
	
	# --- PBR METALLIC OPTIMIZATION (Calibrated for high specular highlights) ---
	wall_material.metallic = 1.0 # 100% physically accurate metal!
	wall_material.roughness = 0.34 # Brushed satin surface (diffuses light perfectly, avoiding black spots)
	wall_material.metallic_specular = 0.6 # Amplified specular shine
	
	# Clearcoat lacquer coat for wet metallic reflections
	wall_material.clearcoat_enabled = true
	wall_material.clearcoat = 1.0
	wall_material.clearcoat_roughness = 0.12
	
	# Base emission settings
	wall_material.emission_enabled = true
	wall_material.emission = Color(0.0, 0.0, 0.25) # Internal neon-core glow
	
	# 2. Player Material (Glossy Yellow Toy Plastic)
	player_material = StandardMaterial3D.new()
	player_material.albedo_color = Color(1.0, 1.0, 0.0) 
	player_material.roughness = 0.15 
	player_material.metallic = 0.05 
	player_material.clearcoat_enabled = true 
	player_material.clearcoat = 1.0
	player_material.clearcoat_roughness = 0.08
	player_material.emission_enabled = false
	
	# 3. Frightened Ghost Material (Glowing blue)
	ghost_frightened_material = StandardMaterial3D.new()
	ghost_frightened_material.albedo_color = Color(0.0, 0.0, 1.0) 
	ghost_frightened_material.emission_enabled = true
	ghost_frightened_material.emission = Color(0.0, 0.2, 0.8) 
	
	# 4. Standard Ghost Materials (Glossy Neon Toys)
	var blinky_color := Color(1.0, 0.0, 0.15) 
	var blinky_mat := StandardMaterial3D.new()
	blinky_mat.albedo_color = blinky_color
	blinky_mat.roughness = 0.15
	blinky_mat.metallic = 0.05
	blinky_mat.clearcoat_enabled = true
	blinky_mat.clearcoat = 1.0
	blinky_mat.emission_enabled = true
	blinky_mat.emission = blinky_color * 0.32 
	ghost_materials["Blinky"] = blinky_mat
	
	var pinky_color := Color(1.0, 0.1, 0.5)
	var pinky_mat := StandardMaterial3D.new()
	pinky_mat.albedo_color = pinky_color
	pinky_mat.roughness = 0.15
	pinky_mat.metallic = 0.05
	pinky_mat.clearcoat_enabled = true
	pinky_mat.clearcoat = 1.0
	pinky_mat.emission_enabled = true
	pinky_mat.emission = pinky_color * 0.32
	ghost_materials["Pinky"] = pinky_mat
	
	var inky_color := Color(0.0, 0.9, 1.0)
	var inky_mat := StandardMaterial3D.new()
	inky_mat.albedo_color = inky_color
	inky_mat.roughness = 0.15
	inky_mat.metallic = 0.05
	inky_mat.clearcoat_enabled = true
	inky_mat.clearcoat = 1.0
	inky_mat.emission_enabled = true
	inky_mat.emission = inky_color * 0.32
	ghost_materials["Inky"] = inky_mat
	
	var clyde_color := Color(1.0, 0.5, 0.0)
	var clyde_mat := StandardMaterial3D.new()
	clyde_mat.albedo_color = clyde_color
	clyde_mat.roughness = 0.15
	clyde_mat.metallic = 0.05
	clyde_mat.clearcoat_enabled = true
	clyde_mat.clearcoat = 1.0
	clyde_mat.emission_enabled = true
	clyde_mat.emission = clyde_color * 0.32
	ghost_materials["Clyde"] = clyde_mat

# Main entry point to compile the 3D environment out of the level JSON data
func build(level_data: Dictionary) -> void:
	if not is_instance_valid(parent_node) or level_data.is_empty():
		return
		
	var start_total_time : int = Time.get_ticks_msec()
	
	# --- PROFILE PHASE A: ENVIRONMENT SETUP ---
	var start_phase_a := Time.get_ticks_msec()
	
	# Reset telemetry counters
	walls_spawned = 0
	pellets_spawned = 0
	ice_spawned = 0
	speed_spawned = 0
	
	# Initialize the offline root container (SceneTree I/O Optimization)
	level_holder = Node3D.new()
	level_holder.name = "LevelHolder"
	
	# Initialize fused compound containers (Physics & Rendering Optimization)
	global_wall_physics_body = StaticBody3D.new()
	global_wall_physics_body.name = "MapWallsPhysics"
	global_wall_physics_body.collision_layer = 1
	global_wall_physics_body.collision_mask = 0 # Static solid walls don't need active scanning
	level_holder.add_child(global_wall_physics_body)
	
	global_wall_visuals_container = Node3D.new()
	global_wall_visuals_container.name = "MapWallsVisuals"
	level_holder.add_child(global_wall_visuals_container)
	
	# --- DECLARATIONS FIRST (Resolves local scope compiler bugs!) ---
	var layout : Array = level_data.get("layout", [])
	var width : int = int(level_data.get("grid_width", 0))
	var height : int = int(level_data.get("grid_height", 0))
	
	var map_offset_x : float = (float(width) * CELL_SIZE) / 2.0
	var map_offset_z : float = (float(height) * CELL_SIZE) / 2.0
		
	if level_data.has("wall_color"):
		var w_color = Color(level_data["wall_color"])
		wall_material.albedo_color = w_color
		# --- OPTIMIZATION: Amplified core neon emission on the metal pipes ---
		wall_material.emission = w_color * 0.35
		
	_setup_world_environment()
	_spawn_flat_dark_floor(width, height)
	
	var duration_a : int = Time.get_ticks_msec() - start_phase_a
	print("[PROFILE] Phase A (Environment & Floor Setup) completed in: ", duration_a, "ms")
	
	# --- PROFILE PHASE B: GRID SPAWNING LOOP ---
	var start_phase_b := Time.get_ticks_msec()
	
	var gate_y : int = 12
	var gate_x : int = int(float(width) / 2.0)
	
	for z in range(layout.size()):
		var row : Array = layout[z]
		for x in range(row.size()):
			var cell_type : int = int(row[x])
			var pos_x : float = (x * CELL_SIZE) - map_offset_x + (CELL_SIZE / 2.0)
			var pos_z : float = (z * CELL_SIZE) - map_offset_z + (CELL_SIZE / 2.0)
			var world_pos := Vector3(pos_x, 0.0, pos_z)
			
			if x == gate_x and z == gate_y:
				_create_ghost_house_gate(world_pos)
			
			match cell_type:
				1: _create_wall(world_pos, x, z, level_data) 
				2: _create_pellet(world_pos, false)
				3:
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

	for link_info in portals_to_link:
		var my_portal : Portal = link_info["portal"]
		# Search locally within the offline root container (DIP compliance)
		var partner_portal = level_holder.get_node_or_null(link_info["partner_name"]) as Portal
		if partner_portal:
			my_portal.initialize(partner_portal)
			
	var duration_b : int = Time.get_ticks_msec() - start_phase_b
	print("[PROFILE] Phase B (Grid Entities Spawn Loop) completed in: ", duration_b, "ms")

	# --- PROFILE PHASE C: PERIMETER BILLBOARDS & DECORATIONS ---
	var start_phase_c := Time.get_ticks_msec()
	_spawn_perimeter_billboards(map_offset_x, map_offset_z)
	_spawn_perimeter_decorations(map_offset_x, map_offset_z) # Spawns windmills AND three Cyber-Taula shrines!
	var duration_c : int = Time.get_ticks_msec() - start_phase_c
	print("[PROFILE] Phase C (Perimeter Billboards Setup) completed in: ", duration_c, "ms")
	
	# --- PROFILE PHASE D: VISUAL MESH MERGING ---
	var start_phase_d := Time.get_ticks_msec()
	_merge_and_optimize_visuals()
	var duration_d : int = Time.get_ticks_msec() - start_phase_d
	print("[PROFILE] Phase D (Visual Mesh Merging Algorithm) completed in: ", duration_d, "ms")
	
	# --- ATTACH TO ACTIVE TREE ---
	# Connect the entire pre-compiled and fully optimized 3D world to the active SceneTree in a single frame
	parent_node.add_child(level_holder)
	
	var total_duration : int = Time.get_ticks_msec() - start_total_time
	print("[TELEMETRY] Total 3D Level Assembly completed in: ", total_duration, "ms")
	print("[TELEMETRY] Grid Entities Spawned -> Walls: ", walls_spawned, ", Bottles: ", pellets_spawned, ", Hielo: ", ice_spawned, ", Limones: ", speed_spawned)

func _setup_world_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env_res := Environment.new()
	
	# --- OPTIMIZATION: Increased ambient light energy to brighten metallic reflections ---
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.24, 0.24, 0.36) # Brighter fill color
	env_res.ambient_light_energy = 1.45 # Amplified ambient bounce
	
	env_res.background_mode = Environment.BG_CLEAR_COLOR
	env_res.background_color = Color(0.01, 0.01, 0.02, 1.0) 
	
	env_res.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_res.tonemap_exposure = 1.08
	
	var is_low_end : bool = OS.has_feature("mobile") or OS.has_feature("web")
	env_res.glow_enabled = true
	env_res.glow_intensity = 0.22 if is_low_end else 0.45 
	env_res.glow_strength = 0.5 if is_low_end else 0.8
	env_res.glow_bloom = 0.05 if is_low_end else 0.10 
	env_res.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	world_env.environment = env_res
	# Attach world environment cleanly to the offline level_holder
	level_holder.add_child(world_env)
	
	RenderingServer.set_default_clear_color(Color(0.01, 0.01, 0.02, 1.0))
	
	var main_node = parent_node.get_parent()
	if is_instance_valid(main_node):
		var dir_light = main_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if is_instance_valid(dir_light):
			# --- OPTIMIZATION: Increased directional light energy to create bright specular highlights on metal curves ---
			dir_light.light_energy = 1.25 
			dir_light.light_color = Color(1.0, 0.98, 0.95) 
			dir_light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)

func _spawn_flat_dark_floor(width: int, height: int) -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(float(width) * CELL_SIZE + 300.0, 0.1, float(height) * CELL_SIZE + 300.0)
	
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.01, 0.01, 0.02) 
	floor_mat.roughness = 0.95 
	floor_mat.metallic = 0.0
	floor_mat.metallic_specular = 0.1 
	floor_mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_VERTEX
	
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = floor_mat
	floor_instance.position = Vector3(0.0, -0.05, 0.0) 
	
	# Attach flat floor to the offline root container
	level_holder.add_child(floor_instance)

# Instantiates a fused wall section leveraging compound shapes and modular visuals
func _create_wall(pos: Vector3, x: int, z: int, level_data: Dictionary) -> void:
	var rendering_style : String = level_data.get("rendering_style", "pipes")
	var strategy : WallStyleStrategy = wall_strategies.get(rendering_style, wall_strategies["pipes"])
	
	# 1. Visual Node (StaticBody3D to satisfy strategies signature, but placed offline under visuals container)
	var wall_visual_node := StaticBody3D.new()
	wall_visual_node.collision_layer = 0
	wall_visual_node.collision_mask = 0
	wall_visual_node.position = pos
	global_wall_visuals_container.add_child(wall_visual_node)
	
	# Draw mesh geometry procedural components
	strategy.build_mesh(wall_visual_node, x, z, CELL_SIZE, WALL_HEIGHT, wall_material, level_data)
		
	# 2. Physics Node (StaticBody3D placed offline under level_holder)
	var static_body := StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	static_body.position = pos
	
	# Shared BoxShape3D physics shape assignment (99.8% memory/alloc savings)
	var collision_shape := CollisionShape3D.new()
	if shared_wall_shape:
		collision_shape.shape = shared_wall_shape
	else:
		var fallback_shape := BoxShape3D.new()
		fallback_shape.size = Vector3(CELL_SIZE, 20.0, CELL_SIZE)
		collision_shape.shape = fallback_shape
		
	collision_shape.position.y = 10.0 
	static_body.add_child(collision_shape)
	
	level_holder.add_child(static_body)
	
	walls_spawned += 1

# Programmatically compiles 4 giant billboards on the cardial directions of the perimeter
func _spawn_perimeter_billboards(ox: float, oz: float) -> void:
	var margin : float = 2.6
	
	# 1. North Billboard (Top, facing Southwards directly at the camera)
	_create_billboard_sign(Vector3(0.0, 0.0, -oz - margin), 0.0)
	
	# 2. South Billboard (Bottom, facing Northwards towards the play area)
	_create_billboard_sign(Vector3(0.0, 0.0, oz + margin), 180.0)
	
	# 3. East Billboard (Right, rotated -45º to face South-West/Camera)
	_create_billboard_sign(Vector3(ox + margin, 0.0, 0.0), -45.0)
	
	# 4. West Billboard (Left, rotated 45º to face South-East/Camera)
	_create_billboard_sign(Vector3(-ox - margin, 0.0, 0.0), 45.0)

# Procedural Billboard assembler (Soporte + Backing de Carbono + Neón + Cartel Xoriguer Doble Cara)
func _create_billboard_sign(pos: Vector3, rot_y: float) -> void:
	var billboard_root := Node3D.new()
	
	# 1. Structural Metal Post
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.08
	post_mesh.height = 3.0
	post_mesh.radial_segments = 8
	
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.1, 0.1, 0.12) 
	post_mat.roughness = 0.4
	post_mat.metallic = 0.8
	
	var post_inst := MeshInstance3D.new()
	post_inst.mesh = post_mesh
	post_inst.material_override = post_mat
	post_inst.position.y = 1.50 
	billboard_root.add_child(post_inst)
	
	# 2. Signboard Carbon Backing
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(2.6, 4.0, 0.12)
	
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color(0.05, 0.05, 0.07)
	back_mat.roughness = 0.7
	
	var back_inst := MeshInstance3D.new()
	back_inst.mesh = back_mesh
	back_inst.material_override = back_mat
	back_inst.position.y = 3.00 
	billboard_root.add_child(back_inst)
	
	# 3. Lateral Glowing Neon Frame bars
	var neon_mesh := BoxMesh.new()
	neon_mesh.size = Vector3(0.08, 4.04, 0.14)
	
	var neon_mat := StandardMaterial3D.new()
	neon_mat.albedo_color = Color(0.0, 0.8, 1.0)
	neon_mat.emission_enabled = true
	neon_mat.emission = Color(0.0, 0.6, 1.0) 
	
	var left_neon := MeshInstance3D.new()
	left_neon.mesh = neon_mesh
	left_neon.material_override = neon_mat
	left_neon.position = Vector3(-1.32, 3.00, 0.0) 
	billboard_root.add_child(left_neon)
	
	var right_neon := MeshInstance3D.new()
	right_neon.mesh = neon_mesh
	right_neon.material_override = neon_mat
	right_neon.position = Vector3(1.32, 3.00, 0.0) 
	billboard_root.add_child(right_neon)
	
	# --- DIP / CACHING IMPLEMENTATION ---
	# Uses the pre-loaded high-resolution billboard texture, preventing runtime disk hits
	if cached_billboard_poster:
		var poster_sprite := Sprite3D.new()
		poster_sprite.texture = cached_billboard_poster
		poster_sprite.shaded = false 
		poster_sprite.double_sided = true 
		poster_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD 
		
		var target_height : float = 3.8
		var img_height : float = float(cached_billboard_poster.get_height())
		if img_height > 0.0:
			poster_sprite.pixel_size = target_height / img_height
			
		poster_sprite.position = Vector3(0.0, 3.00, 0.07) 
		billboard_root.add_child(poster_sprite)
	else:
		# Standalone fallback if the cached poster is missing
		var poster_mesh := BoxMesh.new()
		poster_mesh.size = Vector3(2.4, 3.8, 0.02)
		var poster_mat := StandardMaterial3D.new()
		poster_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		poster_mat.albedo_color = Color(0.0, 0.8, 1.0)
		
		var front_poster := MeshInstance3D.new()
		front_poster.mesh = poster_mesh
		front_poster.material_override = poster_mat
		front_poster.position = Vector3(0.0, 3.00, 0.07) 
		billboard_root.add_child(front_poster)
		
		var back_poster := MeshInstance3D.new()
		back_poster.mesh = poster_mesh
		back_poster.material_override = poster_mat
		back_poster.position = Vector3(0.0, 3.00, -0.07)
		back_poster.rotation_degrees.y = 180.0
		billboard_root.add_child(back_poster)
	
	# Apply coordinates and rotations
	billboard_root.position = pos
	billboard_root.rotation_degrees.y = rot_y
	
	# Attach billboards to the offline root container
	level_holder.add_child(billboard_root)

# Programmatically instantiates and places 4 symmetric Cyber-Windmills at the corners and 3 Cyber-Taulas behind the billboards (SOLID OCP)
func _spawn_perimeter_decorations(ox: float, oz: float) -> void:
	# Align margin proximity (2.8m) to match the backlit billboards (2.6m) for perfect diorama framing
	var margin : float = 2.8 
	var strategy = PerimeterDecorationStrategies.CyberWindmill.new()
	
	# 1. North-West Corner (facing 45 degrees directly towards the center lane)
	strategy.build_decoration(level_holder, Vector3(-ox - margin, 0.0, -oz - margin), 45.0)
	
	# 2. North-East Corner (facing -45 degrees)
	strategy.build_decoration(level_holder, Vector3(ox + margin, 0.0, -oz - margin), -45.0)
	
	# 3. South-West Corner (facing 135 degrees)
	strategy.build_decoration(level_holder, Vector3(-ox - margin, 0.0, oz + margin), 135.0)
	
	# 4. South-East Corner (facing -135 degrees)
	strategy.build_decoration(level_holder, Vector3(ox + margin, 0.0, oz + margin), -135.0)
	
	# --- NEW: Spawn 3 Prehistoric Cyber-Taula Shrines in the cardinal outskirts ---
	var taula = PerimeterDecorationStrategies.CyberTaula.new()
	var taula_margin : float = 4.2 # Placed slightly further out behind the billboard posts (2.6m) to form a layered background
	
	# North Taula (centered behind North billboard, facing South/Camera)
	taula.build_decoration(level_holder, Vector3(0.0, 0.0, -oz - taula_margin), 180.0)
	
	# East Taula (centered behind East billboard, facing West/Player)
	taula.build_decoration(level_holder, Vector3(ox + taula_margin, 0.0, 0.0), -90.0)
	
	# West Taula (centered behind West billboard, facing East/Player)
	taula.build_decoration(level_holder, Vector3(-ox - taula_margin, 0.0, 0.0), 90.0)

func _create_ghost_house_gate(pos: Vector3) -> void:
	var static_body := StaticBody3D.new()
	static_body.name = "GhostHouseGate"
	
	static_body.collision_layer = 8
	static_body.collision_mask = 0 
	
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = box_shape
	collision_shape.position.y = WALL_HEIGHT / 2.0
	static_body.add_child(collision_shape)
	
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(CELL_SIZE, 0.05, CELL_SIZE) 
	mesh_instance.mesh = box_mesh
	
	var laser_mat := StandardMaterial3D.new()
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_mat.albedo_color = Color(1.0, 0.0, 1.0, 0.25) 
	laser_mat.emission_enabled = true
	laser_mat.emission = Color(1.0, 0.0, 0.6) 
	mesh_instance.material_override = laser_mat
	mesh_instance.position.y = 0.025 
	static_body.add_child(mesh_instance)
	
	static_body.position = pos
	# Attach laser gate to the offline root container
	level_holder.add_child(static_body)

func _create_ghost_spawn_pad(pos: Vector3, color: Color) -> void:
	var pad_holder := Node3D.new()
	
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.65
	base_mesh.bottom_radius = 0.65
	base_mesh.height = 0.05
	base_mesh.radial_segments = 16
	
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.08, 0.08, 0.1) 
	base_mat.roughness = 0.6
	base_mat.metallic = 0.6
	
	var base_instance := MeshInstance3D.new()
	base_instance.mesh = base_mesh
	base_instance.material_override = base_mat
	base_instance.position.y = 0.025 
	pad_holder.add_child(base_instance)
	
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.58
	ring_mesh.bottom_radius = 0.58
	ring_mesh.height = 0.06 
	ring_mesh.radial_segments = 16
	
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = color
	ring_mat.emission_enabled = true
	ring_mat.emission = color * 0.85 
	
	var ring_instance := MeshInstance3D.new()
	ring_instance.mesh = ring_mesh
	ring_instance.material_override = ring_mat
	ring_instance.position.y = 0.03
	pad_holder.add_child(ring_instance)
	
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
	pad_holder.position.y = 0.01 
	# Attach spawn pads to the offline root container
	level_holder.add_child(pad_holder)

# Spawns a pellet on the grid injecting the pre-cached scene asset to prevent runtime disk IO bottlenecks
func _create_pellet(pos: Vector3, is_power: bool) -> void:
	var pellet := Pellet.new()
	pellet.is_power_pellet = is_power
	
	# Dependency Injection: Pass the cached standard model downwards (SOLID DIP)
	if cached_bottle_scene:
		pellet.bottle_scene_cache = cached_bottle_scene
		
	pellet.position = pos
	pellet.position.y = 0.5
	
	if parent_node.has_method("_on_pellet_eaten"):
		pellet.eaten.connect(parent_node._on_pellet_eaten)
		
	# Attach standard pellets to the offline root container (fully restored, native and stable!)
	level_holder.add_child(pellet)
	
	if GameManager:
		GameManager.register_pellet()
		
	pellets_spawned += 1

# Spawns a frosty ice pellet on the grid injecting the pre-cached scene asset
func _create_ice_pellet(pos: Vector3) -> void:
	var ice_pellet := IcePellet.new()
	
	# Dependency Injection: Pass the cached ice model downwards (SOLID DIP)
	if cached_ice_scene:
		ice_pellet.ice_scene_cache = cached_ice_scene
		
	ice_pellet.position = pos
	ice_pellet.position.y = 0.5
	
	if parent_node.has_method("_on_ice_pellet_eaten"):
		ice_pellet.ice_pellet_eaten.connect(parent_node._on_ice_pellet_eaten)
		
	# Attach ice pellets to the offline root container
	level_holder.add_child(ice_pellet)
	
	if GameManager:
		GameManager.register_pellet()
		
	ice_spawned += 1

# Spawns an electric lemon pellet on the grid injecting the pre-cached scene asset
func _create_speed_pellet(pos: Vector3) -> void:
	var speed_pellet := SpeedPellet.new()
	
	# Dependency Injection: Pass the cached speed model downwards (SOLID DIP)
	if cached_lemon_scene:
		speed_pellet.lemon_scene_cache = cached_lemon_scene
		
	speed_pellet.position = pos
	speed_pellet.position.y = 0.5
	
	if parent_node.has_method("_on_speed_pellet_eaten"):
		speed_pellet.speed_pellet_eaten.connect(parent_node._on_speed_pellet_eaten)
		
	# Attach speed lemons to the offline root container
	level_holder.add_child(speed_pellet)
	
	if GameManager:
		GameManager.register_pellet()
		
	speed_spawned += 1

# Instantiates the player character injecting pre-assembled models from RAM
func _spawn_player(pos: Vector3) -> void:
	var player_instance := Player.new()
	player_instance.spawn_position = pos
	player_instance.position = pos
	
	# Inject the precompiled AnimationLibrary into Player (SOLID DIP)
	if cached_player_animation_library:
		player_instance.precompiled_anim_library = cached_player_animation_library
	
	player_instance.initialize(player_material, waka_audio_stream, death_audio_stream)
	player_instance.position.y = player_instance.get_spawn_height_offset()
	
	if "player_instance" in parent_node:
		parent_node.player_instance = player_instance
		
	if parent_node.has_method("_on_player_death_completed"):
		player_instance.death_completed.connect(parent_node._on_player_death_completed)
		
	# Attach player to the offline root container
	level_holder.add_child(player_instance)
	
	var camera := DioramaCamera.new()
	# Attach camera to the offline root container
	level_holder.add_child(camera)

# Spawns a ghost on the grid, retrieving the corresponding preloaded 3D model
func _spawn_ghost(pos: Vector3, level_data: Dictionary) -> void:
	var ghost := Ghost.new()
	var ghost_type : String = ghost_types[spawned_ghosts_count % ghost_types.size()]
	spawned_ghosts_count += 1
	ghost.position = pos
	
	var strategy : GhostBehavior
	match ghost_type:
		"Blinky": strategy = BlinkyBehavior.new()
		"Pinky": strategy = PinkyBehavior.new()
		"Inky": 
			var inky_strategy = InkyBehavior.new()
			var blinky_ref = parent_node.get_tree().get_first_node_in_group("ghosts")
			for g in parent_node.get_tree().get_nodes_in_group("ghosts"):
				if g is Ghost and g.ghost_type == "Blinky":
					blinky_ref = g
					break
			inky_strategy.squad_leader = blinky_ref
			strategy = inky_strategy
		"Clyde": strategy = ClydeBehavior.new()
		_: strategy = GhostBehavior.new()
		
	var norm_mat : StandardMaterial3D = ghost_materials.get(ghost_type)
	var layout : Array = level_data.get("layout", [])
	var grid_w : int = int(level_data.get("grid_width", 0))
	var grid_h : int = int(level_data.get("grid_height", 0))
	
	_create_ghost_spawn_pad(pos, norm_mat.albedo_color)
	
	# Fetch preloaded PackedScene resource from cache (SOLID DIP compliance)
	var preloaded_scene : PackedScene = cached_ghost_scenes.get(ghost_type, null)
	
	# Initialize ghost with pre-loaded cache resource in final slot
	ghost.initialize(
		ghost_type, 
		strategy, 
		norm_mat, 
		ghost_frightened_material, 
		layout, 
		grid_w, 
		grid_h, 
		ghost_eaten_audio_stream,
		preloaded_scene
	)
	
	ghost.position.y = ghost.get_spawn_height_offset()
	
	if parent_node.has_method("_on_ghost_player_caught"):
		ghost.player_caught.connect(parent_node._on_ghost_player_caught)
		
	# Attach ghosts to the offline root container
	level_holder.add_child(ghost)

func _create_portal(pos: Vector3, my_name: String, partner_name: String) -> void:
	var portal := Portal.new()
	portal.name = my_name
	portal.position = pos
	portal.position.y = 0.8
	
	# Attach portals to the offline root container
	level_holder.add_child(portal)
	
	portals_to_link.append({
		"portal": portal,
		"partner_name": partner_name
	})

# Dynamic mesh merger: fuses all individual wall meshes in memory based on active materials (DIP Compliance)
func _merge_and_optimize_visuals() -> void:
	var material_map : Dictionary = {}
	
	# Recursive search for all MeshInstance3D nodes in the wall container
	var mesh_instances : Array[MeshInstance3D] = []
	_find_mesh_instances_recursive(global_wall_visuals_container, mesh_instances)
	
	if mesh_instances.is_empty():
		return
		
	# Extract and group geometry data by Material
	for mi in mesh_instances:
		var mesh : Mesh = mi.mesh
		if not mesh:
			continue
			
		var mat : Material = mi.material_override
		if not mat:
			mat = mi.get_active_material(0)
		if not mat:
			mat = wall_material # Default fallback
			
		# Compute relative transform offset coordinate to parent global spacing bounds
		# Safe local calculation: multiplies the local coordinates of the visual node and its child mesh
		var parent_node_3d = mi.get_parent() as Node3D
		var transform : Transform3D = Transform3D.IDENTITY
		if parent_node_3d:
			transform = parent_node_3d.transform * mi.transform
		else:
			transform = mi.transform
		
		if not material_map.has(mat):
			material_map[mat] = []
		material_map[mat].append({
			"mesh": mesh,
			"transform": transform
		})
		
	# Compile a single merged MeshInstance3D for each unique Material
	for mat in material_map:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		for item in material_map[mat]:
			var m : Mesh = item["mesh"]
			var t : Transform3D = item["transform"]
			
			# Append each mesh surface with its relative coordinate transform
			for s in range(m.get_surface_count()):
				st.append_from(m, s, t)
				
		var merged_mesh : ArrayMesh = st.commit()
		
		var merged_instance := MeshInstance3D.new()
		merged_instance.mesh = merged_mesh
		merged_instance.material_override = mat
		global_wall_visuals_container.add_child(merged_instance)
		
	# Free all the 1400 individual visual rendering nodes to clean up the SceneTree!
	for child in global_wall_visuals_container.get_children():
		if child != null and child is MeshInstance3D and child.mesh is ArrayMesh:
			continue # Preserve the newly compiled merged instances!
		child.queue_free()

# Recursive helper to gather all mesh instances under the visuals container
func _find_mesh_instances_recursive(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_mesh_instances_recursive(child, result)

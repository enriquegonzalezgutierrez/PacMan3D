# ==============================================================================
# Description: Procedural Level Assembler / 3D Mesh Factory. Hand-crafts 
#              materials, builds wall styles using WallStyleStrategy pattern, 
#              spawns gameplay entities, links portals, and builds illuminated 
#              double-sided Menorcan Gin Xoriguer billboards on the map outskirts.
#              SOLID Refactoring & Visual Fixes:
#              - Spectator Angling Fix: Configured the side billboards (East & West) 
#                to rotate diagonally at -45º and 45º towards the diorama camera (South). 
#                This makes the Gin Xoriguer PNG fully visible and readable from 
#                the screen viewport.
#              - Sprite3D Poster Engine: Replaced BoxMesh with a native Sprite3D.
#              - Image Format Guard: Automatically detects and prioritizes PNGs.
#              - Floor Shading Optimization: Changed shading mode of the floor.
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

# Compiles and setups materials procedurally
func _initialize_materials() -> void:
	# 1. Wall Material (Brushed Satin Cyber-Plastics)
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.0, 0.0, 1.0) # Default Blue
	wall_material.roughness = 0.45 
	wall_material.metallic = 0.12 
	wall_material.metallic_specular = 0.4 
	wall_material.emission_enabled = true
	wall_material.emission = Color(0.0, 0.0, 0.15) 
	
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
		
	if level_data.has("wall_color"):
		var w_color = Color(level_data["wall_color"])
		wall_material.albedo_color = w_color
		wall_material.emission = w_color * 0.15
		
	_setup_world_environment()
		
	var layout : Array = level_data.get("layout", [])
	var width : int = int(level_data.get("grid_width", 0))
	var height : int = int(level_data.get("grid_height", 0))
	
	var map_offset_x : float = (float(width) * CELL_SIZE) / 2.0
	var map_offset_z : float = (float(height) * CELL_SIZE) / 2.0
	
	_spawn_flat_dark_floor(width, height)
	
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
		var partner_portal = parent_node.get_node_or_null(link_info["partner_name"]) as Portal
		if partner_portal:
			my_portal.initialize(partner_portal)

	# --- SPACIAL BILLBOARDS GENERATOR ---
	# Spawns 4 beautiful neon-backlit Gin Xoriguer advertisements outside the boundaries (SRP)
	_spawn_perimeter_billboards(map_offset_x, map_offset_z)

func _setup_world_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env_res := Environment.new()
	
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.15, 0.15, 0.22) 
	env_res.ambient_light_energy = 1.0 
	
	env_res.background_mode = Environment.BG_CLEAR_COLOR
	env_res.background_color = Color(0.01, 0.01, 0.02, 1.0) 
	
	var is_low_end : bool = OS.has_feature("mobile") or OS.has_feature("web")
	env_res.glow_enabled = true
	env_res.glow_intensity = 0.22 if is_low_end else 0.45 
	env_res.glow_strength = 0.5 if is_low_end else 0.8
	env_res.glow_bloom = 0.05 if is_low_end else 0.10 
	env_res.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	world_env.environment = env_res
	parent_node.add_child(world_env)
	
	RenderingServer.set_default_clear_color(Color(0.01, 0.01, 0.02, 1.0))
	
	var main_node = parent_node.get_parent()
	if is_instance_valid(main_node):
		var dir_light = main_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if is_instance_valid(dir_light):
			dir_light.light_energy = 0.55 
			dir_light.light_color = Color(1.0, 1.0, 1.0) 
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
	
	parent_node.add_child(floor_instance)

# --- RESTORED WALL GENERATOR (FIXED PARSER ERROR) ---
# Instantiates procedurally designed wall meshes depending on the active level theme
func _create_wall(pos: Vector3, x: int, z: int, level_data: Dictionary) -> void:
	var static_body := StaticBody3D.new()
	var rendering_style : String = level_data.get("rendering_style", "pipes")
	
	# Query and build the style using the WallStyleStrategy pattern (OCP)
	var strategy : WallStyleStrategy = wall_strategies.get(rendering_style, wall_strategies["pipes"])
	strategy.build_mesh(static_body, x, z, CELL_SIZE, WALL_HEIGHT, wall_material, level_data)
		
	# Physical Collider (Uniform across all styles)
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(CELL_SIZE, 20.0, CELL_SIZE)
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = box_shape
	collision_shape.position.y = 10.0 
	static_body.add_child(collision_shape)
	
	static_body.position = pos
	parent_node.add_child(static_body)

# Programmatically compiles 4 giant billboards on the cardial directions of the perimeter
func _spawn_perimeter_billboards(ox: float, oz: float) -> void:
	# Reduced margin from 5.5 to 2.6 meters outside play corridors.
	# Places the giant advertisements right next to the boundary walls for massive impact.
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
	
	# 2. Signboard Carbon Backing (Fixed: Portrait Aspect Ratio of 2.6x4.0 meters)
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
	
	# 3. Lateral Glowing Neon Frame bars (Fixed: Height adapted to 4.0 meters)
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
	
	# --- MULTI-EXTENSION DEFENSIVE LOADER (DIP Compliance) ---
	var ad_tex : Texture2D = null
	var extensions = [".png", ".jpg", ".jpeg", ".PNG", ".JPG", ".JPEG"] # Prioritized PNG first!
	for ext in extensions:
		var test_path = "res://assets/ui/images/xoriguer_ad" + ext
		if ResourceLoader.exists(test_path):
			ad_tex = load(test_path) as Texture2D
			break
			
	if ad_tex:
		# --- DYNAMIC SPRITE3D POSTER ENGINE (Stretching & Zooming Fix) ---
		# Fixed: Replaced BoxMesh with a native Sprite3D node to completely bypass 
		# UV wrapping and projection stretching. It renders your cropped PNG bottle 
		# transparently, preserving its native aspect ratio 1:1.
		var poster_sprite := Sprite3D.new()
		poster_sprite.texture = ad_tex
		poster_sprite.shaded = false # Equivalent to UNSHADED (100% original crisp colors)
		poster_sprite.double_sided = true # Visible from both front and back
		poster_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD # Perfect transparent cutout
		
		# Mathematically calculate the pixel_size to fit the 3.8-meter height perfectly (40% increase)
		var target_height : float = 3.8
		var img_height : float = float(ad_tex.get_height())
		if img_height > 0.0:
			poster_sprite.pixel_size = target_height / img_height
			
		poster_sprite.position = Vector3(0.0, 3.00, 0.07) # Centered on front of chasis
		billboard_root.add_child(poster_sprite)
	else:
		# Fallback flat cyan mesh if the image is missing/not imported yet
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
	
	parent_node.add_child(billboard_root)

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
	parent_node.add_child(static_body)

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
	parent_node.add_child(pad_holder)

func _create_pellet(pos: Vector3, is_power: bool) -> void:
	var pellet := Pellet.new()
	pellet.is_power_pellet = is_power
	pellet.position = pos
	pellet.position.y = 0.5
	
	if parent_node.has_method("_on_pellet_eaten"):
		pellet.eaten.connect(parent_node._on_pellet_eaten)
		
	parent_node.add_child(pellet)
	
	if GameManager:
		GameManager.register_pellet()

func _create_ice_pellet(pos: Vector3) -> void:
	var ice_pellet := IcePellet.new()
	ice_pellet.position = pos
	ice_pellet.position.y = 0.5
	
	if parent_node.has_method("_on_ice_pellet_eaten"):
		ice_pellet.ice_pellet_eaten.connect(parent_node._on_ice_pellet_eaten)
		
	parent_node.add_child(ice_pellet)
	
	if GameManager:
		GameManager.register_pellet()

func _create_speed_pellet(pos: Vector3) -> void:
	var speed_pellet := SpeedPellet.new()
	speed_pellet.position = pos
	speed_pellet.position.y = 0.5
	
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
	
	if "player_instance" in parent_node:
		parent_node.player_instance = player_instance
		
	if parent_node.has_method("_on_player_death_completed"):
		player_instance.death_completed.connect(parent_node._on_player_death_completed)
		
	parent_node.add_child(player_instance)
	
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
	
	ghost.initialize(ghost_type, strategy, norm_mat, ghost_frightened_material, layout, grid_w, grid_h, ghost_eaten_audio_stream)
	ghost.position.y = ghost.get_spawn_height_offset()
	
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

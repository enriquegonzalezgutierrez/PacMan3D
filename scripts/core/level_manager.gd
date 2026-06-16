# ==============================================================================
# Description: Parses the level JSON file, feeds the layout data to the global
#              GameManager, and generates the 3D grid of Pac-Man entities.
#              SOLID Refactoring:
#              - DI Container: Acts as the central Dependency Injection container,
#                preloading audio streams, building materials, and injecting them
#                into Player and Ghost entities.
#              - Orchestrator: Connects decoupled signals from Pellets and Ghosts
#                to the GameManager global state, removing low-level couplings.
#              - Portal Linker: Dynamically wires Portal pairs at runtime using
#                direct object references instead of string search lookups.
#              - Cooperative AI Support: Passes the ghost identity type during
#                dependency injection for Inky's cooperative AI search.
#              - Game Feel Update: Manages the sequential death of Pac-Man,
#                freezing all ghosts during the death animation and subtracting
#                lives only when the audio playback is complete.
#              - Background Music: Integrates the level's procedural soundtrack.
#              - OCP & DIP (Dynamic Height Decoupling): Removed all hardcoded
#                spawning Y-heights. The manager queries Player and Ghost 
#                instances dynamically in runtime for their physical spawn offsets.
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
var bgm_stream : AudioStream = preload("res://assets/audio/bgm/level_1_bgm.mp3") 

# Centralized Materials (SRP Compliance)
var wall_material : StandardMaterial3D
var player_material : StandardMaterial3D
var ghost_frightened_material : StandardMaterial3D
var ghost_materials : Dictionary = {} # Maps type to specific color material

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
	if _load_level_data("res://data/level_01.json"):
		_build_environment()

# Centralized visual resource creation
func _initialize_materials() -> void:
	# 1. Wall Material
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.0, 0.0, 1.0) # Classic Blue
	
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

# Loads and parses the JSON level configuration
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
		if GameManager:
			GameManager.level_layout = layout
			GameManager.grid_width = int(level_data.get("grid_width", 0))
			GameManager.grid_height = int(level_data.get("grid_height", 0))
			
		var width : float = float(level_data.get("grid_width", 0))
		var height : float = float(level_data.get("grid_height", 0))
		map_offset_x = (width * CELL_SIZE) / 2.0
		map_offset_z = (height * CELL_SIZE) / 2.0
		return true
	return false

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
				1: _create_wall(world_pos)
				2: _create_pellet(world_pos, false)
				3: _create_pellet(world_pos, true)
				4: _spawn_player(world_pos)
				5: _spawn_ghost(world_pos)
				6: _create_portal(world_pos, "Portal_A", "Portal_B")
				7: _create_portal(world_pos, "Portal_B", "Portal_A")
				
	# Post-spawn pass: Link portal pairs together directly (DIP Compliance)
	for link_info in portals_to_link:
		var my_portal : Portal = link_info["portal"]
		var partner_portal = get_node_or_null(link_info["partner_name"]) as Portal
		if partner_portal:
			my_portal.initialize(partner_portal)

# Instantiates a 3D wall block
func _create_wall(pos: Vector3) -> void:
	var static_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = wall_material
	
	var box_shape := BoxShape3D.new()
	box_shape.size = box_mesh.size
	collision_shape.shape = box_shape
	
	static_body.add_child(mesh_instance)
	static_body.add_child(collision_shape)
	static_body.position = pos
	static_body.position.y = WALL_HEIGHT / 2.0 
	add_child(static_body)

# Instantiates a standard or power pellet and connects its signals
func _create_pellet(pos: Vector3, is_power: bool) -> void:
	var pellet := Pellet.new()
	pellet.is_power_pellet = is_power
	pellet.position = pos
	pellet.position.y = 0.5
	
	# Connect pellet consumption to local router (DIP Compliance)
	pellet.eaten.connect(_on_pellet_eaten)
	
	add_child(pellet)
	
	# Centralized pellet counter registration
	if GameManager:
		GameManager.register_pellet()

# Instantiates the player character and injects its resources
func _spawn_player(pos: Vector3) -> void:
	player_instance = Player.new()
	player_instance.spawn_position = pos
	player_instance.position = pos
	
	# Dependency Injection
	player_instance.initialize(player_material, waka_audio_stream, death_audio_stream)
	
	# FIXED DYNAMIC CALCULATION: Query the player for its physical spawn height dynamically (OCP/DIP Compliance)
	player_instance.position.y = player_instance.get_spawn_height_offset()
	
	# Listen to the decoupled death sequence completion event (SRP Compliance)
	player_instance.death_completed.connect(_on_player_death_completed)
	
	add_child(player_instance)

# Factory/DI method: Spawns a ghost, assigns strategy, and injects resources
func _spawn_ghost(pos: Vector3) -> void:
	var ghost := Ghost.new()
	
	# Assign sequential ghost type identity
	var ghost_type : String = ghost_types[spawned_ghosts_count % ghost_types.size()]
	spawned_ghosts_count += 1
	
	ghost.position = pos
	
	# Factory creation of concrete behavior strategies (OCP / DIP Compliance)
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
	
	# Inject dependencies
	ghost.initialize(ghost_type, strategy, norm_mat, ghost_frightened_material, layout, grid_w, grid_h)
	
	# FIXED DYNAMIC CALCULATION: Query the ghost for its physical spawn height dynamically (OCP/DIP Compliance)
	ghost.position.y = ghost.get_spawn_height_offset()
	
	# Listen to decoupled entity events (DIP Compliance)
	ghost.player_caught.connect(_on_ghost_player_caught)
	
	add_child(ghost)

# Instantiates a warp portal and registers it for the linking pass
func _create_portal(pos: Vector3, my_name: String, partner_name: String) -> void:
	var portal := Portal.new()
	portal.name = my_name
	portal.position = pos
	portal.position.y = 0.8
	add_child(portal)
	
	# Cache link configuration details for the post-spawn linking pass
	portals_to_link.append({
		"portal": portal,
		"partner_name": partner_name
	})

# --- SIGNAL ROUTING & GAMEPLAY ORCHESTRATION ---

# Signal callback: Routes pellet eating to global GameManager score mutations
func _on_pellet_eaten(is_power: bool) -> void:
	if GameManager:
		if is_power:
			GameManager.add_score(40)
			GameManager.activate_power_pellet()
		GameManager.pellet_eaten()

# Signal callback: Routes ghost caught events to score increments or player death sequence triggers
func _on_ghost_player_caught(is_frightened: bool) -> void:
	if GameManager:
		if is_frightened:
			GameManager.add_score(200)
		else:
			# Normal ghost caught Pac-Man:
			# 1. Freeze all active ghosts in place (Game Feel / Polish)
			for ghost in get_tree().get_nodes_in_group("ghosts"):
				if ghost.has_method("set_frozen"):
					ghost.set_frozen(true)
					
			# 2. Pause the background music dramatically during death sequence (SRP Compliance)
			if bgm_player:
				bgm_player.stream_paused = true
					
			# 3. Instruct Pac-Man to initiate his local sequential death
			if player_instance:
				player_instance.die()

# Signal callback: Triggered ONLY after Pac-Man's death sequence finishes (audio + particles)
func _on_player_death_completed() -> void:
	if GameManager:
		# Subtract life (This emits player_killed and automatically triggers unfreezes/resets)
		GameManager.lose_life()

# Global Signal: Tells all active ghosts to activate frightened mode
func _on_power_pellet_activated() -> void:
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if ghost.has_method("activate_frightened_mode"):
			ghost.activate_frightened_mode()

# Global Signal: Tells all active ghosts to reset to spawn positions
func _on_player_killed() -> void:
	# Unpause background music when the game/player resets back to action
	if bgm_player:
		bgm_player.stream_paused = false
		
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if ghost.has_method("reset_to_base"):
			ghost.reset_to_base()

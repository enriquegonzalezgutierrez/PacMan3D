# ==============================================================================
# Description: Parses the level JSON file, feeds the layout data to the global
#              GameManager, and coordinates gameplay states and signals.
#              Phase 4 Update (Extreme Performance):
#              - Connected ghost score and special items floating texts to the 
#                VFXPoolManager using dynamic root resolution to bypass Godot's 
#                autoload compiler cache bugs (100% Bulletproof Compile).
#              Phase 3 Update (AAA Visuals):
#              - Screen Glitch VFX integration.
#              Phase 2 Update (Menorcan Lore Expansion):
#              - Ensaimada Shield Integration & Mahón Cheese Decoy System.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node3D
class_name LevelManager

# Map Grid Constants
const CELL_SIZE : float = 2.0

# Active entities and players tracking
var player_instance : Player = null
var bgm_player : AudioStreamPlayer = null

# Persistent level configurations
var level_data : Dictionary = {}
var map_offset_x : float = 0.0
var map_offset_z : float = 0.0

# Dynamic Autoload Resolvers (Bypasses Godot compiler cache bugs safely)
var vfx_pool : Node = null

# Fruit spawning state tracking variables
const FRUIT_LIFETIME : float = 10.0 # Despawns after 10 seconds if not eaten

func _ready() -> void:
	# Resolve the global pooler dynamically from the engine root viewport
	vfx_pool = get_node_or_null("/root/VFXPoolManager")
	
	_connect_game_manager_signals()
	
	var hud = get_parent().get_node_or_null("HUD") as HUD
	if hud:
		hud.start_game.connect(_on_start_game)
	else:
		_on_start_game()

# Connect LevelManager to receive global signal notifications
func _connect_game_manager_signals() -> void:
	if GameManager:
		GameManager.power_pellet_activated.connect(_on_power_pellet_activated)
		GameManager.player_killed.connect(_on_player_killed)
		GameManager.victory.connect(_on_automated_victory_sequence)

# Programmatically configures and plays the BGM dynamically matched to the level
func _setup_bgm() -> void:
	var level_idx : int = 1
	var speed_multiplier : float = 1.0
	
	if GameManager:
		level_idx = GameManager.current_level
		speed_multiplier = GameManager.get_ghost_speed_multiplier()
		
	var bgm_path := "res://assets/audio/bgm/level_%d_bgm.mp3" % level_idx
	
	if not FileAccess.file_exists(bgm_path):
		bgm_path = "res://assets/audio/bgm/level_1_bgm.mp3"
		
	var bgm_stream : AudioStream = load(bgm_path)
	
	if bgm_stream:
		if is_instance_valid(bgm_player):
			bgm_player.stop()
			bgm_player.queue_free()
			
		bgm_player = AudioStreamPlayer.new()
		bgm_player.stream = bgm_stream
		bgm_player.volume_db = -12.0 
		bgm_player.pitch_scale = speed_multiplier 
		bgm_player.autoplay = true
		add_child(bgm_player)
		bgm_player.play()

func _on_start_game() -> void:
	var level_idx : int = 1
	if GameManager:
		level_idx = GameManager.current_level
		
	var level_path := "res://data/level_%02d.json" % level_idx
	
	if _load_level_data(level_path):
		_setup_bgm() 
		
		var builder := LevelBuilder.new(self)
		builder.build(level_data)
		
		await get_tree().create_timer(0.8).timeout
		
		var hud = get_parent().get_node_or_null("HUD") as HUD
		if is_instance_valid(hud):
			hud.hide_status_overlay()

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
		
		if not MapValidator.validate_map(layout, width, height):
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

# Spawns a floating 3D Label from the RAM pool (Phase 4 Optimization)
func _spawn_floating_score(pos: Vector3, points: int = 200) -> void:
	var text_val : String = str(points)
	var color : Color = Color(1.0, 1.0, 1.0) 
	
	if points >= 800:
		color = Color(0.0, 1.0, 1.0) 
		
	if is_instance_valid(vfx_pool):
		vfx_pool.spawn_floating_score(pos, text_val, color)
	else:
		# Dynamic fallback in case Autoload is completely missing
		var fallback := FloatingScore3D.new()
		fallback.text = text_val
		fallback.modulate = color
		fallback.global_position = pos + Vector3(0.0, 1.2, 0.0)
		add_child(fallback)

# --- MENORCAN LORE EXPANSION: SPECIAL ITEMS ---

func _spawn_fruit_bonus() -> void:
	var fruit := Fruit.new()
	var current_lvl : int = 1
	if GameManager:
		current_lvl = GameManager.current_level
		
	fruit.initialize(current_lvl)
	if is_instance_valid(player_instance):
		fruit.position = player_instance.spawn_position
	fruit.position.y = 0.5
	
	fruit.eaten.connect(_on_special_item_eaten)
	get_tree().create_timer(FRUIT_LIFETIME).timeout.connect(fruit.queue_free)
	add_child(fruit)

# Process special items utilizing pooled floatings
func _on_special_item_eaten(points: int, effect: String) -> void:
	if GameManager:
		GameManager.add_score(points)
		
	var text_val : String = "+%d" % points
	var color : Color = Color(1.0, 1.0, 0.0) 
	
	if effect == "shield":
		text_val = "SHIELD!"
		color = Color(0.0, 0.8, 1.0) 
		if is_instance_valid(player_instance):
			player_instance.activate_shield()
			
	elif effect == "decoy":
		text_val = "DECOY!"
		color = Color(1.0, 0.6, 0.0) 
		_deploy_cheese_decoy()
		
	# Spawn floating feedback directly from our startup RAM pre-allocations
	if is_instance_valid(player_instance):
		if is_instance_valid(vfx_pool):
			vfx_pool.spawn_floating_score(player_instance.spawn_position, text_val, color)

func _deploy_cheese_decoy() -> void:
	if not is_instance_valid(player_instance): return
	
	var decoy := Node3D.new()
	decoy.position = player_instance.global_position
	
	var cheese_mesh := PrismMesh.new()
	cheese_mesh.size = Vector3(0.8, 0.6, 0.8)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = cheese_mesh
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.0)
	mesh_inst.material_override = mat
	mesh_inst.rotation_degrees.x = -90.0
	mesh_inst.position.y = 0.5
	decoy.add_child(mesh_inst)
	add_child(decoy)
	
	player_instance.remove_from_group("player")
	decoy.add_to_group("player")
	
	var tween = create_tween().set_loops()
	tween.tween_property(mesh_inst, "position:y", 0.8, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mesh_inst, "position:y", 0.5, 0.5).set_trans(Tween.TRANS_SINE)
	
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(decoy):
			decoy.queue_free()
		if is_instance_valid(player_instance):
			player_instance.add_to_group("player")
	)

# --- STRATEGIC MAP UTILITIES ---

func _on_ice_pellet_eaten() -> void:
	if GameManager:
		GameManager.add_score(150)
		GameManager.pellet_eaten()
		
	get_tree().call_group("ghosts", "set_frozen", true)
	_apply_ghost_frost_effect(true)
	
	get_tree().create_timer(4.0).timeout.connect(func():
		get_tree().call_group("ghosts", "set_frozen", false)
		_apply_ghost_frost_effect(false)
	)

func _apply_ghost_frost_effect(enabled: bool) -> void:
	var ghosts = get_tree().get_nodes_in_group("ghosts")
	for ghost in ghosts:
		if ghost is Ghost:
			if enabled:
				var frost_mat := StandardMaterial3D.new()
				frost_mat.albedo_color = Color(0.0, 0.8, 1.0) 
				frost_mat.emission_enabled = true
				frost_mat.emission = Color(0.0, 0.4, 0.8) 
				ghost._apply_material(frost_mat)
			else:
				ghost._apply_material(ghost.original_material)

func _on_speed_pellet_eaten() -> void:
	if GameManager:
		GameManager.add_score(100)
		GameManager.pellet_eaten()
	_trigger_camera_shake(0.4, 0.3) 


# --- AUTOMATED PROGRESSION SEQUENCE ---

func _on_automated_victory_sequence() -> void:
	get_tree().call_group("ghosts", "set_frozen", true)
	if is_instance_valid(player_instance):
		player_instance.set_physics_process(false)
		
	if is_instance_valid(bgm_player):
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -40.0, 1.5)
		
	await get_tree().create_timer(2.0).timeout
	
	if GameManager:
		if GameManager.has_next_level():
			GameManager.advance_level()
			get_tree().reload_current_scene()
		else:
			var credits := CreditsScreen.new()
			get_tree().root.add_child(credits)
			get_tree().current_scene.queue_free()
			get_tree().current_scene = credits

func _trigger_camera_shake(intensity: float, duration: float) -> void:
	var camera = get_tree().get_first_node_in_group("camera") as DioramaCamera
	if is_instance_valid(camera):
		camera.trigger_shake(intensity, duration)

# --- SIGNAL ROUTING & GAMEPLAY ORCHESTRATION ---

func _on_pellet_eaten(is_power: bool) -> void:
	if GameManager:
		if is_power:
			GameManager.add_score(40)
			GameManager.activate_power_pellet()
		GameManager.pellet_eaten()
		
		var current_eaten : int = GameManager.pellets_eaten
		if current_eaten == 70 or current_eaten == 170:
			_spawn_fruit_bonus()

func _on_ghost_player_caught(is_frightened: bool, catch_position: Vector3) -> void:
	if GameManager:
		if is_frightened:
			var points_awarded = GameManager.register_ghost_eaten()
			_spawn_floating_score(catch_position, points_awarded)
			_trigger_camera_shake(0.4, 0.25) 
			
			get_tree().paused = true
			await get_tree().create_timer(0.05, true, false, true).timeout
			get_tree().paused = false
			
		else:
			if is_instance_valid(player_instance):
				if player_instance.is_recovering:
					return 
				if player_instance.has_shield:
					player_instance.pop_shield()
					_trigger_camera_shake(0.7, 0.4) 
					return 
			
			var hud = get_parent().get_node_or_null("HUD") as HUD
			if is_instance_valid(hud) and is_instance_valid(hud.status_overlay):
				hud.status_overlay.trigger_death_glitch()
			
			for ghost in get_tree().get_nodes_in_group("ghosts") :
				if ghost.has_method("set_frozen"):
					ghost.set_frozen(true)
					
			if bgm_player:
				bgm_player.stream_paused = true
					
			if player_instance:
				player_instance.die()
				_trigger_camera_shake(0.9, 0.6) 

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

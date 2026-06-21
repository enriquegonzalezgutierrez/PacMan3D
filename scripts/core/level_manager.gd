# ==============================================================================
# Description: Parses the level JSON file, feeds the layout data to the global
#              GameManager, and coordinates gameplay states and signals.
#              Phase 2 Update (Menorcan Lore Expansion):
#              - Ensaimada Shield Integration: Intercepts ghost collisions to 
#                pop the holographic shield instead of dying, triggering i-frames.
#              - Mahón Cheese Decoy System: Uses a brilliant group-hacking 
#                technique (swapping the "player" node group to a decoy object) 
#                so all ghosts dynamically hunt the cheese for 5 seconds without 
#                altering a single line of their AI code (Strict OCP Compliance).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node3D
class_name LevelManager

# Active entities and players tracking
var player_instance : Player = null
var bgm_player : AudioStreamPlayer = null

# Persistent level configurations
var level_data : Dictionary = {}
var map_offset_x : float = 0.0
var map_offset_z : float = 0.0

# Fruit spawning state tracking variables
const FRUIT_LIFETIME : float = 10.0 # Despawns after 10 seconds if not eaten

func _ready() -> void:
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
		# Match music speed to ghost difficulty
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
		bgm_player.pitch_scale = speed_multiplier # Scales pitch with difficulty
		bgm_player.autoplay = true
		add_child(bgm_player)
		bgm_player.play()

# Triggered dynamically when the player clicks START GAME in the HUD Menu
func _on_start_game() -> void:
	var level_idx : int = 1
	if GameManager:
		level_idx = GameManager.current_level
		
	var level_path := "res://data/level_%02d.json" % level_idx
	
	if _load_level_data(level_path):
		_setup_bgm() 
		
		# Instantiate our procedural LevelBuilder and assemble the 3D world (SRP Compliance)
		var builder := LevelBuilder.new(self)
		builder.build(level_data)
		
		# Enforce a brief 0.8-second delay so that players on high-end PCs 
		# can actually read the "GENERATING SYSTEM" neon loading text.
		await get_tree().create_timer(0.8).timeout
		
		# Hide the initial system generation loading screen
		var hud = get_parent().get_node_or_null("HUD") as HUD
		if is_instance_valid(hud):
			hud.hide_status_overlay()

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
		
		# Validate the map design using our decoupled MapValidator (SRP Compliance)
		if not MapValidator.validate_map(layout, width, height):
			push_error("LEVEL LOADING ABORTED: Map validation failed.")
			return false
			
		if GameManager:
			GameManager.level_layout = layout
			GameManager.grid_width = width
			GameManager.grid_height = height
			
		var cell_size : float = 2.0
		map_offset_x = (float(width) * cell_size) / 2.0
		map_offset_z = (float(height) * cell_size) / 2.0
		return true
	return false

# Spawns a floating 3D Label above coordinates (used when eating ghosts)
func _spawn_floating_score(pos: Vector3, points: int = 200) -> void:
	var score_text := FloatingScore3D.new()
	score_text.text = str(points)
	
	# High-Tier combo visual feedback
	if points >= 800:
		score_text.modulate = Color(0.0, 1.0, 1.0) # Bright Cyan for huge combos
		
	add_child(score_text)
	score_text.global_position = pos + Vector3(0.0, 1.2, 0.0)


# --- MENORCAN LORE EXPANSION: SPECIAL ITEMS ---

# Procedurally instantiates the level-adapted fruit/item at Pac-Man's starting location
func _spawn_fruit_bonus() -> void:
	var fruit := Fruit.new()
	
	var current_lvl : int = 1
	if GameManager:
		current_lvl = GameManager.current_level
		
	# Polymorphically initialize the item's identity
	fruit.initialize(current_lvl)
	
	if is_instance_valid(player_instance):
		fruit.position = player_instance.spawn_position
	fruit.position.y = 0.5
	
	# Connect to the newly updated signal signature
	fruit.eaten.connect(_on_special_item_eaten)
	
	# Despawn Timer: auto-destroys the node if not eaten after 10 seconds
	get_tree().create_timer(FRUIT_LIFETIME).timeout.connect(fruit.queue_free)
	
	add_child(fruit)
	print("ARCADE BONUS ITEM GENERATED AT PELLET COUNT: ", GameManager.pellets_eaten)

# Evaluates the effect of the consumed item (Fruit, Shield, or Decoy)
func _on_special_item_eaten(points: int, effect: String) -> void:
	if GameManager:
		GameManager.add_score(points)
		
	# Instantiate and style the floating text based on the effect type
	var feedback_text := FloatingScore3D.new()
	
	if effect == "shield":
		feedback_text.text = "SHIELD!"
		feedback_text.modulate = Color(0.0, 0.8, 1.0) # Cyber Cyan
		if is_instance_valid(player_instance):
			player_instance.activate_shield()
			
	elif effect == "decoy":
		feedback_text.text = "DECOY!"
		feedback_text.modulate = Color(1.0, 0.6, 0.0) # Cheese Orange
		_deploy_cheese_decoy()
		
	else:
		feedback_text.text = "+%d" % points
		feedback_text.modulate = Color(1.0, 1.0, 0.0) # Golden yellow for normal fruits
		
	add_child(feedback_text)
	if is_instance_valid(player_instance):
		feedback_text.global_position = player_instance.spawn_position + Vector3(0.0, 1.5, 0.0)

# Deploys a temporary visual cheese and hacks the node groups to distract the AI
func _deploy_cheese_decoy() -> void:
	if not is_instance_valid(player_instance): return
	
	# 1. Create a simple floating cheese visual anchor
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
	
	# 2. GROUP HACKING (OCP Compliance): 
	# We remove the real player from the target group and assign the decoy.
	# All ghosts will instantly calculate their routes towards the cheese!
	player_instance.remove_from_group("player")
	decoy.add_to_group("player")
	
	# 3. Simple floating animation
	var tween = create_tween().set_loops()
	tween.tween_property(mesh_inst, "position:y", 0.8, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mesh_inst, "position:y", 0.5, 0.5).set_trans(Tween.TRANS_SINE)
	
	# 4. Self-Destruct Sequence after 5 seconds
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(decoy):
			decoy.queue_free()
		# Restore target acquisition back to MartínMan
		if is_instance_valid(player_instance):
			player_instance.add_to_group("player")
	)


# --- STRATEGIC MAP UTILITIES ---

# Reward callback: freezes all active ghosts and tints them frosty blue for 4.0 seconds
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
		
		# Special items spawn exactly at 70 and 170 pellets eaten
		var current_eaten : int = GameManager.pellets_eaten
		if current_eaten == 70 or current_eaten == 170:
			_spawn_fruit_bonus()

func _on_ghost_player_caught(is_frightened: bool, catch_position: Vector3) -> void:
	if GameManager:
		if is_frightened:
			# Hit-Stop & Combo System
			var points_awarded = GameManager.register_ghost_eaten()
			_spawn_floating_score(catch_position, points_awarded)
			_trigger_camera_shake(0.4, 0.25) 
			
			get_tree().paused = true
			await get_tree().create_timer(0.05, true, false, true).timeout
			get_tree().paused = false
			
		else:
			# --- SURVIVAL MECHANICS (Phase 2 Update) ---
			if is_instance_valid(player_instance):
				# 1. If currently in recovery i-frames, ignore the ghost collision completely
				if player_instance.is_recovering:
					return 
					
				# 2. If shielded, break the shield, survive, and get i-frames
				if player_instance.has_shield:
					player_instance.pop_shield()
					_trigger_camera_shake(0.7, 0.4) # Heavy glass shatter shake
					return 
			
			# --- NORMAL DEATH ---
			for ghost in get_tree().get_nodes_in_group("ghosts") :
				if ghost.has_method("set_frozen"):
					ghost.set_frozen(true)
					
			if bgm_player:
				bgm_player.stream_paused = true
					
			if player_instance:
				player_instance.die()
				_trigger_camera_shake(0.9, 0.6) # Heavy violent death explosion shake

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

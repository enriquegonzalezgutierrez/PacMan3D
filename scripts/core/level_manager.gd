# ==============================================================================
# Description: Parses the level JSON file, feeds the layout data to the global
#              GameManager, and coordinates gameplay states and signals.
#              Phase 2 Updates:
#              - AUTOMATED PROGRESSION: Bypasses victory UI entirely. Automatically 
#                freezes the game, waits 2 seconds, and transitions to the next 
#                JSON level seamlessly.
#              - DYNAMIC AUDIO SCALING: Dynamically increases the BGM pitch scale 
#                by 5% per level to match the scaled ghost speeds.
#              - CINEMATIC CAMERA SHAKE TRIGGERS: Dispatches camera shake signals 
#                on player deaths (violent shake) and ghost consumption (bite impact).
#              Phase 3 Updates:
#              - DUAL-SPAWN FRUIT TRIGGERS (SRP Compliance): Removed the process loop 
#                and timed spawn variables. Fruit spawns are now strictly event-driven, 
#                triggered exactly at 70 and 170 pellets eaten.
#              - LEVEL-ADAPTED FRUIT INJECTION (DIP/OCP Compliance): Injects the 
#                current level index into the fruit builder during spawning.
#              Phase 4 Updates:
#              - SPEED OVERLOAD ORCHESTRATION: Integrated the speed_pellet_eaten 
#                callback to award points, progress levels, and trigger an 
#                electric snap camera shake.
#              - DISMISS SYSTEM LOADING OVERLAY: Added programmatic HUD overlay 
#                dismissal once 3D level assembly completes, preventing lag illusions.
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
		# Match music speed to ghost difficulty (Phase 2 Compliance)
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
		
		# --- DISMISS SYSTEM GENERATION OVERLAY (Phase 4 UX Compliance) ---
		# Safely locate the HUD and dismiss the "PLEASE WAIT" loading screen 
		# now that the heavy 3D physical world assembly is complete.
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
func _spawn_floating_score(pos: Vector3) -> void:
	var score_text := FloatingScore3D.new()
	add_child(score_text)
	score_text.global_position = pos + Vector3(0.0, 1.2, 0.0)

# Procedurally instantiates the level-adapted fruit at Pac-Man's starting location (DIP/SRP Compliance)
func _spawn_fruit_bonus() -> void:
	var fruit := Fruit.new()
	
	var current_lvl : int = 1
	if GameManager:
		current_lvl = GameManager.current_level
		
	# Polymorphically initialize the fruit's identity and visual meshes (Phase 3)
	fruit.initialize(current_lvl)
	
	# Spawn exactly at Pac-Man's starting coordinate (Y offset is handled in fruit.gd)
	if is_instance_valid(player_instance):
		fruit.position = player_instance.spawn_position
	fruit.position.y = 0.5
	
	# Connect the custom points mutation callback
	fruit.eaten.connect(_on_fruit_eaten)
	
	# Despawn Timer: auto-destroys the node if not eaten after 10 seconds
	get_tree().create_timer(FRUIT_LIFETIME).timeout.connect(fruit.queue_free)
	
	add_child(fruit)
	print("ARCADE BONUS FRUIT GENERATED AT PELLET COUNT: ", GameManager.pellets_eaten)

# Reward callback: grants points and spawns a golden-yellow +500 floating text
func _on_fruit_eaten(points: int) -> void:
	if GameManager:
		GameManager.add_score(points)
		
	var score_text := FloatingScore3D.new()
	# Inject custom dynamic score string and golden colors before adding to the tree (SRP Compliance)
	score_text.text = "+%d" % points
	score_text.modulate = Color(1.0, 1.0, 0.0) # Golden yellow
	add_child(score_text)
	
	if is_instance_valid(player_instance):
		score_text.global_position = player_instance.spawn_position + Vector3(0.0, 1.5, 0.0)

# Reward callback: freezes all active ghosts and tints them frosty blue for 4.0 seconds (SRP/OCP Compliance)
func _on_ice_pellet_eaten() -> void:
	if GameManager:
		# Award +150 points for strategic utility collection
		GameManager.add_score(150)
		GameManager.pellet_eaten()
		
	# 1. Freeze all active ghosts instantly (SRP/OCP Compliance)
	get_tree().call_group("ghosts", "set_frozen", true)
	_apply_ghost_frost_effect(true)
	
	# 2. Start a 4.0 seconds unfreeze timer
	get_tree().create_timer(4.0).timeout.connect(func():
		# 3. Restore movement and normal original materials dynamically (OCP Compliance)
		get_tree().call_group("ghosts", "set_frozen", false)
		_apply_ghost_frost_effect(false)
	)

# Helper to dynamically compile and swap ghost materials to frosty blue on freeze states (SRP Compliance)
func _apply_ghost_frost_effect(enabled: bool) -> void:
	var ghosts = get_tree().get_nodes_in_group("ghosts")
	for ghost in ghosts:
		if ghost is Ghost:
			if enabled:
				var frost_mat := StandardMaterial3D.new()
				frost_mat.albedo_color = Color(0.0, 0.8, 1.0) # Glowing Frost Cyan
				frost_mat.emission_enabled = true
				frost_mat.emission = Color(0.0, 0.4, 0.8) # Frost Glow
				ghost._apply_material(frost_mat)
			else:
				# Restore normal original behavioral colors (SRP Compliance)
				ghost._apply_material(ghost.original_material)


# --- PHASE 4: SPEED OVERLOAD RESPONSE ---

# Reward callback: grants points for the speed-booster ray and progresses pellet counters (Phase 4)
func _on_speed_pellet_eaten() -> void:
	if GameManager:
		# Award +100 points for electric lightning acquisition
		GameManager.add_score(100)
		GameManager.pellet_eaten()
		
	_trigger_camera_shake(0.4, 0.3) # Electric fast camera shockwave snap!


# --- PHASE 2: AUTOMATED PROGRESSION SEQUENCE ---

# Triggered dynamically by GameManager when total_pellets == 0
func _on_automated_victory_sequence() -> void:
	# 1. Freeze all active entities
	get_tree().call_group("ghosts", "set_frozen", true)
	if is_instance_valid(player_instance):
		# Prevent further player inputs during cinematic transition
		player_instance.set_physics_process(false)
		
	# 2. Fade out music elegantly
	if is_instance_valid(bgm_player):
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -40.0, 1.5)
		
	# 3. Wait for 2.0 seconds (Cinematic pause)
	await get_tree().create_timer(2.0).timeout
	
	# 4. Trigger state advance or roll credits
	if GameManager:
		if GameManager.has_next_level():
			GameManager.advance_level()
			get_tree().reload_current_scene()
		else:
			# ALL LEVELS CLEARED: Roll credits
			var credits := CreditsScreen.new()
			get_tree().root.add_child(credits)
			get_tree().current_scene.queue_free()
			get_tree().current_scene = credits


# --- PHASE 2: CAMERA SHAKE HELPER ---

# Helper to retrieve the active camera and apply a screen shake displacement (DIP/Phase 2 Compliance)
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
		
		# --- PHASE 3: DUAL-SPAWN FRUIT TRIGGERS ---
		# Fruit spawns exactly at 70 and 170 pellets eaten (Arcade accurate)
		var current_eaten : int = GameManager.pellets_eaten
		if current_eaten == 70 or current_eaten == 170:
			_spawn_fruit_bonus()

func _on_ghost_player_caught(is_frightened: bool, catch_position: Vector3) -> void:
	if GameManager:
		if is_frightened:
			GameManager.add_score(200)
			_spawn_floating_score(catch_position)
			_trigger_camera_shake(0.35, 0.25) # Subtle satisfying arcade bite shake
		else:
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

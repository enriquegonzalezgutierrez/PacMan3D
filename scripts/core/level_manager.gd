# ==============================================================================
# Description: Parses the level JSON file, feeds the layout data to the global
#              GameManager, and coordinates gameplay states and signals.
#              SOLID Refactoring:
#              - LAMBDA MEMORY FIX: Connected the fruit despawn timer directly to 
#                fruit.queue_free. This lets Godot auto-disconnect the signal if 
#                the fruit is eaten early, preventing lambda-capture null errors.
#              - BONUS FRUIT TIMERS: Plays the bonus cherry on Pac-Man's starting coordinate.
#              - DYNAMIC SOUNDTRACK LOADING: Dynamically loads background music.
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
var fruit_spawn_timer : float = 0.0
const FRUIT_SPAWN_DELAY : float = 15.0 # Spawns 15 seconds after level start
const FRUIT_LIFETIME : float = 10.0 # Despawns after 10 seconds if not eaten
var fruit_has_spawned_this_level : bool = false

func _ready() -> void:
	_connect_game_manager_signals()
	
	var hud = get_parent().get_node_or_null("HUD") as HUD
	if hud:
		hud.start_game.connect(_on_start_game)
	else:
		_on_start_game()

func _process(delta: float) -> void:
	# Handle Bonus Fruit Spawning loop dynamically (SRP Compliance)
	if is_instance_valid(player_instance) and not fruit_has_spawned_this_level:
		fruit_spawn_timer += delta
		if fruit_spawn_timer >= FRUIT_SPAWN_DELAY:
			_spawn_fruit_bonus()

# Connect LevelManager to receive global signal notifications
func _connect_game_manager_signals() -> void:
	if GameManager:
		GameManager.power_pellet_activated.connect(_on_power_pellet_activated)
		GameManager.player_killed.connect(_on_player_killed)

# Programmatically configures and plays the BGM dynamically matched to the level
func _setup_bgm() -> void:
	var level_idx : int = 1
	if GameManager:
		level_idx = GameManager.current_level
		
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
		bgm_player.autoplay = true
		add_child(bgm_player)
		bgm_player.play()

# Triggered dynamically when the player clicks START GAME in the HUD Menu
func _on_start_game() -> void:
	# Reset local level fruit trackers
	fruit_spawn_timer = 0.0
	fruit_has_spawned_this_level = false
	
	var level_idx : int = 1
	if GameManager:
		level_idx = GameManager.current_level
		
	var level_path := "res://data/level_%02d.json" % level_idx
	
	if _load_level_data(level_path):
		_setup_bgm() 
		
		# Instantiate our procedural LevelBuilder and assemble the 3D world (SRP Compliance)
		var builder := LevelBuilder.new(self)
		builder.build(level_data)

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

# Procedurally instantiates the custom double cherry fruit at Pac-Man's starting location
func _spawn_fruit_bonus() -> void:
	fruit_has_spawned_this_level = true
	
	var fruit := Fruit.new()
	# Spawn exactly at Pac-Man's starting coordinate (Y offset is handled in fruit.gd)
	fruit.position = player_instance.spawn_position
	fruit.position.y = 0.5
	
	# Connect the custom points mutation callback
	fruit.eaten.connect(_on_fruit_eaten)
	
	# --- DIRECT METHOD CONNECTION FIX ---
	# Connecting directly to fruit.queue_free lets Godot auto-cleanup if the fruit is eaten early
	get_tree().create_timer(FRUIT_LIFETIME).timeout.connect(fruit.queue_free)
	
	add_child(fruit)
	print("BONUS FRUIT GENERATED AT PLAYER STARTING GRID COORDINATE!")

# Reward callback: grants points and spawns a golden-yellow +500 floating text
func _on_fruit_eaten(points: int) -> void:
	if GameManager:
		GameManager.add_score(points)
		
	var score_text := FloatingScore3D.new()
	score_text.text = "+%d" % points
	score_text.modulate = Color(1.0, 1.0, 0.0) # Golden yellow
	add_child(score_text)
	score_text.global_position = player_instance.spawn_position + Vector3(0.0, 1.5, 0.0)

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
		
	# Reset level fruit timers on player death/reset (guarantees a fair chance to eat it again)
	fruit_spawn_timer = 0.0
	fruit_has_spawned_this_level = false
	
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if ghost.has_method("reset_to_base"):
			ghost.reset_to_base()

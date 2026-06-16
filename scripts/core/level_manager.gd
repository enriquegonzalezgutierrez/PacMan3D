# ==============================================================================
# Description: Parses the level JSON file, feeds the layout data to the global
#              GameManager, and coordinates gameplay states and signals.
#              SOLID Refactoring:
#              - SRP Refactoring (Step 3): Completely removed 3D mesh instantiating,
#                material compiling, and asset preloading. Delegated dynamically 
#                to LevelBuilder.
#              - SRP Refactoring (Step 1): Map validation delegated to MapValidator.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node3D
class_name LevelManager

# Preloaded assets for orchestrating scene-level BGM (SRP Compliance)
var bgm_stream : AudioStream = preload("res://assets/audio/bgm/level_1_bgm.mp3") 

# Active entities and players tracking
var player_instance : Player = null
var bgm_player : AudioStreamPlayer = null

var level_data : Dictionary = {}
var map_offset_x : float = 0.0
var map_offset_z : float = 0.0

func _ready() -> void:
	_connect_game_manager_signals()
	_setup_bgm() 
	
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

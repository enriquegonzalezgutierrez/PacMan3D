# ==============================================================================
# Description: Global singleton managing game state, score, lives, win/loss
#              conditions, and event signals. 
#              Phase 2 Update: Added dynamic difficulty scaling.
#              Phase 3 Update: Added secure, encrypted local high-score persistence 
#              (save/load) compatible with both PC and Android sandboxes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node

# Signals to communicate with the UI (HUD)
signal score_changed(new_score: int)
signal high_score_changed(new_high_score: int) # Notifies HUD when record is loaded/broken
signal lives_changed(new_lives: int)
signal game_over()
signal victory()

# Gameplay state signals
signal power_pellet_activated()
signal player_killed()

# Game State Variables
var score : int = 0
var high_score : int = 0 # Persistent record
var lives : int = 3
var total_pellets : int = 0
var pellets_eaten : int = 0

# Persistent progression tracking
var current_level : int = 1
var is_game_started : bool = false # Tracks if we are actively playing a session

# Grid layout cache for the 2D Minimap (Filled by LevelManager)
var level_layout : Array = []
var grid_width : int = 0
var grid_height : int = 0

# Secure Local Storage Configuration (Cross-Platform Sandbox paths)
const SAVE_PATH : String = "user://high_scores.dat"
const ENCRYPTION_KEY : String = "PacMan3D_SecureArcadeKey_9901"

func _ready() -> void:
	load_high_score() # Load previous record immediately on boot
	reset_game()

# Resets the game variables for a completely new playthrough
func reset_game() -> void:
	score = 0
	lives = 3
	total_pellets = 0
	pellets_eaten = 0
	current_level = 1 
	is_game_started = false # Reset session on game over or full restart
	
	# Defer the signal emissions until the node tree is fully ready
	call_deferred("_emit_initial_signals")

func _emit_initial_signals() -> void:
	score_changed.emit(score)
	high_score_changed.emit(high_score) # Dispatch the loaded record to the HUD
	lives_changed.emit(lives)

# Adds points and updates the HUD
func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)
	
	# Real-time record breaking feedback (LSP/OCP Compliance)
	if score > high_score:
		high_score = score
		high_score_changed.emit(high_score)

# Handles losing a life, emitting the reset signal, and checking for Game Over
func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	
	player_killed.emit()
	
	if lives <= 0:
		save_high_score() # Save current record on game over (optimized write frequency)
		game_over.emit()

# Called by the LevelManager or Pellets when they are spawned
func register_pellet() -> void:
	total_pellets += 1

# Called by the Player when eating a pellet
func pellet_eaten() -> void:
	pellets_eaten += 1
	add_score(10)
	
	if pellets_eaten >= total_pellets and total_pellets > 0:
		save_high_score() # Save current record on level victory
		victory.emit()

# Triggers the Frightened state for all ghosts
func activate_power_pellet() -> void:
	power_pellet_activated.emit()

# --- PHASE 2: ARCADE DIFFICULTY PROGRESSION MATH ---

# Increases ghost base speed by 5% per level (Level 1 = 1.0x, Level 5 = 1.20x)
func get_ghost_speed_multiplier() -> float:
	return 1.0 + ((current_level - 1) * 0.05)

# Reduces the frightened duration by 1 second per level (Level 1 = 7.0s, Minimum = 2.0s)
func get_frightened_duration() -> float:
	var duration : float = 7.0 - float(current_level - 1)
	return max(2.0, duration) # Caps the minimum duration to 2.0 seconds

# --- PHASE 3: SECURE PERSISTENT STORAGE SERIALIZER (PC & Android Compatible) ---

# Saves the high score to an encrypted binary file
func save_high_score() -> void:
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, ENCRYPTION_KEY)
	if file:
		file.store_32(high_score) # Save as an optimized 32-bit integer
		file.close()

# Loads and decrypts the high score on startup
func load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, ENCRYPTION_KEY)
		if file:
			high_score = file.get_32()
			file.close()
		else:
			# Decryption failed (file tampered with or corrupted). Reset record safely.
			high_score = 0
			save_high_score()
	else:
		high_score = 0

# Dynamic check to see if another procedural JSON level exists in the folder
func has_next_level() -> bool:
	var next_level_path = "res://data/level_%02d.json" % (current_level + 1)
	return FileAccess.file_exists(next_level_path)

# Advances state tracking variables to prepare for the next level load
func advance_level() -> void:
	current_level += 1
	total_pellets = 0
	pellets_eaten = 0

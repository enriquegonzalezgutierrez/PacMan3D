# ==============================================================================
# Description: Global singleton managing game state, score, lives, win/loss
#              conditions, and event signals. 
#              SOLID Refactoring:
#              - SRP Compliance: Session state management is fully separated 
#                from data persistence. Delegates all array sorting, binary 
#                encryption, and leaderboard logic to LeaderboardManager.
#              - Data Migration: Automatically migrates single high score saves 
#                from older versions (high_scores.dat) into the new Top 5 
#                Tournament Leaderboard on startup.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node

# Signals to communicate with the UI (HUD)
signal score_changed(new_score: int)
signal high_score_changed(new_high_score: int) 
signal lives_changed(new_lives: int)
signal game_over()
signal victory()

# Gameplay state signals
signal power_pellet_activated()
signal player_killed()

# Game State Variables
var score : int = 0
var high_score : int = 0 
var lives : int = 3
var total_pellets : int = 0
var pellets_eaten : int = 0

# Persistent progression tracking
var current_level : int = 1
var is_game_started : bool = false 

# Grid layout cache for the 2D Minimap
var level_layout : Array = []
var grid_width : int = 0
var grid_height : int = 0

# Local cache of the active Top 5 Leaderboard
var leaderboard_cache : Array[Dictionary] = []

# Legacy file configurations for automatic migration
const LEGACY_SAVE_PATH : String = "user://high_scores.dat"
const LEGACY_ENCRYPTION_KEY : String = "PacMan3D_SecureArcadeKey_9901"

func _ready() -> void:
	# 1. Migrate older high score files to the new leaderboard safely
	_migrate_legacy_save()
	
	# 2. Retrieve the active Top 5 leaderboard from storage (SRP Compliance)
	leaderboard_cache = LeaderboardManager.load_leaderboard()
	if leaderboard_cache.size() > 0:
		high_score = leaderboard_cache[0]["score"] # Top 1 is the active High Score
		
	reset_game()

# Resets the game variables for a completely new playthrough
func reset_game() -> void:
	score = 0
	lives = 3
	total_pellets = 0
	pellets_eaten = 0
	current_level = 1 
	is_game_started = false 
	
	call_deferred("_emit_initial_signals")

func _emit_initial_signals() -> void:
	score_changed.emit(score)
	high_score_changed.emit(high_score) 
	lives_changed.emit(lives)

# Adds points and updates the HUD
func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)
	
	# Real-time record breaking feedback
	if score > high_score:
		high_score = score
		high_score_changed.emit(high_score)

# Handles losing a life, emitting the reset signal, and checking for Game Over
func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	
	player_killed.emit()
	
	if lives <= 0:
		# GameManager no longer saves here. Saving is deferred to the 
		# Letter Wheel initials-input screen on Game Over if qualifying.
		game_over.emit()

func register_pellet() -> void:
	total_pellets += 1

func pellet_eaten() -> void:
	pellets_eaten += 1
	add_score(10)
	
	if pellets_eaten >= total_pellets and total_pellets > 0:
		# Save high score cache temporarily if broke record on victory
		if score >= high_score:
			_update_high_score_leaderboard_standby()
		victory.emit()

func activate_power_pellet() -> void:
	power_pellet_activated.emit()

# --- ARCADE DIFFICULTY PROGRESSION MATH ---

func get_ghost_speed_multiplier() -> float:
	return 1.0 + ((current_level - 1) * 0.05)

func get_frightened_duration() -> float:
	var duration : float = 7.0 - float(current_level - 1)
	return max(2.0, duration) 

# --- TOURNAMENT MODE LEADERBOARD API (SRP Compliance) ---

# Public query to check if current score qualifies for the local Top 5
func qualifies_for_leaderboard() -> bool:
	return LeaderboardManager.qualifies_for_leaderboard(score, leaderboard_cache)

# Commits player initials and score, re-sorting the cache and saving encrypted data
func submit_leaderboard_entry(initials: String) -> void:
	leaderboard_cache = LeaderboardManager.insert_entry(initials, score, leaderboard_cache)
	if leaderboard_cache.size() > 0:
		high_score = leaderboard_cache[0]["score"]
		high_score_changed.emit(high_score)

# Helper to automatically update top score on the fly during victories
func _update_high_score_leaderboard_standby() -> void:
	if leaderboard_cache.size() > 0:
		# Update the temporary first record as 'YOU' until final game over entry
		leaderboard_cache[0]["score"] = high_score
		LeaderboardManager.save_leaderboard(leaderboard_cache)

# --- AUTOMATIC DATA MIGRATION (DIP Compliance) ---

# Reads single high score saves from older versions and migrates them into the leaderboard
func _migrate_legacy_save() -> void:
	if FileAccess.file_exists(LEGACY_SAVE_PATH) and not FileAccess.file_exists(LeaderboardManager.SAVE_PATH):
		var legacy_score : int = 0
		var file := FileAccess.open_encrypted_with_pass(LEGACY_SAVE_PATH, FileAccess.READ, LEGACY_ENCRYPTION_KEY)
		if file:
			legacy_score = file.get_32()
			file.close()
			
		if legacy_score > 0:
			# Instantiate a default list and inject the legacy record as 'PAC' (Pac-Man)
			var base_list = LeaderboardManager.get_default_leaderboard()
			base_list.append({
				"name": "PAC",
				"score": legacy_score
			})
			base_list.sort_custom(func(a, b): return a["score"] > b["score"])
			if base_list.size() > LeaderboardManager.MAX_ENTRIES:
				base_list.resize(LeaderboardManager.MAX_ENTRIES)
				
			LeaderboardManager.save_leaderboard(base_list)
			
		# Delete legacy file to clean the sandbox directory
		DirAccess.remove_absolute(LEGACY_SAVE_PATH)

# --- PROGRESSION PATH ---

func has_next_level() -> bool:
	var next_level_path = "res://data/level_%02d.json" % (current_level + 1)
	return FileAccess.file_exists(next_level_path)

func advance_level() -> void:
	current_level += 1
	total_pellets = 0
	pellets_eaten = 0

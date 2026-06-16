# ==============================================================================
# Description: Global singleton managing game state, score, lives, win/loss
#              conditions, and event signals. Also stores the current level layout
#              matrix to allow HUD components (like the Minimap) to query it.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node

# Signals to communicate with the UI (HUD)
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal game_over()
signal victory()

# Gameplay state signals
signal power_pellet_activated()
signal player_killed()

# Game State Variables
var score : int = 0
var lives : int = 3
var total_pellets : int = 0
var pellets_eaten : int = 0

# Grid layout cache for the 2D Minimap (Filled by LevelManager)
var level_layout : Array = []
var grid_width : int = 0
var grid_height : int = 0

func _ready() -> void:
	reset_game()

# Resets the game variables for a new playthrough
func reset_game() -> void:
	score = 0
	lives = 3
	total_pellets = 0
	pellets_eaten = 0
	
	# Defer the signal emissions until the node tree is fully ready
	call_deferred("_emit_initial_signals")

func _emit_initial_signals() -> void:
	score_changed.emit(score)
	lives_changed.emit(lives)

# Adds points and updates the HUD
func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

# Handles losing a life, emitting the reset signal, and checking for Game Over
func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	
	player_killed.emit()
	
	if lives <= 0:
		game_over.emit()

# Called by the LevelManager or Pellets when they are spawned
func register_pellet() -> void:
	total_pellets += 1

# Called by the Player when eating a pellet
func pellet_eaten() -> void:
	pellets_eaten += 1
	add_score(10)
	
	if pellets_eaten >= total_pellets and total_pellets > 0:
		victory.emit()

# Triggers the Frightened state for all ghosts
func activate_power_pellet() -> void:
	power_pellet_activated.emit()

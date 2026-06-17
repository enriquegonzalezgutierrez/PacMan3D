# ==============================================================================
# Description: Handles the cinematic intro video playback and transitions
#              smoothly to the Main Menu scene once completed or skipped.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name IntroSplash

@onready var video_player : VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	# Enforce processing during transitions
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if is_instance_valid(video_player):
		video_player.finished.connect(_on_video_finished)
		video_player.play()

func _input(event: InputEvent) -> void:
	# Allow players to skip the intro video by pressing SPACE, ESC or tapping the screen
	var is_skipped : bool = false
	
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE:
			is_skipped = true
	elif event is InputEventScreenTouch and event.pressed:
		is_skipped = true
		
	if is_skipped:
		_transition_to_menu()

func _on_video_finished() -> void:
	_transition_to_menu()

func _transition_to_menu() -> void:
	# Disable inputs to prevent multiple duplicate transition triggers
	set_process_input(false)
	
	if is_instance_valid(video_player):
		video_player.stop()
		
	# Instantly transition to the main scene containing the HUD and Main Menu
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")

# ==============================================================================
# Description: Handles the cinematic intro video playback and transitions 
#              smoothly to the Main Menu scene once completed or skipped.
#              SOLID Refactoring & Feature Update:
#              - Intro Audio Support (SRP): Programmatically instantiates and 
#                plays the main menu BGM track during video playback, ensuring 
#                clean audio termination on transition to prevent overlap bugs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name IntroSplash

@onready var video_player : VideoStreamPlayer = $VideoStreamPlayer
var intro_audio : AudioStreamPlayer

func _ready() -> void:
	# Enforce processing during initial load transitions
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Programmatically configure and play the intro soundtrack (SRP Compliance)
	_setup_intro_audio()
	
	if is_instance_valid(video_player):
		video_player.finished.connect(_on_video_finished)
		video_player.play()

# Programmatically configures and plays the intro soundtrack
func _setup_intro_audio() -> void:
	intro_audio = AudioStreamPlayer.new()
	
	# Load main_menu_bgm as the introductory theme
	var bgm_stream = load("res://assets/audio/bgm/main_menu_bgm.mp3")
	if bgm_stream:
		intro_audio.stream = bgm_stream
		intro_audio.volume_db = -8.0 # Comfortable volume level
		add_child(intro_audio)
		intro_audio.play()

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

# Cleans up audio and video players before changing scene (DIP Compliance)
func _transition_to_menu() -> void:
	# Disable inputs to prevent multiple duplicate transition triggers
	set_process_input(false)
	
	# Safely stop and terminate audio/video emitters
	if is_instance_valid(video_player):
		video_player.stop()
		
	if is_instance_valid(intro_audio):
		intro_audio.stop()
		intro_audio.queue_free()
		
	# Instantly transition to the main scene containing the HUD and Main Menu
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")

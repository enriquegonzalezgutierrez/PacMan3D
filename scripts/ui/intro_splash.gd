# ==============================================================================
# Description: Handles the cinematic intro video playback and transitions 
#              smoothly to the Main Menu scene once completed or skipped.
#              SOLID Refactoring & Feature Update:
#              - Seamless Persistent Audio (SRP): Delegated background music 
#                playback to the global AudioManager autoload. The music is 
#                no longer stopped during transition, allowing it to continue 
#                seamlessly into the Main Menu.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name IntroSplash

@onready var video_player : VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	# Enforce processing during initial load transitions
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Programmatically request AudioManager to play the menu BGM (DIP Compliance)
	_setup_persistent_intro_audio()
	
	if is_instance_valid(video_player):
		video_player.finished.connect(_on_video_finished)
		video_player.play()

# Requests the global AudioManager singleton to start playing the menu theme
func _setup_persistent_intro_audio() -> void:
	var bgm_stream = load("res://assets/audio/bgm/main_menu_bgm.mp3")
	if bgm_stream and AudioManager:
		# Start playing on the persistent global channel (no restart on transition!)
		AudioManager.play_bgm(bgm_stream, -8.0)

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

# Cleans up only the video player, letting the music play uninterrupted (DIP Compliance)
func _transition_to_menu() -> void:
	# Disable inputs to prevent multiple duplicate transition triggers
	set_process_input(false)
	
	# Stop the video player
	if is_instance_valid(video_player):
		video_player.stop()
		
	# Instantly transition to the main scene containing the HUD and Main Menu
	# Notice: We DO NOT stop AudioManager, allowing the soundtrack to flow beautifully.
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")

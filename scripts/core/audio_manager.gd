# ==============================================================================
# Description: Global Persistent Audio Manager (Autoload Singleton).
#              Manages global background music playbacks, transitions, and 
#              prevents tracks from restarting during scene loads.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted all global background music and bus 
#                routing logic from local scenes into a single persistent singleton.
#              - DIP Compliance: Exposes simple public APIs so any scene 
#                (Intro, MainMenu, LevelManager) can request audio changes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node

# Persistent BGM Player sitting in the root of the Engine tree
var bgm_player : AudioStreamPlayer

func _ready() -> void:
	# Enforce persistent processing during any pause states
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_bgm_player()

func _initialize_bgm_player() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "GlobalBGMPlayer"
	
	# Verify and create the native "Music" bus if not present yet
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx == -1:
		AudioServer.add_bus()
		music_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_idx, "Music")
		
	bgm_player.bus = "Music"
	add_child(bgm_player)

# Plays a background music stream. 
# If the requested song is ALREADY playing, it seamlessly continues without restarting!
func play_bgm(stream: AudioStream, volume_db: float = -8.0) -> void:
	if not stream:
		return
		
	# --- SEAMLESS TRANSITION CHECK ---
	# If the same soundtrack is already playing, do absolutely nothing!
	if bgm_player.stream == stream and bgm_player.playing:
		# Gradually adjust volume if requested, but do not restart the playback coordinates
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", volume_db, 0.5)
		return
		
	# New song requested: Stop, load, and play
	bgm_player.stop()
	bgm_player.stream = stream
	bgm_player.volume_db = volume_db
	bgm_player.play()

# Stops the active background music instantly
func stop_bgm() -> void:
	if bgm_player:
		bgm_player.stop()

# Smoothly fades out the volume to -40dB before stopping
func fade_out_bgm(duration: float = 1.5) -> void:
	if bgm_player and bgm_player.playing:
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -40.0, duration)
		tween.tween_callback(stop_bgm)

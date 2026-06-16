# ==============================================================================
# Description: Lightweight Label3D component that displays a 3D score value 
#              floating upwards in world space, smoothly fading out over time.
#              SOLID Refactoring:
#              - SRP: Completely isolated class dedicated to rendering and
#                animating local 3D floating visual labels (Pac-Mania style).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Label3D
class_name FloatingScore3D

# Animation parameters
const RISE_SPEED : float = 2.0 # Speed at which the text floats upwards
const FADE_SPEED : float = 1.8 # Speed of transparency fading

func _ready() -> void:
	# Enable automatic billboarding so the text always faces the active camera
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Design configuration
	text = "200" # Classic Pac-Man score reward for eating ghosts
	pixel_size = 0.012 # Adjust size to look crisp and clear in 3D space
	modulate = Color(1.0, 1.0, 1.0, 1.0) # Bright white color
	outline_modulate = Color(0.0, 0.0, 0.0, 1.0) # Black outline for maximum readability
	
	# Safety cleanup timer: guarantees node removal even if frame updates stall
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): queue_free())

func _process(delta: float) -> void:
	# 1. Float upwards on the vertical Y axis
	global_position.y += RISE_SPEED * delta
	
	# 2. Smoothly fade transparency out
	var alpha : float = modulate.a - (FADE_SPEED * delta)
	if alpha <= 0.0:
		queue_free()
	else:
		modulate.a = alpha

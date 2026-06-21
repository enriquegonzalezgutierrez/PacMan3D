# ==============================================================================
# Description: Lightweight Label3D component that displays a 3D score value 
#              floating upwards in world space, smoothly fading out over time.
#              Phase 4 Update (Extreme Performance):
#              - Replaced queue_free() with process-halting logic so the 
#                VFXPoolManager can recycle and reuse these instances indefinitely.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Label3D
class_name FloatingScore3D

const RISE_SPEED : float = 2.0 
const FADE_SPEED : float = 1.8 

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size = 0.012 
	outline_modulate = Color(0.0, 0.0, 0.0, 1.0) 
	
	if text == "":
		text = "200"

func _process(delta: float) -> void:
	# 1. Float upwards
	global_position.y += RISE_SPEED * delta
	
	# 2. Smoothly fade transparency out
	var alpha : float = modulate.a - (FADE_SPEED * delta)
	
	if alpha <= 0.0:
		# --- POOL RECYCLING (Phase 4) ---
		# Instead of destroying the node (queue_free), we just hide it and 
		# stop its process loop. The VFXPoolManager will wake it up later!
		visible = false
		set_process(false)
	else:
		modulate.a = alpha

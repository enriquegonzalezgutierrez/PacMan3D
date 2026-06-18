# ==============================================================================
# Description: Independent tracking Camera3D. Handles specialized diorama 
#              view perspective optics, steep tilt angles, and smooth position 
#              interpolation (drag/inertia damping) relative to the Player.
#              SOLID Refactoring & Visual Fixes:
#              - Calibrated Diometric Perspective: Adjusted height and distance 
#                offsets to pull the viewport slightly further back and up, 
#                enhancing tactical corridor awareness while fully showcasing 
#                MartínMan's 3D running model.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Camera3D
class_name DioramaCamera

# Configuration constants matching optimized diorama optics (Diometric Calibration)
const CAMERA_FOV : float = 42.0 # Narrower FOV for flat, high-contrast isometric looks
const CAMERA_OFFSET := Vector3(0.0, 13.0, 11.0) # Pulled back and up slightly for better awareness
const CAMERA_ROTATION_DEGREES := Vector3(-50.0, 0.0, 0.0) # Calibrated angle for final framing
const LERP_WEIGHT : float = 0.08 # Main camera damping follow speed
const SNAP_THRESHOLD : float = 15.0 # Max distance before snapping instantly

# Immersive Animation Parameters
const LEAD_DISTANCE : float = 1.4 
const BOBBING_AMPLITUDE : float = 0.10 
const BOBBING_SPEED : float = 1.2 
var time_passed : float = 0.0

# Dynamic dampening state
var current_lead_offset : Vector3 = Vector3.ZERO
var player_target : Node3D = null

# Cinematic Screen Shake State
var shake_intensity : float = 0.0
var shake_duration : float = 0.0
var max_shake_duration : float = 1.0

func _ready() -> void:
	add_to_group("camera") 
	
	# Configure visual perspective optics procedurally on startup
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = CAMERA_FOV
	rotation_degrees = CAMERA_ROTATION_DEGREES
	current = true
	
	# Unparent the camera's spatial transform from its spawning parent (decouples rotation)
	top_level = true
	time_passed = randf_range(0.0, 5.0)
	
	_find_player_target()

# Public API to trigger cinematic screen impacts from external orchestrators (DIP Compliance)
func trigger_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration
	max_shake_duration = max(0.01, duration)

# Dynamic search to find the active player target in the scene group
func _find_player_target() -> void:
	player_target = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_target):
		_find_player_target()
		return
		
	time_passed += delta
	
	# 1. Calculate Stabilized Dynamic Look-Ahead (Lead-In)
	var target_lead := Vector3.ZERO
	if "current_direction" in player_target and player_target.current_direction != Vector3.ZERO:
		target_lead = player_target.current_direction * LEAD_DISTANCE
		
	current_lead_offset = current_lead_offset.lerp(target_lead, 0.05)
		
	# 2. Calculate Cinematic Drone Bobbing (Gentle 10cm float)
	var bobbing_y : float = sin(time_passed * BOBBING_SPEED) * BOBBING_AMPLITUDE
	
	# Assemble final target position
	var target_pos : Vector3 = player_target.global_position + CAMERA_OFFSET + current_lead_offset
	target_pos.y += bobbing_y
	
	# If the distance is too large (teleport/respawn), snap instantly
	if global_position.distance_to(target_pos) > SNAP_THRESHOLD:
		global_position = target_pos
		current_lead_offset = target_lead 
	else:
		# Smooth spatial damping follow
		global_position = global_position.lerp(target_pos, LERP_WEIGHT)
		
	# 3. Calculate Cinematic Screen Shake decay
	if shake_duration > 0.0:
		shake_duration -= delta
		
		var decay_ratio : float = clampf(shake_duration / max_shake_duration, 0.0, 1.0)
		var current_intensity : float = shake_intensity * (decay_ratio * decay_ratio)
		
		var shake_offset = Vector3(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		
		global_position += shake_offset
	else:
		shake_intensity = 0.0

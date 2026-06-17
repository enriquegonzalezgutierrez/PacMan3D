# ==============================================================================
# Description: Independent tracking Camera3D. Handles specialized diorama 
#              view perspective optics, steep tilt angles, and smooth position 
#              interpolation (drag/inertia damping) relative to the Player.
#              SOLID Refactoring & Polish:
#              - NAUSEA-FREE LEAD INTERPOLATION: Swapped velocity tracking with 
#                Pac-Man's stable current_direction vector, and isolated the 
#                lead-offset into its own heavy LERP loop (0.05) to eliminate 
#                jitter, sudden snaps, and camera motion sickness.
#              - PROCEDURAL DRONE BOBBING: Subtle vertical hover float.
#              Phase 2 Updates:
#              - CINEMATIC SCREEN SHAKE: Added an exponential decaying camera 
#                shake displacement offset to add weight to eating ghosts or dying.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Camera3D
class_name DioramaCamera

# Configuration constants matching optimized diorama optics
const CAMERA_FOV : float = 48.0
const CAMERA_OFFSET := Vector3(0.0, 15.0, 6.0)
const CAMERA_ROTATION_DEGREES := Vector3(-68.0, 0.0, 0.0)
const LERP_WEIGHT : float = 0.08 # Main camera damping follow speed
const SNAP_THRESHOLD : float = 15.0 # Max distance before snapping instantly

# Immersive Animation Parameters (SRP/Juice Compliance)
const LEAD_DISTANCE : float = 1.4 # Sized subtly to prevent viewport whiplash
const BOBBING_AMPLITUDE : float = 0.10 # Gentle 10cm vertical float
const BOBBING_SPEED : float = 1.2 # Speed of the hovering drone bob
var time_passed : float = 0.0

# Dynamic dampening state
var current_lead_offset : Vector3 = Vector3.ZERO
var player_target : Node3D = null

# Cinematic Screen Shake State (Phase 2 Compliance)
var shake_intensity : float = 0.0
var shake_duration : float = 0.0
var max_shake_duration : float = 1.0

func _ready() -> void:
	add_to_group("camera") # Added to global group for loose coupling lookup
	
	# Configure visual perspective optics procedurally on startup
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = CAMERA_FOV
	rotation_degrees = CAMERA_ROTATION_DEGREES
	current = true
	
	# Unparent the camera's spatial transform from its spawning parent (decouples rotation)
	top_level = true
	
	# Randomize first bob phase to prevent robotic startup
	time_passed = randf_range(0.0, 5.0)
	
	_find_player_target()

# Public API to trigger cinematic screen impacts from external orchestrators (DIP Compliance)
func trigger_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration
	max_shake_duration = max(0.01, duration) # Avoid division by zero

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
	# Query Pac-Man's stable current_direction to prevent velocity stutter noise (SRP/OCP Compliance)
	if "current_direction" in player_target and player_target.current_direction != Vector3.ZERO:
		target_lead = player_target.current_direction * LEAD_DISTANCE
		
	# Independently LERP the lead offset with a low weight (0.05) to guarantee buttery-smooth, nausea-free transitions
	current_lead_offset = current_lead_offset.lerp(target_lead, 0.05)
		
	# 2. Calculate Cinematic Drone Bobbing (Gentle 10cm float)
	var bobbing_y : float = sin(time_passed * BOBBING_SPEED) * BOBBING_AMPLITUDE
	
	# Assemble final target position
	var target_pos : Vector3 = player_target.global_position + CAMERA_OFFSET + current_lead_offset
	target_pos.y += bobbing_y
	
	# If the distance is too large (teleport/respawn), snap instantly
	if global_position.distance_to(target_pos) > SNAP_THRESHOLD:
		global_position = target_pos
		current_lead_offset = target_lead # Reset offset instantly
	else:
		# Smooth spatial damping follow
		global_position = global_position.lerp(target_pos, LERP_WEIGHT)
		
	# 3. Calculate Cinematic Screen Shake decay (Phase 2 Compliance)
	if shake_duration > 0.0:
		shake_duration -= delta
		
		# Exponential decay multiplier based on remaining lifetime
		var decay_ratio : float = clampf(shake_duration / max_shake_duration, 0.0, 1.0)
		var current_intensity : float = shake_intensity * (decay_ratio * decay_ratio)
		
		var shake_offset = Vector3(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		
		# Apply shake directly on top of the damped position to preserve crisp frequency
		global_position += shake_offset
	else:
		shake_intensity = 0.0

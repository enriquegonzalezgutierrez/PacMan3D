# ==============================================================================
# Description: Independent tracking Camera3D. Handles specialized diorama 
#              view perspective optics, steep tilt angles, and smooth position 
#              interpolation (drag/inertia damping) relative to the Player.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted camera physics, optic properties, 
#                and tracking routines completely out of the player controller.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Camera3D
class_name DioramaCamera

# Configuration constants matching optimized diorama optics
const CAMERA_FOV : float = 48.0
const CAMERA_OFFSET := Vector3(0.0, 15.0, 6.0)
const CAMERA_ROTATION_DEGREES := Vector3(-68.0, 0.0, 0.0)
const LERP_WEIGHT : float = 0.08 # Damping weight for buttery-smooth follow
const SNAP_THRESHOLD : float = 15.0 # Max distance before snapping instantly (prevents lagging on respawn)

var player_target : Node3D = null

func _ready() -> void:
	# Configure visual perspective optics procedurally on startup
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = CAMERA_FOV
	rotation_degrees = CAMERA_ROTATION_DEGREES
	current = true
	
	# Unparent the camera's spatial transform from its spawning parent (decouples rotation)
	top_level = true
	
	_find_player_target()

# Dynamic search to find the active player target in the scene group
func _find_player_target() -> void:
	player_target = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player_target):
		_find_player_target()
		return
		
	# Target spatial position based on the dynamic offset
	var target_pos : Vector3 = player_target.global_position + CAMERA_OFFSET
	
	# If the distance is too large (e.g. player teleport or respawn), snap instantly
	if global_position.distance_to(target_pos) > SNAP_THRESHOLD:
		global_position = target_pos
	else:
		# Otherwise, follow with elegant, smooth spatial damping inertia
		global_position = global_position.lerp(target_pos, LERP_WEIGHT)

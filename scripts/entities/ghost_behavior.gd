# ==============================================================================
# Description: Base class (Strategy Pattern) for Ghost targeting behaviors.
#              Enables strict adherence to SOLID Open/Closed Principle (OCP).
#              Updates: Added virtual hooks for customized character-specific 
#                       mesh proportions, pupil offsets, and accessories to 
#                       comply with SRP, OCP, and LSP.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name GhostBehavior

# Virtual method to be overridden by specific ghost behavior subclasses
# Returns the 3D target coordinate that the ghost should navigate towards
func get_target_position(ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		return player.global_position
	return ghost.global_position

# --- VIRTUAL GRAPHICS HOOKS (SRP / OCP / LSP Compliance) ---

# Overridden by subclasses to define their unique physical radius proportions
func get_capsule_radius() -> float:
	return 0.9 # Default standard radius

# Overridden by subclasses to define their unique physical height proportions
func get_capsule_height() -> float:
	return 1.8 # Default standard height

# Overridden by subclasses to offset pupil centers dynamically (e.g. cross-eyed or sad gazes)
func get_pupil_offsets() -> Dictionary:
	return {
		"left": Vector3(-0.35, 0.4, -0.93),
		"right": Vector3(0.35, 0.4, -0.93)
	}

# Overridden by subclasses to procedurally construct and parent visual accessories
func attach_custom_decorations(_visual_mesh: MeshInstance3D) -> void:
	pass # Optional hook (e.g. Pinky's bow ribbon)

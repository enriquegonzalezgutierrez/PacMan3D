# ==============================================================================
# Description: Base class (Strategy Pattern) for Ghost targeting behaviors.
#              Enables strict adherence to SOLID Open/Closed Principle (OCP).
#              SOLID Refactoring:
#              - OCP Compliance: Added the `get_scatter_target` virtual method. 
#                This entirely removes the massive switch/match statements inside 
#                ghost.gd, allowing each behavior strategy to dictate its own 
#                retreat corner dynamically.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name GhostBehavior

# --- VIRTUAL TARGETING HOOKS ---

# Returns the 3D target coordinate that the ghost should navigate towards during CHASE state
func get_target_position(ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		return player.global_position
	return ghost.global_position

# Returns the 3D target coordinate for the SCATTER state (retreat to corners)
func get_scatter_target(grid_width: int, grid_height: int, cell_size: float) -> Vector3:
	# Default fallback: Top-Left corner
	var offset_x = (float(grid_width) * cell_size) / 2.0
	var offset_z = (float(grid_height) * cell_size) / 2.0
	var min_x = cell_size - offset_x + (cell_size / 2.0)
	var min_z = cell_size - offset_z + (cell_size / 2.0)
	
	return Vector3(min_x, 0.9, min_z)


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
	pass # Optional hook (e.g. Pinky's bow ribbon, Blinky's horns)

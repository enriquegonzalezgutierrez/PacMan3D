# ==============================================================================
# Description: Flanker/Tactician behavior strategy for Inky (Cyan).
#              Implements SOLID Open/Closed Principle (OCP).
#              SOLID Refactoring:
#              - DIP Compliance: Removed iterative tree lookups for "Blinky". 
#                Inky now expects a loosely-coupled `squad_leader` Node3D to 
#                calculate flank positions, decoupling the behavior from specific names.
#              - Scatter Target Hook: Inky now defines his own retreat corner 
#                (Bottom-Right) directly within his strategy object.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name InkyBehavior

# Injected dependency for flanking calculations
var squad_leader : Node3D = null

# --- TARGETING OVERRIDES ---

# Inky uses the Squad Leader's position and the player's position to flank the player
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player and is_instance_valid(squad_leader):
		var vec_to_player : Vector3 = player.global_position - squad_leader.global_position
		return player.global_position + vec_to_player
	elif player:
		return player.global_position
	return _ghost.global_position

# Inky retreats to the Bottom-Right corner of the maze
func get_scatter_target(grid_width: int, grid_height: int, cell_size: float) -> Vector3:
	var offset_x = (float(grid_width) * cell_size) / 2.0
	var offset_z = (float(grid_height) * cell_size) / 2.0
	var max_x = (float(grid_width - 2) * cell_size) - offset_x + (cell_size / 2.0)
	var max_z = (float(grid_height - 2) * cell_size) - offset_z + (cell_size / 2.0)
	
	return Vector3(max_x, 0.9, max_z)


# --- GRAPHICS OVERRIDES (SRP/OCP/LSP Compliance) ---

func get_capsule_radius() -> float:
	return 1.0 # Stubby

func get_capsule_height() -> float:
	return 1.55 # Short

func get_pupil_offsets() -> Dictionary:
	return {
		"left": Vector3(-0.23, 0.4, -0.93),
		"right": Vector3(0.23, 0.4, -0.93)
	}

# Procedurally builds and attaches the sideways cyberpunk baseball cap
func attach_custom_decorations(visual_mesh: MeshInstance3D) -> void:
	var cap_holder := Node3D.new()
	
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.0, 0.8, 1.0) 
	cap_mat.emission_enabled = true
	cap_mat.emission = Color(0.0, 0.4, 0.8) 
	cap_mat.roughness = 0.1
	
	var capsule_height = get_capsule_height()
	
	# Cap Crown
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.46
	crown_mesh.height = 0.28
	
	var crown := MeshInstance3D.new()
	crown.mesh = crown_mesh
	crown.material_override = cap_mat
	crown.position = Vector3(0.0, capsule_height / 2.0 - 0.02, 0.0)
	cap_holder.add_child(crown)
	
	# Visor / Bill
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.6, 0.04, 0.35)
	
	var visor := MeshInstance3D.new()
	visor.mesh = visor_mesh
	visor.material_override = cap_mat
	visor.position = Vector3(0.18, capsule_height / 2.0 - 0.04, -0.42)
	visor.rotation_degrees = Vector3(-10.0, -35.0, -15.0) 
	cap_holder.add_child(visor)
	
	visual_mesh.add_child(cap_holder)

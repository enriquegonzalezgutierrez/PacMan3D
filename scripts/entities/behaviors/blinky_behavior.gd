# ==============================================================================
# Description: Direct Chaser behavior strategy for Blinky (Red).
#              Implements SOLID Open/Closed Principle (OCP).
#              SOLID Refactoring:
#              - Scatter Target Hook: Blinky now defines his own retreat corner 
#                (Top-Right) directly within his strategy object.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name BlinkyBehavior

# --- TARGETING OVERRIDES ---

# Blinky always targets the player's exact direct position
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		return player.global_position
	return _ghost.global_position

# Blinky retreats to the Top-Right corner of the maze
func get_scatter_target(grid_width: int, grid_height: int, cell_size: float) -> Vector3:
	var offset_x = (float(grid_width) * cell_size) / 2.0
	var offset_z = (float(grid_height) * cell_size) / 2.0
	var max_x = (float(grid_width - 2) * cell_size) - offset_x + (cell_size / 2.0)
	var min_z = cell_size - offset_z + (cell_size / 2.0)
	
	return Vector3(max_x, 0.9, min_z)


# --- GRAPHICS OVERRIDES (SRP/OCP/LSP Compliance) ---

func get_capsule_radius() -> float:
	return 0.88 # Aggressive streamlined shell

func get_capsule_height() -> float:
	return 1.8 # Tall standing height

# Procedurally builds and attaches the glowing red-orange devil horns
func attach_custom_decorations(visual_mesh: MeshInstance3D) -> void:
	var horns_holder := Node3D.new()
	
	# Glowing Fire-Orange/Red material
	var horn_mat := StandardMaterial3D.new()
	horn_mat.albedo_color = Color(1.0, 0.15, 0.0) # Bright neon orange-red
	horn_mat.emission_enabled = true
	horn_mat.emission = Color(1.0, 0.05, 0.0) # Intense glow
	horn_mat.roughness = 0.1
	
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0 # Creates a perfect cone
	cone_mesh.bottom_radius = 0.09
	cone_mesh.height = 0.35
	cone_mesh.radial_segments = 8
	
	# Left Horn
	var left_horn := MeshInstance3D.new()
	left_horn.mesh = cone_mesh
	left_horn.material_override = horn_mat
	left_horn.position = Vector3(-0.32, get_capsule_height() / 2.0 + 0.08, -0.15)
	left_horn.rotation_degrees = Vector3(15.0, 0.0, 20.0) 
	horns_holder.add_child(left_horn)
	
	# Right Horn
	var right_horn := MeshInstance3D.new()
	right_horn.mesh = cone_mesh
	right_horn.material_override = horn_mat
	right_horn.position = Vector3(0.32, get_capsule_height() / 2.0 + 0.08, -0.15)
	right_horn.rotation_degrees = Vector3(15.0, 0.0, -20.0)
	horns_holder.add_child(right_horn)
	
	visual_mesh.add_child(horns_holder)

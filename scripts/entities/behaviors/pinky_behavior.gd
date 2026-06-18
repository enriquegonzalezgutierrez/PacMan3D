# ==============================================================================
# Description: Ambusher behavior strategy for Pinky (Pink).
#              Implements SOLID Open/Closed Principle (OCP).
#              SOLID Refactoring:
#              - Scatter Target Hook: Pinky now defines her own retreat corner 
#                (Top-Left) directly within her strategy object.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name PinkyBehavior

# --- TARGETING OVERRIDES ---

# Pinky targets 8 meters (4 grid tiles) ahead of the player's current moving direction
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		var player_dir : Vector3 = player.velocity.normalized()
		if player_dir != Vector3.ZERO:
			return player.global_position + (player_dir * 8.0)
		return player.global_position
	return _ghost.global_position

# Pinky retreats to the Top-Left corner of the maze
func get_scatter_target(grid_width: int, grid_height: int, cell_size: float) -> Vector3:
	var offset_x = (float(grid_width) * cell_size) / 2.0
	var offset_z = (float(grid_height) * cell_size) / 2.0
	var min_x = cell_size - offset_x + (cell_size / 2.0)
	var min_z = cell_size - offset_z + (cell_size / 2.0)
	
	return Vector3(min_x, 0.9, min_z)


# --- GRAPHICS OVERRIDES (SRP/OCP/LSP Compliance) ---

func get_capsule_radius() -> float:
	return 0.82 # Slender, elegant shell

func get_capsule_height() -> float:
	return 1.95 # Tall height

# Procedurally builds and attaches the glowing hot-pink 3D ribbon bow
func attach_custom_decorations(visual_mesh: MeshInstance3D) -> void:
	var bow_holder := Node3D.new()
	
	var bow_mat := StandardMaterial3D.new()
	bow_mat.albedo_color = Color(1.0, 0.1, 0.5) 
	bow_mat.emission_enabled = true
	bow_mat.emission = Color(1.0, 0.0, 0.4)
	bow_mat.roughness = 0.1
	
	var capsule_height = get_capsule_height()
	
	# Center Knot
	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 0.04
	torus_mesh.outer_radius = 0.09
	
	var knot := MeshInstance3D.new()
	knot.mesh = torus_mesh
	knot.material_override = bow_mat
	knot.position = Vector3(0.0, capsule_height / 2.0 + 0.08, 0.1) 
	knot.rotation_degrees.x = 90.0
	bow_holder.add_child(knot)
	
	var loop_mesh := CylinderMesh.new()
	loop_mesh.top_radius = 0.0 
	loop_mesh.bottom_radius = 0.12
	loop_mesh.height = 0.25
	loop_mesh.radial_segments = 8
	
	# Left Loop 
	var left_loop := MeshInstance3D.new()
	left_loop.mesh = loop_mesh
	left_loop.material_override = bow_mat
	left_loop.position = Vector3(-0.15, capsule_height / 2.0 + 0.08, 0.1)
	left_loop.rotation_degrees = Vector3(0.0, 0.0, -70.0) 
	bow_holder.add_child(left_loop)
	
	# Right Loop 
	var right_loop := MeshInstance3D.new()
	right_loop.mesh = loop_mesh
	right_loop.material_override = bow_mat
	right_loop.position = Vector3(0.15, capsule_height / 2.0 + 0.08, 0.1)
	right_loop.rotation_degrees = Vector3(0.0, 0.0, 70.0) 
	bow_holder.add_child(right_loop)
	
	visual_mesh.add_child(bow_holder)

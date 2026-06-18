# ==============================================================================
# Description: Cowardly/Wanderer behavior strategy for Clyde (Orange).
#              Implements SOLID Open/Closed Principle (OCP).
#              SOLID Refactoring:
#              - Scatter Target Hook: Clyde now defines his own retreat corner 
#                (Bottom-Left) directly within his strategy object.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name ClydeBehavior

# --- TARGETING OVERRIDES ---

# Clyde targets player if far away, but runs back to spawn corner if too close
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		var dist_to_player : float = _ghost.global_position.distance_to(player.global_position)
		if dist_to_player > 14.0: # 7 tiles away
			return player.global_position
		
		# If too close, target own spawn corner (retrieved dynamically)
		if "spawn_position" in _ghost:
			return _ghost.spawn_position
		return _ghost.global_position
	return _ghost.global_position

# Clyde retreats to the Bottom-Left corner of the maze
func get_scatter_target(grid_width: int, grid_height: int, cell_size: float) -> Vector3:
	var offset_x = (float(grid_width) * cell_size) / 2.0
	var offset_z = (float(grid_height) * cell_size) / 2.0
	var min_x = cell_size - offset_x + (cell_size / 2.0)
	var max_z = (float(grid_height - 2) * cell_size) - offset_z + (cell_size / 2.0)
	
	return Vector3(min_x, 0.9, max_z)


# --- GRAPHICS OVERRIDES (SRP/OCP/LSP Compliance) ---

func get_capsule_radius() -> float:
	return 1.05 # Plump

func get_capsule_height() -> float:
	return 1.65 # Round

func get_pupil_offsets() -> Dictionary:
	return {
		"left": Vector3(-0.35, 0.32, -0.93),
		"right": Vector3(0.35, 0.32, -0.93)
	}

# Procedurally builds and attaches the robotic neon-orange antenna
func attach_custom_decorations(visual_mesh: MeshInstance3D) -> void:
	var antenna_holder := Node3D.new()
	
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.08, 0.08, 0.1) 
	shaft_mat.roughness = 0.6
	shaft_mat.metallic = 0.5
	
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(1.0, 0.5, 0.0) 
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(1.0, 0.35, 0.0) 
	tip_mat.roughness = 0.1
	
	var capsule_height = get_capsule_height()
	
	# Antenna Shaft
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.015
	shaft_mesh.bottom_radius = 0.025
	shaft_mesh.height = 0.4
	shaft_mesh.radial_segments = 6
	
	var shaft := MeshInstance3D.new()
	shaft.mesh = shaft_mesh
	shaft.material_override = shaft_mat
	shaft.position = Vector3(0.0, capsule_height / 2.0 + 0.18, 0.0)
	shaft.rotation_degrees = Vector3(15.0, 0.0, 0.0) 
	antenna_holder.add_child(shaft)
	
	# Antenna Tip
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.08
	sphere_mesh.height = 0.16
	
	var tip := MeshInstance3D.new()
	tip.mesh = sphere_mesh
	tip.material_override = tip_mat
	tip.position = Vector3(0.0, capsule_height / 2.0 + 0.36, 0.09)
	antenna_holder.add_child(tip)
	
	visual_mesh.add_child(antenna_holder)

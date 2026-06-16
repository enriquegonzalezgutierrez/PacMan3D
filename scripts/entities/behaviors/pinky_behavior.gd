# ==============================================================================
# Description: Ambusher behavior strategy for Pinky (Pink).
#              Implements SOLID Open/Closed Principle (OCP).
#              Updates: Overrode visual hooks to make Pinky slender and 
#                       attach a procedural pink head bow.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name PinkyBehavior

# Pinky targets 8 meters (4 grid tiles) ahead of the player's current moving direction
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		var player_dir : Vector3 = player.velocity.normalized()
		if player_dir != Vector3.ZERO:
			return player.global_position + (player_dir * 8.0)
		return player.global_position
	return _ghost.global_position

# --- GRAPHICS OVERRIDES (SRP/OCP/LSP Compliance) ---

func get_capsule_radius() -> float:
	return 0.82 # Slender

func get_capsule_height() -> float:
	return 1.95 # Tall

func attach_custom_decorations(visual_mesh: MeshInstance3D) -> void:
	var bow_holder := Node3D.new()
	
	var bow_mat := StandardMaterial3D.new()
	bow_mat.albedo_color = Color(1.0, 0.4, 0.6) # Neon pink bow
	bow_mat.roughness = 0.3
	
	var bow_sphere_mesh := SphereMesh.new()
	bow_sphere_mesh.radius = 0.18
	bow_sphere_mesh.height = 0.36
	
	var left_bow := MeshInstance3D.new()
	left_bow.mesh = bow_sphere_mesh
	left_bow.material_override = bow_mat
	left_bow.position = Vector3(-0.15, get_capsule_height() / 2.0 + 0.08, 0.0)
	bow_holder.add_child(left_bow)
	
	var right_bow := MeshInstance3D.new()
	right_bow.mesh = bow_sphere_mesh
	right_bow.material_override = bow_mat
	right_bow.position = Vector3(0.15, get_capsule_height() / 2.0 + 0.08, 0.0)
	bow_holder.add_child(right_bow)
	
	visual_mesh.add_child(bow_holder)

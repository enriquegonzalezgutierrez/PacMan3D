# ==============================================================================
# Description: Flanker/Tactician behavior strategy for Inky (Cyan).
#              Implements SOLID Open/Closed Principle (OCP).
#              Phase 4 Updates:
#              - SIDEWAYS CYBER CAP: Programmatically builds a cool sideways 
#                cyberpunk baseball cap on Inky's head composed of a squashed 
#                SphereMesh crown and a flat, multi-axis tilted BoxMesh visor.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name InkyBehavior

# Inky uses Blinky's position and the player's position to flank the player
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		var blinky : Node3D = null
		var ghosts = _ghost.get_tree().get_nodes_in_group("ghosts")
		
		for g in ghosts:
			if g is Ghost and g.ghost_type == "Blinky":
				blinky = g
				break
		
		if blinky:
			var vec_to_player : Vector3 = player.global_position - blinky.global_position
			return player.global_position + vec_to_player
		return player.global_position
	return _ghost.global_position

# --- GRAPHICS OVERRIDES (SRP/OCP/LSP Compliance) ---

func get_capsule_radius() -> float:
	return 1.0 # Stubby

func get_capsule_height() -> float:
	return 1.55 # Short

func get_pupil_offsets() -> Dictionary:
	# Shift both pupil offsets inward to look cross-eyed/derpy (SRP/OCP Compliance)
	return {
		"left": Vector3(-0.23, 0.4, -0.93),
		"right": Vector3(0.23, 0.4, -0.93)
	}

# Procedurally builds and attaches the sideways cyberpunk baseball cap
func attach_custom_decorations(visual_mesh: MeshInstance3D) -> void:
	var cap_holder := Node3D.new()
	
	# Electric Cyan neon material
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.0, 0.8, 1.0) # Saturated electric cyan
	cap_mat.emission_enabled = true
	cap_mat.emission = Color(0.0, 0.4, 0.8) # Cyan glow
	cap_mat.roughness = 0.1
	
	var capsule_height = get_capsule_height()
	
	# 1. Cap Crown (Squashed sphere sitting flush on top of head)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.46
	crown_mesh.height = 0.28
	
	var crown := MeshInstance3D.new()
	crown.mesh = crown_mesh
	crown.material_override = cap_mat
	crown.position = Vector3(0.0, capsule_height / 2.0 - 0.02, 0.0)
	cap_holder.add_child(crown)
	
	# 2. Visor / Bill (Flat box rotated diagonally on three axes)
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.6, 0.04, 0.35)
	
	var visor := MeshInstance3D.new()
	visor.mesh = visor_mesh
	visor.material_override = cap_mat
	visor.position = Vector3(0.18, capsule_height / 2.0 - 0.04, -0.42)
	visor.rotation_degrees = Vector3(-10.0, -35.0, -15.0) # Tilted sideways and slightly downwards
	cap_holder.add_child(visor)
	
	visual_mesh.add_child(cap_holder)

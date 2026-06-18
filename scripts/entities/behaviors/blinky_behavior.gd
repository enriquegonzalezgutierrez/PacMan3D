# ==============================================================================
# Description: Direct Chaser behavior strategy for Blinky (Red).
#              Implements SOLID Open/Closed Principle (OCP).
#              Phase 4 Updates:
#              - NEON DEVIL HORNS: Programmatically attaches two glowing red-orange 
#                devil horns (CylinderMesh as Cone) onto Blinky's head to visually represent 
#                his aggressive chaser personality.
#              - CONEMESH COMPATIBILITY FIX: Replaced obsolete 'ConeMesh' with native 
#                Godot 4 'CylinderMesh' (top_radius = 0.0) to prevent parser compile errors.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name BlinkyBehavior

# Blinky always targets the player's exact direct position
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		return player.global_position
	return _ghost.global_position

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
	
	# CylinderMesh configured as a Cone (top_radius = 0.0) to resolve compile errors in Godot 4
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0 # Creates a perfect cone
	cone_mesh.bottom_radius = 0.09
	cone_mesh.height = 0.35
	cone_mesh.radial_segments = 8
	
	# 1. Left Horn (Positioned left-front, angled outwards and forwards)
	var left_horn := MeshInstance3D.new()
	left_horn.mesh = cone_mesh
	left_horn.material_override = horn_mat
	left_horn.position = Vector3(-0.32, get_capsule_height() / 2.0 + 0.08, -0.15)
	left_horn.rotation_degrees = Vector3(15.0, 0.0, 20.0) # Angle forward and out
	horns_holder.add_child(left_horn)
	
	# 2. Right Horn (Positioned right-front, angled outwards and forwards)
	var right_horn := MeshInstance3D.new()
	right_horn.mesh = cone_mesh
	right_horn.material_override = horn_mat
	right_horn.position = Vector3(0.32, get_capsule_height() / 2.0 + 0.08, -0.15)
	right_horn.rotation_degrees = Vector3(15.0, 0.0, -20.0) # Angle forward and out
	horns_holder.add_child(right_horn)
	
	visual_mesh.add_child(horns_holder)

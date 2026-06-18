# ==============================================================================
# Description: Ambusher behavior strategy for Pinky (Pink).
#              Implements SOLID Open/Closed Principle (OCP).
#              Phase 4 Updates:
#              - GLOWING 3D RIBBON BOW: Re-engineered her bow to be a high-fidelity 
#                3D structure composed of a Torus center knot and two inclined 
#                loops of fluorescent hot-pink neon.
#              - TORUS COMPATIBILITY FIX: Removed manual segment counts on TorusMesh 
#                to leverage Godot 4's native smooth defaults and prevent cross-version 
#                parser errors.
#              - CONEMESH COMPATIBILITY FIX: Replaced obsolete 'ConeMesh' with native 
#                Godot 4 'CylinderMesh' (top_radius = 0.0) to prevent parser compile errors.
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
	return 0.82 # Slender, elegant shell

func get_capsule_height() -> float:
	return 1.95 # Tall height

# Procedurally builds and attaches the glowing hot-pink 3D ribbon bow
func attach_custom_decorations(visual_mesh: MeshInstance3D) -> void:
	var bow_holder := Node3D.new()
	
	# Fluorescent Hot-Pink neon material
	var bow_mat := StandardMaterial3D.new()
	bow_mat.albedo_color = Color(1.0, 0.1, 0.5) # Glowing hot pink
	bow_mat.emission_enabled = true
	bow_mat.emission = Color(1.0, 0.0, 0.4) # Neon emission
	bow_mat.roughness = 0.1
	
	var capsule_height = get_capsule_height()
	
	# 1. Center Knot (Thin Torus standing vertically pointing front-back)
	# Fixed: Removed manual segment assignments to guarantee cross-version compilation
	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 0.04
	torus_mesh.outer_radius = 0.09
	
	var knot := MeshInstance3D.new()
	knot.mesh = torus_mesh
	knot.material_override = bow_mat
	knot.position = Vector3(0.0, capsule_height / 2.0 + 0.08, 0.1) # Positioned on top-back head
	knot.rotation_degrees.x = 90.0
	bow_holder.add_child(knot)
	
	# CylinderMesh configured as a Cone (top_radius = 0.0) to resolve compile errors in Godot 4
	var loop_mesh := CylinderMesh.new()
	loop_mesh.top_radius = 0.0 # Creates a perfect cone
	loop_mesh.bottom_radius = 0.12
	loop_mesh.height = 0.25
	loop_mesh.radial_segments = 8
	
	# 2. Left Loop (Cone pointed left)
	var left_loop := MeshInstance3D.new()
	left_loop.mesh = loop_mesh
	left_loop.material_override = bow_mat
	left_loop.position = Vector3(-0.15, capsule_height / 2.0 + 0.08, 0.1)
	left_loop.rotation_degrees = Vector3(0.0, 0.0, -70.0) # Angled left-upwards
	bow_holder.add_child(left_loop)
	
	# 3. Right Loop (Cone pointed right)
	var right_loop := MeshInstance3D.new()
	right_loop.mesh = loop_mesh
	right_loop.material_override = bow_mat
	right_loop.position = Vector3(0.15, capsule_height / 2.0 + 0.08, 0.1)
	right_loop.rotation_degrees = Vector3(0.0, 0.0, 70.0) # Angled right-upwards
	bow_holder.add_child(right_loop)
	
	visual_mesh.add_child(bow_holder)

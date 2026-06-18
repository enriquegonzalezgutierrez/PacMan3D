# ==============================================================================
# Description: Procedural 3D Mesh Builder for Ghosts.
#              Assembles the procedural capsule, retro eyes, wavy skirt, and 
#              calls the strategy pattern to attach custom decorations.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted entirely from ghost.gd. This class 
#                is strictly responsible for the 3D visual generation, completely 
#                decoupling graphics from AI and physics logic.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name GhostVisualBuilder

# Assembles the ghost's 3D components and returns the dynamic node references 
# needed by ghost.gd for procedural animations.
static func build_visuals(ghost: CharacterBody3D, strategy: GhostBehavior, original_material: StandardMaterial3D) -> Dictionary:
	var visual_mesh = MeshInstance3D.new()
	var collision_shape = CollisionShape3D.new()
	
	# 1. Query dynamic visual specifications from the Strategy (OCP/SRP Compliance)
	var radius : float = 0.9
	var height : float = 1.8
	
	if strategy:
		radius = strategy.get_capsule_radius()
		height = strategy.get_capsule_height()
		
	# 2. Main Capsule Body
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = radius
	capsule_mesh.height = height
	visual_mesh.mesh = capsule_mesh
	
	if not original_material:
		original_material = StandardMaterial3D.new()
		original_material.albedo_color = Color(1.0, 0.0, 0.0)
		original_material.roughness = 0.2
		
	visual_mesh.material_override = original_material
	
	# 3. Procedural Retro Ghost Eyes
	var eyes_holder = Node3D.new()
	
	var sclera_mat := StandardMaterial3D.new()
	sclera_mat.albedo_color = Color(1.0, 1.0, 1.0) # Pure White Sclera
	sclera_mat.roughness = 0.6
	
	var pupil_mat := StandardMaterial3D.new()
	pupil_mat.albedo_color = Color(0.0, 0.2, 1.0) # Classic Blue pupils
	pupil_mat.roughness = 0.4
	
	# Default forward pupil offsets on face
	var pupil_left_pos := Vector3(-0.35, 0.4, -0.75 - radius * 0.2)
	var pupil_right_pos := Vector3(0.35, 0.4, -0.75 - radius * 0.2)
	
	if strategy:
		var custom_offsets : Dictionary = strategy.get_pupil_offsets()
		pupil_left_pos = custom_offsets.get("left", pupil_left_pos)
		pupil_right_pos = custom_offsets.get("right", pupil_right_pos)
	
	var sclera_mesh := SphereMesh.new()
	sclera_mesh.radius = 0.2
	sclera_mesh.height = 0.4
	
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.08
	pupil_mesh.height = 0.16
	
	# Left Eye
	var left_sclera := MeshInstance3D.new()
	left_sclera.mesh = sclera_mesh
	left_sclera.material_override = sclera_mat
	left_sclera.position = Vector3(-0.35, 0.4, -0.75) 
	eyes_holder.add_child(left_sclera)
	
	var left_pupil := MeshInstance3D.new()
	left_pupil.mesh = pupil_mesh
	left_pupil.material_override = pupil_mat
	left_pupil.position = pupil_left_pos
	eyes_holder.add_child(left_pupil)
	
	# Right Eye
	var right_sclera := MeshInstance3D.new()
	right_sclera.mesh = sclera_mesh
	right_sclera.material_override = sclera_mat
	right_sclera.position = Vector3(0.35, 0.4, -0.75)
	eyes_holder.add_child(right_sclera)
	
	var right_pupil := MeshInstance3D.new()
	right_pupil.mesh = pupil_mesh
	right_pupil.material_override = pupil_mat
	right_pupil.position = pupil_right_pos
	eyes_holder.add_child(right_pupil)
	
	visual_mesh.add_child(eyes_holder)
	
	# 4. Procedural Retro Wavy Skirt
	var skirt_spheres : Array[MeshInstance3D] = []
	var skirt_radius : float = 0.28
	var skirt_mesh := SphereMesh.new()
	skirt_mesh.radius = skirt_radius
	skirt_mesh.height = skirt_radius * 2.0
	
	var skirt_base_y = -height / 2.0
	var skirt_offsets = [
		Vector3(-radius * 0.5, skirt_base_y, 0.0),
		Vector3(radius * 0.5, skirt_base_y, 0.0),
		Vector3(0.0, skirt_base_y, -radius * 0.5),
		Vector3(0.0, skirt_base_y, radius * 0.5)
	]
	
	for offset in skirt_offsets:
		var sphere := MeshInstance3D.new()
		sphere.mesh = skirt_mesh
		sphere.material_override = original_material 
		sphere.position = offset
		visual_mesh.add_child(sphere) 
		skirt_spheres.append(sphere)
		
	# 5. Procedural Accessories Attachment
	if strategy:
		strategy.attach_custom_decorations(visual_mesh)
	
	# 6. Physical Collision Shape
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height
	collision_shape.shape = capsule_shape
	
	# Attach components to the active Ghost node
	ghost.add_child(visual_mesh)
	ghost.add_child(collision_shape)
	
	# Return references needed for animation (hovering, blinking, waving)
	return {
		"visual_mesh": visual_mesh,
		"eyes_holder": eyes_holder,
		"skirt_spheres": skirt_spheres,
		"capsule_height": height
	}

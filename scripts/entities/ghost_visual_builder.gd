# ==============================================================================
# Description: Procedural 3D Mesh and CPUParticle Builder for Ghosts (Ciber-Molinos).
#              SOLID Refactoring & Visual Fixes:
#              - Giant Scale Up Fix: Increased visual scale to 1.75x to match 
#                MartínMan's proportions and give them an imponent presence.
#              - Material Sync: Returns the compiled PBR textured material.
#              - Console Cleanup: Removed all diagnostic tree printing logs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name GhostVisualBuilder

# Assembles the ghost's 3D components and returns the dynamic node references
static func build_visuals(ghost: CharacterBody3D, strategy: GhostBehavior, original_material: StandardMaterial3D, ghost_type: String) -> Dictionary:
	var visual_mesh : Node3D = null
	var collision_shape = CollisionShape3D.new()
	
	# Default standard dimensions
	var radius : float = 0.6
	var height : float = 1.7
	
	if strategy:
		radius = strategy.get_capsule_radius()
		height = strategy.get_capsule_height()
		
	# 1. Programmatically load and instantiate the correct Ciber-Molino FBX model
	var model_name : String = ghost_type.to_lower()
	var character_path : String = "res://assets/models/ghosts/" + model_name + "/" + model_name + ".fbx"
	
	if ResourceLoader.exists(character_path):
		var character_scene = load(character_path) as PackedScene
		if character_scene:
			visual_mesh = character_scene.instantiate()
			
	# Defensive Fallback: If FBX is missing, fallback to a standard low-poly capsule
	if not is_instance_valid(visual_mesh):
		visual_mesh = MeshInstance3D.new()
		var fallback_mesh := CapsuleMesh.new()
		fallback_mesh.radius = radius
		fallback_mesh.height = height
		visual_mesh.mesh = fallback_mesh
		if original_material:
			visual_mesh.material_override = original_material
			
	# 2. Programmatically compile the PBR material from Meshy AI texture maps (SRP Compliance)
	var pbr_material := StandardMaterial3D.new()
	pbr_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Unshaded for glowing neon details!
	
	# Dynamically scan the textures folder to load textures regardless of dynamic filename indices
	_load_textures_for_ghost(model_name, pbr_material)
	
	# Recursively map our compiled PBR material onto all internal mesh surfaces
	_apply_material_recursive(visual_mesh, pbr_material)
	
	# Scale up to a massive 1.75x to match the new giant 1080p proportions
	visual_mesh.scale = Vector3(1.75, 1.75, 1.75)
	
	# Find where the Skeleton3D actually lives inside the instantiated scene
	var blades_node = _find_blades_node_recursive(visual_mesh)
	
	# 4. Attach the color-matched base thruster exhaust CPUParticles3D
	var particle_color = original_material.albedo_color if original_material else Color(1.0, 0.0, 0.0)
	var thruster_emitter = _build_thruster_particles(particle_color)
	visual_mesh.add_child(thruster_emitter)
	thruster_emitter.emitting = true
	
	# 5. Programmatically compile the Physics Capsule collider
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height
	collision_shape.shape = capsule_shape
	
	# Attach components to the active Ghost node
	ghost.add_child(visual_mesh)
	ghost.add_child(collision_shape)
	
	return {
		"visual_mesh": visual_mesh,
		"blades_node": blades_node,
		"capsule_height": height,
		"compiled_material": pbr_material
	}

# Helper to recursively apply flat materials to nested MeshInstance3D nodes inside the FBX
static func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material_recursive(child, material)

# Scan and apply textures dynamically based on file system directories (DIP Compliance)
static func _load_and_apply_texture(target_mat: StandardMaterial3D, folder_path: String, type: String) -> void:
	if not DirAccess.dir_exists_absolute(folder_path):
		return
		
	var dir = DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.ends_with(".import"):
				var name_lower : String = file_name.to_lower()
				var is_match : bool = false
				
				# Filter for specific texture type (e.g. metallic, normal, roughness, or base color)
				if type == "albedo" and "metallic" not in name_lower and "normal" not in name_lower and "roughness" not in name_lower:
					if "texture" in name_lower or "albedo" in name_lower or "diffuse" in name_lower:
						is_match = true
				elif type == "metallic" and "metallic" in name_lower:
					is_match = true
				elif type == "normal" and "normal" in name_lower:
					is_match_detected = true
				elif type == "roughness" and "roughness" in name_lower:
					is_match = true
					
				if is_match:
					var full_tex_path = folder_path + file_name
					var tex = load(full_tex_path) as Texture2D
					if tex:
						apply_texture_channel(target_mat, tex, type)
						break
			file_name = dir.get_next()
		dir.list_dir_end()

static var is_match_detected : bool = false

static func apply_texture_channel(mat: StandardMaterial3D, tex: Texture2D, type: String) -> void:
	match type:
		"albedo": mat.albedo_texture = tex
		"metallic":
			mat.metallic = 1.0
			mat.metallic_texture = tex
		"roughness": mat.roughness_texture = tex
		"normal":
			mat.normal_enabled = true
			mat.normal_texture = tex

# Autonomous Directory Texture Loader (DIP Compliance)
# Scans the textures/ folder, identifies maps, and binds them cleanly to the material
static func _load_textures_for_ghost(ghost_name: String, target_mat: StandardMaterial3D) -> void:
	var path = "res://assets/models/ghosts/" + ghost_name + "/textures/"
	_load_and_apply_texture(target_mat, path, "albedo")
	_load_and_apply_texture(target_mat, path, "metallic")
	_load_and_apply_texture(target_mat, path, "roughness")
	_load_and_apply_texture(target_mat, path, "normal")

# Recursive helper to locate the independent blades/propeller mesh
static func _find_blades_node_recursive(node: Node) -> Node3D:
	var name_lower = node.name.to_lower()
	if node is MeshInstance3D and ("1" in node.name or "blade" in name_lower or "propeller" in name_lower or "part" in name_lower):
		return node
	for child in node.get_children():
		var found = _find_blades_node_recursive(child)
		if found:
			return found
	return null

# Compiles a gorgeous downward rocket jet stream (Juice Compliance)
static func _build_thruster_particles(color: Color) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	
	emitter.mesh = mesh
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.10
	emitter.direction = Vector3.DOWN 
	emitter.spread = 15.0 
	emitter.initial_velocity_min = 2.0
	emitter.initial_velocity_max = 4.0
	emitter.gravity = Vector3(0.0, -9.8, 0.0) 
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = curve
	
	emitter.amount = 8 
	emitter.lifetime = 0.3
	emitter.position = Vector3(0.0, -0.4, 0.0) 
	
	return emitter

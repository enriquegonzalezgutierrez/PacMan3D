# ==============================================================================
# Description: Procedural 3D Mesh and CPUParticle Builder for Ghosts (Ciber-Molinos).
#              SOLID Refactoring & Android Optimization:
#              - Static Path Loader (DIP): Loads standardized texture filenames 
#                ('albedo.png', 'normal.png', etc.) directly from disk. 
#                This completely bypasses Android's DirAccess limitations, 
#                guaranteeing 100% cross-platform compatibility.
#              - Giant Scale Up: Increased visual scale to 1.5x.
#              - Propeller Extractor: Locates the independent blades node recursively.
#              - Base Thruster Exhaust (VFX): Attaches a color-matched jet stream.
#              - DIP Compliance: Receives a pre-cached PackedScene representation 
#                of its specific 3D model, eliminating disk hits during runtime 
#                instantiation.
#              - Performance Telemetry: Integrated class-level static counters 
#                to log cache status on the first spawn without flooding the logs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name GhostVisualBuilder

# Static Telemetry Counters (Optimization Verification)
static var cache_hits : int = 0
static var cache_misses : int = 0

# Assembles the ghost's 3D components and returns the dynamic node references
static func build_visuals(ghost: CharacterBody3D, strategy: GhostBehavior, original_material: StandardMaterial3D, ghost_type: String, preloaded_scene: PackedScene = null) -> Dictionary:
	var visual_mesh : Node3D = null
	var collision_shape = CollisionShape3D.new()
	var model_name : String = ghost_type.to_lower()
	
	# Default standard dimensions
	var radius : float = 0.6
	var height : float = 1.7
	
	if strategy:
		radius = strategy.get_capsule_radius()
		height = strategy.get_capsule_height()
		
	# --- DIP / CACHING IMPLEMENTATION ---
	# Instantiate from memory if cache is injected; execute fallback load from disk otherwise
	if preloaded_scene:
		visual_mesh = preloaded_scene.instantiate()
		
		# Telemetry check: log first cache hit
		GhostVisualBuilder.cache_hits += 1
		if GhostVisualBuilder.cache_hits == 1:
			print("[CACHE STATUS] GhostVisualBuilder: First cache HIT verified successfully!")
	else:
		var character_path : String = "res://assets/models/ghosts/" + model_name + "/" + model_name + ".fbx"
		if ResourceLoader.exists(character_path):
			var character_scene = load(character_path) as PackedScene
			if character_scene:
				visual_mesh = character_scene.instantiate()
				
		# Telemetry check: log first cache miss
		GhostVisualBuilder.cache_misses += 1
		if GhostVisualBuilder.cache_misses == 1:
			print("[CACHE STATUS] GhostVisualBuilder: First cache MISS detected (loading fallback from disk)!")
			
	# Defensive Fallback: If FBX is missing, fallback to a standard low-poly capsule
	if not is_instance_valid(visual_mesh):
		visual_mesh = MeshInstance3D.new()
		var fallback_mesh := CapsuleMesh.new()
		fallback_mesh.radius = radius
		fallback_mesh.height = height
		visual_mesh.mesh = fallback_mesh
		if original_material:
			visual_mesh.material_override = original_material
			
	# 2. Programmatically compile the PBR material from the new clean texture paths (SRP Compliance)
	var pbr_material := StandardMaterial3D.new()
	pbr_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Unshaded for glowing neon details!
	
	# --- STATIC STABLE PATH LOADING ---
	# Uses explicit non-scanning paths for 100% Android compile compatibility
	var tex_dir : String = "res://assets/models/ghosts/" + model_name + "/textures/"
	
	if ResourceLoader.exists(tex_dir + "albedo.png"):
		pbr_material.albedo_texture = load(tex_dir + "albedo.png") as Texture2D
	if ResourceLoader.exists(tex_dir + "metallic.png"):
		pbr_material.metallic = 1.0
		pbr_material.metallic_texture = load(tex_dir + "metallic.png") as Texture2D
	if ResourceLoader.exists(tex_dir + "roughness.png"):
		pbr_material.roughness_texture = load(tex_dir + "roughness.png") as Texture2D
	if ResourceLoader.exists(tex_dir + "normal.png"):
		pbr_material.normal_enabled = true
		pbr_material.normal_texture = load(tex_dir + "normal.png") as Texture2D
	
	# Recursively map our compiled PBR material onto all internal mesh surfaces
	_apply_material_recursive(visual_mesh, pbr_material)
	
	# Scale up to a massive 1.5x to match the new giant proportions
	visual_mesh.scale = Vector3(1.5, 1.5, 1.5)
	
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
	
	# Attach components to the ghost
	ghost.add_child(visual_mesh)
	ghost.add_child(collision_shape)
	
	return {
		"visual_mesh": visual_mesh,
		"blades_node": blades_node,
		"capsule_height": height,
		"compiled_material": pbr_material
	}

# Helper to recursively apply PBR materials to nested MeshInstance3D nodes inside the FBX
static func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material_recursive(child, material)

# Recursive helper to find the blades structure within the mesh
static func _find_blades_node_recursive(node: Node) -> Node3D:
	if node is MeshInstance3D and node.name.begins_with("blades"):
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

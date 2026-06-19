# ==============================================================================
# Description: Code-Only 3D Character and Animation Assembler for MartínMan.
#              SOLID Refactoring & Visual Fixes:
#              - Rigged Mesh Swapping: Upgraded the loader to instantiate the 
#                base mesh directly from animations/idle.fbx.
#              - Static Path Loader (DIP): Updated texture paths to read the newly 
#                renamed 'albedo.png', 'normal.png', etc. directly from disk. 
#                This guarantees 100% texture rendering on Android mobile APKs.
#              - Visual Scaling Fix: Programmatically scaled up the 3D character 
#                mesh by 1.75x to fit the 2-meter corridors.
#              - DIP Compliance: Implements compile_animation_library() to precompile 
#                all skeletal bone track paths into a single reusable RAM library, 
#                rebuilding the player natively during level start without T-poses 
#                or dynamic disk loading stalls.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name PlayerVisualBuilder

# Compiles MartínMan's meshes, materials, and registers the 5 Mixamo animations code-only
static func build_visuals(player: CharacterBody3D, _player_material: StandardMaterial3D, precompiled_anim_library: AnimationLibrary = null) -> Dictionary:
	var visual_mesh : Node3D = null
	var collision_shape := CollisionShape3D.new()
	var anim_player := AnimationPlayer.new()
	
	# 1. Programmatically load and instantiate MartínMan's rigged model (using idle.fbx)
	var character_path := "res://assets/models/player/animations/idle.fbx"
	if ResourceLoader.exists(character_path):
		var character_scene = load(character_path) as PackedScene
		if character_scene:
			visual_mesh = character_scene.instantiate()
	
	# Defensive Fallback: If idle.fbx is missing, fallback to a standard low-poly capsule
	if not is_instance_valid(visual_mesh):
		visual_mesh = MeshInstance3D.new()
		var fallback_mesh := CapsuleMesh.new()
		fallback_mesh.radius = 0.6
		fallback_mesh.height = 1.7
		visual_mesh.mesh = fallback_mesh
		
	# 2. Programmatically compile the PBR material from the new clean texture paths (DIP Compliance)
	var pbr_material := StandardMaterial3D.new()
	pbr_material.roughness = 0.5 
	
	var texture_base_path := "res://assets/models/player/textures/"
	
	# Load Albedo
	if ResourceLoader.exists(texture_base_path + "albedo.png"):
		pbr_material.albedo_texture = load(texture_base_path + "albedo.png") as Texture2D
		
	# Load Metallic
	if ResourceLoader.exists(texture_base_path + "metallic.png"):
		pbr_material.metallic = 1.0 
		pbr_material.metallic_texture = load(texture_base_path + "metallic.png") as Texture2D
		
	# Load Roughness
	if ResourceLoader.exists(texture_base_path + "roughness.png"):
		pbr_material.roughness_texture = load(texture_base_path + "roughness.png") as Texture2D
		
	# Load Normal detail map
	if ResourceLoader.exists(texture_base_path + "normal.png"):
		pbr_material.normal_enabled = true
		pbr_material.normal_texture = load(texture_base_path + "normal.png") as Texture2D
		
	# Recursively map our compiled PBR material onto all internal mesh surfaces
	_apply_material_recursive(visual_mesh, pbr_material)
	
	# 3. Attach the programmatically generated AnimationPlayer
	anim_player.name = "AnimationPlayer"
	visual_mesh.add_child(anim_player)
	
	# Find where the Skeleton3D actually lives inside the instantiated scene
	var skeleton = _find_skeleton(visual_mesh)
	var skeleton_relative_path : String = ""
	if skeleton:
		skeleton_relative_path = str(visual_mesh.get_path_to(skeleton))
		
	# --- DIP / CACHING IMPLEMENTATION ---
	if precompiled_anim_library:
		# Direct registration from pre-compiled RAM cache (0ms cost!)
		anim_player.add_animation_library("", precompiled_anim_library)
		print("[CACHE STATUS] PlayerVisualBuilder: Injected AnimationLibrary attached successfully!")
	else:
		# Fallback dynamic compilation on the fly (original logic)
		var anim_base_dir := "res://assets/models/player/animations/"
		_load_and_register_animation(anim_player, anim_base_dir + "idle.fbx", "idle", skeleton_relative_path)
		_load_and_register_animation(anim_player, anim_base_dir + "running.fbx", "running", skeleton_relative_path)
		_load_and_register_animation(anim_player, anim_base_dir + "jump.fbx", "jump", skeleton_relative_path)
		_load_and_register_animation(anim_player, anim_base_dir + "falling.fbx", "falling", skeleton_relative_path)
		_load_and_register_animation(anim_player, anim_base_dir + "death.fbx", "death", skeleton_relative_path)
		
		# Set up standard loop modes for continuous animations (Godot 4 API)
		if anim_player.has_animation("idle"):
			anim_player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		if anim_player.has_animation("running"):
			anim_player.get_animation("running").loop_mode = Animation.LOOP_LINEAR
		if anim_player.has_animation("falling"):
			anim_player.get_animation("falling").loop_mode = Animation.LOOP_LINEAR
		
	# Rotate the character mesh 180 degrees so he faces forward along the Z running axis
	visual_mesh.rotation_degrees.y = 180.0
	
	# Programmatically scales the 3D mesh by 1.75x to match the physical arena size
	visual_mesh.scale = Vector3(1.75, 1.75, 1.75)
	
	# 5. Programmatically compile the Physics Capsule collider
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.55
	capsule_shape.height = 1.70
	collision_shape.shape = capsule_shape
	collision_shape.position.y = 0.0 
	
	# Attach components to the player
	player.add_child(visual_mesh)
	player.add_child(collision_shape)
	
	return {
		"visual_mesh": visual_mesh,
		"anim_player": anim_player
	}

# Compiles and remaps all 5 dynamic Mixamo animations into a single reusable AnimationLibrary (SOLID DIP)
static func compile_animation_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var skeleton_relative_path : String = ""
	var character_path := "res://assets/models/player/animations/idle.fbx"
	
	# Resolve the skeleton relative path from a temporary instance
	if ResourceLoader.exists(character_path):
		var temp_instance = load(character_path).instantiate()
		var skeleton = _find_skeleton(temp_instance)
		if skeleton:
			skeleton_relative_path = str(temp_instance.get_path_to(skeleton))
		temp_instance.queue_free()
		
	# Compile and remap the 5 animations into the library
	var anim_base_dir := "res://assets/models/player/animations/"
	_load_and_remap_to_library(library, anim_base_dir + "idle.fbx", "idle", skeleton_relative_path)
	_load_and_remap_to_library(library, anim_base_dir + "running.fbx", "running", skeleton_relative_path)
	_load_and_remap_to_library(library, anim_base_dir + "jump.fbx", "jump", skeleton_relative_path)
	_load_and_remap_to_library(library, anim_base_dir + "falling.fbx", "falling", skeleton_relative_path)
	_load_and_remap_to_library(library, anim_base_dir + "death.fbx", "death", skeleton_relative_path)
	
	# Set up standard loop modes for continuous animations (Godot 4 API)
	if library.has_animation("idle"):
		library.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	if library.has_animation("running"):
		library.get_animation("running").loop_mode = Animation.LOOP_LINEAR
	if library.has_animation("falling"):
		library.get_animation("falling").loop_mode = Animation.LOOP_LINEAR
		
	return library

# Internal helper to extract, clone, and remap tracks from an FBX scene into a shared library
static func _load_and_remap_to_library(library: AnimationLibrary, fbx_path: String, anim_key: String, skeleton_relative_path: String) -> void:
	if not ResourceLoader.exists(fbx_path):
		return
		
	var anim_scene = load(fbx_path) as PackedScene
	if anim_scene:
		var temp_instance = anim_scene.instantiate()
		var temp_player = temp_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
		
		if temp_player and temp_player.get_animation_list().size() > 0:
			var raw_anim_name = temp_player.get_animation_list()[0]
			var anim_resource = temp_player.get_animation(raw_anim_name).duplicate() as Animation # Duplicate to prevent shared mutations
			
			# --- BONE TRACK REMAPPER ---
			# Dynamically rewrites track paths to match MartínMan's actual skeleton path (e.g. RootNode/Skeleton3D)
			if skeleton_relative_path != "":
				for track_idx in range(anim_resource.get_track_count()):
					var path = anim_resource.track_get_path(track_idx)
					var path_str = str(path)
					if ":" in path_str:
						var split = path_str.split(":")
						var bone_part = split[1]
						var new_path = skeleton_relative_path + ":" + bone_part
						anim_resource.track_set_path(track_idx, NodePath(new_path))
						
			library.add_animation(anim_key, anim_resource)
			
		temp_instance.queue_free()

# Helper to recursively apply PBR materials to nested MeshInstance3D nodes inside the FBX
static func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material_recursive(child, material)

# Recursive helper to find the real Skeleton3D node inside MartínMan
static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var sk = _find_skeleton(child)
		if sk:
			return sk
	return null

# Code-only FBX Animation Extractor (SRP Compliance)
# Instantiates the FBX, steals its skeletal Animation Resource, and registers it cleanly
static func _load_and_register_animation(target_player: AnimationPlayer, fbx_path: String, anim_key: String, skeleton_relative_path: String) -> void:
	if not ResourceLoader.exists(fbx_path):
		return
		
	var anim_scene = load(fbx_path) as PackedScene
	if anim_scene:
		var temp_instance = anim_scene.instantiate()
		var temp_player = temp_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
		
		if temp_player and temp_player.get_animation_list().size() > 0:
			var raw_anim_name = temp_player.get_animation_list()[0]
			var anim_resource = temp_player.get_animation(raw_anim_name)
			
			# --- BONE TRACK REMAPPER ---
			# Dynamically rewrites track paths to match MartínMan's actual skeleton path (e.g. RootNode/Skeleton3D)
			if skeleton_relative_path != "":
				for track_idx in range(anim_resource.get_track_count()):
					var path = anim_resource.track_get_path(track_idx)
					var path_str = str(path)
					if ":" in path_str:
						var split = path_str.split(":")
						var bone_part = split[1]
						var new_path = skeleton_relative_path + ":" + bone_part
						anim_resource.track_set_path(track_idx, NodePath(new_path))
			
			# Create or retrieve the unnamed default AnimationLibrary ("")
			var library : AnimationLibrary
			if target_player.has_animation_library(""):
				library = target_player.get_animation_library("")
			else:
				library = AnimationLibrary.new()
				target_player.add_animation_library("", library)
				
			# Safely inject the extracted and remapped Mixamo animation track into the library
			library.add_animation(anim_key, anim_resource)
			
		temp_instance.queue_free() # Clean up temporary node immediately


# ==============================================================================
# --- HIGH PERFORMANCE CPUPARTICLES GENERATORS (Platform Agnostic) ---
# ==============================================================================

static func build_power_particles() -> CPUParticles3D:
	var power_particles := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(1.0, 0.8, 0.0) 
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = p_mat
	
	power_particles.mesh = mesh
	power_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	power_particles.emission_sphere_radius = 0.5
	power_particles.direction = Vector3.UP
	power_particles.spread = 45.0
	power_particles.initial_velocity_min = 1.0
	power_particles.initial_velocity_max = 2.0
	power_particles.gravity = Vector3(0.0, -2.0, 0.0)
	power_particles.amount = 12 
	power_particles.lifetime = 0.5
	power_particles.position = Vector3(0.0, 0.1, 0.0) 
	return power_particles

static func build_speed_particles() -> CPUParticles3D:
	var speed_particles := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.0, 1.0, 1.0) 
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	p_mat.emission_enabled = true
	p_mat.emission = Color(0.0, 0.8, 1.0) 
	mesh.material = p_mat
	
	speed_particles.mesh = mesh
	speed_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	speed_particles.emission_sphere_radius = 0.65
	speed_particles.direction = Vector3.UP
	speed_particles.spread = 180.0
	speed_particles.initial_velocity_min = 2.0
	speed_particles.initial_velocity_max = 4.0
	speed_particles.gravity = Vector3(0.0, 1.5, 0.0) 
	speed_particles.amount = 12 
	speed_particles.lifetime = 0.4
	speed_particles.position = Vector3(0.0, 0.1, 0.0)
	return speed_particles

static func build_motion_trail() -> CPUParticles3D:
	var motion_trail := CPUParticles3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.14
	sphere_mesh.height = 0.28
	
	var trail_mat := StandardMaterial3D.new()
	trail_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.albedo_color = Color(1.0, 1.0, 0.0)
	trail_mat.emission_enabled = true
	trail_mat.emission = Color(0.5, 0.5, 0.0)
	
	sphere_mesh.material = trail_mat
	motion_trail.mesh = sphere_mesh
	motion_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motion_trail.emission_sphere_radius = 0.15
	motion_trail.direction = Vector3.ZERO
	motion_trail.gravity = Vector3.ZERO
	motion_trail.initial_velocity_min = 0.0
	motion_trail.initial_velocity_max = 0.0
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	motion_trail.scale_amount_curve = curve
	
	motion_trail.amount = 20 
	motion_trail.lifetime = 0.35
	motion_trail.emitting = false
	motion_trail.position = Vector3(0.0, 0.1, 0.0)
	return motion_trail

static func trigger_jump_thrust(parent: Node, pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mesh.material = mat
	
	particles.mesh = mesh
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.2
	particles.direction = Vector3.DOWN
	particles.spread = 35.0
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 9.0
	particles.gravity = Vector3(0.0, -8.0, 0.0)
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve
	
	particles.amount = 12
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.35
	
	parent.add_child(particles)
	particles.global_position = pos 
	particles.emitting = true
	
	parent.get_tree().create_timer(0.6).timeout.connect(particles.queue_free)

static func trigger_death_particles(parent: Node, pos: Vector3, player_material: StandardMaterial3D) -> void:
	var particles := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	
	var mat := StandardMaterial3D.new()
	if player_material:
		mat.albedo_color = player_material.albedo_color
	else:
		mat.albedo_color = Color(1.0, 1.0, 0.0)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.3
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 7.0
	particles.gravity = Vector3(0.0, -12.0, 0.0)
	
	particles.amount = 30
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.8
	
	parent.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	
	parent.get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

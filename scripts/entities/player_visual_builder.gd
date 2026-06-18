# ==============================================================================
# Description: Procedural 3D Mesh and CPUParticle Builder for the Player (Pac-Man).
#              SOLID Refactoring & Mobile Optimization:
#              - Performance Optimization: Replaced GPUParticles3D with 
#                highly compatible CPUParticles3D. This bypasses compute shader 
#                compilation overhead, preventing rendering stutters on budget 
#                mobile and legacy GPUs.
#              - SRP Compliance: Assembles meshes and configures CPUParticles.
#              - Context Fix: Corrected static scope access and parenting logic.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name PlayerVisualBuilder

# Compiles the physical 3D mesh representations of Pac-Man and returns 
# references needed by player.gd for gameplay animations.
static func build_visuals(player: CharacterBody3D, player_material: StandardMaterial3D) -> Dictionary:
	var visual_mesh = MeshInstance3D.new()
	var collision_shape = CollisionShape3D.new()
	var radius : float = 0.85
	
	# 1. Main Spherical Body
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	visual_mesh.mesh = sphere_mesh
	visual_mesh.material_override = player_material
	
	# 2. Blinking Scleras and Pupils
	var eyes_holder = Node3D.new()
	
	var sclera_mat := StandardMaterial3D.new()
	sclera_mat.albedo_color = Color(1.0, 1.0, 1.0)
	sclera_mat.roughness = 0.6
	
	var pupil_material = StandardMaterial3D.new()
	pupil_material.albedo_color = Color(0.0, 0.8, 0.1) # Glowing Green
	pupil_material.roughness = 0.4
	
	var sclera_mesh := SphereMesh.new()
	sclera_mesh.radius = 0.20
	sclera_mesh.height = 0.40
	
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.08
	pupil_mesh.height = 0.16
	
	# Left Eye
	var left_sclera := MeshInstance3D.new()
	left_sclera.mesh = sclera_mesh
	left_sclera.material_override = sclera_mat
	left_sclera.position = Vector3(-0.35, 0.45, -0.65)
	eyes_holder.add_child(left_sclera)
	
	var left_pupil := MeshInstance3D.new()
	left_pupil.mesh = pupil_mesh
	left_pupil.material_override = pupil_material
	left_pupil.position = Vector3(-0.35, 0.45, -0.83)
	eyes_holder.add_child(left_pupil)
	
	# Right Eye
	var right_sclera := MeshInstance3D.new()
	right_sclera.mesh = sclera_mesh
	right_sclera.material_override = sclera_mat
	right_sclera.position = Vector3(0.35, 0.45, -0.65)
	eyes_holder.add_child(right_sclera)
	
	var right_pupil := MeshInstance3D.new()
	right_pupil.mesh = pupil_mesh
	right_pupil.material_override = pupil_material
	right_pupil.position = Vector3(0.35, 0.45, -0.83)
	eyes_holder.add_child(right_pupil)
	
	visual_mesh.add_child(eyes_holder)
	
	# 3. Procedural Chewing Mouth
	var mouth_mat := StandardMaterial3D.new()
	mouth_mat.albedo_color = Color(0.01, 0.01, 0.01) 
	mouth_mat.roughness = 1.0
	mouth_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED 
	
	var mouth_box := BoxMesh.new()
	mouth_box.size = Vector3(1.0, 1.0, 0.5) 
	
	# Fixed: Declared locally inside the static function scope
	var mouth_instance := MeshInstance3D.new()
	mouth_instance.mesh = mouth_box
	mouth_instance.material_override = mouth_mat
	mouth_instance.position = Vector3(0.0, -0.15, -0.62) 
	mouth_instance.scale = Vector3(0.5, 0.1, 0.5) 
	visual_mesh.add_child(mouth_instance) 
	
	# 4. Procedural Cyber-DJ Headphones
	var headphones_holder := Node3D.new()
	
	var headphone_dark_mat := StandardMaterial3D.new()
	headphone_dark_mat.albedo_color = Color(0.06, 0.06, 0.08) 
	headphone_dark_mat.roughness = 0.6
	headphone_dark_mat.metallic = 0.5
	
	# Fixed: Declared locally inside the static function scope
	var headphone_ring_material := StandardMaterial3D.new()
	headphone_ring_material.albedo_color = Color(0.0, 0.8, 1.0) 
	headphone_ring_material.emission_enabled = true
	headphone_ring_material.emission = Color(0.0, 0.5, 1.0) 
	headphone_ring_material.roughness = 0.1
	
	var band_mesh := TorusMesh.new()
	band_mesh.inner_radius = 0.82
	band_mesh.outer_radius = 0.88
	
	var band := MeshInstance3D.new()
	band.mesh = band_mesh
	band.material_override = headphone_dark_mat
	band.rotation_degrees.z = 90.0 
	headphones_holder.add_child(band)
	
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.28
	cup_mesh.bottom_radius = 0.28
	cup_mesh.height = 0.12
	cup_mesh.radial_segments = 16
	
	var left_cup := MeshInstance3D.new()
	left_cup.mesh = cup_mesh
	left_cup.material_override = headphone_dark_mat
	left_cup.position = Vector3(-0.85, 0.0, 0.0)
	left_cup.rotation_degrees.z = 90.0 
	headphones_holder.add_child(left_cup)
	
	var right_cup := MeshInstance3D.new()
	right_cup.mesh = cup_mesh
	right_cup.material_override = headphone_dark_mat
	right_cup.position = Vector3(0.85, 0.0, 0.0)
	right_cup.rotation_degrees.z = 90.0
	headphones_holder.add_child(right_cup)
	
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.22
	ring_mesh.bottom_radius = 0.22
	ring_mesh.height = 0.14
	ring_mesh.radial_segments = 16
	
	var left_ring := MeshInstance3D.new()
	left_ring.mesh = ring_mesh
	left_ring.material_override = headphone_ring_material
	left_ring.position = Vector3(-0.86, 0.0, 0.0)
	left_ring.rotation_degrees.z = 90.0
	headphones_holder.add_child(left_ring)
	
	var right_ring := MeshInstance3D.new()
	right_ring.mesh = ring_mesh
	right_ring.material_override = headphone_ring_material
	right_ring.position = Vector3(0.86, 0.0, 0.0)
	right_ring.rotation_degrees.z = 90.0
	headphones_holder.add_child(right_ring)
	
	visual_mesh.add_child(headphones_holder)
	
	# 5. Physical Collider
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	
	# Fixed: Added to the injected parent player node reference directly
	player.add_child(visual_mesh)
	player.add_child(collision_shape)
	
	return {
		"visual_mesh": visual_mesh,
		"eyes_holder": eyes_holder,
		"pupil_material": pupil_material,
		"mouth_instance": mouth_instance,
		"headphone_ring_material": headphone_ring_material
	}


# ==============================================================================
# --- HIGH PERFORMANCE CPUPARTICLES GENERATORS (Platform Agnostic) ---
# ==============================================================================

# Programmatically configures and attaches CPUParticles3D for Invincibility Golden Aura
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
	power_particles.position = Vector3(0.0, -0.2, 0.0)
	
	return power_particles

# Programmatically configures and attaches CPUParticles3D for Speed Overload Sparks
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
	speed_particles.position = Vector3(0.0, -0.1, 0.0)
	
	return speed_particles

# Programmatically configures and attaches CPUParticles3D for Continuous Light-Trail Ribbon
static func build_motion_trail() -> CPUParticles3D:
	var motion_trail := CPUParticles3D.new()
	
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.16
	sphere_mesh.height = 0.32
	
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
	motion_trail.position = Vector3(0.0, -0.1, 0.0)
	
	return motion_trail

# Instantiates CPUParticles3D for One-Shot Downward Jump Thrust Rocket Jets
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
	particles.global_position = pos - Vector3(0.0, 0.45, 0.0)
	particles.emitting = true
	
	parent.get_tree().create_timer(0.6).timeout.connect(particles.queue_free)

# Instantiates CPUParticles3D for One-Shot Player Death Explosions
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
	

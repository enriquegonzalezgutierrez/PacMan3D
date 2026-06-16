# ==============================================================================
# Description: CharacterBody3D controller for Pac-Man. Handles movement inputs,
#              visual mesh rotation, and continuous arcade movement.
#              Features an ORTHOGRAPHIC top-down camera to prevent 3D perspective.
#              SOLID Refactoring:
#              - DIP (Dependency Inversion): Materials and audio streams are now
#                injected from the outside (LevelManager) instead of hardcoded.
#              - SRP (Single Responsibility): Strictly focused on player physics
#                movement, inputs, and triggering local death visuals/audio.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CharacterBody3D
class_name Player

const SPEED : float = 7.0
const CELL_SIZE : float = 2.0 
const ALIGNMENT_FORCE : float = 15.0 

# Injected Dependencies (DIP Compliance)
var player_material : StandardMaterial3D
var munch_stream : AudioStream
var death_stream : AudioStream

# Internal Node Components
var visual_mesh : MeshInstance3D 
var munch_audio : AudioStreamPlayer
var death_audio : AudioStreamPlayer

var spawn_position : Vector3
var current_direction : Vector3 = Vector3.ZERO
var next_direction : Vector3 = Vector3.ZERO

# Dependency Injection initializer method (Now accepts both munch and death audio streams)
func initialize(material: StandardMaterial3D, audio_stream: AudioStream, d_stream: AudioStream) -> void:
	player_material = material
	munch_stream = audio_stream
	death_stream = d_stream

func _ready() -> void:
	add_to_group("player")
	_configure_collision_layers()
	_build_player_visuals()
	_setup_camera()
	_setup_audio()

func _configure_collision_layers() -> void:
	collision_layer = 2
	collision_mask = 5

func _build_player_visuals() -> void:
	visual_mesh = MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	
	var radius : float = 0.6
	
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	visual_mesh.mesh = sphere_mesh
	
	# Fallback safety if dependencies were not injected
	if not player_material:
		player_material = StandardMaterial3D.new()
		player_material.albedo_color = Color(1.0, 1.0, 0.0)
		player_material.roughness = 0.1
		
	visual_mesh.material_override = player_material
	
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	
	add_child(visual_mesh)
	add_child(collision_shape)

func _setup_camera() -> void:
	var spring_arm := SpringArm3D.new()
	spring_arm.top_level = true
	spring_arm.position = Vector3(0.0, 30.0, 0.0)
	spring_arm.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	spring_arm.spring_length = 0.0
	
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 46.0 
	camera.current = true 
	
	spring_arm.add_child(camera)
	add_child(spring_arm)

# Sets up separate, non-overlapping audio channels (SRP Compliance)
func _setup_audio() -> void:
	# 1. Munch Audio Player (Waka-Waka)
	munch_audio = AudioStreamPlayer.new()
	if munch_stream:
		munch_audio.stream = munch_stream
	munch_audio.max_polyphony = 1
	munch_audio.volume_db = -5.0 
	add_child(munch_audio)
	
	# 2. Death Audio Player (Descending pitch sweep)
	death_audio = AudioStreamPlayer.new()
	if death_stream:
		death_audio.stream = death_stream
	death_audio.max_polyphony = 1
	death_audio.volume_db = -3.0 # Slightly louder for impact
	add_child(death_audio)

# Public method to be called when eating a pellet
func play_eat_sound() -> void:
	if munch_audio and munch_audio.stream:
		munch_audio.stop()
		munch_audio.play()

# Programmatically spawns a beautiful retro particle explosion and triggers death audio
func play_death_particles() -> void:
	# Trigger death audio immediately (SRP Compliance)
	if death_audio and death_audio.stream:
		death_audio.play()
		
	var particles := GPUParticles3D.new()
	
	# 1. Mesh setup: Small yellow cubes matching Pac-Man's color
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	
	var mat := StandardMaterial3D.new()
	if player_material:
		mat.albedo_color = player_material.albedo_color
	else:
		mat.albedo_color = Color(1.0, 1.0, 0.0)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	# 2. Physics process setup for explosion behavior
	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = 0.3
	
	p_mat.direction = Vector3.UP
	p_mat.spread = 180.0 
	
	p_mat.initial_velocity_min = 4.0
	p_mat.initial_velocity_max = 7.0
	p_mat.gravity = Vector3(0.0, -12.0, 0.0) 
	
	p_mat.damping_min = 1.0
	p_mat.damping_max = 2.0
	
	particles.process_material = p_mat
	
	# 3. Particle system emissions
	particles.amount = 30
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.8
	
	# Save current coordinate position BEFORE tree insertion
	var death_position = global_position
	
	# Add to LevelManager first, so it doesn't get freed with Player
	get_parent().add_child(particles)
	
	# Apply coordinates AFTER tree insertion to avoid Transform reset bugs
	particles.global_position = death_position
	particles.emitting = true
	
	# Safely cleanup the programmatic node after lifetime ends
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): particles.queue_free())

# Triggers particles, audio, and teleports player back to start
func respawn() -> void:
	play_death_particles()
	global_position = spawn_position
	velocity = Vector3.ZERO
	current_direction = Vector3.ZERO
	next_direction = Vector3.ZERO

func _physics_process(_delta: float) -> void:
	_handle_arcade_input()
	_process_arcade_movement()

func _handle_arcade_input() -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		next_direction = Vector3(input_dir.x, 0.0, input_dir.y).normalized()

func _process_arcade_movement() -> void:
	if next_direction != Vector3.ZERO:
		var test_offset = next_direction * 0.5
		if not test_move(global_transform, test_offset):
			current_direction = next_direction
			
	if current_direction != Vector3.ZERO:
		var test_offset = current_direction * 0.1 
		if test_move(global_transform, test_offset):
			current_direction = Vector3.ZERO
			next_direction = Vector3.ZERO 
			
	if current_direction != Vector3.ZERO:
		velocity = current_direction * SPEED
		
		if current_direction.x != 0.0:
			var target_z = round(global_position.z / CELL_SIZE) * CELL_SIZE
			velocity.z = (target_z - global_position.z) * ALIGNMENT_FORCE
		elif current_direction.z != 0.0:
			var target_x = round(global_position.x / CELL_SIZE) * CELL_SIZE
			velocity.x = (target_x - global_position.x) * ALIGNMENT_FORCE
			
		var target_rotation_y = atan2(-current_direction.x, -current_direction.z)
		visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, target_rotation_y, 0.25)
	else:
		velocity = Vector3.ZERO
		
	move_and_slide()

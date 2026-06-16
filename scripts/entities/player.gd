# ==============================================================================
# Description: CharacterBody3D controller for Pac-Man. Handles movement inputs,
#              visual mesh rotation, and continuous arcade movement.
#              Features an ORTHOGRAPHIC top-down camera to prevent 3D perspective.
#              SOLID Refactoring:
#              - SRP & State Machine: Added a self-contained `DEAD` state.
#                Pac-Man now manages his own death sequence.
#              - Collision Fix: Only physically blocks with Layer 1 (Walls).
#              - Giant Arcade Proportions: Giant 1.7m diameter sphere.
#              - Dynamic Cinematic Camera: Replaced flat static camera with a 
#                smoothly-interpolated Perspective Follow Camera, tilted at 
#                -55 degrees (Pac-Mania style).
#              - Bug Fix: Fixed the C++ tree transform error by calling `add_child`
#                before adjusting 'camera_holder.global_position'.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CharacterBody3D
class_name Player

# Signal emitted when the death audio and particles finish (DIP Compliance)
signal death_completed()

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
var camera_holder : Node3D # Tilted independent pivot for smooth tracking

var spawn_position : Vector3
var current_direction : Vector3 = Vector3.ZERO
var next_direction : Vector3 = Vector3.ZERO
var is_dead : bool = false

# Dependency Injection initializer method
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
	# Exist on Layer 2 (Player)
	collision_layer = 2
	# Only physically block with Layer 1 (Walls)
	collision_mask = 1

func _build_player_visuals() -> void:
	visual_mesh = MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# GIANT RETRO SIZE: Fills the 2.0m corridor tightly (diameter 1.7)
	var radius : float = 0.85
	
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	visual_mesh.mesh = sphere_mesh
	visual_mesh.material_override = player_material
	
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	
	add_child(visual_mesh)
	add_child(collision_shape)

# Set up a dynamic perspective following camera (Pac-Mania style)
func _setup_camera() -> void:
	camera_holder = Node3D.new()
	camera_holder.top_level = true
	
	# FIXED: Add the child to the scene tree FIRST so it is inside the tree,
	# allowing global_position assignments to work without C++ engine errors.
	add_child(camera_holder)
	camera_holder.global_position = global_position
	
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55.0 # Slightly narrow field of view for a more cinematic feel
	
	# Angled Offset: 11 meters high, 7.5 meters behind (on Z axis)
	camera.position = Vector3(0.0, 11.0, 7.5)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	
	camera.current = true
	
	camera_holder.add_child(camera)

# Sets up separate, non-overlapping audio channels
func _setup_audio() -> void:
	# 1. Munch Audio Player (Waka-Waka)
	munch_audio = AudioStreamPlayer.new()
	if munch_stream:
		munch_audio.stream = munch_stream
	munch_audio.max_polyphony = 1
	munch_audio.volume_db = -5.0 
	add_child(munch_audio)
	
	# 2. Death Audio Player
	death_audio = AudioStreamPlayer.new()
	if death_stream:
		death_audio.stream = death_stream
	death_audio.max_polyphony = 1
	death_audio.volume_db = -3.0 
	add_child(death_audio)

# Public method to be called when eating a pellet
func play_eat_sound() -> void:
	if munch_audio and munch_audio.stream:
		munch_audio.stop()
		munch_audio.play()

# Public method: Initiates the sequential, gated death routine (SRP Compliance)
func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	if visual_mesh:
		visual_mesh.visible = false
		
	play_death_particles()
	
	if death_audio and death_audio.stream:
		await death_audio.finished
	else:
		await get_tree().create_timer(1.0).timeout
		
	death_completed.emit()
	
	_actual_respawn()

# Programmatically spawns particles and starts audio playback
func play_death_particles() -> void:
	if death_audio and death_audio.stream:
		death_audio.play()
		
	var particles := GPUParticles3D.new()
	
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
	
	particles.amount = 30
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.8
	
	var death_position = global_position
	
	get_parent().add_child(particles)
	particles.global_position = death_position
	particles.emitting = true
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): particles.queue_free())

# Teleports the player back to start (No particles, used for initial spawning / game resets)
func respawn() -> void:
	_actual_respawn()

# Handles physical coordinate teleports and restores visibility
func _actual_respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	current_direction = Vector3.ZERO
	next_direction = Vector3.ZERO
	if visual_mesh:
		visual_mesh.visible = true
	
	# Instant camera snap back to spawn coordinate to prevent sliding confusion
	if is_instance_valid(camera_holder):
		camera_holder.global_position = spawn_position
		
	is_dead = false

# Public API helper
func get_spawn_height_offset() -> float:
	return 0.85

func _physics_process(_delta: float) -> void:
	# Keep the camera following smoothly even when Pac-Man is dead
	if is_instance_valid(camera_holder):
		# Buttery-smooth LERP interpolation (0.08) creates elegant drag/damping inertia
		camera_holder.global_position = camera_holder.global_position.lerp(global_position, 0.08)

	if is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return
		
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

# ==============================================================================
# Description: CharacterBody3D controller for Pac-Man. Handles movement inputs,
#              visual mesh rotation, and continuous arcade movement.
#              SOLID Refactoring & Fixes:
#              - SRP Refactoring (Step 2): Completely stripped all Camera3D setup, 
#                tracking interpolation, and snapping routines out of this script.
#                Camera tracking is now handled independently by DioramaCamera.
#              - DYNAMIC ALIGNMENT FIX: Calculates grid offset dynamically 
#                using GameManager map bounds. This permanently prevents Pac-Man 
#                from clipping/freezing when switching between odd (31x31) and 
#                even (32x32) map sizes.
#              - SRP & State Machine: Added a self-contained `DEAD` state.
#              - Collision Fix: Only physically blocks with Layer 1 (Walls).
#              - Giant Arcade Proportions: Giant 1.7m diameter sphere.
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

# Jump & Gravity Constants (Virtual physics - Calibrated for high clearance)
const JUMP_VELOCITY : float = 14.5 
const GRAVITY : float = 40.0 

# Injected Dependencies (DIP Compliance)
var player_material : StandardMaterial3D
var munch_stream : AudioStream
var death_stream : AudioStream

# Internal Node Components
var visual_mesh : MeshInstance3D 
var munch_audio : AudioStreamPlayer
var death_audio : AudioStreamPlayer

# Gameplay State
var spawn_position : Vector3
var current_direction : Vector3 = Vector3.ZERO
var next_direction : Vector3 = Vector3.ZERO
var is_dead : bool = false

# Jump States
var virtual_floor_y : float = 0.85 # Calibrated automatically on ready
var is_jumping : bool = false

# Dependency Injection initializer method
func initialize(material: StandardMaterial3D, audio_stream: AudioStream, d_stream: AudioStream) -> void:
	player_material = material
	munch_stream = audio_stream
	death_stream = d_stream

func _ready() -> void:
	add_to_group("player")
	_configure_collision_layers()
	_build_player_visuals()
	_setup_audio()
	
	# Automatically calibrate virtual floor based on injected height coordinate (SOLID DIP)
	virtual_floor_y = global_position.y

func _configure_collision_layers() -> void:
	# Exist on Layer 2 (Player)
	collision_layer = 2
	# Only physically block with Layer 1 (Walls)
	collision_mask = 1

func _build_player_visuals() -> void:
	var collision_shape := CollisionShape3D.new()
	visual_mesh = MeshInstance3D.new()
	
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

# Teleports the player back to start
func respawn() -> void:
	_actual_respawn()

# Handles physical coordinate teleports and restores visibility
func _actual_respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	current_direction = Vector3.ZERO
	next_direction = Vector3.ZERO
	is_jumping = false
	
	if visual_mesh:
		visual_mesh.visible = true
	
	is_dead = false

# Public API helper
func get_spawn_height_offset() -> float:
	return 0.85

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# --- VIRTUAL JUMP PHYSICS (GRAVITY & LANDING) ---
	if global_position.y > virtual_floor_y:
		# Apply gravity downwards
		velocity.y -= GRAVITY * delta
	else:
		# Clamp Pac-Man flat on the floor
		velocity.y = 0.0
		global_position.y = virtual_floor_y
		is_jumping = false
		
	# Trigger Jump: spacebar
	if Input.is_action_just_pressed("ui_select") and not is_jumping:
		velocity.y = JUMP_VELOCITY
		is_jumping = true

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
		# Preserve the vertical jump velocity while moving horizontally
		var y_vel = velocity.y
		velocity = current_direction * SPEED
		velocity.y = y_vel
		
		# --- DYNAMIC GRID OFFSET MATH ---
		# Calculates offsets dynamically using global map bounds to prevent even/odd size mismatches
		var offset_x : float = 32.0
		var offset_z : float = 32.0
		if GameManager and GameManager.grid_width > 0:
			offset_x = (float(GameManager.grid_width) * CELL_SIZE) / 2.0
		if GameManager and GameManager.grid_height > 0:
			offset_z = (float(GameManager.grid_height) * CELL_SIZE) / 2.0
		
		if current_direction.x != 0.0:
			var g_z = round((global_position.z + offset_z - (CELL_SIZE / 2.0)) / CELL_SIZE)
			var target_z = g_z * CELL_SIZE - offset_z + (CELL_SIZE / 2.0)
			velocity.z = (target_z - global_position.z) * ALIGNMENT_FORCE
		elif current_direction.z != 0.0:
			var g_x = round((global_position.x + offset_x - (CELL_SIZE / 2.0)) / CELL_SIZE)
			var target_x = g_x * CELL_SIZE - offset_x + (CELL_SIZE / 2.0)
			velocity.x = (target_x - global_position.x) * ALIGNMENT_FORCE
			
		var target_rotation_y = atan2(-current_direction.x, -current_direction.z)
		visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, target_rotation_y, 0.25)
	else:
		var y_vel = velocity.y
		velocity = Vector3.ZERO
		velocity.y = y_vel
		
	move_and_slide()

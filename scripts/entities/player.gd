# ==============================================================================
# Description: CharacterBody3D controller for Pac-Man. Handles movement inputs,
#              visual mesh rotation, and continuous arcade movement.
#              SOLID Refactoring & Visual Polish:
#              - LAMBDA MEMORY FIX: Connected the death particle despawn timer 
#                directly to particles.queue_free. This lets Godot auto-disconnect 
#                the signal if the level reloads early, preventing lambda-capture errors.
#              - PROCEDURAL CHEWING MOUTH: Instantiates an unshaded matte-black mouth.
#              - DYNAMIC BLINKING RETRO EYES: Procedurally generates white scleras.
#              - SRP Refactoring (Step 2): Completely stripped all Camera3D setup.
#              - DYNAMIC ALIGNMENT FIX: Calculates grid offset dynamically.
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

# Dynamic Eye Tracking Variables
var eyes_holder : Node3D
var pupil_material : StandardMaterial3D
var is_blinking : bool = false
var blink_timer : float = 0.0
var blink_duration : float = 0.15
var next_blink_time : float = 3.0 # Initial time before first blink

# Invincibility Power State Variables (Arcade Juice)
var is_powered_up : bool = false
var power_timer : float = 0.0
const POWER_DURATION : float = 7.0 # Matches Ghost Frightened duration
var power_particles : GPUParticles3D = null

# Dynamic Chewing Mouth Variables (SRP/Juice Compliance)
var mouth_instance : MeshInstance3D
var mouth_time : float = 0.0

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
	
	# Randomize first blink timing to stagger animations
	next_blink_time = randf_range(2.0, 5.0)
	
	# Connect dynamically to global power pellet activations (DIP Compliance)
	if GameManager:
		GameManager.power_pellet_activated.connect(activate_power_up)
	
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
	
	# Main Pac-Man body sphere
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	visual_mesh.mesh = sphere_mesh
	visual_mesh.material_override = player_material
	
	# --- PROCEDURAL BLINKING PAC-MAN EYES ---
	eyes_holder = Node3D.new()
	
	var sclera_mat := StandardMaterial3D.new()
	sclera_mat.albedo_color = Color(1.0, 1.0, 1.0) # White Sclera
	sclera_mat.roughness = 0.6
	
	# Keep an instance reference to pupil_material so we can dynamically tint it on power states
	pupil_material = StandardMaterial3D.new()
	pupil_material.albedo_color = Color(0.0, 0.8, 0.1) # Glowing Neon Green Pupil
	pupil_material.roughness = 0.4
	
	# Eye mesh shapes
	var sclera_mesh := SphereMesh.new()
	sclera_mesh.radius = 0.20
	sclera_mesh.height = 0.40
	
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.08
	pupil_mesh.height = 0.16
	
	# 1. Left Sclera (White)
	var left_sclera := MeshInstance3D.new()
	left_sclera.mesh = sclera_mesh
	left_sclera.material_override = sclera_mat
	left_sclera.position = Vector3(-0.35, 0.45, -0.65)
	eyes_holder.add_child(left_sclera)
	
	# 2. Right Sclera (White)
	var right_sclera := MeshInstance3D.new()
	right_sclera.mesh = sclera_mesh
	right_sclera.material_override = sclera_mat
	right_sclera.position = Vector3(0.35, 0.45, -0.65)
	eyes_holder.add_child(right_sclera)
	
	# 3. Left Pupil (Green)
	var left_pupil := MeshInstance3D.new()
	left_pupil.mesh = pupil_mesh
	left_pupil.material_override = pupil_material
	left_pupil.position = Vector3(-0.35, 0.45, -0.83)
	eyes_holder.add_child(left_pupil)
	
	# 4. Right Pupil (Green)
	var right_pupil := MeshInstance3D.new()
	right_pupil.mesh = pupil_mesh
	right_pupil.material_override = pupil_material
	right_pupil.position = Vector3(0.35, 0.45, -0.83)
	eyes_holder.add_child(right_pupil)
	
	# Attach eyes to the visual mesh so they rotate dynamically with Pac-Man
	visual_mesh.add_child(eyes_holder)
	
	# --- PROCEDURAL RETRO CHEWING MOUTH (SRP/OCP Compliance) ---
	var mouth_mat := StandardMaterial3D.new()
	mouth_mat.albedo_color = Color(0.01, 0.01, 0.01) # Deep shadow black
	mouth_mat.roughness = 1.0
	mouth_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Unshaded for black abyss effect
	
	var mouth_box := BoxMesh.new()
	mouth_box.size = Vector3(1.0, 1.0, 0.5) # Base unit box to scale dynamically
	
	mouth_instance = MeshInstance3D.new()
	mouth_instance.mesh = mouth_box
	mouth_instance.material_override = mouth_mat
	mouth_instance.position = Vector3(0.0, -0.15, -0.62) # Positioned on front lower face
	mouth_instance.scale = Vector3(0.5, 0.1, 0.5) # Start closed
	
	visual_mesh.add_child(mouth_instance) # Child of body so it rotates with Pac-Man
	
	# --- PHYSICAL COLLIDER ---
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
		
	# Clean up any active power particle trails on death
	_deactivate_power_up()
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
	
	# --- DIRECT METHOD CONNECTION FIX ---
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

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

# --- POWER UP SEQUENCE (JUICE COMPLIANCE) ---

# Public Callback: Triggers invincibility state transformations (OCP Compliance)
func activate_power_up() -> void:
	is_powered_up = true
	power_timer = POWER_DURATION
	
	# 1. Glow body to a vibrant neon golden-orange
	player_material.albedo_color = Color(1.0, 0.45, 0.0) # Golden Orange
	player_material.emission_enabled = true
	player_material.emission = Color(1.0, 0.25, 0.0) # Golden Glow
	
	# 2. Shift pupils to an angry glowing neon-red
	if pupil_material:
		pupil_material.albedo_color = Color(1.0, 0.0, 0.0) # Fierce Red
		pupil_material.emission_enabled = true
		pupil_material.emission = Color(1.0, 0.0, 0.0) # Red Glow
		
	# 3. Spawn subtle gold sparkle particle aura
	if not is_instance_valid(power_particles):
		_spawn_power_particles()

# Programmatically configures and attaches a glowing aura trail underneath Pac-Man
func _spawn_power_particles() -> void:
	power_particles = GPUParticles3D.new()
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(1.0, 0.8, 0.0) # Golden sparkles
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = p_mat
	power_particles.draw_pass_1 = mesh
	
	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc_mat.emission_sphere_radius = 0.5
	proc_mat.direction = Vector3.UP
	proc_mat.spread = 45.0
	proc_mat.initial_velocity_min = 1.0
	proc_mat.initial_velocity_max = 2.0
	proc_mat.gravity = Vector3(0.0, -2.0, 0.0)
	
	power_particles.process_material = proc_mat
	power_particles.amount = 15
	power_particles.lifetime = 0.5
	
	add_child(power_particles)
	power_particles.position = Vector3(0.0, -0.2, 0.0) # Centered at feet level

# Restores the original visual colors and clears particle emitters
func _deactivate_power_up() -> void:
	is_powered_up = false
	
	# Restore normal body
	player_material.albedo_color = Color(1.0, 1.0, 0.0) # Yellow
	player_material.emission_enabled = false
	
	# Restore normal green pupils
	if pupil_material:
		pupil_material.albedo_color = Color(0.0, 0.8, 0.1) # Green
		pupil_material.emission_enabled = false
		
	# Delete the particle trail
	if is_instance_valid(power_particles):
		power_particles.queue_free()

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

	# --- INVINCIBILITY CYCLE PROCESSOR ---
	if is_powered_up:
		power_timer -= delta
		if power_timer <= 0.0:
			_deactivate_power_up()
		else:
			# Cooldown Warning: blink body, eyes, and sparks during the final 2.5 seconds
			if power_timer <= 2.5:
				var blink = int(power_timer * 5.0) % 2 == 0
				if blink:
					# Temporarily show original colors
					player_material.albedo_color = Color(1.0, 1.0, 0.0)
					player_material.emission_enabled = false
					if pupil_material:
						pupil_material.albedo_color = Color(0.0, 0.8, 0.1)
						pupil_material.emission_enabled = false
					if is_instance_valid(power_particles):
						power_particles.emitting = false
				else:
					# Return to golden glow
					player_material.albedo_color = Color(1.0, 0.45, 0.0)
					player_material.emission_enabled = true
					player_material.emission = Color(1.0, 0.25, 0.0)
					if pupil_material:
						pupil_material.albedo_color = Color(1.0, 0.0, 0.0)
						pupil_material.emission_enabled = true
						pupil_material.emission = Color(1.0, 0.0, 0.0)
					if is_instance_valid(power_particles):
						power_particles.emitting = true

	_handle_arcade_input()
	_process_arcade_movement()
	_process_eye_blinking(delta)
	_process_mouth_animation(delta)

# Orchestrates smooth chewing and dynamic mouth-stretching while running (SRP Compliance)
func _process_mouth_animation(delta: float) -> void:
	if not is_instance_valid(mouth_instance) or is_dead:
		return
		
	# Only chew if Pac-Man is actively moving (velocity magnitude is high)
	if velocity.length() > 0.1:
		mouth_time += delta
		# Fast biting cycle (24.0 rad/s)
		# Biting factor oscillates cleanly between 0.0 and 1.0
		var bite_factor : float = (sin(mouth_time * 24.0) + 1.0) / 2.0
		
		# Squash and Stretch: scale mouth vertically while stretching cheeks horizontally
		mouth_instance.scale.y = lerpf(0.05, 0.72, bite_factor)
		mouth_instance.scale.x = lerpf(0.5, 0.62, bite_factor)
	else:
		# Relax mouth to a slightly open line when static
		mouth_instance.scale.y = 0.12
		mouth_instance.scale.x = 0.52

# Handles the dynamic eye-blinking scale animation
func _process_eye_blinking(delta: float) -> void:
	if not is_instance_valid(eyes_holder):
		return
		
	# Skip standard blinking cycles if Pac-Man is in a focused, angry invincibility state
	if is_powered_up:
		eyes_holder.scale.y = 1.0 # Keep eyes wide open
		return
		
	blink_timer += delta
	if not is_blinking:
		if blink_timer >= next_blink_time:
			# Shut eyes closed
			is_blinking = true
			blink_timer = 0.0
			eyes_holder.scale.y = 0.05
	else:
		if blink_timer >= blink_duration:
			# Re-open eyes and calculate randomized next interval
			is_blinking = false
			blink_timer = 0.0
			next_blink_time = randf_range(2.5, 6.0)
			eyes_holder.scale.y = 1.0

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

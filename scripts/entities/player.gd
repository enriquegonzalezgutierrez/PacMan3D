# ==============================================================================
# Description: CharacterBody3D controller for MartínMan (formerly Pac-Man). 
#              Handles movement inputs, visual mesh rotation, virtual jump 
#              physics, and runs skeletal animations based on movement velocities.
#              SOLID Refactoring:
#              - SRP & LSP Compliance: Swapped the visual rendering engine 
#                completely without changing any core movement or grid-clamping physics.
#              - Skeletal Animation Engine: Replaced mathematical sphere chewing 
#                with high-fidelity skeletal animations (idle, running, jump, falling, death).
#              - DIP Compliance: Accepts a precompiled AnimationLibrary resource 
#                from LevelBuilder, bypassing expensive runtime disk loads 
#                and remapping calculations.
#              - Grid-Guided Arcade Movement: Replaced unstable physics-based test-moves 
#                with 100% precise matrix grid checks. Includes corner-cutting tolerance 
#                and automatic lane alignment to guarantee flawless, fluid, and continuous 
#                movement exactly like the original arcade cabinets.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CharacterBody3D
class_name Player

# Signal emitted when the death completed audio and particles finish
signal death_completed()

const SPEED : float = 7.0
const CELL_SIZE : float = 2.0 
const ALIGNMENT_FORCE : float = 15.0 

# Jump & Gravity Constants
const JUMP_VELOCITY : float = 14.5 
const GRAVITY : float = 40.0 

# Injected Dependencies (DIP Compliance)
var player_material : StandardMaterial3D
var munch_stream : AudioStream
var death_stream : AudioStream

# Precompiled animation library in RAM (SOLID DIP Compliance)
var precompiled_anim_library : AnimationLibrary = null

# Internal Node Components
var munch_audio : AudioStreamPlayer3D
var death_audio : AudioStreamPlayer3D

# Skeletal Animation References (Injected by PlayerVisualBuilder)
var visual_mesh : Node3D 
var anim_player : AnimationPlayer

# Invincibility Power State Variables
var is_powered_up : bool = false
var power_timer : float = 0.0
const POWER_DURATION : float = 7.0 
var power_particles : CPUParticles3D = null

# Speed Overload State Variables
var is_speed_boosted : bool = false
var speed_boost_timer : float = 0.0
const SPEED_BOOST_DURATION : float = 5.0
const BOOSTED_SPEED : float = 10.5 
var speed_particles : CPUParticles3D = null

# Continuous Energy Motion Trail Variables
var motion_trail : CPUParticles3D = null
var motion_trail_material : StandardMaterial3D = null

# Gameplay State
var spawn_position : Vector3
var current_direction : Vector3 = Vector3.ZERO
var next_direction : Vector3 = Vector3.ZERO
var is_dead : bool = false

# Jump States
var virtual_floor_y : float = 0.85 
var is_jumping : bool = false

# Dependency Injection initializer method
func initialize(material: StandardMaterial3D, audio_stream: AudioStream, d_stream: AudioStream) -> void:
	player_material = material
	munch_stream = audio_stream
	death_stream = d_stream

func _ready() -> void:
	add_to_group("player")
	_configure_collision_layers()
	
	# Assemble visuals using our SRP Builder, injecting the precompiled library (SOLID DIP)
	var visual_components = PlayerVisualBuilder.build_visuals(self, player_material, precompiled_anim_library)
	visual_mesh = visual_components["visual_mesh"]
	anim_player = visual_components["anim_player"]
	
	_setup_audio()
	
	# Instantiate and parent our CPU motion trail
	motion_trail = PlayerVisualBuilder.build_motion_trail()
	if motion_trail and motion_trail.mesh:
		motion_trail_material = motion_trail.mesh.material
	add_child(motion_trail)
	
	if GameManager:
		GameManager.power_pellet_activated.connect(activate_power_up)
	
	virtual_floor_y = global_position.y

func _configure_collision_layers() -> void:
	collision_layer = 2
	collision_mask = 1 | 8

# Programmatically constructs the spatial 3D audio players (3D Positional Audio Compliance)
func _setup_audio() -> void:
	# 1. Munch Audio Player (Waka-Waka)
	munch_audio = AudioStreamPlayer3D.new()
	munch_audio.unit_size = 12.0 
	munch_audio.max_distance = 32.0 
	munch_audio.panning_strength = 1.0 
	munch_audio.attenuation_filter_cutoff_hz = 6000.0 
	
	if munch_stream:
		munch_audio.stream = munch_stream
	munch_audio.max_polyphony = 1
	munch_audio.volume_db = -5.0 
	add_child(munch_audio)
	
	# 2. Death Audio Player
	death_audio = AudioStreamPlayer3D.new()
	death_audio.unit_size = 16.0 
	death_audio.max_distance = 40.0
	death_audio.panning_strength = 1.0
	death_audio.attenuation_filter_cutoff_hz = 5000.0 
	
	if death_stream:
		death_audio.stream = death_stream
	death_audio.max_polyphony = 1
	death_audio.volume_db = -3.0 
	add_child(death_audio)

func play_eat_sound() -> void:
	if munch_audio and munch_audio.stream:
		munch_audio.stop()
		munch_audio.play()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	_deactivate_power_up()
	_deactivate_speed_boost()
	
	if is_instance_valid(motion_trail):
		motion_trail.emitting = false
		
	# Trigger explosive death particles via builder (SRP Compliance)
	PlayerVisualBuilder.trigger_death_particles(get_parent(), global_position, player_material)
	
	# Play character death animation
	_play_animation("death")
	
	if death_audio and death_audio.stream:
		death_audio.play()
		await death_audio.finished 
	else:
		await get_tree().create_timer(1.0).timeout
		
	death_completed.emit()
	_actual_respawn()

func respawn() -> void:
	_actual_respawn()

func _actual_respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	current_direction = Vector3.ZERO
	next_direction = Vector3.ZERO
	is_jumping = false
	
	if visual_mesh:
		visual_mesh.visible = true
		
	if is_instance_valid(motion_trail):
		motion_trail.emitting = false
	
	is_dead = false

func get_spawn_height_offset() -> float:
	return 0.85

# --- POWER UP CYCLE ---

func activate_power_up() -> void:
	is_powered_up = true
	power_timer = POWER_DURATION
	
	# Change colors to golden-orange
	player_material.albedo_color = Color(1.0, 0.45, 0.0) 
	player_material.emission_enabled = true
	player_material.emission = Color(1.0, 0.25, 0.0) 
	
	if not is_instance_valid(power_particles):
		power_particles = PlayerVisualBuilder.build_power_particles()
		add_child(power_particles)

func _deactivate_power_up() -> void:
	is_powered_up = false
	player_material.albedo_color = Color(1.0, 1.0, 0.0) 
	player_material.emission_enabled = false
	
	if is_instance_valid(power_particles):
		power_particles.queue_free()

# --- SPEED BOOST CYCLE ---

func activate_speed_boost() -> void:
	is_speed_boosted = true
	speed_boost_timer = SPEED_BOOST_DURATION
	
	if not is_instance_valid(speed_particles):
		speed_particles = PlayerVisualBuilder.build_speed_particles()
		add_child(speed_particles)

func _deactivate_speed_boost() -> void:
	is_speed_boosted = false
	if is_instance_valid(speed_particles):
		speed_particles.queue_free()

# --- CONTINUOUS TRAIL MATH ---

func _update_motion_trail_materials() -> void:
	if not is_instance_valid(motion_trail_material):
		return
		
	if is_speed_boosted:
		motion_trail_material.albedo_color = Color(0.0, 1.0, 1.0)
		motion_trail_material.emission = Color(0.0, 0.8, 1.0)
		motion_trail_material.emission_energy_multiplier = randf_range(1.0, 1.5) 
	elif is_powered_up:
		motion_trail_material.albedo_color = Color(1.0, 0.45, 0.0)
		motion_trail_material.emission = Color(1.0, 0.2, 0.0)
		motion_trail_material.emission_energy_multiplier = 0.4
	else:
		motion_trail_material.albedo_color = Color(1.0, 1.0, 0.0)
		motion_trail_material.emission = Color(0.5, 0.5, 0.0)
		motion_trail_material.emission_energy_multiplier = 0.8

# Convert high-resolution 3D coordinates back to clean grid-level 2D matrices
func _world_to_grid(pos: Vector3) -> Vector2i:
	var offset_x : float = 32.0
	var offset_z : float = 32.0
	if GameManager and GameManager.grid_width > 0:
		offset_x = (float(GameManager.grid_width) * CELL_SIZE) / 2.0
	if GameManager and GameManager.grid_height > 0:
		offset_z = (float(GameManager.grid_height) * CELL_SIZE) / 2.0
		
	var x = int(round((pos.x + offset_x - (CELL_SIZE / 2.0)) / CELL_SIZE))
	var z = int(round((pos.z + offset_z - (CELL_SIZE / 2.0)) / CELL_SIZE))
	return Vector2i(x, z)

# Convert grid-level 2D coordinates back to clean 3D world space
func _grid_to_world(grid_pos: Vector2i) -> Vector3:
	var offset_x : float = 32.0
	var offset_z : float = 32.0
	if GameManager and GameManager.grid_width > 0:
		offset_x = (float(GameManager.grid_width) * CELL_SIZE) / 2.0
	if GameManager and GameManager.grid_height > 0:
		offset_z = (float(GameManager.grid_height) * CELL_SIZE) / 2.0
		
	var x = float(grid_pos.x) * CELL_SIZE - offset_x + (CELL_SIZE / 2.0)
	var z = float(grid_pos.y) * CELL_SIZE - offset_z + (CELL_SIZE / 2.0)
	return Vector3(x, virtual_floor_y, z)

# Checks if a target cell coordinates does not contain a physical wall block (SOLID SRP)
func _is_cell_walkable(grid_pos: Vector2i) -> bool:
	if GameManager == null or GameManager.level_layout.is_empty():
		return false
	var gw = GameManager.grid_width
	var gh = GameManager.grid_height
	
	# Wrap around for portal coordinates (safety clamping)
	var target_x = (grid_pos.x + gw) % gw
	var target_z = (grid_pos.y + gh) % gh
	
	var cell_type = int(GameManager.level_layout[target_z][target_x])
	return cell_type != 1 # 1 is wall, any other cell type is fully walkable

# Mathematical lane centering alignment to prevent drifting or getting caught on wall corners
func _snap_to_lane_center(current_pos: Vector3, direction: Vector3) -> Vector3:
	var snapped_pos := current_pos
	
	# Alignment offsets read dynamically from map boundaries
	var offset_x : float = 32.0
	var offset_z : float = 32.0
	if GameManager and GameManager.grid_width > 0:
		offset_x = (float(GameManager.grid_width) * CELL_SIZE) / 2.0
	if GameManager and GameManager.grid_height > 0:
		offset_z = (float(GameManager.grid_height) * CELL_SIZE) / 2.0
	
	# If turning horizontally (LEFT/RIGHT), snap the vertical (Z) coordinate to the nearest cell center
	if direction.x != 0.0:
		var g_z = round((current_pos.z + offset_z - (CELL_SIZE / 2.0)) / CELL_SIZE)
		snapped_pos.z = g_z * CELL_SIZE - offset_z + (CELL_SIZE / 2.0)
		
	# If turning vertically (UP/DOWN), snap the horizontal (X) coordinate to the nearest cell center
	elif direction.z != 0.0:
		var g_x = round((current_pos.x + offset_x - (CELL_SIZE / 2.0)) / CELL_SIZE)
		snapped_pos.x = g_x * CELL_SIZE - offset_x + (CELL_SIZE / 2.0)
		
	return snapped_pos

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Virtual Jump Physics
	if global_position.y > virtual_floor_y:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
		global_position.y = virtual_floor_y
		is_jumping = false
		
	if Input.is_action_just_pressed("ui_select") and not is_jumping:
		velocity.y = JUMP_VELOCITY
		is_jumping = true
		
		# Trigger the upward jet-thrust spark blast (SRP Compliance)
		PlayerVisualBuilder.trigger_jump_thrust(get_parent(), global_position)

	# Invincibility process
	if is_powered_up:
		power_timer -= delta
		if power_timer <= 0.0:
			_deactivate_power_up()
		else:
			if power_timer <= 2.5:
				var blink = int(power_timer * 5.0) % 2 == 0
				if blink:
					player_material.albedo_color = Color(1.0, 1.0, 0.0)
					player_material.emission_enabled = false
					if is_instance_valid(power_particles):
						power_particles.emitting = false
				else:
					player_material.albedo_color = Color(1.0, 0.45, 0.0)
					player_material.emission_enabled = true
					player_material.emission = Color(1.0, 0.25, 0.0)
					if is_instance_valid(power_particles):
						power_particles.emitting = true

	# Speed booster process
	if is_speed_boosted:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0.0:
			_deactivate_speed_boost()

	_handle_arcade_input()
	_process_arcade_movement()
	
	# --- PLAY PHYSICS-DRIVEN SKELETAL ANIMATIONS (SRP Compliance) ---
	_animate_character()

# Evaluates physics state velocities to trigger skeletal Mixamo tracks
func _animate_character() -> void:
	if is_dead:
		_play_animation("death")
		return
		
	var is_airborne : bool = (global_position.y > virtual_floor_y + 0.05)
	if is_airborne:
		if velocity.y > 0.1:
			_play_animation("jump")
		else:
			_play_animation("falling")
	elif velocity.length() > 0.1:
		_play_animation("running")
	else:
		_play_animation("idle")

# Helper to play animations safely preventing track loops restarts
func _play_animation(anim_name: String) -> void:
	if is_instance_valid(anim_player) and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)

# Gathers inputs, filtering out diagonals to ensure strict cardinal direction vectors
func _handle_arcade_input() -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		var target_dir := Vector3.ZERO
		
		# Cardinal filter: discard the weaker axis to prevent diagonal collision traps
		if abs(input_dir.x) > abs(input_dir.y):
			target_dir = Vector3(sign(input_dir.x), 0.0, 0.0)
		else:
			target_dir = Vector3(0.0, 0.0, sign(input_dir.y))
			
		next_direction = target_dir

# Processes movement using a robust grid-guided lane-snapping input buffering algorithm
func _process_arcade_movement() -> void:
	if GameManager == null or GameManager.level_layout.is_empty():
		move_and_slide()
		return
		
	var current_run_speed : float = BOOSTED_SPEED if is_speed_boosted else SPEED
	
	# Get current 2D grid position coordinates
	var curr_grid := _world_to_grid(global_position)
	var cell_center := _grid_to_world(curr_grid)
	
	# --- 1. HANDLE DIRECTION SWITCH (TURNING WITH CORNER TOLERANCE) ---
	if next_direction != Vector3.ZERO and next_direction != current_direction:
		# Check if player requests a 180-degree turn (always allowed instantly!)
		if next_direction == -current_direction:
			current_direction = next_direction
		else:
			# Check if the target cell in next_direction is walkable
			var target_grid : Vector2i = curr_grid + Vector2i(int(next_direction.x), int(next_direction.z))
			if _is_cell_walkable(target_grid):
				# We can turn! Check if player is within turning range of the cell center (Corner Cutting)
				var dist_to_center : float = global_position.distance_to(cell_center)
				if dist_to_center < 0.65: # Within tolerance (around 1/3 of a cell width)
					global_position = cell_center # Snap to exact center for clean turn
					current_direction = next_direction
			
	# --- 2. MOVEMENT ENGINE ---
	if current_direction != Vector3.ZERO:
		# Check if the next cell in our current direction is blocked by a wall
		var next_grid : Vector2i = curr_grid + Vector2i(int(current_direction.x), int(current_direction.z))
		var is_blocked_ahead : bool = not _is_cell_walkable(next_grid)
		
		# If blocked ahead, we must stop EXACTLY at the center of the current cell
		if is_blocked_ahead:
			var dist_to_center : float = global_position.distance_to(cell_center)
			# Check if we have reached or slightly passed the center
			var dot_prod : float = (cell_center - global_position).dot(current_direction)
			if dot_prod <= 0.0 or dist_to_center < 0.15:
				global_position = cell_center # Snap exactly to stop
				velocity = Vector3.ZERO
				current_direction = Vector3.ZERO
				next_direction = Vector3.ZERO
			else:
				# Keep moving towards the center to stop cleanly
				var y_vel = velocity.y
				velocity = current_direction * current_run_speed
				velocity.y = y_vel
		else:
			# Path is completely clear ahead: keep running
			var y_vel = velocity.y
			velocity = current_direction * current_run_speed
			velocity.y = y_vel
			
			# Lock non-moving axis to center of current lane
			global_position = _snap_to_lane_center(global_position, current_direction)
			
		# Smooth cardinal rotation (no diagonals ever!)
		var target_rotation_y = atan2(-current_direction.x, -current_direction.z) + PI
		visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, target_rotation_y, 0.25)
	else:
		var y_vel = velocity.y
		velocity = Vector3.ZERO
		velocity.y = y_vel
		
	if is_instance_valid(motion_trail):
		_update_motion_trail_materials() 
		motion_trail.emitting = (velocity.length() > 0.1)
		
	move_and_slide()


# ==============================================================================
# --- MINIMAP POLYMORPHISM (LSP/OCP COMPLIANCE) ---
# ==============================================================================

func get_minimap_color() -> Color:
	return Color(1.0, 1.0, 0.0) # Electric Yellow

func get_minimap_radius() -> float:
	return 4.5

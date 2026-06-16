# ==============================================================================
# Description: CharacterBody3D controller for Ghosts. Handles primitive capsule
#              generation, collision-tested pathfinding, and coordinates
#              with an abstract behavior strategy.
#              SOLID Refactoring & Fixes:
#              - BUG FIX: Resolved MeshInstance3D .radius compilation crash on 
#                the right pupil.
#              - CHASE / SCATTER ARCADE CYCLE: Implemented classic state cycling 
#                timers (20s Chase, 7s Scatter) targeting symmetric home corners 
#                in 3D space, making their movements incredibly distinct.
#              - DYNAMIC BLINKING RETRO EYES: Saves a class reference to the 
#                eyeball nodes and runs an independent, randomized scale-based 
#                blinking animation.
#              - ARCADE-ACCURATE LEAVING: Guides ghosts along a strict horizontal
#                and vertical path to exit the Ghost House.
#              - ONE-WAY FOSO DOOR: Dynamically blocks ghosts from re-entering.
#              - WARNING ELIMINATION: Replaced integer division with float division.
#              - DYNAMIC ALIGNMENT FIX: Calculates grid offset dynamically.
#              - Giant Proportions: Increased size (radius 0.9, height 1.8).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CharacterBody3D
class_name Ghost

# Signals to notify orchestrators of gameplay events (Position is broadcasted)
signal player_caught(is_frightened: bool, catch_position: Vector3)

# State Machine definitions
enum State { LEAVING, CHASE, SCATTER, FRIGHTENED }
var current_state : State = State.LEAVING

# Movement constants
const BASE_SPEED : float = 5.0
const FRIGHTENED_SPEED : float = 2.5
const CARDINAL_DIRECTIONS = [
	Vector3.FORWARD,
	Vector3.BACK,
	Vector3.LEFT,
	Vector3.RIGHT
]

const CELL_SIZE : float = 2.0
const ALIGNMENT_FORCE : float = 15.0 

var speed : float = BASE_SPEED

# Injected Dependencies (DIP Compliance)
var ghost_type : String = "" 
var behavior_strategy : GhostBehavior
var original_material : StandardMaterial3D
var frightened_material : StandardMaterial3D
var level_layout : Array = []
var grid_width : int = 0
var grid_height : int = 0
var eaten_stream : AudioStream

# Internal Node Components
var visual_mesh : MeshInstance3D
var eaten_audio : AudioStreamPlayer
var current_direction : Vector3 = Vector3.FORWARD
var next_direction : Vector3 = Vector3.FORWARD

# State cycle timers (Arcade standard timings)
var state_timer : float = 0.0
const CHASE_DURATION : float = 20.0
const SCATTER_DURATION : float = 7.0

# Frightened timer variables
var frightened_timer : float = 0.0
const FRIGHTENED_DURATION : float = 7.0

# Dynamic Eye Tracking Variables
var eyes_holder : Node3D
var is_blinking : bool = false
var blink_timer : float = 0.0
var blink_duration : float = 0.15
var next_blink_time : float = 3.0 # Initial time before first blink

# Foso navigation state
var spawn_position : Vector3
var exit_position : Vector3 = Vector3(0.0, 0.9, -6.5) # Dynamic fallback default
var is_inside_foso : bool = true 
var is_frozen : bool = false # Freezes ghosts during Pac-Man's death sequence

# Grid tracking variables to detect intersection crossings
var last_grid_pos : Vector2i = Vector2i(-1, -1)

# Dependency Injection initializer method
func initialize(
	type: String,
	strategy: GhostBehavior, 
	norm_mat: StandardMaterial3D, 
	fright_mat: StandardMaterial3D, 
	layout: Array, 
	width: int, 
	height: int,
	eat_stream: AudioStream
) -> void:
	ghost_type = type
	behavior_strategy = strategy
	original_material = norm_mat
	frightened_material = fright_mat
	level_layout = layout
	grid_width = width
	grid_height = height
	eaten_stream = eat_stream

func _ready() -> void:
	spawn_position = global_position
	add_to_group("ghosts")
	
	_configure_collision_layers()
	_build_ghost_visuals()
	_setup_player_detection()
	_setup_audio()
	
	# Randomize first blink timing to stagger animations
	next_blink_time = randf_range(2.0, 5.0)
	
	# --- DYNAMIC GHOST HOUSE EXIT DETECTION ---
	# Automatically scans the active level matrix to find the exact gate coordinates 
	_detect_exit_position_dynamically()
	
	# Initialize directions randomly
	current_direction = CARDINAL_DIRECTIONS.pick_random()
	next_direction = current_direction
	
	# Initialize grid coordinates safely
	var offset : float = float(grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	last_grid_pos = Vector2i(grid_x, grid_z)

# Automatically locates the foso door dynamically to prevent pathing issues
func _detect_exit_position_dynamically() -> void:
	if level_layout.is_empty() or grid_width <= 0 or grid_height <= 0:
		return
		
	# WARNING FIXED: Cast to float before division to resolve Integer Division compiler warnings
	var center_x : int = int(float(grid_width) / 2.0)
	
	# Scan rows 10 to 13 (where foso doors are strictly located in generator templates)
	for r in range(10, 14):
		if r < grid_height:
			# Check the center column and its adjacent columns
			for c in [center_x, center_x - 1, center_x + 1]:
				if c >= 0 and c < grid_width:
					# Find the open door tile (0: Empty or 2: Pellet)
					if level_layout[r][c] == 0 or level_layout[r][c] == 2:
						var offset_x : float = (float(grid_width) * CELL_SIZE) / 2.0
						var offset_z : float = (float(grid_height) * CELL_SIZE) / 2.0
						var gate_x : float = (c * CELL_SIZE) - offset_x + (CELL_SIZE / 2.0)
						var gate_z : float = (r * CELL_SIZE) - offset_z + (CELL_SIZE / 2.0)
						# Push target position slightly forward to ensure they fully cross the door threshold
						exit_position = Vector3(gate_x, 0.9, gate_z - 0.5)
						return

func _configure_collision_layers() -> void:
	# Exist on Layer 3 (Ghosts)
	collision_layer = 4
	# Only physically block with Layer 1 (Walls)
	collision_mask = 1

# Programmatically builds the capsule mesh, physical collision box, and iconic eyes
func _build_ghost_visuals() -> void:
	visual_mesh = MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# GIANT ARCADE SIZE: Diameter of 1.8m fills 90% of the 2.0m corridor width
	var radius : float = 0.9
	var height : float = 1.8
	
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = radius
	capsule_mesh.height = height
	visual_mesh.mesh = capsule_mesh
	
	if not original_material:
		original_material = StandardMaterial3D.new()
		original_material.albedo_color = Color(1.0, 0.0, 0.0)
		original_material.roughness = 0.2
		
	visual_mesh.material_override = original_material
	
	# --- PROCEDURAL RETRO GHOST EYES ---
	eyes_holder = Node3D.new()
	
	var sclera_mat := StandardMaterial3D.new()
	sclera_mat.albedo_color = Color(1.0, 1.0, 1.0) # Pure White Sclera
	sclera_mat.roughness = 0.6
	
	var pupil_mat := StandardMaterial3D.new()
	pupil_mat.albedo_color = Color(0.0, 0.2, 1.0) # Classic Pac-Man Blue pupils
	pupil_mat.roughness = 0.4
	
	# 1. Left Sclera Sphere (White Eye)
	var left_sclera := MeshInstance3D.new()
	var sclera_mesh := SphereMesh.new()
	sclera_mesh.radius = 0.2
	sclera_mesh.height = 0.4
	left_sclera.mesh = sclera_mesh
	left_sclera.material_override = sclera_mat
	left_sclera.position = Vector3(-0.35, 0.4, -0.75) # Forward on Z axis
	eyes_holder.add_child(left_sclera)
	
	# 2. Right Sclera Sphere (White Eye)
	var right_sclera := MeshInstance3D.new()
	right_sclera.mesh = sclera_mesh
	right_sclera.material_override = sclera_mat
	right_sclera.position = Vector3(0.35, 0.4, -0.75)
	eyes_holder.add_child(right_sclera)
	
	# 3. Left Pupil Sphere (Blue Pupil)
	var left_pupil := MeshInstance3D.new()
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.08
	pupil_mesh.height = 0.16
	left_pupil.mesh = pupil_mesh
	left_pupil.material_override = pupil_mat
	left_pupil.position = Vector3(-0.35, 0.4, -0.93)
	eyes_holder.add_child(left_pupil)
	
	# 4. Right Pupil Sphere (Blue Pupil)
	var right_pupil := MeshInstance3D.new()
	right_pupil.mesh = pupil_mesh # Reuses pre-built left pupil mesh (SRP compliance, eliminates compilation crash)
	right_pupil.material_override = pupil_mat
	right_pupil.position = Vector3(0.35, 0.4, -0.93)
	eyes_holder.add_child(right_pupil)
	
	# Add the eyes holder to visual_mesh so they rotate automatically with the body orientation
	visual_mesh.add_child(eyes_holder)
	
	# --- PHYSICAL COLLISION SHAPE ---
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height
	collision_shape.shape = capsule_shape
	
	add_child(visual_mesh)
	add_child(collision_shape)

func _setup_player_detection() -> void:
	var detection_area := Area3D.new()
	var detection_shape := CollisionShape3D.new()
	
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.9
	capsule_shape.height = 1.8
	detection_shape.shape = capsule_shape
	
	detection_area.add_child(detection_shape)
	add_child(detection_area)
	
	detection_area.collision_layer = 0
	detection_area.collision_mask = 2
	
	detection_area.body_entered.connect(_on_player_detected)

func _setup_audio() -> void:
	eaten_audio = AudioStreamPlayer.new()
	if eaten_stream:
		eaten_audio.stream = eaten_stream
	eaten_audio.max_polyphony = 1
	eaten_audio.volume_db = -4.0 
	add_child(eaten_audio)

# Public method to freeze ghost navigation
func set_frozen(enabled: bool) -> void:
	is_frozen = enabled
	if is_frozen:
		velocity = Vector3.ZERO

# Public API helper
func get_spawn_height_offset() -> float:
	return 0.9 

# Main physics loop managing timers, states, movement, and separation
func _physics_process(delta: float) -> void:
	if is_frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# --- ARCADE-ACCURATE LEAVING GUIDANCE ---
	# Bypasses grid navigation entirely until they fully exit the Ghost House
	if is_inside_foso:
		var target_x = exit_position.x
		# 1. Slide horizontally to line up with the door
		if abs(global_position.x - target_x) > 0.05:
			var dir_x = sign(target_x - global_position.x)
			velocity = Vector3(dir_x * FRIGHTENED_SPEED, 0.0, 0.0)
			
			var target_rotation_y = atan2(-velocity.x, -velocity.z)
			rotation.y = lerp_angle(rotation.y, target_rotation_y, 0.2)
		else:
			# 2. Once aligned, snap precisely and slide straight up through the gate
			global_position.x = target_x
			velocity = Vector3(0.0, 0.0, -FRIGHTENED_SPEED)
			rotation.y = lerp_angle(rotation.y, 0.0, 0.2) # Face North
			
		move_and_slide()
		
		# Gate threshold check
		var pos_2d := Vector2(global_position.x, global_position.z)
		var exit_2d := Vector2(exit_position.x, exit_position.z)
		if pos_2d.distance_to(exit_2d) < 1.0:
			is_inside_foso = false
			current_state = State.CHASE
			speed = BASE_SPEED
			_apply_material(original_material)
		return

	# --- CHASE / SCATTER ARCADE CYCLE TIMERS ---
	if not is_inside_foso and not is_frozen and current_state != State.FRIGHTENED:
		state_timer += delta
		if current_state == State.CHASE:
			if state_timer >= CHASE_DURATION:
				current_state = State.SCATTER
				state_timer = 0.0
				_choose_new_direction() # Force target recalculated
		elif current_state == State.SCATTER:
			if state_timer >= SCATTER_DURATION:
				current_state = State.CHASE
				state_timer = 0.0
				_choose_new_direction()

	if current_state == State.FRIGHTENED:
		frightened_timer -= delta
		if frightened_timer <= 0.0:
			_exit_frightened_state()
		else:
			# Frightened blinking warning transition
			if frightened_timer <= 2.5:
				var blink = int(frightened_timer * 5.0) % 2 == 0
				if blink and original_material:
					_apply_material(original_material)
				elif frightened_material:
					_apply_material(frightened_material)
			elif frightened_material:
				_apply_material(frightened_material)

	# --- GRID-BASED DECISION MAKING ---
	var offset : float = float(grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	var current_grid_pos := Vector2i(grid_x, grid_z)
	
	if current_grid_pos != last_grid_pos:
		last_grid_pos = current_grid_pos
		_choose_new_direction()
	elif is_on_wall():
		_choose_new_direction()
		
	# --- SMOOTH BUFFERED TURN LOGIC ---
	if next_direction != Vector3.ZERO and next_direction != current_direction:
		var test_offset = next_direction * 0.5 
		if not test_move(global_transform, test_offset):
			current_direction = next_direction
		
	# --- BASE MOVEMENT & SMOOTH STEERING ALIGNMENT ---
	if current_direction != Vector3.ZERO:
		velocity = current_direction * speed
		
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
	else:
		velocity = Vector3.ZERO
		
	# --- SOFT SEPARATION (FLOCKING REPULSION) ---
	var separation := Vector3.ZERO
	var all_ghosts = get_tree().get_nodes_in_group("ghosts")
	
	for g in all_ghosts:
		if g != self and is_instance_valid(g) and not is_inside_foso:
			var dist = global_position.distance_to(g.global_position)
			if dist > 0.0 and dist < 1.9:
				var push_dir = (global_position - g.global_position).normalized()
				separation += push_dir * (1.9 - dist) * 3.0
				
	velocity += separation
		
	# --- ROTATION & PHYSICS UPDATE ---
	if current_direction != Vector3.ZERO:
		var target_rotation_y = atan2(-current_direction.x, -current_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, 0.2)
		
	move_and_slide()
	_process_eye_blinking(delta)

# Handles the dynamic eye-blinking scale animation
func _process_eye_blinking(delta: float) -> void:
	if not is_instance_valid(eyes_holder):
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

# Helper to swap visual materials safely
func _apply_material(mat: StandardMaterial3D) -> void:
	if visual_mesh and mat:
		visual_mesh.material_override = mat

# Performs a mathematical check in the injected level matrix to see if a cell is open (Not a wall)
func _get_matrix_open_directions() -> Array:
	var open_dirs = []
	if level_layout.is_empty():
		return CARDINAL_DIRECTIONS
		
	var offset : float = float(grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	
	# One-way foso gate coordinates
	var gate_y = 12
	var gate_x = int(float(grid_width) / 2.0)
	
	for dir in CARDINAL_DIRECTIONS:
		var target_x : int = grid_x + int(dir.x)
		var target_z : int = grid_z + int(dir.z)
		
		if target_x >= 0 and target_x < grid_width and target_z >= 0 and target_z < grid_height:
			# ONE-WAY DOOR RULE: If outside the foso, treat the gate as a solid wall
			if not is_inside_foso and target_x == gate_x and target_z == gate_y:
				continue
				
			var cell_type : int = int(level_layout[target_z][target_x])
			if cell_type != 1: 
				open_dirs.append(dir)
				
	return open_dirs

# AI direction choice based on active State and open paths
func _choose_new_direction() -> void:
	var open_dirs = _get_matrix_open_directions()
	
	var possible_directions = []
	for dir in open_dirs:
		if dir != -current_direction:
			possible_directions.append(dir)
			
	if possible_directions.is_empty():
		possible_directions = open_dirs
	if possible_directions.is_empty():
		possible_directions = CARDINAL_DIRECTIONS

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		next_direction = possible_directions.pick_random()
		return

	var target_pos : Vector3 = player.global_position

	if is_inside_foso:
		target_pos = exit_position
	elif current_state == State.SCATTER:
		# Direct corner targets matching classic arcade corners (OCP Compliance)
		var offset_x = (float(grid_width) * CELL_SIZE) / 2.0
		var offset_z = (float(grid_height) * CELL_SIZE) / 2.0
		var min_x = CELL_SIZE - offset_x + (CELL_SIZE / 2.0)
		var max_x = (float(grid_width - 2) * CELL_SIZE) - offset_x + (CELL_SIZE / 2.0)
		var min_z = CELL_SIZE - offset_z + (CELL_SIZE / 2.0)
		var max_z = (float(grid_height - 2) * CELL_SIZE) - offset_z + (CELL_SIZE / 2.0)
		
		match ghost_type:
			"Blinky": target_pos = Vector3(max_x, 0.9, min_z) # Top-Right
			"Pinky": target_pos = Vector3(min_x, 0.9, min_z)  # Top-Left
			"Inky": target_pos = Vector3(max_x, 0.9, max_z)   # Bottom-Right
			"Clyde": target_pos = Vector3(min_x, 0.9, max_z)  # Bottom-Left
			_: target_pos = Vector3(min_x, 0.9, min_z)
	elif current_state == State.FRIGHTENED:
		var best_dir = possible_directions[0]
		var max_dist : float = -1.0
		for dir in possible_directions:
			var next_pos : Vector3 = global_position + (dir * CELL_SIZE)
			var dist : float = next_pos.distance_to(player.global_position)
			if dist > max_dist:
				max_dist = dist
				break
		next_direction = best_dir
		return
	else:
		if behavior_strategy:
			target_pos = behavior_strategy.get_target_position(self, player)

	if randf() < 0.85:
		var best_dir = possible_directions[0]
		var min_dist : float = 999999.0
		
		for dir in possible_directions:
			var next_pos : Vector3 = global_position + (dir * CELL_SIZE)
			var dist : float = next_pos.distance_to(target_pos)
			if dist < min_dist:
				min_dist = dist
				best_dir = dir
				
		next_direction = best_dir
	else:
		next_direction = possible_directions.pick_random()

# Public method: Triggers Frightened mode
func activate_frightened_mode() -> void:
	current_state = State.FRIGHTENED
	speed = FRIGHTENED_SPEED
	frightened_timer = FRIGHTENED_DURATION
	
	next_direction = -current_direction
	_apply_material(frightened_material)

# Restores the ghost back to standard chase behavior
func _exit_frightened_state() -> void:
	current_state = State.CHASE
	speed = BASE_SPEED
	state_timer = 0.0 # Reset cycle timer
	_apply_material(original_material)

# Public method: Resets ghost back to base (DIP Compliance)
func reset_to_base() -> void:
	is_frozen = false 
	global_position = spawn_position
	is_inside_foso = true 
	current_state = State.LEAVING
	speed = BASE_SPEED
	state_timer = 0.0 # Reset cycle timer
	_apply_material(original_material)
	
	current_direction = CARDINAL_DIRECTIONS.pick_random()
	next_direction = current_direction
	
	var offset : float = float(grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	last_grid_pos = Vector2i(grid_x, grid_z)

# Programmatically spawns a beautiful ghostly particle explosion when eaten and plays sound
func play_eaten_particles() -> void:
	if eaten_audio and eaten_audio.stream:
		eaten_audio.play()
		
	var particles := GPUParticles3D.new()
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.12)
	
	var mat := StandardMaterial3D.new()
	if original_material:
		mat.albedo_color = original_material.albedo_color
	else:
		mat.albedo_color = Color(0.0, 1.0, 1.0) 
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = 0.2
	
	p_mat.direction = Vector3.UP
	p_mat.spread = 180.0 
	
	p_mat.initial_velocity_min = 3.0
	p_mat.initial_velocity_max = 5.0
	p_mat.gravity = Vector3(0.0, -8.0, 0.0) 
	
	p_mat.damping_min = 1.0
	p_mat.damping_max = 2.0
	
	particles.process_material = p_mat
	
	particles.amount = 20
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.6
	
	var eaten_position = global_position
	
	get_parent().add_child(particles)
	particles.global_position = eaten_position
	particles.emitting = true
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): particles.queue_free())

# Handles player intersection and emits state notification signals
func _on_player_detected(body: Node3D) -> void:
	if body.is_in_group("player"):
		if current_state == State.FRIGHTENED:
			play_eaten_particles()
			
			# Notify listeners with both the state and the exact 3D world coordinate (DIP Compliance)
			player_caught.emit(true, global_position)
			
			global_position = spawn_position
			is_inside_foso = true 
			current_state = State.LEAVING
			speed = BASE_SPEED
			_apply_material(original_material)
		else:
			# Notify listeners of player catch with coordinates
			player_caught.emit(false, global_position)

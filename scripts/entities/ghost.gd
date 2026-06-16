# ==============================================================================
# Description: CharacterBody3D controller for Ghosts. Handles primitive capsule
#              generation, collision-tested pathfinding, and coordinates
#              with an abstract behavior strategy.
#              SOLID Refactoring:
#              - SRP: Removed body.respawn() call. The ghost only reports the
#                collision via signals, leaving orchestrators to handle the sequence.
#              - Polishing: Added a public `set_frozen` method to freeze ghosts.
#              - Collision Fix: Only physically blocks with Layer 1 (Walls).
#              - Visual Effects & OCP: Added a programmatic 3D particle explosion
#                which dynamically matches the ghost's original color.
#              - Giant Proportions: Increased size (radius 0.9, height 1.8) to fit
#                tightly within 2.0m wide corridors, locking them on rails and
#                preventing lane drifting.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CharacterBody3D
class_name Ghost

# Signals to notify orchestrators of gameplay events (SRP Compliance)
signal player_caught(is_frightened: bool)

# State Machine definitions
enum State { LEAVING, CHASE, FRIGHTENED }
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

# Internal Node Components
var visual_mesh : MeshInstance3D
var current_direction : Vector3 = Vector3.FORWARD
var next_direction : Vector3 = Vector3.FORWARD

# Frightened timer variables
var frightened_timer : float = 0.0
const FRIGHTENED_DURATION : float = 7.0

# Foso navigation state
var spawn_position : Vector3
var exit_position : Vector3 = Vector3(0.0, 0.8, -4.0) 
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
	height: int
) -> void:
	ghost_type = type
	behavior_strategy = strategy
	original_material = norm_mat
	frightened_material = fright_mat
	level_layout = layout
	grid_width = width
	grid_height = height

func _ready() -> void:
	spawn_position = global_position
	add_to_group("ghosts")
	
	_configure_collision_layers()
	_build_ghost_visuals()
	_setup_player_detection()
	
	# Initialize directions randomly
	current_direction = CARDINAL_DIRECTIONS.pick_random()
	next_direction = current_direction
	
	# Initialize grid coordinates safely
	var offset : float = float(grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	last_grid_pos = Vector2i(grid_x, grid_z)

func _configure_collision_layers() -> void:
	# Exist on Layer 3 (Ghosts)
	collision_layer = 4
	# Only physically block with Layer 1 (Walls)
	collision_mask = 1

# Programmatically builds the capsule mesh and physical collision box
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
	
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height
	collision_shape.shape = capsule_shape
	
	add_child(visual_mesh)
	add_child(collision_shape)

func _setup_player_detection() -> void:
	var detection_area := Area3D.new()
	var detection_shape := CollisionShape3D.new()
	
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 1.0 # Adjusted up to match the larger body size
	detection_shape.shape = sphere_shape
	
	detection_area.add_child(detection_shape)
	add_child(detection_area)
	
	detection_area.collision_layer = 0
	detection_area.collision_mask = 2
	
	detection_area.body_entered.connect(_on_player_detected)

# Public method to freeze ghost navigation
func set_frozen(enabled: bool) -> void:
	is_frozen = enabled
	if is_frozen:
		velocity = Vector3.ZERO

# Main physics loop managing timers, states, movement, and separation
func _physics_process(delta: float) -> void:
	if is_frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if is_inside_foso:
		var pos_2d := Vector2(global_position.x, global_position.z)
		var exit_2d := Vector2(exit_position.x, exit_position.z)
		if pos_2d.distance_to(exit_2d) < 1.0:
			is_inside_foso = false
			if current_state == State.LEAVING:
				current_state = State.CHASE
				speed = BASE_SPEED
				_apply_material(original_material)
				
	elif current_state == State.FRIGHTENED:
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
		
		if current_direction.x != 0.0:
			var target_z = round(global_position.z / CELL_SIZE) * CELL_SIZE
			velocity.z = (target_z - global_position.z) * ALIGNMENT_FORCE
		elif current_direction.z != 0.0:
			var target_x = round(global_position.x / CELL_SIZE) * CELL_SIZE
			velocity.x = (target_x - global_position.x) * ALIGNMENT_FORCE
	else:
		velocity = Vector3.ZERO
		
	# --- SOFT SEPARATION (FLOCKING REPULSION) ---
	var separation := Vector3.ZERO
	var all_ghosts = get_tree().get_nodes_in_group("ghosts")
	
	for g in all_ghosts:
		if g != self and is_instance_valid(g) and not is_inside_foso:
			var dist = global_position.distance_to(g.global_position)
			# Adjusted repulsion distance to 1.9 to prevent wide mesh overlap
			if dist > 0.0 and dist < 1.9:
				var push_dir = (global_position - g.global_position).normalized()
				separation += push_dir * (1.9 - dist) * 3.0
				
	velocity += separation
		
	# --- ROTATION & PHYSICS UPDATE ---
	if current_direction != Vector3.ZERO:
		var target_rotation_y = atan2(-current_direction.x, -current_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, 0.2)
		
	move_and_slide()

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
	
	for dir in CARDINAL_DIRECTIONS:
		var target_x : int = grid_x + int(dir.x)
		var target_z : int = grid_z + int(dir.z)
		
		if target_x >= 0 and target_x < grid_width and target_z >= 0 and target_z < grid_height:
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
	elif current_state == State.FRIGHTENED:
		var best_dir = possible_directions[0]
		var max_dist : float = -1.0
		for dir in possible_directions:
			var next_pos : Vector3 = global_position + (dir * CELL_SIZE)
			var dist : float = next_pos.distance_to(player.global_position)
			if dist > max_dist:
				max_dist = dist
				best_dir = dir
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
	_apply_material(original_material)

# Public method: Resets ghost back to base (DIP Compliance)
func reset_to_base() -> void:
	is_frozen = false 
	global_position = spawn_position
	is_inside_foso = true 
	current_state = State.LEAVING
	speed = BASE_SPEED
	_apply_material(original_material)
	
	current_direction = CARDINAL_DIRECTIONS.pick_random()
	next_direction = current_direction
	
	var offset : float = float(grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	last_grid_pos = Vector2i(grid_x, grid_z)

# Programmatically spawns a beautiful ghostly particle explosion when eaten
func play_eaten_particles() -> void:
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
			# Trigger the beautiful original-colored particle explosion
			play_eaten_particles()
			
			# Notify listeners that a frightened ghost was eaten
			player_caught.emit(true)
			
			global_position = spawn_position
			is_inside_foso = true 
			current_state = State.LEAVING
			speed = BASE_SPEED
			_apply_material(original_material)
		else:
			# Notify listeners that a normal ghost caught Pac-Man
			player_caught.emit(false)

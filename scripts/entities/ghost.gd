# ==============================================================================
# Description: CharacterBody3D controller for Ghosts. Handles primitive capsule
#              generation, collision-tested pathfinding, and assigns SOLID
#              compliant behavior strategy patterns.
#              UPDATED: Increased Ghost visual and collision size to make them
#              larger and more imposing than the standard Pac-Man sphere.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CharacterBody3D
class_name Ghost

# State Machine definitions
enum State { LEAVING, CHASE, FRIGHTENED }
var current_state : State = State.LEAVING

@export_enum("Blinky", "Pinky", "Inky", "Clyde") var ghost_type : String = "Blinky"

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
const ALIGNMENT_FORCE : float = 15.0 # Smooth vector steering alignment force

var speed : float = BASE_SPEED
var ghost_material : StandardMaterial3D

# Buffered turning logic (Identical to Player)
var current_direction : Vector3 = Vector3.FORWARD
var next_direction : Vector3 = Vector3.FORWARD

# Frightened timer variables
var frightened_timer : float = 0.0
const FRIGHTENED_DURATION : float = 7.0

# Caching positions and foso navigation state
var spawn_position : Vector3
var exit_position : Vector3 = Vector3(0.0, 0.8, -4.0) # Coordinate of the foso gate exit
var is_inside_foso : bool = true # Force exit navigation prior to player chasing

# Grid tracking variables to detect new tile intersections
var last_grid_pos : Vector2i = Vector2i(-1, -1)

# SOLID Strategy reference (Targeting logic is delegated here)
var behavior_strategy : GhostBehavior

func _ready() -> void:
	spawn_position = global_position
	add_to_group("ghosts")
	
	_configure_collision_layers()
	_initialize_material()
	_build_ghost_visuals()
	_setup_player_detection()
	_initialize_behavior_strategy()
	
	# Initialize directions randomly
	current_direction = CARDINAL_DIRECTIONS.pick_random()
	next_direction = current_direction
	
	# Initialize the grid position to prevent an instant turn check on frame 1
	var offset : float = float(GameManager.grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	last_grid_pos = Vector2i(grid_x, grid_z)
	
	if GameManager:
		GameManager.power_pellet_activated.connect(_on_power_pellet_activated)
		GameManager.player_killed.connect(_on_player_killed)

# Configures symmetric collision layers: Ghost is on Layer 3, blocks with Layer 1 (Walls) and Layer 2 (Player)
func _configure_collision_layers() -> void:
	collision_layer = 4
	collision_mask = 3

# Instantiate strategy dynamically based on ghost type (SOLID - Open/Closed compliance)
func _initialize_behavior_strategy() -> void:
	match ghost_type:
		"Blinky": behavior_strategy = BlinkyBehavior.new()
		"Pinky": behavior_strategy = PinkyBehavior.new()
		"Inky": behavior_strategy = InkyBehavior.new()
		"Clyde": behavior_strategy = ClydeBehavior.new()
		_: behavior_strategy = GhostBehavior.new()

# Configures the material color based on the ghost's identity
func _initialize_material() -> void:
	if not ghost_material:
		ghost_material = StandardMaterial3D.new()
		
	ghost_material.roughness = 0.2
	ghost_material.emission_enabled = false
	
	match ghost_type:
		"Blinky": ghost_material.albedo_color = Color(1.0, 0.0, 0.0) # Red
		"Pinky": ghost_material.albedo_color = Color(1.0, 0.7, 0.8) # Pink
		"Inky": ghost_material.albedo_color = Color(0.0, 1.0, 1.0) # Cyan
		"Clyde": ghost_material.albedo_color = Color(1.0, 0.6, 0.0) # Orange

# Programmatically builds the capsule mesh and physical collision box
func _build_ghost_visuals() -> void:
	var mesh_instance := MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# INCREASED SIZE: Ghosts are now larger than Pac-Man (0.6 radius)
	var radius : float = 0.75
	var height : float = 1.8
	
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = radius
	capsule_mesh.height = height
	mesh_instance.mesh = capsule_mesh
	mesh_instance.material_override = ghost_material
	
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height
	collision_shape.shape = capsule_shape
	
	add_child(mesh_instance)
	add_child(collision_shape)

# Setup a dedicated trigger area to safely detect player intersection on Layer 2
func _setup_player_detection() -> void:
	var detection_area := Area3D.new()
	var detection_shape := CollisionShape3D.new()
	
	var sphere_shape := SphereShape3D.new()
	# Scaled up detection area slightly to match new body size
	sphere_shape.radius = 0.95 
	detection_shape.shape = sphere_shape
	
	detection_area.add_child(detection_shape)
	add_child(detection_area)
	
	detection_area.collision_layer = 0
	detection_area.collision_mask = 2
	
	detection_area.body_entered.connect(_on_player_detected)

# Main physics loop managing timers, states, movement, separation, and rotation
func _physics_process(delta: float) -> void:
	# Foso exit controller (Calculated on 2D horizontal plane)
	if is_inside_foso:
		var pos_2d := Vector2(global_position.x, global_position.z)
		var exit_2d := Vector2(exit_position.x, exit_position.z)
		if pos_2d.distance_to(exit_2d) < 1.0:
			is_inside_foso = false
			if current_state == State.LEAVING:
				current_state = State.CHASE
				speed = BASE_SPEED
				_initialize_material()
				
	elif current_state == State.FRIGHTENED:
		frightened_timer -= delta
		if frightened_timer <= 0.0:
			_exit_frightened_state()
		else:
			# Frightened blinking warning
			if frightened_timer <= 2.5:
				var blink = int(frightened_timer * 5.0) % 2 == 0
				if blink:
					ghost_material.albedo_color = Color(1.0, 1.0, 1.0)
					ghost_material.emission_enabled = true
					ghost_material.emission = Color(0.8, 0.8, 0.8)
				else:
					ghost_material.albedo_color = Color(0.0, 0.0, 1.0)
					ghost_material.emission_enabled = true
					ghost_material.emission = Color(0.0, 0.2, 0.8)
			else:
				ghost_material.albedo_color = Color(0.0, 0.0, 1.0)
				ghost_material.emission_enabled = true
				ghost_material.emission = Color(0.0, 0.2, 0.8)

	# --- GRID-BASED DECISION MAKING LOOP ---
	var offset : float = float(GameManager.grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	var current_grid_pos := Vector2i(grid_x, grid_z)
	
	# Evaluate AI direction choice ONLY when entering a new tile or hitting a wall
	if current_grid_pos != last_grid_pos:
		last_grid_pos = current_grid_pos
		_choose_new_direction()
	elif is_on_wall():
		_choose_new_direction()
		
	# --- SMOOTH BUFFERED TURN LOGIC (Same as Player) ---
	# Tests if the path is clear to execute the turn buffered by the AI
	if next_direction != Vector3.ZERO and next_direction != current_direction:
		var test_offset = next_direction * 0.5 
		if not test_move(global_transform, test_offset):
			current_direction = next_direction
		
	# --- BASE MOVEMENT & SMOOTH STEERING ALIGNMENT ---
	if current_direction != Vector3.ZERO:
		velocity = current_direction * speed
		
		# Pull ghosts smoothly to the centerline of corridors
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
			# Adjusted repulsion distance for the larger capsules
			if dist > 0.0 and dist < 1.6:
				var push_dir = (global_position - g.global_position).normalized()
				separation += push_dir * (1.6 - dist) * 3.0
				
	# Apply separation force to the final velocity
	velocity += separation
		
	# --- ROTATION & PHYSICS UPDATE ---
	if current_direction != Vector3.ZERO:
		var target_rotation_y = atan2(-current_direction.x, -current_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, 0.2)
		
	move_and_slide()

# Performs a mathematical check in the level matrix to see if a cell is open (Not a wall)
func _get_matrix_open_directions() -> Array:
	var open_dirs = []
	if not GameManager or GameManager.level_layout.is_empty():
		return CARDINAL_DIRECTIONS
		
	var offset : float = float(GameManager.grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	
	for dir in CARDINAL_DIRECTIONS:
		var target_x : int = grid_x + int(dir.x)
		var target_z : int = grid_z + int(dir.z)
		
		if target_x >= 0 and target_x < GameManager.grid_width and target_z >= 0 and target_z < GameManager.grid_height:
			var cell_type : int = int(GameManager.level_layout[target_z][target_x])
			if cell_type != 1: 
				open_dirs.append(dir)
				
	return open_dirs

# AI direction choice based on active State and open paths. Assigns to NEXT_DIRECTION buffer.
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

# Signal Callback: Triggers Frightened mode and instantly reverses direction (Classic arcade rule)
func _on_power_pellet_activated() -> void:
	current_state = State.FRIGHTENED
	speed = FRIGHTENED_SPEED
	frightened_timer = FRIGHTENED_DURATION
	
	next_direction = -current_direction
	
	ghost_material.albedo_color = Color(0.0, 0.0, 1.0) 
	ghost_material.emission_enabled = true
	ghost_material.emission = Color(0.0, 0.2, 0.8) 

# Restores the ghost back to standard chase behavior
func _exit_frightened_state() -> void:
	current_state = State.CHASE
	speed = BASE_SPEED
	_initialize_material()

# Signal Callback: Resets ghost back to base
func _on_player_killed() -> void:
	global_position = spawn_position
	is_inside_foso = true 
	current_state = State.LEAVING
	speed = BASE_SPEED
	_initialize_material()
	
	current_direction = CARDINAL_DIRECTIONS.pick_random()
	next_direction = current_direction
	
	var offset : float = float(GameManager.grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	last_grid_pos = Vector2i(grid_x, grid_z)

# Handles player intersection
func _on_player_detected(body: Node3D) -> void:
	if body.is_in_group("player"):
		if current_state == State.FRIGHTENED:
			if GameManager:
				GameManager.add_score(200)
			
			global_position = spawn_position
			is_inside_foso = true 
			current_state = State.LEAVING
			speed = BASE_SPEED
			_initialize_material()
		else:
			if current_state == State.CHASE:
				if GameManager:
					GameManager.lose_life()
					
				if body.has_method("respawn"):
					body.respawn()

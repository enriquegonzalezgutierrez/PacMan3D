# ==============================================================================
# Description: CharacterBody3D controller for Pac-Man. Handles movement inputs,
#              automatic camera setup, visual mesh rotation, and continuous 
#              arcade-faithful movement with symmetric collision layering. 
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CharacterBody3D
class_name Player

const SPEED : float = 7.0
const CELL_SIZE : float = 2.0 # Grid step to calculate corridor centerlines
const ALIGNMENT_FORCE : float = 15.0 # Speed factor to smoothly pull player to lane center

var player_material : StandardMaterial3D
var visual_mesh : MeshInstance3D # Reference to rotate only the ball, not the camera

# Assigned dynamically by the LevelManager prior to _ready() to prevent (0,0,0) bugs
var spawn_position : Vector3

# Arcade movement queue variables
var current_direction : Vector3 = Vector3.ZERO
var next_direction : Vector3 = Vector3.ZERO

func _ready() -> void:
	# Crucial: Pellets and Ghosts look for this group on collision
	add_to_group("player")
	
	_configure_collision_layers()
	_initialize_material()
	_build_player_visuals()
	_setup_camera()

# Configures symmetric collision layers: Player is on Layer 2, blocks with Layer 1 (Walls) and Layer 3 (Ghosts)
func _configure_collision_layers() -> void:
	# Exist on Layer 2 (Bit value 2)
	collision_layer = 2
	# Block physically with Layer 1 (Walls) and Layer 3 (Ghosts) (Bit values 1 + 4 = 5)
	collision_mask = 5

# Sets up the classic shiny yellow material for Pac-Man
func _initialize_material() -> void:
	player_material = StandardMaterial3D.new()
	player_material.albedo_color = Color(1.0, 1.0, 0.0) # Bright Yellow
	player_material.roughness = 0.1
	player_material.metallic = 0.1

# Programmatically generates the sphere mesh and physical collision box
func _build_player_visuals() -> void:
	visual_mesh = MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	
	var radius : float = 0.8
	
	# Setup Mesh (Sphere)
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	visual_mesh.mesh = sphere_mesh
	visual_mesh.material_override = player_material
	
	# Setup Collision Shape (Sphere)
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	
	# Assemble the node tree
	add_child(visual_mesh)
	add_child(collision_shape)

# Automatically attaches an optimized, perfectly framed follow camera
func _setup_camera() -> void:
	var spring_arm := SpringArm3D.new()
	
	# Balanced distance (14.0m) to frame Pac-Man and several lanes ahead
	spring_arm.spring_length = 14.0
	
	# Steep downward angle (-60.0) to keep Pac-Man fully visible in the lower-middle screen area
	spring_arm.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	
	# Position the camera pivot slightly higher (1.5) above the player's center
	spring_arm.position = Vector3(0.0, 1.5, 0.0)
	
	var camera := Camera3D.new()
	camera.current = true # Sets this camera as the active viewport camera
	
	# Assemble camera setup
	spring_arm.add_child(camera)
	add_child(spring_arm)

# Resets player position to its original spawn point on death
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	current_direction = Vector3.ZERO
	next_direction = Vector3.ZERO

# Physics processing loop for movement calculations
func _physics_process(_delta: float) -> void:
	_handle_arcade_input()
	_process_arcade_movement()

# Captures keyboard inputs to register the "next desired direction" (Input queue)
func _handle_arcade_input() -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_dir != Vector2.ZERO:
		next_direction = Vector3(input_dir.x, 0.0, input_dir.y).normalized()

# Evaluates corridor spaces, applies smooth vector steering, and executes movement
func _process_arcade_movement() -> void:
	# 1. Queue Check (Turn decision)
	if next_direction != Vector3.ZERO:
		var test_offset = next_direction * 0.5
		if not test_move(global_transform, test_offset):
			current_direction = next_direction
			
	# 2. Collision Check (Wall dead-ends)
	if current_direction != Vector3.ZERO:
		var test_offset = current_direction * 0.1 # Small step forward check
		if test_move(global_transform, test_offset):
			current_direction = Vector3.ZERO
			next_direction = Vector3.ZERO # Wipe queue
			
	# 3. Apply movement and Steering-based Lane Centering
	if current_direction != Vector3.ZERO:
		velocity = current_direction * SPEED
		
		# SMOOTH STEERING CORRECTION:
		# Smoothly pull player to center of corridors on perpendicular axis
		if current_direction.x != 0.0:
			var target_z = round(global_position.z / CELL_SIZE) * CELL_SIZE
			velocity.z = (target_z - global_position.z) * ALIGNMENT_FORCE
		elif current_direction.z != 0.0:
			var target_x = round(global_position.x / CELL_SIZE) * CELL_SIZE
			velocity.x = (target_x - global_position.x) * ALIGNMENT_FORCE
			
		# Rotate visual ball mesh smoothly towards the active direction
		var target_rotation_y = atan2(-current_direction.x, -current_direction.z)
		visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, target_rotation_y, 0.25)
	else:
		velocity = Vector3.ZERO
		
	move_and_slide()

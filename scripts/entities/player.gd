# ==============================================================================
# Description: CharacterBody3D controller for Pac-Man. Handles movement inputs,
#              visual mesh rotation, and continuous arcade movement.
#              Features an ORTHOGRAPHIC top-down camera to prevent 3D perspective
#              optical illusions (walls hiding objects on the edges).
#              UPDATED: Adjusted player radius to match the ghost's proportions.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CharacterBody3D
class_name Player

const SPEED : float = 7.0
const CELL_SIZE : float = 2.0 
const ALIGNMENT_FORCE : float = 15.0 

var player_material : StandardMaterial3D
var visual_mesh : MeshInstance3D 

var spawn_position : Vector3
var current_direction : Vector3 = Vector3.ZERO
var next_direction : Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("player")
	_configure_collision_layers()
	_initialize_material()
	_build_player_visuals()
	_setup_camera()

func _configure_collision_layers() -> void:
	collision_layer = 2
	collision_mask = 5

func _initialize_material() -> void:
	player_material = StandardMaterial3D.new()
	player_material.albedo_color = Color(1.0, 1.0, 0.0) 
	player_material.roughness = 0.1
	player_material.metallic = 0.1

func _build_player_visuals() -> void:
	visual_mesh = MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# Reduced radius from 0.8 to 0.6 to match the ghosts' width (capsule radius is 0.6)
	var radius : float = 0.6
	
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

func _setup_camera() -> void:
	var spring_arm := SpringArm3D.new()
	spring_arm.top_level = true
	spring_arm.position = Vector3(0.0, 30.0, 0.0)
	spring_arm.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	spring_arm.spring_length = 0.0
	
	var camera := Camera3D.new()
	
	# =======================================================================
	# Orthogonal Camera setup to remove 3D perspective hiding objects behind walls.
	# =======================================================================
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Size to cover the 21x21 grid (42 meters) plus a small margin
	camera.size = 46.0 
	
	camera.current = true 
	
	spring_arm.add_child(camera)
	add_child(spring_arm)

func respawn() -> void:
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

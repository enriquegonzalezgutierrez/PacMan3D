# ==============================================================================
# Description: CharacterBody3D controller for Ghosts. Handles collision-tested 
#              pathfinding, state machine management, and coordinates with an 
#              abstract behavior strategy.
#              SOLID Refactoring:
#              - SRP & LSP Compliance: Maintained clean separation of concerns.
#              - Positional 3D Audio: Upgraded eaten audio to AudioStreamPlayer3D. 
#                Implemented dynamic stereo panning, log distance attenuation, 
#                and atmospheric low-pass damping filters.
#              - API Fix: Removed non-existent attenuation_filter_enabled property 
#                to comply with Godot 4's native AudioStreamPlayer3D specifications.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CharacterBody3D
class_name Ghost

# Signals to notify orchestrators of gameplay events
signal player_caught(is_frightened: bool, catch_position: Vector3)

# State Machine definitions
enum State { LEAVING, CHASE, SCATTER, FRIGHTENED, EATEN }
var current_state : State = State.LEAVING

# Movement constants
var base_speed : float = 5.0
var frightened_speed : float = 2.5
const EATEN_SPEED : float = 18.0 
const CARDINAL_DIRECTIONS = [
	Vector3.FORWARD,
	Vector3.BACK,
	Vector3.LEFT,
	Vector3.RIGHT
]

const CELL_SIZE : float = 2.0
const ALIGNMENT_FORCE : float = 15.0 

var speed : float = base_speed

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
var eaten_audio : AudioStreamPlayer3D
var current_direction : Vector3 = Vector3.FORWARD
var next_direction : Vector3 = Vector3.FORWARD

# State cycle timers
var state_timer : float = 0.0
const CHASE_DURATION : float = 20.0
const SCATTER_DURATION : float = 7.0

# Frightened timer variables
var frightened_timer : float = 0.0
var frightened_duration : float = 7.0 

# Visual Builder References (Injected by GhostVisualBuilder)
var eyes_holder : Node3D
var skirt_spheres : Array[MeshInstance3D] = []
var capsule_height : float = 1.8 

# Dynamic Eye Tracking Variables
var is_blinking : bool = false
var blink_timer : float = 0.0
var blink_duration : float = 0.15
var next_blink_time : float = 3.0

var hover_time : float = 0.0

# Foso navigation state
var spawn_position : Vector3
var exit_position : Vector3 = Vector3(0.0, 0.9, -6.5) 
var is_inside_foso : bool = true 
var is_frozen : bool = false 

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
	
	if GameManager:
		var multiplier = GameManager.get_ghost_speed_multiplier()
		base_speed *= multiplier
		frightened_speed *= multiplier
		speed = base_speed
		
		frightened_duration = GameManager.get_frightened_duration()
	
	_configure_collision_layers()
	
	# Delegate visual construction to the static builder (SRP Compliance)
	var visual_components = GhostVisualBuilder.build_visuals(self, behavior_strategy, original_material)
	visual_mesh = visual_components["visual_mesh"]
	eyes_holder = visual_components["eyes_holder"]
	skirt_spheres = visual_components["skirt_spheres"]
	capsule_height = visual_components["capsule_height"]
	
	_setup_player_detection()
	_setup_audio()
	
	next_blink_time = randf_range(2.0, 5.0)
	hover_time = randf_range(0.0, 5.0)
	
	_detect_exit_position_dynamically()
	
	current_direction = CARDINAL_DIRECTIONS.pick_random()
	next_direction = current_direction
	
	var offset : float = float(grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	last_grid_pos = Vector2i(grid_x, grid_z)

func _detect_exit_position_dynamically() -> void:
	if level_layout.is_empty() or grid_width <= 0 or grid_height <= 0:
		return
		
	var center_x : int = int(float(grid_width) / 2.0)
	
	for r in range(10, 14):
		if r < grid_height:
			for c in [center_x, center_x - 1, center_x + 1]:
				if c >= 0 and c < grid_width:
					if level_layout[r][c] == 0 or level_layout[r][c] == 2:
						var offset_x : float = (float(grid_width) * CELL_SIZE) / 2.0
						var offset_z : float = (float(grid_height) * CELL_SIZE) / 2.0
						var gate_x : float = (c * CELL_SIZE) - offset_x + (CELL_SIZE / 2.0)
						var gate_z : float = (r * CELL_SIZE) - offset_z + (CELL_SIZE / 2.0)
						exit_position = Vector3(gate_x, 0.9, gate_z - 0.5)
						return

func _configure_collision_layers() -> void:
	collision_layer = 4
	collision_mask = 1

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

# Programmatically constructs the spatial 3D audio player (3D Positional Audio Compliance)
func _setup_audio() -> void:
	eaten_audio = AudioStreamPlayer3D.new()
	eaten_audio.unit_size = 10.0 # Attenuation begins at 10 meters
	eaten_audio.max_distance = 30.0 # Fades completely past map limits
	eaten_audio.panning_strength = 1.0 # High-contrast stereo panning
	
	# --- API FIX: ENABLING FILTERS AUTOMATICALLY IN GODOT 4 ---
	# In Godot 4, setting the cutoff frequency automatically activates the low-pass 
	# distance filter, completely removing the need for a separate boolean property.
	eaten_audio.attenuation_filter_cutoff_hz = 5000.0 # 5 kHz low-pass cutoff
	
	if eaten_stream:
		eaten_audio.stream = eaten_stream
	eaten_audio.max_polyphony = 1
	eaten_audio.volume_db = -4.0 
	add_child(eaten_audio)

func set_frozen(enabled: bool) -> void:
	is_frozen = enabled
	if is_frozen:
		velocity = Vector3.ZERO

func get_spawn_height_offset() -> float:
	return 0.9 

func _physics_process(delta: float) -> void:
	if is_frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if is_inside_foso:
		var target_x = exit_position.x
		if abs(global_position.x - target_x) > 0.05:
			var dir_x = sign(target_x - global_position.x)
			velocity = Vector3(dir_x * frightened_speed, 0.0, 0.0)
			var target_rotation_y = atan2(-velocity.x, -velocity.z)
			rotation.y = lerp_angle(rotation.y, target_rotation_y, 0.2)
		else:
			global_position.x = target_x
			velocity = Vector3(0.0, 0.0, -frightened_speed)
			rotation.y = lerp_angle(rotation.y, 0.0, 0.2)
			
		move_and_slide()
		_process_ghost_animations(delta)
		
		var pos_2d := Vector2(global_position.x, global_position.z)
		var exit_2d := Vector2(exit_position.x, exit_position.z)
		if pos_2d.distance_to(exit_2d) < 1.0:
			is_inside_foso = false
			current_state = State.CHASE
			speed = base_speed
			_apply_material(original_material)
			collision_mask = 1 | 8
		return

	if not is_inside_foso and not is_frozen and current_state != State.FRIGHTENED and current_state != State.EATEN:
		state_timer += delta
		if current_state == State.CHASE:
			if state_timer >= CHASE_DURATION:
				current_state = State.SCATTER
				state_timer = 0.0
				_choose_new_direction() 
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
			if frightened_timer <= 2.5:
				var blink = int(frightened_timer * 5.0) % 2 == 0
				if blink and original_material:
					_apply_material(original_material)
				elif frightened_material:
					_apply_material(frightened_material)
			elif frightened_material:
				_apply_material(frightened_material)
				
	if current_state == State.EATEN:
		var pos_2d := Vector2(global_position.x, global_position.z)
		var spawn_2d := Vector2(spawn_position.x, spawn_position.z)
		if pos_2d.distance_to(spawn_2d) < 0.5:
			is_inside_foso = true 
			current_state = State.LEAVING
			speed = base_speed
			_set_body_visibility(true) 
			_apply_material(original_material)
			collision_mask = 1
			current_direction = CARDINAL_DIRECTIONS.pick_random()
			next_direction = current_direction
			return

	var offset : float = float(grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	var current_grid_pos := Vector2i(grid_x, grid_z)
	
	if current_grid_pos != last_grid_pos:
		last_grid_pos = current_grid_pos
		_choose_new_direction()
	elif is_on_wall():
		_choose_new_direction()
		
	if next_direction != Vector3.ZERO and next_direction != current_direction:
		var test_offset = next_direction * 0.5 
		if not test_move(global_transform, test_offset):
			current_direction = next_direction
		
	if current_direction != Vector3.ZERO:
		var adjusted_speed : float = speed
		if not is_inside_foso and current_state != State.EATEN:
			var ghosts = get_tree().get_nodes_in_group("ghosts")
			for g in ghosts:
				if g != self and is_instance_valid(g) and not g.is_inside_foso:
					var to_g : Vector3 = g.global_position - global_position
					var dist : float = to_g.length()
					if dist > 0.1 and dist < 1.8:
						if current_direction.dot(to_g.normalized()) > 0.7:
							adjusted_speed = speed * 0.72 
							break
							
		velocity = current_direction * adjusted_speed
		
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
		
	move_and_slide()
	_process_ghost_animations(delta)

func _process_ghost_animations(delta: float) -> void:
	if is_frozen: return
		
	hover_time += delta
	_process_eye_blinking(delta)
	
	if is_instance_valid(visual_mesh):
		visual_mesh.position.y = sin(hover_time * 3.0) * 0.06
		
	for i in range(skirt_spheres.size()):
		var sphere = skirt_spheres[i]
		if is_instance_valid(sphere):
			var phase_offset : float = i * (PI / 2.0)
			var skirt_base_y = -capsule_height / 2.0
			sphere.position.y = skirt_base_y + sin(hover_time * 6.0 + phase_offset) * 0.08
			
	if not is_inside_foso and current_direction != Vector3.ZERO:
		var target_rotation_y = atan2(-current_direction.x, -current_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, 0.2)

func _process_eye_blinking(delta: float) -> void:
	if not is_instance_valid(eyes_holder):
		return
		
	blink_timer += delta
	if not is_blinking:
		if blink_timer >= next_blink_time:
			is_blinking = true
			blink_timer = 0.0
			eyes_holder.scale.y = 0.05
	else:
		if blink_timer >= blink_duration:
			is_blinking = false
			blink_timer = 0.0
			next_blink_time = randf_range(2.5, 6.0)
			eyes_holder.scale.y = 1.0

func _apply_material(mat: StandardMaterial3D) -> void:
	if current_state == State.EATEN:
		return
		
	if visual_mesh and mat:
		visual_mesh.material_override = mat
		for sphere in skirt_spheres:
			if is_instance_valid(sphere):
				sphere.material_override = mat

func _set_body_visibility(should_be_visible: bool) -> void:
	if visual_mesh:
		if should_be_visible:
			visual_mesh.material_override = original_material
			for sphere in skirt_spheres:
				if is_instance_valid(sphere):
					sphere.visible = true
					sphere.material_override = original_material
		else:
			visual_mesh.material_override = _get_invisible_material()
			for sphere in skirt_spheres:
				if is_instance_valid(sphere):
					sphere.visible = false
				
		if is_instance_valid(eyes_holder):
			eyes_holder.visible = true

func _get_invisible_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.0) 
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED 
	return mat

func _get_matrix_open_directions() -> Array:
	var open_dirs = []
	if level_layout.is_empty():
		return CARDINAL_DIRECTIONS
		
	var offset : float = float(grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	
	var gate_y = 12
	var gate_x = int(float(grid_width) / 2.0)
	
	for dir in CARDINAL_DIRECTIONS:
		var target_x : int = grid_x + int(dir.x)
		var target_z : int = grid_z + int(dir.z)
		
		if target_x >= 0 and target_x < grid_width and target_z >= 0 and target_z < grid_height:
			if not is_inside_foso and target_x == gate_x and target_z == gate_y and current_state != State.EATEN:
				continue
				
			var cell_type : int = int(level_layout[target_z][target_x])
			if cell_type != 1: 
				open_dirs.append(dir)
				
	return open_dirs

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
	var target_pos : Vector3 = global_position

	if current_state == State.EATEN:
		target_pos = spawn_position 
	elif is_inside_foso:
		target_pos = exit_position 
	elif current_state == State.SCATTER:
		if behavior_strategy:
			target_pos = behavior_strategy.get_scatter_target(grid_width, grid_height, CELL_SIZE)
	elif current_state == State.FRIGHTENED:
		if player:
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
		if behavior_strategy and player:
			target_pos = behavior_strategy.get_target_position(self, player)

	if current_state == State.EATEN or is_inside_foso:
		var best_dir = possible_directions[0]
		var min_dist : float = 999999.0
		
		for dir in possible_directions:
			var next_pos : Vector3 = global_position + (dir * CELL_SIZE)
			var dist : float = next_pos.distance_to(target_pos)
			if dist < min_dist:
				min_dist = dist
				best_dir = dir
				
		next_direction = best_dir
		return

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

func activate_frightened_mode() -> void:
	if current_state == State.EATEN or is_inside_foso:
		return
		
	current_state = State.FRIGHTENED
	speed = frightened_speed
	frightened_timer = frightened_duration
	
	next_direction = -current_direction
	_apply_material(frightened_material)

func _exit_frightened_state() -> void:
	current_state = State.CHASE
	speed = base_speed
	state_timer = 0.0 
	_apply_material(original_material)

func reset_to_base() -> void:
	is_frozen = false 
	global_position = spawn_position
	is_inside_foso = true 
	current_state = State.LEAVING
	speed = base_speed
	state_timer = 0.0 
	_set_body_visibility(true)
	_apply_material(original_material)
	
	collision_mask = 1
	current_direction = CARDINAL_DIRECTIONS.pick_random()
	next_direction = current_direction
	
	var offset : float = float(grid_width * CELL_SIZE / 2.0) - (CELL_SIZE / 2.0)
	var grid_x : int = int(round((global_position.x + offset) / CELL_SIZE))
	var grid_z : int = int(round((global_position.z + offset) / CELL_SIZE))
	last_grid_pos = Vector2i(grid_x, grid_z)

func play_eaten_particles() -> void:
	if eaten_audio and eaten_audio.stream:
		eaten_audio.play()
		
	var particles := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.12)
	
	var mat := StandardMaterial3D.new()
	if original_material:
		mat.albedo_color = original_material.albedo_color
	else:
		mat.albedo_color = Color(0.0, 1.0, 1.0) 
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.2
	particles.direction = Vector3.UP
	particles.spread = 180.0 
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0.0, -8.0, 0.0) 
	
	particles.amount = 20
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.6
	
	var eaten_position = global_position
	get_parent().add_child(particles)
	particles.global_position = eaten_position
	particles.emitting = true
	
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

func _on_player_detected(body: Node3D) -> void:
	if body.is_in_group("player"):
		if current_state == State.FRIGHTENED:
			play_eaten_particles()
			player_caught.emit(true, global_position)
			
			current_state = State.EATEN
			speed = EATEN_SPEED
			_set_body_visibility(false)
			
			collision_mask = 1
			current_direction = -current_direction
			next_direction = current_direction
		elif current_state != State.EATEN:
			player_caught.emit(false, global_position)


# ==============================================================================
# --- MINIMAP POLYMORPHISM (LSP/OCP COMPLIANCE) ---
# ==============================================================================

func get_minimap_color() -> Color:
	if current_state == State.EATEN:
		return Color.TRANSPARENT 
	elif current_state == State.FRIGHTENED and frightened_material:
		return frightened_material.albedo_color
	elif original_material:
		return original_material.albedo_color
	return Color(1.0, 1.0, 1.0) 

func get_minimap_radius() -> float:
	return 4.0

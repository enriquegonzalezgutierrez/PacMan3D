# ==============================================================================
# Description: CharacterBody3D controller for Ghosts. Handles primitive capsule
#              generation, collision-tested pathfinding, and coordinates
#              with an abstract behavior strategy.
#              Phase 2 Updates:
#              - ARCADE DIFFICULTY PROGRESSION: Dynamically queries GameManager 
#                to scale movement speeds and reduce frightened duration per level.
#              - EATEN STATE (FLOATING EYES): Ghosts no longer instantly teleport. 
#                Upon consumption, their body vanishes and their eyes walk 
#                through the foso door, navigating all the way to their individual 
#                respawn pads before materializing.
#              - WARNING FIX: Renamed local parameter 'is_visible' to 
#                'should_be_visible' to resolve shadowed variable warning from Node3D.
#              - DETERMINISTIC EYE PATHFINDING: Eaten ghosts bypass the random 
#                steering check and take the absolute shortest route to the foso.
#              - VISUAL MATERIAL GUARD: Prevent timers from recoloring the 
#                invisible body back to blue while retreating.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CharacterBody3D
class_name Ghost

# Signals to notify orchestrators of gameplay events (Position is broadcasted)
signal player_caught(is_frightened: bool, catch_position: Vector3)

# State Machine definitions
enum State { LEAVING, CHASE, SCATTER, FRIGHTENED, EATEN }
var current_state : State = State.LEAVING

# Movement constants (Base values before GameManager multipliers)
var base_speed : float = 5.0
var frightened_speed : float = 2.5
const EATEN_SPEED : float = 18.0 # High speed retreat for floating eyes
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
var eaten_audio : AudioStreamPlayer
var current_direction : Vector3 = Vector3.FORWARD
var next_direction : Vector3 = Vector3.FORWARD

# State cycle timers (Arcade standard timings)
var state_timer : float = 0.0
const CHASE_DURATION : float = 20.0
const SCATTER_DURATION : float = 7.0

# Frightened timer variables
var frightened_timer : float = 0.0
var frightened_duration : float = 7.0 # Scaled dynamically on ready

# Dynamic Eye Tracking Variables
var eyes_holder : Node3D
var is_blinking : bool = false
var blink_timer : float = 0.0
var blink_duration : float = 0.15
var next_blink_time : float = 3.0 # Initial time before first blink

# Dynamic Floating & Skirt Animation Variables (SRP Compliance)
var hover_time : float = 0.0
var skirt_spheres : Array[MeshInstance3D] = []
var capsule_height : float = 1.8 # Cached dynamically from strategy on ready

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
	
	# --- PHASE 2: DYNAMIC DIFFICULTY SCALING ---
	if GameManager:
		var multiplier = GameManager.get_ghost_speed_multiplier()
		base_speed *= multiplier
		frightened_speed *= multiplier
		speed = base_speed
		
		frightened_duration = GameManager.get_frightened_duration()
	
	_configure_collision_layers()
	_build_ghost_visuals()
	_setup_player_detection()
	_setup_audio()
	
	# Randomize first blink and hover timings to stagger animations
	next_blink_time = randf_range(2.0, 5.0)
	hover_time = randf_range(0.0, 5.0)
	
	# --- DYNAMIC GHOST HOUSE EXIT DETECTION ---
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
	
	# Default standard dimensions
	var radius : float = 0.9
	var height : float = 1.8
	
	# Query dynamic visual specifications from the Strategy (OCP/SRP Compliance)
	if behavior_strategy:
		radius = behavior_strategy.get_capsule_radius()
		height = behavior_strategy.get_capsule_height()
		
	capsule_height = height # Cache local height for bottom skirt animation offsets
	
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
	
	# Default forward pupil offsets on face
	var pupil_left_pos := Vector3(-0.35, 0.4, -0.75 - radius * 0.2)
	var pupil_right_pos := Vector3(0.35, 0.4, -0.75 - radius * 0.2)
	
	# Query character-specific pupil offsets from Strategy (OCP/SRP Compliance)
	if behavior_strategy:
		var custom_offsets : Dictionary = behavior_strategy.get_pupil_offsets()
		pupil_left_pos = custom_offsets.get("left", pupil_left_pos)
		pupil_right_pos = custom_offsets.get("right", pupil_right_pos)
	
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
	left_pupil.position = pupil_left_pos
	eyes_holder.add_child(left_pupil)
	
	# 4. Right Pupil Sphere (Blue Pupil)
	var right_pupil := MeshInstance3D.new()
	right_pupil.mesh = pupil_mesh 
	right_pupil.material_override = pupil_mat
	right_pupil.position = pupil_right_pos
	eyes_holder.add_child(right_pupil)
	
	visual_mesh.add_child(eyes_holder)
	
	# --- PROCEDURAL RETRO WAVY SKIRT (SRP/OCP Compliance) ---
	var skirt_radius : float = 0.28
	var skirt_mesh := SphereMesh.new()
	skirt_mesh.radius = skirt_radius
	skirt_mesh.height = skirt_radius * 2.0
	
	# Calculate skirt offsets dynamically using body radius and height
	var skirt_base_y = -height / 2.0
	var skirt_offsets = [
		Vector3(-radius * 0.5, skirt_base_y, 0.0),
		Vector3(radius * 0.5, skirt_base_y, 0.0),
		Vector3(0.0, skirt_base_y, -radius * 0.5),
		Vector3(0.0, skirt_base_y, radius * 0.5)
	]
	
	for i in range(skirt_offsets.size()):
		var sphere := MeshInstance3D.new()
		sphere.mesh = skirt_mesh
		sphere.material_override = original_material # Uses active ghost color
		sphere.position = skirt_offsets[i]
		visual_mesh.add_child(sphere) # Child of body so it inherits transformations
		skirt_spheres.append(sphere)
		
	# --- PROCEDURAL ACCESSORIES ATTACHMENT ---
	# Ask Strategy to attach any unique decorations dynamically (OCP/SRP Compliance)
	if behavior_strategy:
		behavior_strategy.attach_custom_decorations(visual_mesh)
	
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
			rotation.y = lerp_angle(rotation.y, 0.0, 0.2) # Face North
			
		move_and_slide()
		_process_ghost_animations(delta)
		
		# Gate threshold check
		var pos_2d := Vector2(global_position.x, global_position.z)
		var exit_2d := Vector2(exit_position.x, exit_position.z)
		if pos_2d.distance_to(exit_2d) < 1.0:
			is_inside_foso = false
			current_state = State.CHASE
			speed = base_speed
			_apply_material(original_material)
		return

	# --- CHASE / SCATTER ARCADE CYCLE TIMERS ---
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
			# Frightened blinking warning transition
			if frightened_timer <= 2.5:
				var blink = int(frightened_timer * 5.0) % 2 == 0
				if blink and original_material:
					_apply_material(original_material)
				elif frightened_material:
					_apply_material(frightened_material)
			elif frightened_material:
				_apply_material(frightened_material)
				
	# --- EATEN STATE LOGIC (Floating Eyes Return) ---
	if current_state == State.EATEN:
		var pos_2d := Vector2(global_position.x, global_position.z)
		var spawn_2d := Vector2(spawn_position.x, spawn_position.z)
		# If we have reached our individual respawn pad coordinates inside the foso, heal and materialize
		if pos_2d.distance_to(spawn_2d) < 0.5:
			is_inside_foso = true 
			current_state = State.LEAVING
			speed = base_speed
			_set_body_visibility(true) # Restore body and default materials first
			_apply_material(original_material)
			
			current_direction = CARDINAL_DIRECTIONS.pick_random()
			next_direction = current_direction
			return

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
		# --- ARCADE LONGITUDINAL SEPARATION ---
		# Dynamically reduces trailing speed when following another ghost closely in the same corridor
		var adjusted_speed : float = speed
		if not is_inside_foso and current_state != State.EATEN:
			var ghosts = get_tree().get_nodes_in_group("ghosts")
			for g in ghosts:
				if g != self and is_instance_valid(g) and not g.is_inside_foso:
					var to_g : Vector3 = g.global_position - global_position
					var dist : float = to_g.length()
					# Buffer distance of 1.8 meters prevents overlapping
					if dist > 0.1 and dist < 1.8:
						# Only slow down if the other ghost is directly ahead (high dot product)
						if current_direction.dot(to_g.normalized()) > 0.7:
							adjusted_speed = speed * 0.72 # Drop to 72% speed
							break
							
		velocity = current_direction * adjusted_speed
		
		# --- DYNAMIC GRID OFFSET MATH ---
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

# Orchestrates smooth hovering translations and ruffling leg waves (SRP Compliance)
func _process_ghost_animations(delta: float) -> void:
	if is_frozen:
		return
		
	hover_time += delta
	_process_eye_blinking(delta)
	
	# 1. Float the main capsule body gently up and down on a vertical sine wave
	if is_instance_valid(visual_mesh):
		visual_mesh.position.y = sin(hover_time * 3.0) * 0.06
		
	# 2. Ripple the skirt ruffles out-of-phase (shifted by PI/2) to simulate swimming tails
	for i in range(skirt_spheres.size()):
		var sphere = skirt_spheres[i]
		if is_instance_valid(sphere):
			var phase_offset : float = i * (PI / 2.0)
			# Skirt base Y is calculated dynamically from body dimensions (DIP/SRP Compliance)
			var skirt_base_y = -capsule_height / 2.0
			sphere.position.y = skirt_base_y + sin(hover_time * 6.0 + phase_offset) * 0.08
			
	# 3. Rotate the ghost body smoothly towards its active moving direction (SRP/OCP Compliance)
	if not is_inside_foso and current_direction != Vector3.ZERO:
		var target_rotation_y = atan2(-current_direction.x, -current_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, 0.2)

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

# Helper to swap visual materials safely across the entire body (including skirt ruffles)
func _apply_material(mat: StandardMaterial3D) -> void:
	# VISUAL GUARD (Phase 2): Completely block any background material recoloring attempts 
	# (like Power Pellet blinking/expiring) while the ghost is in the EATEN (floating eyes) state.
	if current_state == State.EATEN:
		return
		
	if visual_mesh and mat:
		visual_mesh.material_override = mat
		for sphere in skirt_spheres:
			if is_instance_valid(sphere):
				sphere.material_override = mat

# Helper to toggle visibility of the ghost's body while preserving the eyes
func _set_body_visibility(should_be_visible: bool) -> void:
	if visual_mesh:
		if should_be_visible:
			# Restore normal material
			visual_mesh.material_override = original_material
			for sphere in skirt_spheres:
				if is_instance_valid(sphere):
					sphere.visible = true
					sphere.material_override = original_material
		else:
			# Hide the main capsule body using the invisible unshaded material
			visual_mesh.material_override = _get_invisible_material()
			for sphere in skirt_spheres:
				if is_instance_valid(sphere):
					sphere.visible = false
				
		# Always ensure eyes remain fully visible
		if is_instance_valid(eyes_holder):
			eyes_holder.visible = true

# Generates a fully transparent, unshaded material that catches no lighting reflections
func _get_invisible_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.0) # Transparent
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Catches no highlights
	return mat

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
			# ONE-WAY DOOR RULE: If outside the foso and NOT EATEN, treat the gate as a solid wall
			# EATEN ghosts are allowed to pass through the door back into the foso
			if not is_inside_foso and target_x == gate_x and target_z == gate_y and current_state != State.EATEN:
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
	var target_pos : Vector3 = global_position

	# --- GHOST HOUSE ENTER/EXIT TARGETING ---
	if current_state == State.EATEN:
		target_pos = spawn_position # Eaten eyes head directly inside to their respawn pad
	elif is_inside_foso:
		target_pos = exit_position # Leaving ghosts head out towards the door
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

	# --- DETERMINISTIC PATHFINDING FOR EATEN/LEAVING GHOSTS ---
	# Eaten ghosts and leaving ghosts must take the absolute shortest route.
	# We bypass the 15% random steering check to prevent eyes from getting stuck or wandering.
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

	# Standard AI decision making (with 15% organic randomness)
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
	if current_state == State.EATEN or is_inside_foso:
		return
		
	current_state = State.FRIGHTENED
	speed = frightened_speed
	frightened_timer = frightened_duration
	
	next_direction = -current_direction
	_apply_material(frightened_material)

# Restores the ghost back to standard chase behavior
func _exit_frightened_state() -> void:
	current_state = State.CHASE
	speed = base_speed
	state_timer = 0.0 # Reset cycle timer
	_apply_material(original_material)

# Public method: Resets ghost back to base (DIP Compliance)
func reset_to_base() -> void:
	is_frozen = false 
	global_position = spawn_position
	is_inside_foso = true 
	current_state = State.LEAVING
	speed = base_speed
	state_timer = 0.0 # Reset cycle timer
	_set_body_visibility(true)
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
	
	# --- DIRECT METHOD CONNECTION FIX ---
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

# Handles player intersection and emits state notification signals
func _on_player_detected(body: Node3D) -> void:
	if body.is_in_group("player"):
		if current_state == State.FRIGHTENED:
			play_eaten_particles()
			
			# Notify listeners with both the state and the exact 3D world coordinate (DIP Compliance)
			player_caught.emit(true, global_position)
			
			# Transition to the high-speed floating eyes retreat state
			current_state = State.EATEN
			speed = EATEN_SPEED
			_set_body_visibility(false)
			
			# Instantly reverse direction to flee towards base
			current_direction = -current_direction
			next_direction = current_direction
		elif current_state != State.EATEN:
			# Notify listeners of player catch with coordinates
			player_caught.emit(false, global_position)

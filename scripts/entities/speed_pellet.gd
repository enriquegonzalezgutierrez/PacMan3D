# ==============================================================================
# Description: Standalone Pomada Menorquina (Gin with Lemonade) Utility Pellet (Area3D). 
#              Loads the 3D lemon.fbx model, scales it to 1.4x, and applies 
#              a bright unshaded lemon-yellow shader with an electric sparks emitter.
#              SOLID Refactoring & Android Shading Fix:
#              - Mobile Static Injector (DIP): Loads standardized texture filenames 
#                ('albedo.png', 'normal.png', etc.) directly from disk. 
#                This completely bypasses Android's DirAccess limitations, 
#                guaranteeing 100% mobile texture compatibility on exported APKs.
#              - Scale Up: Scaled massively to 1.4x for high-end diorama visibility.
#              - DIP Compliance: Added dependency injection to accept a 
#                pre-cached PackedScene of the 3D lemon model, eliminating 
#                redundant disk reads at runtime during level generation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name SpeedPellet

# Signal emitted when eaten, delegating gameplay state mutations
signal speed_pellet_eaten()

# Dependency Injection Placeholder (Injected by LevelBuilder to prevent disk I/O)
var lemon_scene_cache : PackedScene = null

# Internal visual component references
var visual_holder : Node3D
var time_passed : float = 0.0

func _ready() -> void:
	add_to_group("pellets") 
	_configure_collision_layers()
	_build_pellet_visuals()
	body_entered.connect(_on_body_entered)
	
	# Randomize initial phase to prevent robotic floating synchronization
	time_passed = randf_range(0.0, 5.0)

func _configure_collision_layers() -> void:
	collision_layer = 0
	collision_mask = 2

# Programmatically constructs the 3D Lemon model
func _build_pellet_visuals() -> void:
	visual_holder = Node3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# --- DIP / CACHING IMPLEMENTATION ---
	# Retrieve the model from the injected memory cache. If none exists, execute a fallback load.
	var lemon_mesh : Node3D = null
	if lemon_scene_cache:
		lemon_mesh = lemon_scene_cache.instantiate()
	else:
		var lemon_path := "res://assets/models/items/lemon/lemon.fbx"
		if ResourceLoader.exists(lemon_path):
			var lemon_scene = load(lemon_path) as PackedScene
			if lemon_scene:
				lemon_mesh = lemon_scene.instantiate()
			
	# Defensive Fallback: If FBX is missing, compile a stylized CylinderMesh
	if not is_instance_valid(lemon_mesh):
		lemon_mesh = MeshInstance3D.new()
		var fallback_mesh := CylinderMesh.new()
		fallback_mesh.top_radius = 0.22
		fallback_mesh.bottom_radius = 0.16
		fallback_mesh.height = 0.38
		fallback_mesh.radial_segments = 12
		lemon_mesh.mesh = fallback_mesh
		
	# Configure materials and scales (SRP Compliance)
	_brighten_imported_materials_recursive(lemon_mesh)
	
	# Scale up to a massive 1.4x for high-end diorama visibility
	lemon_mesh.scale = Vector3(1.4, 1.4, 1.4)
	
	# Rotate slightly on Z axis for organic tilt
	lemon_mesh.rotation_degrees.z = 25.0
	visual_holder.add_child(lemon_mesh)
	
	# Attach the CPUParticles3D of electric lightning sparks
	var spark_emitter := _build_electric_spark_emitter()
	visual_holder.add_child(spark_emitter)
	spark_emitter.emitting = true
	
	# Physical trigger boundary
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.70
	collision_shape.shape = sphere_shape
	
	add_child(visual_holder)
	add_child(collision_shape)

# Helper to recursively duplicate and brighten imported textures inside the FBX (SRP/OCP)
func _brighten_imported_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var active_mat = node.get_active_material(0)
		if not active_mat:
			active_mat = StandardMaterial3D.new()
			
		var dup_mat = active_mat.duplicate() as StandardMaterial3D
		dup_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		
		# --- MOBILE STATIC INJECTOR (Bypasses Android DirAccess limitations) ---
		var tex_dir : String = "res://assets/models/items/lemon/textures/"
		
		if ResourceLoader.exists(tex_dir + "albedo.png"):
			dup_mat.albedo_texture = load(tex_dir + "albedo.png") as Texture2D
		if ResourceLoader.exists(tex_dir + "metallic.png"):
			dup_mat.metallic = 1.0
			dup_mat.metallic_texture = load(tex_dir + "metallic.png") as Texture2D
		if ResourceLoader.exists(tex_dir + "roughness.png"):
			dup_mat.roughness_texture = load(tex_dir + "roughness.png") as Texture2D
		if ResourceLoader.exists(tex_dir + "normal.png"):
			dup_mat.normal_enabled = true
			dup_mat.normal_texture = load(tex_dir + "normal.png") as Texture2D
			
		node.material_override = dup_mat
			
	for child in node.get_children():
		_brighten_imported_materials_recursive(child)

# Compiles a gorgeous electric sparks emitter (Juice Compliance)
func _build_electric_spark_emitter() -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 1.0, 1.0) # Electric cyan sparks
	mesh.material = mat
	
	emitter.mesh = mesh
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.28
	emitter.direction = Vector3.UP
	emitter.spread = 180.0
	emitter.initial_velocity_min = 1.5
	emitter.initial_velocity_max = 3.0
	emitter.gravity = Vector3(0.0, 1.0, 0.0) # Sparks float upwards
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = curve
	
	emitter.amount = 8 
	emitter.lifetime = 0.4
	emitter.position = Vector3(0.0, 0.1, 0.0)
	
	return emitter

func _process(delta: float) -> void:
	if not is_instance_valid(visual_holder):
		return
		
	time_passed += delta
	visual_holder.rotate_y(1.8 * delta)
	visual_holder.position.y = sin(time_passed * 3.5) * 0.08

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if body.has_method("play_eat_sound"):
			body.play_eat_sound()
			
		if body.has_method("activate_speed_boost"):
			body.activate_speed_boost()
			
		speed_pellet_eaten.emit()
		queue_free()

# --- MINIMAP POLYMORPHISM (LSP/OCP COMPLIANCE) ---

func get_minimap_color() -> Color:
	return Color(1.0, 0.85, 0.0) 

func get_minimap_radius() -> float:
	return 3.5

# ==============================================================================
# Description: Script for the Pellet entity (Area3D). Spawns themed items 
#              by loading a static 3D FBX model of the Gin Xoriguer bottle.
#              SOLID Refactoring & Visual Fixes:
#              - Real Power Pellet Textures: Removed the flat gold override 
#                from the large power bottles. They now display the original 
#                red cap, green clay glass, and Mahon label, but scaled to 1.6x 
#                and surrounded by a column of floating golden sparks.
#              - Luminous Textures: Keeps unshaded mapping for realistic details.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Pellet

# Signal emitted when eaten, delegating gameplay state mutations
signal eaten(is_power: bool)

@export var is_power_pellet : bool = false

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

# Programmatically builds either a glass chupito or the iconic green Xoriguer bottle
func _build_pellet_visuals() -> void:
	visual_holder = Node3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# 1. Programmatically load and instantiate the user's 3D bottle FBX model
	var bottle_mesh : Node3D = null
	var bottle_path := "res://assets/models/items/xoriguer_bottle.fbx"
	
	if ResourceLoader.exists(bottle_path):
		var bottle_scene = load(bottle_path) as PackedScene
		if bottle_scene:
			bottle_mesh = bottle_scene.instantiate()
			
	# Defensive Fallback: If FBX is missing, compile a stylized cylinder bottle
	if not is_instance_valid(bottle_mesh):
		bottle_mesh = _create_fallback_cylinder_bottle()
		
	# 2. Configure materials and scales depending on Pellet Type (SRP Compliance)
	if not is_power_pellet:
		# --- STANDARD PELLET (Textured Real Xoriguer Bottle) ---
		_brighten_imported_materials_recursive(bottle_mesh)
		
		# Scale down to a cute collectible size
		bottle_mesh.scale = Vector3(0.45, 0.45, 0.45)
		visual_holder.add_child(bottle_mesh)
		
		# Physical trigger boundary
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = 0.35
		collision_shape.shape = sphere_shape
		
	else:
		# --- POWER PELLET (Large Textured Xoriguer Bottle + Sparks) ---
		# Fixed: No more solid gold override! 
		# We preserve the real green glass, red cap, and Mahon windmill label textures, 
		# but brighten them (unshaded) and surround them with floating golden sparks.
		_brighten_imported_materials_recursive(bottle_mesh)
		
		# Scaled up to a massive 1.6x for highly prominent collectible feedback
		bottle_mesh.scale = Vector3(1.6, 1.6, 1.6)
		visual_holder.add_child(gold_mesh_offset(bottle_mesh))
		
		# Attach the golden sparks emitter (CPUParticles3D)
		var spark_emitter := _build_golden_spark_emitter()
		visual_holder.add_child(spark_emitter)
		spark_emitter.emitting = true
		
		# Physical trigger boundary (Enlarged)
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = 0.75
		collision_shape.shape = sphere_shape
		collision_shape.position.y = 0.32
	
	add_child(visual_holder)
	add_child(collision_shape)

# Helper to recursively apply flat materials to nested MeshInstance3D nodes inside the FBX
static func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material_recursive(child, material)

# Helper to recursively duplicate and brighten imported textures inside the FBX (SRP/OCP)
static func _brighten_imported_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		# Extract the active imported material resource of the mesh
		var active_mat = node.get_active_material(0)
		if active_mat is StandardMaterial3D:
			# Duplicate to avoid overwriting the base file on disk
			var dup_mat = active_mat.duplicate() as StandardMaterial3D
			# Force unshaded mode to render the label and green glass with 100% native brightness
			dup_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
			node.material_override = dup_mat
			
	for child in node.get_children():
		_brighten_imported_materials_recursive(child)

# Helper to offset the massive gold bottle elegantly
func gold_mesh_offset(mesh_node: Node3D) -> Node3D:
	var offset_node := Node3D.new()
	offset_node.add_child(mesh_node)
	mesh_node.position.y = -0.15 
	return offset_node

# Compiles a gorgeous floating spark emitter straight upwards (Juice Compliance)
func _build_golden_spark_emitter() -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.0)
	mesh.material = mat
	
	emitter.mesh = mesh
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.18
	emitter.direction = Vector3.UP
	emitter.spread = 15.0 
	emitter.initial_velocity_min = 1.0
	emitter.initial_velocity_max = 2.0
	emitter.gravity = Vector3(0.0, 1.0, 0.0) 
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = curve
	
	emitter.amount = 8 
	emitter.lifetime = 0.5
	emitter.position = Vector3(0.0, 0.4, 0.0) 
	
	return emitter

# Compiles a stylized 3D cylinder bottle as defensive fallback
func _create_fallback_cylinder_bottle() -> Node3D:
	var fallback := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.28
	body_mesh.bottom_radius = 0.28
	body_mesh.height = 0.65
	body.mesh = body_mesh
	fallback.add_child(body)
	return fallback

func _process(delta: float) -> void:
	if not is_instance_valid(visual_holder):
		return
		
	time_passed += delta
	visual_holder.rotate_y(1.5 * delta)
	visual_holder.position.y = sin(time_passed * 2.5) * 0.06

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if body.has_method("play_eat_sound"):
			body.play_eat_sound()
			
		eaten.emit(is_power_pellet)
		queue_free()

# --- MINIMAP POLYMORPHISM (LSP/OCP COMPLIANCE) ---

func get_minimap_color() -> Color:
	return Color(1.0, 0.8, 0.0) if is_power_pellet else Color(0.05, 0.8, 0.1)

func get_minimap_radius() -> float:
	return 3.5 if is_power_pellet else 1.5

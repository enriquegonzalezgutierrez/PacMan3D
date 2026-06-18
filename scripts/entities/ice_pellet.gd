# ==============================================================================
# Description: Standalone Frost-Blue Ice Utility Pellet (Area3D). 
#              Loads the 3D ice.fbx model, scales it to 1.4x, and applies 
#              a translucent unshaded cyan ice shader with a mist particle emitter.
#              SOLID Refactoring & Shading Fix:
#              - Texture Preservation: Removed the flat-color override. 
#                It now duplicates the FBX's native materials and makes them 
#                UNSHADED. This completely preserves the cracks and icy details 
#                of your custom ice model at 100% native brightness.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name IcePellet

# Emitted when eaten to let orchestrators freeze active ghosts
signal ice_pellet_eaten()

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

# Programmatically constructs the 3D Ice Cube model
func _build_pellet_visuals() -> void:
	visual_holder = Node3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# 1. Programmatically load and instantiate the user's 3D Ice Cube FBX model
	var ice_mesh : Node3D = null
	var ice_path := "res://assets/models/items/ice/ice.fbx"
	
	if ResourceLoader.exists(ice_path):
		var ice_scene = load(ice_path) as PackedScene
		if ice_scene:
			ice_mesh = ice_scene.instantiate()
			
	# Defensive Fallback: If FBX is missing, compile a stylized BoxMesh
	if not is_instance_valid(ice_mesh):
		ice_mesh = MeshInstance3D.new()
		var fallback_mesh := BoxMesh.new()
		fallback_mesh.size = Vector3(0.5, 0.5, 0.5)
		ice_mesh.mesh = fallback_mesh
		
	# 2. Configure materials and scales (SRP Compliance)
	# Fixed: No more flat-color override! We duplicate and make imported materials UNSHADED.
	_brighten_imported_materials_recursive(ice_mesh)
	
	# Scale up to a massive 1.4x for high-end diorama visibility
	ice_mesh.scale = Vector3(1.4, 1.4, 1.4)
	
	# Rotate at an angle for beautiful organic floating orientation
	ice_mesh.rotation_degrees = Vector3(25.0, 45.0, 15.0)
	visual_holder.add_child(ice_mesh)
	
	# 3. Attach the CPUParticles3D of frozen mist / steam rising
	var mist_emitter := _build_mist_emitter()
	visual_holder.add_child(mist_emitter)
	mist_emitter.emitting = true
	
	# Physical trigger boundary
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.70
	collision_shape.shape = sphere_shape
	
	add_child(visual_holder)
	add_child(collision_shape)

# Helper to recursively duplicate and brighten imported textures inside the FBX (SRP/OCP)
static func _brighten_imported_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var active_mat = node.get_active_material(0)
		if active_mat is StandardMaterial3D:
			var dup_mat = active_mat.duplicate() as StandardMaterial3D
			dup_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
			# Force a translucent look if preferred, but unshaded ensures 100% brightness
			dup_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			node.material_override = dup_mat
			
	for child in node.get_children():
		_brighten_imported_materials_recursive(child)

# Compiles a gorgeous cold mist emitter straight upwards (Juice Compliance)
func _build_mist_emitter() -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.9, 1.0, 0.4) # Soft frosty cyan
	mesh.material = mat
	
	emitter.mesh = mesh
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.25
	emitter.direction = Vector3.UP
	emitter.spread = 35.0
	emitter.initial_velocity_min = 0.8
	emitter.initial_velocity_max = 1.6
	emitter.gravity = Vector3(0.0, 0.8, 0.0) 
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = curve
	
	emitter.amount = 6 
	emitter.lifetime = 0.6
	emitter.position = Vector3(0.0, 0.1, 0.0)
	
	return emitter

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
			
		ice_pellet_eaten.emit()
		queue_free()

# --- MINIMAP POLYMORPHISM (LSP/OCP COMPLIANCE) ---

func get_minimap_color() -> Color:
	return Color(0.0, 0.8, 1.0) 

func get_minimap_radius() -> float:
	return 3.5

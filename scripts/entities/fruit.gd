# ==============================================================================
# Description: Standalone Fruit bonus item (Area3D). Spawns procedurally as a 
#              large, glossy double-cherry mesh, granting +500 points and 
#              emitting eaten notifications upon player collision.
#              SOLID Refactoring & Visual Polish:
#              - SIZE UPGRADE: Enlarged the cherry spheres, stems, and leaves 
#                by ~40% to make the dynamic bonus item highly readable and 
#                visually prominent from the diorama camera view.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Fruit

# Emits the points value awarded upon consumption
signal eaten(points: int)

var fruit_material : StandardMaterial3D
var stem_material : StandardMaterial3D

# Internal visual component references
var visual_holder : Node3D
var time_passed : float = 0.0

func _ready() -> void:
	_configure_collision_layers()
	_initialize_materials()
	_build_fruit_visuals()
	body_entered.connect(_on_body_entered)
	
	# Randomize initial time state slightly to stagger animations
	time_passed = randf_range(0.0, 5.0)

func _configure_collision_layers() -> void:
	# Exist on Layer 0 (Detects Player on Layer 2)
	collision_layer = 0
	collision_mask = 2

func _initialize_materials() -> void:
	# 1. Glossy Cherry Red
	fruit_material = StandardMaterial3D.new()
	fruit_material.albedo_color = Color(1.0, 0.0, 0.2)
	fruit_material.roughness = 0.1
	fruit_material.metallic = 0.1
	
	# 2. Stem Green
	stem_material = StandardMaterial3D.new()
	stem_material.albedo_color = Color(0.0, 0.8, 0.1)
	stem_material.roughness = 0.5

# Programmatically constructs the enlarged double-cherry mesh
func _build_fruit_visuals() -> void:
	visual_holder = Node3D.new()
	
	# Enlarged cherry sphere meshes
	var cherry_mesh := SphereMesh.new()
	cherry_mesh.radius = 0.34
	cherry_mesh.height = 0.68
	
	# 1. Left Cherry (Position adjusted outwards)
	var left_cherry := MeshInstance3D.new()
	left_cherry.mesh = cherry_mesh
	left_cherry.material_override = fruit_material
	left_cherry.position = Vector3(-0.25, 0.3, 0.0)
	visual_holder.add_child(left_cherry)
	
	# 2. Right Cherry (Position adjusted outwards)
	var right_cherry := MeshInstance3D.new()
	right_cherry.mesh = cherry_mesh
	right_cherry.material_override = fruit_material
	right_cherry.position = Vector3(0.25, 0.3, 0.0)
	visual_holder.add_child(right_cherry)
	
	# 3. Combined Stems (Thicker and longer green boxes)
	var stem_mesh := BoxMesh.new()
	stem_mesh.size = Vector3(0.1, 0.5, 0.1)
	
	var left_stem := MeshInstance3D.new()
	left_stem.mesh = stem_mesh
	left_stem.material_override = stem_material
	left_stem.position = Vector3(-0.15, 0.6, 0.0)
	left_stem.rotation_degrees = Vector3(0, 0, -22) # Angled left
	visual_holder.add_child(left_stem)
	
	var right_stem := MeshInstance3D.new()
	right_stem.mesh = stem_mesh
	right_stem.material_override = stem_material
	right_stem.position = Vector3(0.15, 0.6, 0.0)
	right_stem.rotation_degrees = Vector3(0, 0, 22) # Angled right
	visual_holder.add_child(right_stem)
	
	# 4. Joint Leaf (Slightly larger green sphere)
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 0.13
	leaf_mesh.height = 0.26
	
	var leaf := MeshInstance3D.new()
	leaf.mesh = leaf_mesh
	leaf.material_override = stem_material
	leaf.position = Vector3(0.0, 0.8, 0.0)
	visual_holder.add_child(leaf)
	
	# --- PHYSICAL COLLIDER ---
	# Sphere shape expanded to match the new cherry boundaries
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.65
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = sphere_shape
	collision_shape.position.y = 0.45
	
	add_child(visual_holder)
	add_child(collision_shape)

func _process(delta: float) -> void:
	if not is_instance_valid(visual_holder):
		return
		
	time_passed += delta
	
	# 1. Rotate the cherries continuously on the Y-axis
	visual_holder.rotate_y(1.2 * delta)
	
	# 2. Float gently up and down on a wide, premium-looking sine wave
	visual_holder.position.y = sin(time_passed * 2.0) * 0.08

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Trigger player eat sound (SRP Compliance)
		if body.has_method("play_eat_sound"):
			body.play_eat_sound()
			
		eaten.emit(500) # Emits +500 points value
		queue_free()

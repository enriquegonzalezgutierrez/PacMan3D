# ==============================================================================
# Description: Standalone Fruit bonus item (Area3D). Spawns procedurally as a 
#              glossy double-cherry mesh, granting +500 points and emitting 
#              eaten notifications upon player collision.
#              SOLID Refactoring:
#              - SRP Compliance: Fully isolated visual representation and 
#                collision detection from other items.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Fruit

# Emits the points value awarded upon consumption
signal eaten(points: int)

var fruit_material : StandardMaterial3D
var stem_material : StandardMaterial3D

func _ready() -> void:
	_configure_collision_layers()
	_initialize_materials()
	_build_fruit_visuals()
	body_entered.connect(_on_body_entered)

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

# Programmatically constructs the double-cherry mesh
func _build_fruit_visuals() -> void:
	var holder := Node3D.new()
	
	var cherry_mesh := SphereMesh.new()
	cherry_mesh.radius = 0.22
	cherry_mesh.height = 0.44
	
	# 1. Left Cherry
	var left_cherry := MeshInstance3D.new()
	left_cherry.mesh = cherry_mesh
	left_cherry.material_override = fruit_material
	left_cherry.position = Vector3(-0.16, 0.2, 0.0)
	holder.add_child(left_cherry)
	
	# 2. Right Cherry
	var right_cherry := MeshInstance3D.new()
	right_cherry.mesh = cherry_mesh
	right_cherry.material_override = fruit_material
	right_cherry.position = Vector3(0.16, 0.2, 0.0)
	holder.add_child(right_cherry)
	
	# 3. Combined Stems (Futuristic Green Box Joints)
	var stem_mesh := BoxMesh.new()
	stem_mesh.size = Vector3(0.08, 0.35, 0.08)
	
	var left_stem := MeshInstance3D.new()
	left_stem.mesh = stem_mesh
	left_stem.material_override = stem_material
	left_stem.position = Vector3(-0.1, 0.4, 0.0)
	left_stem.rotation_degrees = Vector3(0, 0, -20) # Angled left
	holder.add_child(left_stem)
	
	var right_stem := MeshInstance3D.new()
	right_stem.mesh = stem_mesh
	right_stem.material_override = stem_material
	right_stem.position = Vector3(0.1, 0.4, 0.0)
	right_stem.rotation_degrees = Vector3(0, 0, 20) # Angled right
	holder.add_child(right_stem)
	
	# 4. Joint Leaf
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 0.09
	leaf_mesh.height = 0.18
	
	var leaf := MeshInstance3D.new()
	leaf.mesh = leaf_mesh
	leaf.material_override = stem_material
	leaf.position = Vector3(0.0, 0.55, 0.0)
	holder.add_child(leaf)
	
	# --- PHYSICAL COLLIDER ---
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.45
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = sphere_shape
	collision_shape.position.y = 0.3
	
	add_child(holder)
	add_child(collision_shape)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Trigger player eat sound (SRP Compliance)
		if body.has_method("play_eat_sound"):
			body.play_eat_sound()
			
		eaten.emit(500) # Emits +500 points value
		queue_free()

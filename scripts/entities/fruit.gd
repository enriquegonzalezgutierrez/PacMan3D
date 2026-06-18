# ==============================================================================
# Description: Standalone Fruit bonus item (Area3D). Spawns procedurally based 
#              on the level and delegates its visual construction to distinct 
#              FruitDesignStrategy objects.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted all 3D mesh compilation and material 
#                theming into specialized FruitDesignStrategy subclasses. 
#                The core Fruit class is now solely responsible for physics, 
#                animations, and radar signals.
#              - OCP Compliance: Adding a new fruit (e.g. Orange) now only 
#                requires writing a new design strategy subclass and adding it 
#                to the dispatch registry, keeping the main class closed to modification.
#              - LSP Compliance: Implements polymorphic getters matching 
#                the Minimap telemetry interface.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Fruit

# Emits the points value awarded upon consumption
signal eaten(points: int)

var points_value : int = 500
var fruit_name : String = "Cherry"

# Materials
var primary_material : StandardMaterial3D
var secondary_material : StandardMaterial3D

# Internal visual component references
var visual_holder : Node3D
var time_passed : float = 0.0

# Strategy Pattern Registry mapping fruits to their design builders (OCP Compliance)
var design_strategies : Dictionary = {
	"Cherry": CherryDesign.new(),
	"Strawberry": StrawberryDesign.new(),
	"Peach": PeachDesign.new(),
	"Apple": AppleDesign.new(),
	"Key": KeyDesign.new()
}

# Resolved name conflict to prevent parser compile crashes
var current_design : FruitDesignStrategy

func initialize(level_number: int) -> void:
	add_to_group("pellets") 
	_configure_collision_layers()
	_determine_fruit_identity(level_number)
	
	# Retrieve strategy dynamically from our OCP Registry
	current_design = design_strategies.get(fruit_name, design_strategies["Cherry"])
	
	_initialize_materials()
	_build_fruit_visuals()
	
	body_entered.connect(_on_body_entered)
	time_passed = randf_range(0.0, 5.0)

func _configure_collision_layers() -> void:
	collision_layer = 0
	collision_mask = 2

# Maps levels to names and score weight
func _determine_fruit_identity(level_number: int) -> void:
	match level_number:
		1:
			fruit_name = "Cherry"
			points_value = 500
		2:
			fruit_name = "Strawberry"
			points_value = 800
		3:
			fruit_name = "Peach"
			points_value = 1000
		4:
			fruit_name = "Apple"
			points_value = 2000
		_:
			fruit_name = "Key"
			points_value = 5000

func _initialize_materials() -> void:
	primary_material = StandardMaterial3D.new()
	primary_material.roughness = 0.15
	primary_material.metallic = 0.1
	
	secondary_material = StandardMaterial3D.new()
	secondary_material.roughness = 0.5
	secondary_material.metallic = 0.0
	
	# Ask active strategy to apply color modifications (SRP Compliance)
	if current_design:
		current_design.configure_materials(primary_material, secondary_material)

# Delegates mesh construction to the active design strategy (SRP Compliance)
func _build_fruit_visuals() -> void:
	visual_holder = Node3D.new()
	
	if current_design:
		current_design.build_visuals(visual_holder, primary_material, secondary_material)
		
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.95
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = sphere_shape
	collision_shape.position.y = 0.55
	
	add_child(visual_holder)
	add_child(collision_shape)

func _process(delta: float) -> void:
	if not is_instance_valid(visual_holder):
		return
		
	time_passed += delta
	visual_holder.rotate_y(1.2 * delta)
	visual_holder.position.y = sin(time_passed * 2.0) * 0.08

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if body.has_method("play_eat_sound"):
			body.play_eat_sound()
			
		eaten.emit(points_value) 
		queue_free()


# --- MINIMAP POLYMORPHISM (LSP/OCP COMPLIANCE) ---

func get_minimap_color() -> Color:
	if current_design:
		return current_design.get_minimap_color()
	return Color(1.0, 0.0, 0.8) # Fallback Magenta

func get_minimap_radius() -> float:
	return 5.2 


# ==============================================================================
# --- NESTED CLASSES: FRUIT GEOMETRY STRATEGIES (OCP/SRP Compliance) ---
# ==============================================================================

class FruitDesignStrategy extends RefCounted:
	func configure_materials(_primary: StandardMaterial3D, _secondary: StandardMaterial3D) -> void:
		pass
	func build_visuals(_visual_holder: Node3D, _primary: StandardMaterial3D, _secondary: StandardMaterial3D) -> void:
		pass
	func get_minimap_color() -> Color:
		return Color(1.0, 0.0, 0.8)


# --- CHERRY DESIGN ---
class CherryDesign extends FruitDesignStrategy:
	func configure_materials(primary: StandardMaterial3D, secondary: StandardMaterial3D) -> void:
		primary.albedo_color = Color(1.0, 0.0, 0.2) # Cherry Red
		secondary.albedo_color = Color(0.0, 0.8, 0.1) # Stem Green
		
	func build_visuals(visual_holder: Node3D, primary: StandardMaterial3D, secondary: StandardMaterial3D) -> void:
		var cherry_mesh := SphereMesh.new()
		cherry_mesh.radius = 0.5
		cherry_mesh.height = 1.0
		
		var left_cherry := MeshInstance3D.new()
		left_cherry.mesh = cherry_mesh
		left_cherry.material_override = primary
		left_cherry.position = Vector3(-0.35, 0.4, 0.0)
		visual_holder.add_child(left_cherry)
		
		var right_cherry := MeshInstance3D.new()
		right_cherry.mesh = cherry_mesh
		right_cherry.material_override = primary
		right_cherry.position = Vector3(0.35, 0.4, 0.0)
		visual_holder.add_child(right_cherry)
		
		var stem_mesh := BoxMesh.new()
		stem_mesh.size = Vector3(0.14, 0.75, 0.14)
		
		var left_stem := MeshInstance3D.new()
		left_stem.mesh = stem_mesh
		left_stem.material_override = secondary
		left_stem.position = Vector3(-0.2, 0.85, 0.0)
		left_stem.rotation_degrees = Vector3(0, 0, -22)
		visual_holder.add_child(left_stem)
		
		var right_stem := MeshInstance3D.new()
		right_stem.mesh = stem_mesh
		right_stem.material_override = secondary
		right_stem.position = Vector3(0.2, 0.85, 0.0)
		right_stem.rotation_degrees = Vector3(0, 0, 22)
		visual_holder.add_child(right_stem)
		
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.2
		leaf_mesh.height = 0.4
		
		var leaf := MeshInstance3D.new()
		leaf.mesh = leaf_mesh
		leaf.material_override = secondary
		leaf.position = Vector3(0.0, 1.2, 0.0)
		visual_holder.add_child(leaf)
		
	func get_minimap_color() -> Color:
		return Color(1.0, 0.0, 0.2)


# --- STRAWBERRY DESIGN ---
class StrawberryDesign extends FruitDesignStrategy:
	func configure_materials(primary: StandardMaterial3D, secondary: StandardMaterial3D) -> void:
		primary.albedo_color = Color(1.0, 0.1, 0.4) # Strawberry Red
		secondary.albedo_color = Color(0.0, 0.7, 0.0) # Leaf Green
		
	func build_visuals(visual_holder: Node3D, primary: StandardMaterial3D, secondary: StandardMaterial3D) -> void:
		var strawberry_mesh := CylinderMesh.new()
		strawberry_mesh.top_radius = 0.52
		strawberry_mesh.bottom_radius = 0.08
		strawberry_mesh.height = 0.95
		strawberry_mesh.radial_segments = 12
		
		var berry := MeshInstance3D.new()
		berry.mesh = strawberry_mesh
		berry.material_override = primary
		berry.position.y = 0.48
		berry.rotation_degrees.x = 180.0
		visual_holder.add_child(berry)
		
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.18
		leaf_mesh.height = 0.36
		
		var leaf := MeshInstance3D.new()
		leaf.mesh = leaf_mesh
		leaf.material_override = secondary
		leaf.position = Vector3(0.0, 0.98, 0.0)
		visual_holder.add_child(leaf)
		
	func get_minimap_color() -> Color:
		return Color(1.0, 0.1, 0.4)


# --- PEACH DESIGN ---
class PeachDesign extends FruitDesignStrategy:
	func configure_materials(primary: StandardMaterial3D, secondary: StandardMaterial3D) -> void:
		primary.albedo_color = Color(1.0, 0.55, 0.1) # Peach Orange
		secondary.albedo_color = Color(0.1, 0.8, 0.1) # Leaf Green
		
	func build_visuals(visual_holder: Node3D, primary: StandardMaterial3D, secondary: StandardMaterial3D) -> void:
		var peach_mesh := SphereMesh.new()
		peach_mesh.radius = 0.58
		peach_mesh.height = 1.16
		
		var peach := MeshInstance3D.new()
		peach.mesh = peach_mesh
		peach.material_override = primary
		peach.position.y = 0.58
		visual_holder.add_child(peach)
		
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.22
		leaf_mesh.height = 0.44
		
		var leaf := MeshInstance3D.new()
		leaf.mesh = leaf_mesh
		leaf.material_override = secondary
		leaf.position = Vector3(0.28, 0.95, 0.0)
		leaf.rotation_degrees = Vector3(0.0, 0.0, -35.0)
		visual_holder.add_child(leaf)
		
	func get_minimap_color() -> Color:
		return Color(1.0, 0.55, 0.1)


# --- APPLE DESIGN ---
class AppleDesign extends FruitDesignStrategy:
	func configure_materials(primary: StandardMaterial3D, secondary: StandardMaterial3D) -> void:
		primary.albedo_color = Color(1.0, 0.0, 0.0) # Apple Red
		secondary.albedo_color = Color(0.4, 0.25, 0.1) # Stem Brown
		
	func build_visuals(visual_holder: Node3D, primary: StandardMaterial3D, secondary: StandardMaterial3D) -> void:
		var apple_mesh := SphereMesh.new()
		apple_mesh.radius = 0.58
		apple_mesh.height = 1.16
		
		var apple := MeshInstance3D.new()
		apple.mesh = apple_mesh
		apple.material_override = primary
		apple.position.y = 0.58
		visual_holder.add_child(apple)
		
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius = 0.06
		stem_mesh.bottom_radius = 0.06
		stem_mesh.height = 0.45
		stem_mesh.radial_segments = 6
		
		var stem := MeshInstance3D.new()
		stem.mesh = stem_mesh
		stem.material_override = secondary
		stem.position = Vector3(0.0, 1.25, 0.0)
		stem.rotation_degrees.z = 15.0
		visual_holder.add_child(stem)
		
	func get_minimap_color() -> Color:
		return Color(1.0, 0.0, 0.0)


# --- KEY DESIGN ---
class KeyDesign extends FruitDesignStrategy:
	func configure_materials(primary: StandardMaterial3D, _secondary: StandardMaterial3D) -> void:
		primary.albedo_color = Color(1.0, 0.8, 0.0) # Cyber Gold
		primary.emission_enabled = true
		primary.emission = Color(1.0, 0.5, 0.0) # Golden Glow
		primary.metallic = 0.8
		
	func build_visuals(visual_holder: Node3D, primary: StandardMaterial3D, _secondary: StandardMaterial3D) -> void:
		var key_holder := Node3D.new()
		
		var shaft_mesh := CylinderMesh.new()
		shaft_mesh.top_radius = 0.09
		shaft_mesh.bottom_radius = 0.09
		shaft_mesh.height = 0.85
		shaft_mesh.radial_segments = 8
		
		var shaft := MeshInstance3D.new()
		shaft.mesh = shaft_mesh
		shaft.material_override = primary
		shaft.position.y = 0.45
		key_holder.add_child(shaft)
		
		var ring_mesh := BoxMesh.new()
		ring_mesh.size = Vector3(0.42, 0.42, 0.15)
		
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = primary
		ring.position.y = 0.95
		key_holder.add_child(ring)
		
		var bit_mesh := BoxMesh.new()
		bit_mesh.size = Vector3(0.28, 0.18, 0.12)
		
		var bit_top := MeshInstance3D.new()
		bit_top.mesh = bit_mesh
		bit_top.material_override = primary
		bit_top.position = Vector3(0.18, 0.3, 0.0)
		key_holder.add_child(bit_top)
		
		var bit_bottom := MeshInstance3D.new()
		bit_bottom.mesh = bit_mesh
		bit_bottom.material_override = primary
		bit_bottom.position = Vector3(0.18, 0.15, 0.0)
		key_holder.add_child(bit_bottom)
		
		visual_holder.add_child(key_holder)
		
	func get_minimap_color() -> Color:
		return Color(1.0, 0.8, 0.0)

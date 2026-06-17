# ==============================================================================
# Description: Standalone Fruit bonus item (Area3D). Spawns procedurally based 
#              on the current level as a highly readable, glossy item 
#              (Cherry, Strawberry, Peach, Apple, Key), granting escalating 
#              point awards and emitting notifications upon consumption.
#              Phase 3 Updates:
#              - ARCADE FRUIT VARIETY: Re-engineered class to procedurally compile 
#                5 unique graphical shapes and assign arcade-accurate point values 
#                (Cherry=500, Strawberry=800, Peach=1000, Apple=2000, Key=5000) 
#                depending on the level.
#              - HIGH-DEFINITION SCALING: Enlarged all 3D mesh proportions by 60% 
#                and scaled up physical colliders for dramatic, clear gameplay.
#              - MINIMAP RADAR INTEGRATION: Added fruit to the "pellets" group and 
#                implemented polymorphic LSP color/radius getters to automatically 
#                render high-value blips on the 2D Minimap.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Fruit

# Emits the points value awarded upon consumption
signal eaten(points: int)

# Fruit properties determined by current level
var points_value : int = 500
var fruit_name : String = "Cherry"

# Materials
var primary_material : StandardMaterial3D
var secondary_material : StandardMaterial3D

# Internal visual component references
var visual_holder : Node3D
var time_passed : float = 0.0

# Initialize the fruit's identity and visual model depending on the level (DIP Compliance)
func initialize(level_number: int) -> void:
	add_to_group("pellets") # Add to active pellets group to allow auto-drawing on Minimap (LSP)
	_configure_collision_layers()
	_determine_fruit_identity(level_number)
	_initialize_materials()
	_build_fruit_visuals()
	
	body_entered.connect(_on_body_entered)
	
	# Randomize initial time state slightly to stagger animations
	time_passed = randf_range(0.0, 5.0)

func _configure_collision_layers() -> void:
	# Exist on Layer 0 (Detects Player on Layer 2)
	collision_layer = 0
	collision_mask = 2

# Assigns arcade-accurate names and points based on level
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
			# Level 5 and onwards spawns the prestigious Golden Key
			fruit_name = "Key"
			points_value = 5000

func _initialize_materials() -> void:
	primary_material = StandardMaterial3D.new()
	primary_material.roughness = 0.15
	primary_material.metallic = 0.1
	
	secondary_material = StandardMaterial3D.new()
	secondary_material.roughness = 0.5
	secondary_material.metallic = 0.0
	
	# Apply distinct color palettes dynamically matching retro pixels (SRP Compliance)
	match fruit_name:
		"Cherry":
			primary_material.albedo_color = Color(1.0, 0.0, 0.2) # Glossy Cherry Red
			secondary_material.albedo_color = Color(0.0, 0.8, 0.1) # Stem Green
		"Strawberry":
			primary_material.albedo_color = Color(1.0, 0.1, 0.4) # Bright Pinkish Strawberry Red
			secondary_material.albedo_color = Color(0.0, 0.7, 0.0) # Leaf Green
		"Peach":
			primary_material.albedo_color = Color(1.0, 0.55, 0.1) # Soft Gloss Peach Orange
			secondary_material.albedo_color = Color(0.1, 0.8, 0.1) # Leaf Green
		"Apple":
			primary_material.albedo_color = Color(1.0, 0.0, 0.0) # Solid Deep Red
			secondary_material.albedo_color = Color(0.4, 0.25, 0.1) # Woody Stem Brown
		"Key":
			# The Key is a brilliant, glowing golden energy construct! (OCP Compliance)
			primary_material.albedo_color = Color(1.0, 0.8, 0.0) # Cyber Gold
			primary_material.emission_enabled = true
			primary_material.emission = Color(1.0, 0.5, 0.0) # Neon Gold Glow
			primary_material.metallic = 0.8 # Metallic shine

# Programmatically compiles the enlarged 3D shapes representing the active bonus fruit
func _build_fruit_visuals() -> void:
	visual_holder = Node3D.new()
	
	match fruit_name:
		"Strawberry":
			# Procedural Strawberry: Cone-shaped berry topped with leafy sphere caps (Enlarged)
			var strawberry_mesh := CylinderMesh.new()
			strawberry_mesh.top_radius = 0.52
			strawberry_mesh.bottom_radius = 0.08
			strawberry_mesh.height = 0.95
			strawberry_mesh.radial_segments = 12
			
			var berry := MeshInstance3D.new()
			berry.mesh = strawberry_mesh
			berry.material_override = primary_material
			berry.position.y = 0.48
			berry.rotation_degrees.x = 180.0 # Point down
			visual_holder.add_child(berry)
			
			var leaf_mesh := SphereMesh.new()
			leaf_mesh.radius = 0.18
			leaf_mesh.height = 0.36
			
			var leaf := MeshInstance3D.new()
			leaf.mesh = leaf_mesh
			leaf.material_override = secondary_material
			leaf.position = Vector3(0.0, 0.98, 0.0)
			visual_holder.add_child(leaf)
			
		"Peach":
			# Procedural Peach: Large orange sphere with a leafy green slice (Enlarged)
			var peach_mesh := SphereMesh.new()
			peach_mesh.radius = 0.58
			peach_mesh.height = 1.16
			
			var peach := MeshInstance3D.new()
			peach.mesh = peach_mesh
			peach.material_override = primary_material
			peach.position.y = 0.58
			visual_holder.add_child(peach)
			
			var leaf_mesh := SphereMesh.new()
			leaf_mesh.radius = 0.22
			leaf_mesh.height = 0.44
			
			var leaf := MeshInstance3D.new()
			leaf.mesh = leaf_mesh
			leaf.material_override = secondary_material
			leaf.position = Vector3(0.28, 0.95, 0.0)
			leaf.rotation_degrees = Vector3(0.0, 0.0, -35.0) # Angled left
			visual_holder.add_child(leaf)
			
		"Apple":
			# Procedural Apple: Large rounded red sphere with a vertical brown stem (Enlarged)
			var apple_mesh := SphereMesh.new()
			apple_mesh.radius = 0.58
			apple_mesh.height = 1.16
			
			var apple := MeshInstance3D.new()
			apple.mesh = apple_mesh
			apple.material_override = primary_material
			apple.position.y = 0.58
			visual_holder.add_child(apple)
			
			var stem_mesh := CylinderMesh.new()
			stem_mesh.top_radius = 0.06
			stem_mesh.bottom_radius = 0.06
			stem_mesh.height = 0.45
			stem_mesh.radial_segments = 6
			
			var stem := MeshInstance3D.new()
			stem.mesh = stem_mesh
			stem.material_override = secondary_material
			stem.position = Vector3(0.0, 1.25, 0.0)
			stem.rotation_degrees.z = 15.0 # Slightly tilted
			visual_holder.add_child(stem)
			
		"Key":
			# Procedural Cyber Gold Key: Symmetrical ring handle connected to a notched shaft (Enlarged)
			var key_holder := Node3D.new()
			
			# 1. Shaft (Horizontal cylinder rotated vertical)
			var shaft_mesh := CylinderMesh.new()
			shaft_mesh.top_radius = 0.09
			shaft_mesh.bottom_radius = 0.09
			shaft_mesh.height = 0.85
			shaft_mesh.radial_segments = 8
			
			var shaft := MeshInstance3D.new()
			shaft.mesh = shaft_mesh
			shaft.material_override = primary_material
			shaft.position.y = 0.45
			key_holder.add_child(shaft)
			
			# 2. Ring Handle (Torus represented as thick box for high-contrast neon looks)
			var ring_mesh := BoxMesh.new()
			ring_mesh.size = Vector3(0.42, 0.42, 0.15)
			
			var ring := MeshInstance3D.new()
			ring.mesh = ring_mesh
			ring.material_override = primary_material
			ring.position.y = 0.95
			key_holder.add_child(ring)
			
			# 3. Notched bits (Flat boxes sticking out on bottom shaft side)
			var bit_mesh := BoxMesh.new()
			bit_mesh.size = Vector3(0.28, 0.18, 0.12)
			
			var bit_top := MeshInstance3D.new()
			bit_top.mesh = bit_mesh
			bit_top.material_override = primary_material
			bit_top.position = Vector3(0.18, 0.3, 0.0)
			key_holder.add_child(bit_top)
			
			var bit_bottom := MeshInstance3D.new()
			bit_bottom.mesh = bit_mesh
			bit_bottom.material_override = primary_material
			bit_bottom.position = Vector3(0.18, 0.15, 0.0)
			key_holder.add_child(bit_bottom)
			
			visual_holder.add_child(key_holder)
			
		_:
			# Default "Cherry": Dual-stem cherry layout (Enlarged)
			var cherry_mesh := SphereMesh.new()
			cherry_mesh.radius = 0.5
			cherry_mesh.height = 1.0
			
			var left_cherry := MeshInstance3D.new()
			left_cherry.mesh = cherry_mesh
			left_cherry.material_override = primary_material
			left_cherry.position = Vector3(-0.35, 0.4, 0.0)
			visual_holder.add_child(left_cherry)
			
			var right_cherry := MeshInstance3D.new()
			right_cherry.mesh = cherry_mesh
			right_cherry.material_override = primary_material
			right_cherry.position = Vector3(0.35, 0.4, 0.0)
			visual_holder.add_child(right_cherry)
			
			var stem_mesh := BoxMesh.new()
			stem_mesh.size = Vector3(0.14, 0.75, 0.14)
			
			var left_stem := MeshInstance3D.new()
			left_stem.mesh = stem_mesh
			left_stem.material_override = secondary_material
			left_stem.position = Vector3(-0.2, 0.85, 0.0)
			left_stem.rotation_degrees = Vector3(0, 0, -22)
			visual_holder.add_child(left_stem)
			
			var right_stem := MeshInstance3D.new()
			right_stem.mesh = stem_mesh
			right_stem.material_override = secondary_material
			right_stem.position = Vector3(0.2, 0.85, 0.0)
			right_stem.rotation_degrees = Vector3(0, 0, 22)
			visual_holder.add_child(right_stem)
			
			var leaf_mesh := SphereMesh.new()
			leaf_mesh.radius = 0.2
			leaf_mesh.height = 0.4
			
			var leaf := MeshInstance3D.new()
			leaf.mesh = leaf_mesh
			leaf.material_override = secondary_material
			leaf.position = Vector3(0.0, 1.2, 0.0)
			visual_holder.add_child(leaf)

	# --- PHYSICAL COLLIDER (Sized up for consistent touch target) ---
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
	
	# 1. Rotate the fruit continuously on the Y-axis
	visual_holder.rotate_y(1.2 * delta)
	
	# 2. Float gently up and down on a wide, premium-looking sine wave
	visual_holder.position.y = sin(time_passed * 2.0) * 0.08

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Trigger player eat sound (SRP Compliance)
		if body.has_method("play_eat_sound"):
			body.play_eat_sound()
			
		eaten.emit(points_value) # Emits level-adapted arcade point values
		queue_free()

# --- MINIMAP POLYMORPHISM (LSP/OCP COMPLIANCE) ---
# These methods allow the Minimap to query drawing instructions of this 
# high-value item, coloring them matching their actual visual colors on the radar.

func get_minimap_color() -> Color:
	match fruit_name:
		"Key": return Color(1.0, 0.8, 0.0) # Golden yellow blip
		"Apple", "Cherry": return Color(1.0, 0.0, 0.2) # Crimson Red blip
		"Strawberry": return Color(1.0, 0.1, 0.4) # Pinkish Red
		"Peach": return Color(1.0, 0.55, 0.1) # Orange
		_: return Color(1.0, 0.0, 0.8) # Magenta fallback

func get_minimap_radius() -> float:
	return 5.2 # Large prominent bonus radar blip!

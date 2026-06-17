# ==============================================================================
# Description: Standalone Frost-Blue Ice Utility Pellet (Area3D). Spawns 
#              procedurally as a floating, rotating neon diamond, emitting 
#              eaten notifications upon player collision.
#              SOLID Refactoring:
#              - SRP Compliance: Fully isolated visual representation and 
#                collision detection from other items.
#              - LSP/OCP COMPLIANCE: Exposes minimap drawing properties via 
#                polymorphic methods to prevent duck-typing in Minimap2D.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name IcePellet

# Emitted when eaten to let orchestrators freeze active ghosts
signal ice_pellet_eaten()

var ice_material : StandardMaterial3D

# Internal visual component references
var mesh_instance : MeshInstance3D
var time_passed : float = 0.0

func _ready() -> void:
	add_to_group("pellets") # Belongs to pellets group so it maintains victory counts
	_configure_collision_layers()
	_initialize_material()
	_build_pellet_visuals()
	body_entered.connect(_on_body_entered)
	
	# Randomize initial phase slightly to stagger animations
	time_passed = randf_range(0.0, 5.0)

func _configure_collision_layers() -> void:
	# Exist on Layer 0 (Detects Player on Layer 2)
	collision_layer = 0
	collision_mask = 2

func _initialize_material() -> void:
	# Glowing Frost-Cyan material
	ice_material = StandardMaterial3D.new()
	ice_material.albedo_color = Color(0.0, 0.8, 1.0)
	ice_material.emission_enabled = true
	ice_material.emission = Color(0.0, 0.4, 0.8) # Frosty glow

# Programmatically constructs the rotating diamond mesh
func _build_pellet_visuals() -> void:
	mesh_instance = MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# Rotated box mesh to form a perfect diamond shape
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.35, 0.35, 0.35)
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = ice_material
	
	# Pre-rotate by 45 degrees on X and Z axes to form the diamond
	mesh_instance.rotation_degrees = Vector3(45.0, 0.0, 45.0)
	
	# Custom capsule collider sized to fit the diamond boundaries
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.35
	collision_shape.shape = sphere_shape
	
	add_child(mesh_instance)
	add_child(collision_shape)

func _process(delta: float) -> void:
	if not is_instance_valid(mesh_instance):
		return
		
	time_passed += delta
	
	# 1. Rotate the diamond continuously on the Y-axis
	mesh_instance.rotate_y(1.5 * delta)
	
	# 2. Float gently up and down on a smooth, low-amplitude sine wave
	mesh_instance.position.y = sin(time_passed * 2.5) * 0.06

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Trigger player eat sound (SRP Compliance)
		if body.has_method("play_eat_sound"):
			body.play_eat_sound()
			
		# Emit notification to let orchestrator pause ghosts
		ice_pellet_eaten.emit()
		
		# Self-destroy
		queue_free()

# --- MINIMAP POLYMORPHISM (LSP/OCP COMPLIANCE) ---
# Instructs the minimap how to draw this specific utility pellet

func get_minimap_color() -> Color:
	return Color(0.0, 0.8, 1.0) # Frost Cyan

func get_minimap_radius() -> float:
	return 3.5

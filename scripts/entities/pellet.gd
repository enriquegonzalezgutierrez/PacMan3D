# ==============================================================================
# Description: Script for the pellet entity (Area3D) that joins the "pellets" 
#              group and detects Player class collisions on Layer 2.
#              SOLID Refactoring & Visual Polish:
#              - DYNAMIC PROCEDURAL ROTATION & FLOAT: Added a process loop to 
#                continuously spin the pellet on its Y axis and float it gently 
#                up and down on a smooth, low-amplitude sine-wave.
#              - DIP: Completely decoupled from the GameManager singleton.
#              - LSP/OCP COMPLIANCE: Exposes minimap drawing properties via 
#                polymorphic methods to prevent duck-typing in Minimap2D.
#              Phase 4 Updates:
#              - MASSIVE SCALE INDICATOR: Sized up standard pellets to 0.25 radius 
#                and power pellets to 0.55 radius for majestic arcade visibility on 1080p.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Pellet

# Signal emitted when eaten, delegating gameplay state mutations (DIP Compliance)
signal eaten(is_power: bool)

@export var is_power_pellet : bool = false
var pellet_material : StandardMaterial3D

# Internal visual component references
var mesh_instance : MeshInstance3D
var time_passed : float = 0.0

func _ready() -> void:
	add_to_group("pellets")
	_configure_collision_layers()
	_initialize_material()
	_build_pellet_visuals()
	body_entered.connect(_on_body_entered)
	
	# Randomize initial time state slightly to prevent all pellets from floating in robotic unison
	time_passed = randf_range(0.0, 5.0)

func _configure_collision_layers() -> void:
	collision_layer = 0 
	collision_mask = 2  

func _initialize_material() -> void:
	pellet_material = StandardMaterial3D.new()
	pellet_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	if is_power_pellet:
		pellet_material.albedo_color = Color(1.0, 0.5, 0.0) 
	else:
		pellet_material.albedo_color = Color(1.0, 1.0, 0.0) 

func _build_pellet_visuals() -> void:
	mesh_instance = MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# Sized up massively for premium 1080p readability
	var radius : float = 0.55 if is_power_pellet else 0.25
	
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	mesh_instance.mesh = sphere_mesh
	mesh_instance.material_override = pellet_material
	
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	
	add_child(mesh_instance)
	add_child(collision_shape)

func _process(delta: float) -> void:
	if not is_instance_valid(mesh_instance):
		return
		
	time_passed += delta
	
	# 1. Rotate the pellet continuously on the Y-axis
	mesh_instance.rotate_y(1.5 * delta)
	
	# 2. Float gently up and down on a smooth, low-amplitude sine wave
	mesh_instance.position.y = sin(time_passed * 2.5) * 0.06

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Let the player trigger its own eat sound (SRP Compliance)
		if body.has_method("play_eat_sound"):
			body.play_eat_sound()
			
		# Emit signal to let orchestrators handle score/state updates (DIP Compliance)
		eaten.emit(is_power_pellet)
		
		# Self-destroy
		queue_free()

# --- MINIMAP POLYMORPHISM (LSP/OCP COMPLIANCE) ---
# These methods allow the Minimap to query drawing instructions without needing
# to know the specific class type of the pellet.

func get_minimap_color() -> Color:
	return Color(1.0, 0.5, 0.0) if is_power_pellet else Color(1.0, 1.0, 0.0)

func get_minimap_radius() -> float:
	return 3.5 if is_power_pellet else 1.5

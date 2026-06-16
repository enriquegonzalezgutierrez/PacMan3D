# ==============================================================================
# Description: Script for the pellet entity (Area3D) that joins the "pellets" 
#              group and detects Player class collisions on Layer 2.
#              SOLID Refactoring:
#              - DIP: Completely decoupled from the GameManager singleton. 
#                Instead of directly mutating global scores, it emits an `eaten` 
#                signal, leaving gameplay state management to the orchestrating classes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Pellet

# Signal emitted when eaten, delegating gameplay state mutations (DIP Compliance)
signal eaten(is_power: bool)

@export var is_power_pellet : bool = false
var pellet_material : StandardMaterial3D

func _ready() -> void:
	add_to_group("pellets")
	_configure_collision_layers()
	_initialize_material()
	_build_pellet_visuals()
	body_entered.connect(_on_body_entered)

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
	var mesh_instance := MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	var radius : float = 0.35 if is_power_pellet else 0.15
	
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

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Let the player trigger its own eat sound (SRP Compliance)
		if body.has_method("play_eat_sound"):
			body.play_eat_sound()
			
		# Emit signal to let orchestrators handle score/state updates (DIP Compliance)
		eaten.emit(is_power_pellet)
		
		# Self-destroy
		queue_free()

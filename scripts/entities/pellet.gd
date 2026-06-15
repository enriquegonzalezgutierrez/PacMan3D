# ==============================================================================
# Description: Script for the pellet entity (Area3D) that registers itself with 
#              the GameManager, joins the "pellets" group, detects Player class
#              collision on Layer 2, and features unshaded (always bright) materials
#              to prevent them from turning black in shadowed corridors.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Pellet

@export var is_power_pellet : bool = false
var pellet_material : StandardMaterial3D

func _ready() -> void:
	add_to_group("pellets")
	if GameManager:
		GameManager.register_pellet()
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
		if GameManager:
			if is_power_pellet:
				GameManager.add_score(40)
				GameManager.activate_power_pellet()
			GameManager.pellet_eaten()
		queue_free()

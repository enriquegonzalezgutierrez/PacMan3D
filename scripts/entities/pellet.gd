# ==============================================================================
# Description: Script for the pellet entity (Area3D) that registers itself with 
#              the GameManager, joins the "pellets" group, detects player 
#              collision, and features self-emission (glow in the dark) materials.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Pellet

# Exported variable allows us to define the pellet type inside the editor or JSON
@export var is_power_pellet : bool = false

var pellet_material : StandardMaterial3D

func _ready() -> void:
	# Register this pellet globally to win conditions and UI/Minimap group queries
	add_to_group("pellets")
	if GameManager:
		GameManager.register_pellet()
	
	_initialize_material()
	_build_pellet_visuals()
	
	# Connect the standard body_entered signal to our callback
	body_entered.connect(_on_body_entered)

# Sets up color and emission glow (Yellow for standard, Orange for Power Pellet)
func _initialize_material() -> void:
	pellet_material = StandardMaterial3D.new()
	
	# Enable self-emission so the pellets glow in dark shadowed corridors
	pellet_material.emission_enabled = true
	
	if is_power_pellet:
		pellet_material.albedo_color = Color(1.0, 0.5, 0.0) # Orange
		pellet_material.emission = Color(1.0, 0.3, 0.0) # Neon orange glow
	else:
		pellet_material.albedo_color = Color(1.0, 1.0, 0.0) # Yellow
		pellet_material.emission = Color(0.6, 0.6, 0.0) # Soft yellow-green glow

# Programmatically generates the Sphere mesh and Sphere collision shape
func _build_pellet_visuals() -> void:
	var mesh_instance := MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# Power Pellets are larger than standard pellets
	var radius : float = 0.35 if is_power_pellet else 0.15
	
	# Setup Mesh (Sphere)
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	mesh_instance.mesh = sphere_mesh
	mesh_instance.material_override = pellet_material
	
	# Setup Collision Shape (Sphere)
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	
	# Assemble the node tree
	add_child(mesh_instance)
	add_child(collision_shape)

# Callback when a physical body enters the Pellet Area3D
func _on_body_entered(body: Node3D) -> void:
	# Check if the colliding object is in the "player" group
	if body.is_in_group("player"):
		if GameManager:
			if is_power_pellet:
				# Power pellets grant more score (40 extra + 10 base = 50 total)
				GameManager.add_score(40)
				# Trigger the global power mode to frighten the ghosts
				GameManager.activate_power_pellet()
			
			# Count pellet as eaten and trigger win condition check
			GameManager.pellet_eaten()
			
		# Remove pellet from the scene
		queue_free()

# ==============================================================================
# Description: Generic portal teleporter (Area3D) that transfers any physics 
#              body to a partner portal, adhering to SOLID principles.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Portal

# The name of the sibling portal to teleport the body to
@export var partner_portal_name : String = ""

func _ready() -> void:
	_build_portal_collision()
	
	# Connect enter/exit signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# Programmatically builds the trigger area collision box
func _build_portal_collision() -> void:
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	
	# Dimensions match the lane grid sizing (CELL_SIZE x CELL_SIZE)
	box_shape.size = Vector3(1.8, 2.0, 1.8)
	collision_shape.shape = box_shape
	
	add_child(collision_shape)

# Callback: Triggers when a player or ghost enters the portal area
func _on_body_entered(body: Node3D) -> void:
	# Avoid infinite loop: If the body has just teleported here from the other side, ignore it
	if body.has_meta("just_teleported"):
		return
		
	# Find the partner portal node dynamically as a sibling in the LevelManager tree
	var partner = get_parent().get_node_or_null(partner_portal_name) as Node3D
	if partner:
		# Mark the body so the target portal ignores its arrival trigger
		body.set_meta("just_teleported", true)
		
		# Execute instantaneous teleportation
		body.global_position = partner.global_position

# Callback: Triggers when the body physically leaves the portal area
func _on_body_exited(body: Node3D) -> void:
	# Wipe the metadata flag once the body is clear of the area, ready for another warp
	if body.has_meta("just_teleported"):
		body.remove_meta("just_teleported")

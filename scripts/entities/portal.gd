# ==============================================================================
# Description: Generic portal teleporter (Area3D) that transfers any physics 
#              body to a partner portal, adhering to SOLID principles.
#              UPDATED: Fixed collision masks to properly detect Player/Ghosts 
#              and fixed teleportation signal race conditions (infinite loops).
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

# Programmatically builds the trigger area collision box and sets Layers
func _build_portal_collision() -> void:
	# CRITICAL FIX: The Area3D needs to monitor the layers where entities exist.
	# collision_layer = 0 (The portal doesn't physically block anything)
	# collision_mask  = 6 (Monitors Layer 2 (Player, value 2) + Layer 3 (Ghosts, value 4))
	collision_layer = 0
	collision_mask = 6
	
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	
	# Dimensions match the lane grid sizing (CELL_SIZE x CELL_SIZE)
	box_shape.size = Vector3(1.8, 2.0, 1.8)
	collision_shape.shape = box_shape
	
	add_child(collision_shape)

# Callback: Triggers when a player or ghost enters the portal area
func _on_body_entered(body: Node3D) -> void:
	# Avoid infinite loop signal race condition: 
	# If the body just arrived here from another portal, ignore the entry trigger.
	if body.has_meta("last_portal") and body.get_meta("last_portal") == name:
		return
		
	# Find the partner portal node dynamically as a sibling in the LevelManager tree
	var partner = get_parent().get_node_or_null(partner_portal_name) as Node3D
	if partner:
		# Mark the body with the DESTINATION portal's name before moving it
		body.set_meta("last_portal", partner.name)
		
		# Execute instantaneous teleportation
		body.global_position = partner.global_position

# Callback: Triggers when the body physically leaves the portal area
func _on_body_exited(body: Node3D) -> void:
	# Once the body fully steps out of the destination portal, clear the metadata
	# so it can use portals again in the future.
	if body.has_meta("last_portal") and body.get_meta("last_portal") == name:
		body.remove_meta("last_portal")

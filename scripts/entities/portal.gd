# ==============================================================================
# Description: Generic portal teleporter (Area3D) that transfers any physics 
#              body to a partner portal, adhering to SOLID principles.
#              SOLID Refactoring:
#              - DIP: Removed scene tree string-based node lookups. The sibling
#                partner portal is directly injected as a Node3D reference.
#              - Robustness: Replaced metadata string name comparison with 
#                direct object reference comparisons, preventing rename bugs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Portal

# Injected Dependency (DIP Compliance)
var partner_portal : Portal = null

# Dependency Injection initializer
func initialize(partner: Portal) -> void:
	partner_portal = partner

func _ready() -> void:
	_build_portal_collision()
	
	# Connect enter/exit signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# Programmatically builds the trigger area collision box and sets Layers
func _build_portal_collision() -> void:
	# Detect Layer 2 (Player) and Layer 3 (Ghosts)
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
	# Avoid teleportation loop: check if the body has just teleported here (referencing this node)
	if body.has_meta("last_portal") and body.get_meta("last_portal") == self:
		return
		
	if partner_portal:
		# Mark the body with the destination portal's object reference
		body.set_meta("last_portal", partner_portal)
		
		# Execute instantaneous teleportation
		body.global_position = partner_portal.global_position

# Callback: Triggers when the body physically leaves the portal area
func _on_body_exited(body: Node3D) -> void:
	# Clear the metadata tag once the entity fully steps out of the destination portal
	if body.has_meta("last_portal") and body.get_meta("last_portal") == self:
		body.remove_meta("last_portal")

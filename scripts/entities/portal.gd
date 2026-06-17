# ==============================================================================
# Description: Generic portal teleporter (Area3D) that transfers any physics 
#              body to a partner portal, adhering to SOLID principles.
#              SOLID Refactoring:
#              - DIP: Removed scene tree string-based node lookups. The sibling
#                partner portal is directly injected as a Node3D reference.
#              - Robustness: Replaced metadata string name comparison with 
#                direct object reference comparisons, preventing rename bugs.
#              Phase 4 Updates:
#              - HOLOGRAPHIC PORTAL GATEWAY: Programmatically builds a gorgeous 
#                glowing neon portal arch with an energy curtain, automatically 
#                aligning its rotation degrees depending on world-axis locations.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name Portal

# Injected Dependency (DIP Compliance)
var partner_portal : Portal = null

# Visual component references
var visual_holder : Node3D
var portal_material : StandardMaterial3D

# Dependency Injection initializer
func initialize(partner: Portal) -> void:
	partner_portal = partner

func _ready() -> void:
	_build_portal_collision()
	_build_portal_visuals()
	
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

# Programmatically constructs the highly polished holographic neon archways (Phase 4)
func _build_portal_visuals() -> void:
	visual_holder = Node3D.new()
	
	# Determine axis orientation based on node name (Symmetric alignment helper)
	var is_side_portal : bool = (name == "Portal_A" or name == "Portal_B")
	if is_side_portal:
		# Rotate 90 degrees to align open gateway with horizontal Z axis corridors
		rotation_degrees.y = 90.0
		
	# 1. Glowing Cyan Energy Material
	portal_material = StandardMaterial3D.new()
	portal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal_material.albedo_color = Color(0.0, 0.8, 1.0, 0.15) # Shimmering translucent blue
	portal_material.emission_enabled = true
	portal_material.emission = Color(0.0, 0.5, 1.0) # Intense neon cyan emission
	portal_material.roughness = 0.1
	
	# 2. Symmetrical Archway Framework (Two vertical posts + one top crossbar)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.08, 1.6, 0.08) # Thin high-contrast posts
	post_mesh.material = portal_material
	
	# Left post
	var left_post := MeshInstance3D.new()
	left_post.mesh = post_mesh
	left_post.position = Vector3(-0.85, 0.8, 0.0) # Flanking the corridor sides
	visual_holder.add_child(left_post)
	
	# Right post
	var right_post := MeshInstance3D.new()
	right_post.mesh = post_mesh
	right_post.position = Vector3(0.85, 0.8, 0.0)
	visual_holder.add_child(right_post)
	
	# Top Crossbar connecting the posts
	var crossbar_mesh := BoxMesh.new()
	crossbar_mesh.size = Vector3(1.78, 0.08, 0.08)
	crossbar_mesh.material = portal_material
	
	var crossbar := MeshInstance3D.new()
	crossbar.mesh = crossbar_mesh
	crossbar.position = Vector3(0.0, 1.6, 0.0)
	visual_holder.add_child(crossbar)
	
	# 3. Holographic Swirling Energy Curtain
	var curtain_mesh := BoxMesh.new()
	curtain_mesh.size = Vector3(1.68, 1.5, 0.02) # Thin translucent sheet inside the arch
	
	var curtain_material := StandardMaterial3D.new()
	curtain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	curtain_material.albedo_color = Color(0.0, 0.8, 1.0, 0.08) # Almost fully transparent
	curtain_material.emission_enabled = true
	curtain_material.emission = Color(0.0, 0.4, 0.8)
	curtain_material.emission_energy_multiplier = 0.4 # Gentle glowing curtain
	curtain_mesh.material = curtain_material
	
	var curtain := MeshInstance3D.new()
	curtain.mesh = curtain_mesh
	curtain.position = Vector3(0.0, 0.75, 0.0)
	visual_holder.add_child(curtain)
	
	# Shift the entire visual assembly slightly backwards to align exactly on map exit boundaries
	visual_holder.position.y = -0.3 # Level with floor grid offsets
	add_child(visual_holder)

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

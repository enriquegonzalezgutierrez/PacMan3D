# ==============================================================================
# Description: Standalone Lightning Bolt Speed Pellet (Area3D). Spawns 
#              procedurally as a glowing, rotating neon zig-zag lightning bolt, 
#              granting a temporary speed boost to the Player upon collision.
#              SOLID Refactoring:
#              - LSP/OCP COMPLIANCE: Exposes polymorphic minimap colors and 
#                radii to integrate seamlessly with the 2D Minimap radar.
#              - SRP: Fully encapsulates the physical 3D zig-zag mesh construction 
#                and collision trigger logic.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Area3D
class_name SpeedPellet

# Signal emitted when eaten, delegating gameplay state mutations (DIP Compliance)
signal speed_pellet_eaten()

var lightning_material : StandardMaterial3D

# Internal visual component references
var visual_holder : Node3D
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
	# Vibrant Glowing Neon Yellow/Cyan electric material
	lightning_material = StandardMaterial3D.new()
	lightning_material.albedo_color = Color(1.0, 0.9, 0.0) # Bright Electric Yellow
	lightning_material.emission_enabled = true
	lightning_material.emission = Color(1.0, 0.7, 0.0) # Golden electric glow
	lightning_material.roughness = 0.1

# Programmatically constructs a beautiful 3D zig-zag lightning bolt
func _build_pellet_visuals() -> void:
	visual_holder = Node3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# Segment dimension variables
	var seg_length : float = 0.35
	var seg_thickness : float = 0.08
	
	var segment_mesh := BoxMesh.new()
	segment_mesh.size = Vector3(seg_thickness, seg_length, seg_thickness)
	
	# 1. Top Segment (Angled right)
	var top_seg := MeshInstance3D.new()
	top_seg.mesh = segment_mesh
	top_seg.material_override = lightning_material
	top_seg.position = Vector3(0.12, 0.42, 0.0)
	top_seg.rotation_degrees.z = -35.0
	visual_holder.add_child(top_seg)
	
	# 2. Middle Segment (Angled left, connecting top and bottom)
	var mid_seg := MeshInstance3D.new()
	mid_seg.mesh = segment_mesh
	mid_seg.material_override = lightning_material
	mid_seg.position = Vector3(0.0, 0.2, 0.0)
	mid_seg.rotation_degrees.z = 35.0
	visual_holder.add_child(mid_seg)
	
	# 3. Bottom Segment (Angled right, finishing the zig-zag)
	var bot_seg := MeshInstance3D.new()
	bot_seg.mesh = segment_mesh
	bot_seg.material_override = lightning_material
	bot_seg.position = Vector3(-0.12, -0.02, 0.0)
	bot_seg.rotation_degrees.z = -35.0
	visual_holder.add_child(bot_seg)
	
	# --- PHYSICAL COLLIDER ---
	# Capsule shape fitted to match the vertical span of the lightning bolt
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.32
	capsule_shape.height = 0.9
	collision_shape.shape = capsule_shape
	collision_shape.position.y = 0.2
	
	add_child(visual_holder)
	add_child(collision_shape)

func _process(delta: float) -> void:
	if not is_instance_valid(visual_holder):
		return
		
	time_passed += delta
	
	# 1. Rotate the lightning bolt continuously on the Y-axis
	visual_holder.rotate_y(1.8 * delta)
	
	# 2. Float gently up and down on a quick, energetic sine wave
	visual_holder.position.y = sin(time_passed * 3.5) * 0.08
	
	# 3. Procedural Electrical Flicker (Modulate emission energy dynamically)
	var flicker : float = randf_range(0.65, 1.25)
	lightning_material.emission_energy_multiplier = flicker

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Let the player trigger its own eat sound (SRP Compliance)
		if body.has_method("play_eat_sound"):
			body.play_eat_sound()
			
		# Trigger speed boost on Player state machine
		if body.has_method("activate_speed_boost"):
			body.activate_speed_boost()
			
		# Emit notification to let orchestrator handle pellet progression count
		speed_pellet_eaten.emit()
		
		# Self-destroy
		queue_free()

# --- MINIMAP POLYMORPHISM (LSP/OCP COMPLIANCE) ---
# Direct implementation of Minimap hooks so the radar draws the speed ray

func get_minimap_color() -> Color:
	return Color(0.0, 1.0, 1.0) # Electric Cyan blip on the radar!

func get_minimap_radius() -> float:
	return 3.5

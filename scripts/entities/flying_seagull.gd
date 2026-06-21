# ==============================================================================
# Description: Independent Flying Cyber-Seagull (Ciber-Gariota de Neón).
#              Generates a 3D mechanical seagull that flies diagonally over 
#              the maze corridors, flapping its neon wings and leaving a glowing 
#              particle trail in real-time.
#              SOLID Architecture Compliance:
#              - SRP: Entirely self-contained. Manages its own flight path, 
#                wing flapping math, and particle trail cleanup.
#              - LSP: Correctly inherits from Node3D and behaves within standard 
#                3D spatial transformations.
#              - Monumental Scale Up: Increased visual proportions by 8x 
#                (1.8m body, 5.8m wingspan) and optimized flight speeds for 
#                majestic, highly visible diorama crossings.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node3D
class_name FlyingSeagull

# Flight configurations (Calibrated for giant visible gliding)
const FLIGHT_HEIGHT : float = 4.2 # Raised to prevent wing clipping with 2m walls
const FLIGHT_SPEED : float = 2.2 # Slowed down for a majestic, highly visible pace
const FLAP_SPEED : float = 4.2 # Slowed down to match the massive wing weight
const FLAP_AMPLITUDE : float = 0.28

# Boundary coordinates (Read dynamically from LevelBuilder offsets)
var map_limit_x : float = 32.0
var map_limit_z : float = 32.0

# Flight path vector
var flight_direction : Vector3 = Vector3(1.0, 0.0, 0.5).normalized()

# Visual component references
var body_mesh : MeshInstance3D = null
var wing_left : MeshInstance3D = null
var wing_right : MeshInstance3D = null
var particle_trail : CPUParticles3D = null

# Materials
var chrome_material : StandardMaterial3D = null
var laser_material : StandardMaterial3D = null

# State tracking variables
var time_passed : float = 0.0

# Initializer to set map boundaries dynamically on spawn (SOLID DIP)
func initialize(limit_x: float, limit_z: float, direction: Vector3) -> void:
	map_limit_x = limit_x + 15.0 # Shift boundary out of view for clean transitions
	map_limit_z = limit_z + 15.0
	flight_direction = direction.normalized()

func _ready() -> void:
	# Ensure the seagull flies even during pause states
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_initialize_materials()
	_build_seagull_geometry()
	
	time_passed = randf_range(0.0, 10.0)

func _initialize_materials() -> void:
	# 1. Sleek Polished Chrome Body (PBR metallic shine)
	chrome_material = StandardMaterial3D.new()
	chrome_material.albedo_color = Color(0.95, 0.95, 0.98)
	chrome_material.metallic = 1.0
	chrome_material.roughness = 0.15
	chrome_material.clearcoat_enabled = true
	chrome_material.clearcoat = 1.0
	
	# 2. Glowing Laser Wings (Vibrant Neon Cyan)
	laser_material = StandardMaterial3D.new()
	laser_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	laser_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_material.albedo_color = Color(0.0, 0.8, 1.0, 0.65) # Translucent cyan
	laser_material.emission_enabled = true
	laser_material.emission = Color(0.0, 0.70, 1.0)

# Programmatically constructs the mechanical seagull's 3D body and wings
func _build_seagull_geometry() -> void:
	var visual_root := Node3D.new()
	add_child(visual_root)
	
	# 1. Main Fuselage Body (Aerodynamic metallic capsule - 1.8 meters long!)
	var body_geom := CylinderMesh.new()
	body_geom.top_radius = 0.08 # Pointed beak
	body_geom.bottom_radius = 0.32 # Robust fuselage (64cm diameter)
	body_geom.height = 1.8
	body_geom.radial_segments = 8
	
	body_mesh = MeshInstance3D.new()
	body_mesh.mesh = body_geom
	body_mesh.material_override = chrome_material
	body_mesh.rotation_degrees.x = 90.0 # Aligned forward
	visual_root.add_child(body_mesh)
	
	# 2. Glowing Left Wing (Giant 2.8-meter wing!)
	var wing_geom := BoxMesh.new()
	wing_geom.size = Vector3(2.8, 0.02, 0.35) # Large laser sheet wing
	
	var left_wing_anchor := Node3D.new()
	left_wing_anchor.position = Vector3(-0.25, 0.0, 0.0) # Adjusted offset to the side of the thick body
	visual_root.add_child(left_wing_anchor)
	
	wing_left = MeshInstance3D.new()
	wing_left.mesh = wing_geom
	wing_left.material_override = laser_material
	wing_left.position = Vector3(-1.4, 0.0, 0.0) # Shift pivot center to the joint
	left_wing_anchor.add_child(wing_left)
	
	# 3. Glowing Right Wing
	var right_wing_anchor := Node3D.new()
	right_wing_anchor.position = Vector3(0.25, 0.0, 0.0)
	visual_root.add_child(right_wing_anchor)
	
	wing_right = MeshInstance3D.new()
	wing_right.mesh = wing_geom
	wing_right.material_override = laser_material
	wing_right.position = Vector3(1.4, 0.0, 0.0)
	right_wing_anchor.add_child(wing_right)
	
	# 4. Neon Particle Trail (Thicker and longer trail)
	particle_trail = CPUParticles3D.new()
	var trail_mesh := BoxMesh.new()
	trail_mesh.size = Vector3(0.08, 0.08, 0.08) # Sized up
	var trail_mat := StandardMaterial3D.new()
	trail_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.albedo_color = Color(0.0, 0.8, 1.0)
	trail_mesh.material = trail_mat
	
	particle_trail.mesh = trail_mesh
	particle_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particle_trail.emission_sphere_radius = 0.15
	particle_trail.direction = -flight_direction # Emitting backward
	particle_trail.gravity = Vector3.ZERO
	particle_trail.initial_velocity_min = 0.8
	particle_trail.initial_velocity_max = 1.8
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	particle_trail.scale_amount_curve = curve
	
	particle_trail.amount = 24 # Increased density
	particle_trail.lifetime = 0.8 # Longer life
	particle_trail.position = Vector3(0.0, 0.0, -0.9) # Tail exhaust
	add_child(particle_trail)

func _physics_process(delta: float) -> void:
	time_passed += delta
	
	# 1. Glide and Translate Position diagonally across the sky
	global_position += flight_direction * FLIGHT_SPEED * delta
	
	# 2. Flap Wings procedurally using a smooth Sine-Wave (Arcade Physics simulation)
	if is_instance_valid(wing_left) and is_instance_valid(wing_right):
		var flap_angle : float = sin(time_passed * FLAP_SPEED) * FLAP_AMPLITUDE
		
		# Rotate wing anchors on their pivot joints
		wing_left.get_parent().rotation.z = flap_angle
		wing_right.get_parent().rotation.z = -flap_angle
		
	# 3. Orient the entire seagull to look straight forward into flight_direction (+PI facing fix)
	var target_rotation_y = atan2(-flight_direction.x, -flight_direction.z) + PI
	rotation.y = target_rotation_y
	
	# 4. Symmetrical Out-of-bounds Wrap-Around check
	if abs(global_position.x) > map_limit_x or abs(global_position.z) > map_limit_z:
		_wrap_flight_coordinates()

# Teleports the seagull to the opposite boundary to loop indefinitely
func _wrap_flight_coordinates() -> void:
	# Reverse coordinates to wrap cleanly across the sky
	if abs(global_position.x) > map_limit_x:
		global_position.x = -sign(global_position.x) * (map_limit_x - 1.0)
	if abs(global_position.z) > map_limit_z:
		global_position.z = -sign(global_position.z) * (map_limit_z - 1.0)

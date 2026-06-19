# ==============================================================================
# Description: Procedural Perimeter Decoration Strategies (SOLID Strategy Pattern).
#              Generates advanced 3D geometries and animations code-only 
#              to populate empty outskirt spaces on the map boundaries.
#              SOLID Architecture Compliance:
#              - SRP: Separates the visual construction of monuments from LevelBuilder.
#              - OCP: Easily extendable with new decoration designs (e.g. Taulas, Boats)
#                by adding new Strategy subclasses here.
#              - LSP/ISP: Exposes a single, unified, lightweight build interface.
#              - Monumental Overhaul: Scales up Cyber-Windmills to giant proportions 
#                (8.0m high, 13.6m blades) with high-contrast stone materials and 
#                pulsing neon ring accents.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name PerimeterDecorationStrategies

# ==============================================================================
# --- VIRTUAL BASE STRATEGY CLASS (SOLID LSP/ISP) ---
# ==============================================================================
class BaseDecorationStrategy extends RefCounted:
	func build_decoration(_parent_node: Node3D, _pos: Vector3, _rot_y: float) -> void:
		pass


# ==============================================================================
# --- CONCRETE MONUMENTAL CYBER-WINDMILL STRATEGY (CIBER-MOLINO GIGANTE) ---
# ==============================================================================
class CyberWindmill extends BaseDecorationStrategy:
	# Shared structural materials (reused across all compiled instances for performance)
	var tower_material : StandardMaterial3D = null
	var cap_material : StandardMaterial3D = null
	var neon_material : StandardMaterial3D = null
	var laser_material : StandardMaterial3D = null

	func _initialize_materials(level_neon_color: Color) -> void:
		# 1. Traditional Whitewashed Stone Tower (High contrast matte white/grey)
		tower_material = StandardMaterial3D.new()
		tower_material.albedo_color = Color(0.90, 0.90, 0.94) # Matte whitewashed stone
		tower_material.roughness = 0.85
		tower_material.metallic = 0.0
		
		# 2. Rotator Dome Cap (Satin Cyber-Copper/Bronze)
		cap_material = StandardMaterial3D.new()
		cap_material.albedo_color = Color(0.80, 0.42, 0.20) # Copper
		cap_material.roughness = 0.3
		cap_material.metallic = 0.85
		cap_material.clearcoat_enabled = true
		cap_material.clearcoat_roughness = 0.15
		
		# 3. Pulsing Neon Accent Rings (Matches the level's active wall theme color)
		neon_material = StandardMaterial3D.new()
		neon_material.albedo_color = level_neon_color
		neon_material.emission_enabled = true
		neon_material.emission = level_neon_color * 1.5 # Intense pulsing neon glow
		neon_material.roughness = 0.2
		
		# 4. Holographic Laser Blades (Emissive Laser Cyan)
		laser_material = StandardMaterial3D.new()
		laser_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		laser_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		laser_material.albedo_color = Color(0.0, 0.8, 1.0, 0.65) # Translucent cyan
		laser_material.emission_enabled = true
		laser_material.emission = Color(0.0, 0.70, 1.0) # High-energy cyan glow

	func build_decoration(parent_node: Node3D, pos: Vector3, rot_y: float) -> void:
		# Retrieve the active wall color dynamically from the LevelBuilder to sync neons
		var level_neon_color := Color(0.0, 0.8, 1.0) # Default cyan
		if "wall_material" in parent_node and parent_node.wall_material:
			level_neon_color = parent_node.wall_material.albedo_color
			
		# Initialize shared materials
		if not tower_material:
			_initialize_materials(level_neon_color)
			
		var windmill_root := Node3D.new()
		windmill_root.position = pos
		windmill_root.rotation_degrees.y = rot_y
		
		# 1. Spawn Monumental Stone Tower Post (Large conical base)
		var tower_mesh := CylinderMesh.new()
		tower_mesh.top_radius = 1.1
		tower_mesh.bottom_radius = 1.6
		tower_mesh.height = 6.5
		tower_mesh.radial_segments = 16
		
		var tower_inst := MeshInstance3D.new()
		tower_inst.mesh = tower_mesh
		tower_inst.material_override = tower_material
		tower_inst.position.y = 3.25 # Centered on floor offsets
		windmill_root.add_child(tower_inst)
		
		# 2. Spawn Pulsing Neon Accent Rings wrapping the tower body (Cyber-Details)
		var ring_heights : Array[float] = [1.2, 3.2, 5.2]
		var ring_radii : Array[float] = [1.45, 1.25, 1.15]
		
		var torus_geom := TorusMesh.new()
		torus_geom.inner_radius = 0.01
		torus_geom.outer_radius = 0.05
		
		for i in range(ring_heights.size()):
			var ring := MeshInstance3D.new()
			ring.mesh = torus_geom
			ring.material_override = neon_material
			ring.position = Vector3(0.0, ring_heights[i], 0.0)
			# Scale torus radius to snugly hug the conical tower walls
			var r_scale : float = ring_radii[i] / 0.05
			ring.scale = Vector3(r_scale, 1.0, r_scale)
			windmill_root.add_child(ring)
		
		# 3. Spawn Rotator Dome Cap (Satin copper sphere on top)
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 1.12
		cap_mesh.height = 1.35
		
		var cap_inst := MeshInstance3D.new()
		cap_inst.mesh = cap_mesh
		cap_inst.material_override = cap_material
		cap_inst.position = Vector3(0.0, 6.45, 0.0) # Sitting exactly on tower head
		windmill_root.add_child(cap_inst)
		
		# 4. Spawn Front Axle Gear (Axle connector)
		var axle_mesh := CylinderMesh.new()
		axle_mesh.top_radius = 0.28
		axle_mesh.bottom_radius = 0.28
		axle_mesh.height = 0.85
		axle_mesh.radial_segments = 10
		
		var axle_inst := MeshInstance3D.new()
		axle_inst.mesh = axle_mesh
		axle_inst.material_override = cap_material
		axle_inst.position = Vector3(0.0, 6.45, 0.72)
		axle_inst.rotation_degrees.x = 90.0 # Facing forward
		windmill_root.add_child(axle_inst)
		
		# 5. Instantiated Animated Blade Rotator (SOLID OOP Compliance)
		var blade_rotator := WindmillRotator.new()
		blade_rotator.position = Vector3(0.0, 6.45, 1.15) # Positioned on front gear axle
		windmill_root.add_child(blade_rotator)
		
		# 6. Compile the 4 GIGANTIC laser energy blades programmatically
		var blade_geometry := BoxMesh.new()
		blade_geometry.size = Vector3(0.35, 6.8, 0.04) # Giant laser energy sheets (Spread = 13.6 meters!)
		
		# Vertical Blades pair
		var vert_blades := MeshInstance3D.new()
		vert_blades.mesh = blade_geometry
		vert_blades.material_override = laser_material
		vert_blades.position = Vector3.ZERO
		blade_rotator.add_child(vert_blades)
		
		# Horizontal Blades pair (rotated 90 degrees)
		var horiz_blades := MeshInstance3D.new()
		horiz_blades.mesh = blade_geometry
		horiz_blades.material_override = laser_material
		horiz_blades.position = Vector3.ZERO
		horiz_blades.rotation_degrees.z = 90.0
		blade_rotator.add_child(horiz_blades)
		
		# Add the completed procedural assembly into the tree parent
		parent_node.add_child(windmill_root)


# ==============================================================================
# --- CONCRETE MONUMENTAL CYBER-TAULA STRATEGY (CIBER-TAULA MEGALÍTICA) ---
# ==============================================================================
class CyberTaula extends BaseDecorationStrategy:
	# Shared structural materials (reused across all compiled instances for performance)
	var stone_material : StandardMaterial3D = null
	var circuit_material : StandardMaterial3D = null

	func _initialize_materials() -> void:
		# 1. Monolithic Stone Material (Dark rough volcanic basalt)
		stone_material = StandardMaterial3D.new()
		stone_material.albedo_color = Color(0.12, 0.12, 0.14) 
		stone_material.roughness = 0.9
		stone_material.metallic = 0.05
		
		# 2. Glowing Circuit Material (High-contrast Neon Magenta)
		circuit_material = StandardMaterial3D.new()
		circuit_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		circuit_material.albedo_color = Color(1.0, 0.0, 0.6) # Intense Magenta
		circuit_material.emission_enabled = true
		circuit_material.emission = Color(1.0, 0.0, 0.5) * 1.6

	func build_decoration(parent_node: Node3D, pos: Vector3, rot_y: float) -> void:
		# Initialize shared materials
		if not stone_material:
			_initialize_materials()
			
		var taula_root := Node3D.new()
		taula_root.position = pos
		taula_root.rotation_degrees.y = rot_y
		
		# A. Vertical Stone Pillar (Soporte de piedra de 5 metros de alto)
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(1.25, 5.0, 0.45)
		
		var pillar_inst := MeshInstance3D.new()
		pillar_inst.mesh = pillar_mesh
		pillar_inst.material_override = stone_material
		pillar_inst.position.y = 2.5 # Centered vertically
		taula_root.add_child(pillar_inst)
		
		# B. Horizontal Cap Stone (Capitel de piedra en "T")
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(2.45, 0.55, 1.35)
		
		var cap_inst := MeshInstance3D.new()
		cap_inst.mesh = cap_mesh
		cap_inst.material_override = stone_material
		cap_inst.position = Vector3(0.0, 5.2, 0.0) # Sitting exactly on top of the vertical pillar
		taula_root.add_child(cap_inst)
		
		# C. Procedural Neon Data-Conduits (Holographic circuit tracks on stone faces)
		var circuit_mesh := BoxMesh.new()
		circuit_mesh.size = Vector3(0.025, 4.4, 0.015) # Thin glowing circuit trace
		
		# Left Vertical Neon Trace
		var left_trace := MeshInstance3D.new()
		left_trace.mesh = circuit_mesh
		left_trace.material_override = circuit_material
		left_trace.position = Vector3(-0.35, 2.2, 0.23) # Slightly offset forward to sit on front surface
		taula_root.add_child(left_trace)
		
		# Right Vertical Neon Trace
		var right_trace := MeshInstance3D.new()
		right_trace.mesh = circuit_mesh
		right_trace.material_override = circuit_material
		right_trace.position = Vector3(0.35, 2.2, 0.23)
		taula_root.add_child(right_trace)
		
		# Connecting Horizontal Neon Data-Bus Trace
		var bus_mesh := BoxMesh.new()
		bus_mesh.size = Vector3(0.725, 0.025, 0.015)
		
		var bus_trace := MeshInstance3D.new()
		bus_trace.mesh = bus_mesh
		bus_trace.material_override = circuit_material
		bus_trace.position = Vector3(0.0, 3.8, 0.235)
		taula_root.add_child(bus_trace)
		
		# Add the completed prehistoric cyber-shrine assembly into the tree parent
		parent_node.add_child(taula_root)


# ==============================================================================
# --- LIGHTWEIGHT PROCEDURAL ROTATOR COMPONENT (SOLID SRP Compliance) ---
# ==============================================================================
class WindmillRotator extends Node3D:
	# Continuous rotation speed on Z axis (expressed in radians per second)
	var rotation_speed : float = 1.15 
	
	func _ready() -> void:
		# Process even during pause states so environment looks alive
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		rotate_z(rotation_speed * delta)

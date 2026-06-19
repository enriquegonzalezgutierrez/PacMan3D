# ==============================================================================
# Description: Wall Style Rendering Strategies.
#              SOLID Refactoring:
#              - OCP Compliance: Implements the Strategy Pattern for different 
#                architectural styles (pipes, blocks, pillars, circuits). 
#                Uses nested classes (inner classes) to bypass Godot 4's 
#                single-class-per-file parser limitation.
#              - Resource Optimization: Implements lazy-loaded caching for primitive 
#                geometry meshes and local materials to eliminate redundant 
#                resource allocations during level grid generation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name WallStyleStrategy

# Virtual method to be overridden by concrete wall style strategies
func build_mesh(_static_body: StaticBody3D, _x: int, _z: int, _cell_size: float, _wall_height: float, _wall_material: StandardMaterial3D, _level_data: Dictionary) -> void:
	pass


# ==============================================================================
# --- BLOCKS WALL STYLE ---
# ==============================================================================
class Blocks extends WallStyleStrategy:
	# Cached mesh resource to share across all blocks
	var cached_mesh : BoxMesh = null

	func build_mesh(static_body: StaticBody3D, _x: int, _z: int, cell_size: float, wall_height: float, wall_material: StandardMaterial3D, _level_data: Dictionary) -> void:
		# Lazy initialization: instantiate only on the first block generation
		if not cached_mesh:
			cached_mesh = BoxMesh.new()
			cached_mesh.size = Vector3(cell_size, wall_height, cell_size)
			
		var block_instance := MeshInstance3D.new()
		block_instance.mesh = cached_mesh
		block_instance.material_override = wall_material
		block_instance.position.y = wall_height / 2.0
		static_body.add_child(block_instance)


# ==============================================================================
# --- PILLARS WALL STYLE ---
# ==============================================================================
class Pillars extends WallStyleStrategy:
	# Cached geometries and materials shared across all pillar elements
	var cached_cylinder : CylinderMesh = null
	var cached_sphere : SphereMesh = null
	var cached_glow_material : StandardMaterial3D = null

	func build_mesh(static_body: StaticBody3D, _x: int, _z: int, _cell_size: float, wall_height: float, wall_material: StandardMaterial3D, _level_data: Dictionary) -> void:
		# Lazy initialization of shared cylinder pillar post
		if not cached_cylinder:
			cached_cylinder = CylinderMesh.new()
			cached_cylinder.top_radius = 0.4
			cached_cylinder.bottom_radius = 0.4
			cached_cylinder.height = wall_height
			cached_cylinder.radial_segments = 12
			
		var pillar_instance := MeshInstance3D.new()
		pillar_instance.mesh = cached_cylinder
		pillar_instance.material_override = wall_material
		pillar_instance.position.y = wall_height / 2.0
		static_body.add_child(pillar_instance)
		
		# Lazy initialization of shared floating cap sphere
		if not cached_sphere:
			cached_sphere = SphereMesh.new()
			cached_sphere.radius = 0.55
			cached_sphere.height = 1.1
			
		# Lazy initialization of glowing cap material (aligned with active wall color)
		if not cached_glow_material:
			cached_glow_material = StandardMaterial3D.new()
			cached_glow_material.albedo_color = wall_material.albedo_color
			cached_glow_material.emission_enabled = true
			cached_glow_material.emission = wall_material.albedo_color * 0.65 
		elif cached_glow_material.albedo_color != wall_material.albedo_color:
			# Safety sync in case level color changes dynamically
			cached_glow_material.albedo_color = wall_material.albedo_color
			cached_glow_material.emission = wall_material.albedo_color * 0.65
		
		var sphere_instance := MeshInstance3D.new()
		sphere_instance.mesh = cached_sphere
		sphere_instance.material_override = cached_glow_material
		sphere_instance.position.y = wall_height
		static_body.add_child(sphere_instance)


# ==============================================================================
# --- CIRCUITS WALL STYLE ---
# ==============================================================================
class Circuits extends WallStyleStrategy:
	# Cached circuit elements to prevent redundant sub-mesh heap allocation
	var cached_base_mesh : BoxMesh = null
	var cached_dark_material : StandardMaterial3D = null
	var cached_track_mesh : BoxMesh = null
	var cached_track_material : StandardMaterial3D = null
	var cached_node_mesh : BoxMesh = null

	func build_mesh(static_body: StaticBody3D, _x: int, _z: int, cell_size: float, wall_height: float, wall_material: StandardMaterial3D, _level_data: Dictionary) -> void:
		# 1. Base dark carbon blocks cache
		if not cached_base_mesh:
			cached_base_mesh = BoxMesh.new()
			cached_base_mesh.size = Vector3(cell_size, wall_height, cell_size)
			
		if not cached_dark_material:
			cached_dark_material = StandardMaterial3D.new()
			cached_dark_material.albedo_color = Color(0.04, 0.04, 0.06) 
			cached_dark_material.roughness = 0.8
			cached_dark_material.metallic = 0.3
		
		var base_instance := MeshInstance3D.new()
		base_instance.mesh = cached_base_mesh
		base_instance.material_override = cached_dark_material
		base_instance.position.y = wall_height / 2.0
		static_body.add_child(base_instance)
		
		# 2. Holographic circuit tracks cache
		if not cached_track_mesh:
			cached_track_mesh = BoxMesh.new()
			cached_track_mesh.size = Vector3(cell_size + 0.03, 0.08, cell_size + 0.03) 
			
		if not cached_track_material:
			cached_track_material = StandardMaterial3D.new()
			cached_track_material.albedo_color = wall_material.albedo_color
			cached_track_material.emission_enabled = true
			cached_track_material.emission = wall_material.albedo_color * 0.8 
			cached_track_material.roughness = 0.1
		elif cached_track_material.albedo_color != wall_material.albedo_color:
			# Safety sync in case level color changes dynamically
			cached_track_material.albedo_color = wall_material.albedo_color
			cached_track_material.emission = wall_material.albedo_color * 0.8
		
		var horiz_line := MeshInstance3D.new()
		horiz_line.mesh = cached_track_mesh
		horiz_line.material_override = cached_track_material
		horiz_line.position.y = wall_height * 0.65 
		static_body.add_child(horiz_line)
		
		# 3. Micro-conduit nodes cache
		if not cached_node_mesh:
			cached_node_mesh = BoxMesh.new()
			cached_node_mesh.size = Vector3(0.08, wall_height + 0.02, 0.08) 
		
		var corner_offsets : Array[Vector3] = [
			Vector3(-cell_size/2.0, wall_height/2.0, -cell_size/2.0),
			Vector3(cell_size/2.0, wall_height/2.0, -cell_size/2.0),
			Vector3(-cell_size/2.0, wall_height/2.0, cell_size/2.0),
			Vector3(cell_size/2.0, wall_height/2.0, cell_size/2.0)
		]
		
		for offset in corner_offsets:
			var node_line := MeshInstance3D.new()
			node_line.mesh = cached_node_mesh
			node_line.material_override = cached_track_material
			node_line.position = offset
			static_body.add_child(node_line)


# ==============================================================================
# --- PIPES WALL STYLE ---
# ==============================================================================
class Pipes extends WallStyleStrategy:
	# Cached cylinder pipes to share among all modules
	var cached_pipe_mesh : CylinderMesh = null

	func build_mesh(static_body: StaticBody3D, x: int, z: int, cell_size: float, _wall_height: float, wall_material: StandardMaterial3D, level_data: Dictionary) -> void:
		var has_horizontal : bool = false
		var has_vertical : bool = false
		
		var layout : Array = level_data.get("layout", [])
		var width : int = int(level_data.get("grid_width", 0))
		var height : int = int(level_data.get("grid_height", 0))
		
		if x > 0 and int(layout[z][x - 1]) == 1: has_horizontal = true
		if x < width - 1 and int(layout[z][x + 1]) == 1: has_horizontal = true
		
		if z > 0 and int(layout[z - 1][x]) == 1: has_vertical = true
		if z < height - 1 and int(layout[z + 1][x]) == 1: has_vertical = true
		
		if not has_horizontal and not has_vertical:
			has_horizontal = true
			has_vertical = true
			
		# Lazy initialization of pipe geometry
		if not cached_pipe_mesh:
			cached_pipe_mesh = CylinderMesh.new()
			cached_pipe_mesh.top_radius = 0.18 
			cached_pipe_mesh.bottom_radius = 0.18
			cached_pipe_mesh.height = cell_size 
			cached_pipe_mesh.radial_segments = 12 
		
		var create_pipe = func(offset_y: float, is_horiz: bool) -> MeshInstance3D:
			var pipe_node := MeshInstance3D.new()
			pipe_node.mesh = cached_pipe_mesh
			pipe_node.material_override = wall_material
			pipe_node.position.y = offset_y
			
			if is_horiz:
				pipe_node.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			else:
				pipe_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)
				
			return pipe_node
			
		if has_horizontal:
			static_body.add_child(create_pipe.call(0.5, true))
			static_body.add_child(create_pipe.call(1.5, true))
			
		if has_vertical:
			static_body.add_child(create_pipe.call(0.5, false))
			static_body.add_child(create_pipe.call(1.5, false))

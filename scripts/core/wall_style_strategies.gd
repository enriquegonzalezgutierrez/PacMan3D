# ==============================================================================
# Description: Wall Style Rendering Strategies.
#              SOLID Refactoring:
#              - OCP Compliance: Implements the Strategy Pattern for different 
#                architectural styles (pipes, blocks, pillars, circuits). 
#                Uses nested classes (inner classes) to bypass Godot 4's 
#                single-class-per-file parser limitation.
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
	func build_mesh(static_body: StaticBody3D, _x: int, _z: int, cell_size: float, wall_height: float, wall_material: StandardMaterial3D, _level_data: Dictionary) -> void:
		var block_mesh := BoxMesh.new()
		block_mesh.size = Vector3(cell_size, wall_height, cell_size)
		
		var block_instance := MeshInstance3D.new()
		block_instance.mesh = block_mesh
		block_instance.material_override = wall_material
		block_instance.position.y = wall_height / 2.0
		static_body.add_child(block_instance)


# ==============================================================================
# --- PILLARS WALL STYLE ---
# ==============================================================================
class Pillars extends WallStyleStrategy:
	# Resolved Warning: Prefixed cell_size with underscore since it's constant-sized
	func build_mesh(static_body: StaticBody3D, _x: int, _z: int, _cell_size: float, wall_height: float, wall_material: StandardMaterial3D, _level_data: Dictionary) -> void:
		var cylinder_mesh := CylinderMesh.new()
		cylinder_mesh.top_radius = 0.4
		cylinder_mesh.bottom_radius = 0.4
		cylinder_mesh.height = wall_height
		cylinder_mesh.radial_segments = 12
		
		var pillar_instance := MeshInstance3D.new()
		pillar_instance.mesh = cylinder_mesh
		pillar_instance.material_override = wall_material
		pillar_instance.position.y = wall_height / 2.0
		static_body.add_child(pillar_instance)
		
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.55
		sphere_mesh.height = 1.1
		
		var glowing_material := StandardMaterial3D.new()
		glowing_material.albedo_color = wall_material.albedo_color
		glowing_material.emission_enabled = true
		glowing_material.emission = wall_material.albedo_color * 0.65 
		
		var sphere_instance := MeshInstance3D.new()
		sphere_instance.mesh = sphere_mesh
		sphere_instance.material_override = glowing_material
		sphere_instance.position.y = wall_height
		static_body.add_child(sphere_instance)


# ==============================================================================
# --- CIRCUITS WALL STYLE ---
# ==============================================================================
class Circuits extends WallStyleStrategy:
	func build_mesh(static_body: StaticBody3D, _x: int, _z: int, cell_size: float, wall_height: float, wall_material: StandardMaterial3D, _level_data: Dictionary) -> void:
		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(cell_size, wall_height, cell_size)
		
		var dark_mat := StandardMaterial3D.new()
		dark_mat.albedo_color = Color(0.04, 0.04, 0.06) 
		dark_mat.roughness = 0.8
		dark_mat.metallic = 0.3
		
		var base_instance := MeshInstance3D.new()
		base_instance.mesh = base_mesh
		base_instance.material_override = dark_mat
		base_instance.position.y = wall_height / 2.0
		static_body.add_child(base_instance)
		
		var track_mat := StandardMaterial3D.new()
		track_mat.albedo_color = wall_material.albedo_color
		track_mat.emission_enabled = true
		track_mat.emission = wall_material.albedo_color * 0.8 
		track_mat.roughness = 0.1
		
		var horiz_mesh := BoxMesh.new()
		horiz_mesh.size = Vector3(cell_size + 0.03, 0.08, cell_size + 0.03) 
		
		var horiz_line := MeshInstance3D.new()
		horiz_line.mesh = horiz_mesh
		horiz_line.material_override = track_mat
		horiz_line.position.y = wall_height * 0.65 
		static_body.add_child(horiz_line)
		
		var node_mesh := BoxMesh.new()
		node_mesh.size = Vector3(0.08, wall_height + 0.02, 0.08) 
		
		var corner_offsets : Array[Vector3] = [
			Vector3(-cell_size/2.0, wall_height/2.0, -cell_size/2.0),
			Vector3(cell_size/2.0, wall_height/2.0, -cell_size/2.0),
			Vector3(-cell_size/2.0, wall_height/2.0, cell_size/2.0),
			Vector3(cell_size/2.0, wall_height/2.0, cell_size/2.0)
		]
		
		for offset in corner_offsets:
			var node_line := MeshInstance3D.new()
			node_line.mesh = node_mesh
			node_line.material_override = track_mat
			node_line.position = offset
			static_body.add_child(node_line)


# ==============================================================================
# --- PIPES WALL STYLE ---
# ==============================================================================
class Pipes extends WallStyleStrategy:
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
			
		var pipe_mesh := CylinderMesh.new()
		pipe_mesh.top_radius = 0.18 
		pipe_mesh.bottom_radius = 0.18
		pipe_mesh.height = cell_size 
		pipe_mesh.radial_segments = 12 
		
		var create_pipe = func(offset_y: float, is_horiz: bool) -> MeshInstance3D:
			var pipe_node := MeshInstance3D.new()
			pipe_node.mesh = pipe_mesh
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

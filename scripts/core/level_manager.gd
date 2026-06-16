# ==============================================================================
# Description: Parses the level JSON file, feeds the layout data to the global
#              GameManager, and generates the 3D grid with a perfect PlaneMesh floor.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node3D
class_name LevelManager

const CELL_SIZE : float = 2.0
const WALL_HEIGHT : float = 2.0

var wall_material : StandardMaterial3D
var floor_material : StandardMaterial3D
var ghost_types : Array[String] = ["Blinky", "Pinky", "Inky", "Clyde"]
var spawned_ghosts_count : int = 0

var level_data : Dictionary = {}
var map_offset_x : float = 0.0
var map_offset_z : float = 0.0

func _ready() -> void:
	_initialize_materials()
	if _load_level_data("res://data/level_01.json"):
		_build_environment()

func _initialize_materials() -> void:
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.0, 0.0, 1.0) 
	
	floor_material = StandardMaterial3D.new()
	floor_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	floor_material.albedo_color = Color(0.3, 0.3, 0.3) 

func _load_level_data(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
		
	var file := FileAccess.open(file_path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(content)
	
	if error == OK:
		level_data = json.data
		var layout : Array = level_data.get("layout", [])
		if GameManager:
			GameManager.level_layout = layout
			GameManager.grid_width = int(level_data.get("grid_width", 0))
			GameManager.grid_height = int(level_data.get("grid_height", 0))
		var width : float = float(level_data.get("grid_width", 0))
		var height : float = float(level_data.get("grid_height", 0))
		map_offset_x = (width * CELL_SIZE) / 2.0
		map_offset_z = (height * CELL_SIZE) / 2.0
		return true
	return false

func _build_environment() -> void:
	var layout : Array = level_data.get("layout", [])
	for z in range(layout.size()):
		var row : Array = layout[z]
		for x in range(row.size()):
			var cell_type : int = int(row[x])
			var pos_x : float = (x * CELL_SIZE) - map_offset_x + (CELL_SIZE / 2.0)
			var pos_z : float = (z * CELL_SIZE) - map_offset_z + (CELL_SIZE / 2.0)
			var world_pos := Vector3(pos_x, 0.0, pos_z)
			
			match cell_type:
				1: _create_wall(world_pos)
				2: _create_pellet(world_pos, false)
				3: _create_pellet(world_pos, true)
				4: _spawn_player(world_pos)
				5: _spawn_ghost(world_pos)
				6: _create_portal(world_pos, "Portal_A", "Portal_B")
				7: _create_portal(world_pos, "Portal_B", "Portal_A")
	_create_floor()

func _create_wall(pos: Vector3) -> void:
	var static_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = wall_material
	var box_shape := BoxShape3D.new()
	box_shape.size = box_mesh.size
	collision_shape.shape = box_shape
	static_body.add_child(mesh_instance)
	static_body.add_child(collision_shape)
	static_body.position = pos
	static_body.position.y = WALL_HEIGHT / 2.0 
	add_child(static_body)

func _create_pellet(pos: Vector3, is_power: bool) -> void:
	var pellet := Pellet.new()
	pellet.is_power_pellet = is_power
	pellet.position = pos
	pellet.position.y = 0.5
	add_child(pellet)

func _spawn_player(pos: Vector3) -> void:
	var player := Player.new()
	player.spawn_position = pos
	player.position = pos
	player.position.y = 0.8
	add_child(player)

func _spawn_ghost(pos: Vector3) -> void:
	var ghost := Ghost.new()
	var type_index : int = spawned_ghosts_count % ghost_types.size()
	ghost.ghost_type = ghost_types[type_index]
	spawned_ghosts_count += 1
	ghost.position = pos
	ghost.position.y = 0.8
	add_child(ghost)

func _create_portal(pos: Vector3, my_name: String, partner_name: String) -> void:
	var portal := Portal.new()
	portal.name = my_name
	portal.partner_portal_name = partner_name
	portal.position = pos
	portal.position.y = 0.8
	add_child(portal)

func _create_floor() -> void:
	var width : float = float(level_data.get("grid_width", 0)) * CELL_SIZE
	var height : float = float(level_data.get("grid_height", 0)) * CELL_SIZE
	var static_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(width, height)
	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = floor_material
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(width, 0.1, height)
	collision_shape.shape = floor_shape
	static_body.add_child(mesh_instance)
	static_body.add_child(collision_shape)
	static_body.position = Vector3(0.0, 0.0, 0.0)
	collision_shape.position.y = -0.05
	add_child(static_body)

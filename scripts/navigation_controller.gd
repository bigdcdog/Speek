extends Node3D

@export var grid_origin := Vector3.ZERO

var astar = AStar3D.new()
var cell_size := 0.1
var grid_size := Vector3i(100, 20, 100)
var collision_radius := 0.8

func generate_grid() -> void:
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			for z in range(grid_size.z):
				var id = astar.get_available_point_id()
				var point_position = grid_origin + Vector3(x, y, z) * cell_size
				
				astar.add_point(id, point_position)
				if is_position_blocked(point_position):
					astar.set_point_disabled(id, true)

func connect_grid() -> void:
	for id in astar.get_point_ids():
		var point_position = astar.get_point_position(id)

		for offset in [
			Vector3i(1, 0, 0),
			Vector3i(-1, 0, 0),
			Vector3i(0, 1, 0),
			Vector3i(0, -1, 0),
			Vector3i(0, 0, 1),
			Vector3i(0, 0, -1)
		]:
			var neighbour_position = point_position + Vector3(offset) * cell_size
			var neighbour_id = astar.get_closest_point(neighbour_position)

			if neighbour_id != id and astar.get_point_position(neighbour_id).is_equal_approx(neighbour_position):
				if not astar.are_points_connected(id, neighbour_id):
					astar.connect_points(id, neighbour_id)

func calculate_path(start: Vector3, target: Vector3) -> PackedVector3Array:
	var start_id = astar.get_closest_point(start)
	var target_id = astar.get_closest_point(target)
	
	var result = astar.get_point_path(start_id, target_id)
	result.append(target)
	
	return result

func is_position_blocked(point_position: Vector3) -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()

	shape.radius = collision_radius
	query.shape = shape
	query.transform.origin = point_position

	var space_state = get_world_3d().direct_space_state
	var results = space_state.intersect_shape(query)

	return not results.is_empty()

func _ready() -> void:
	generate_grid()
	connect_grid()
	print("Grid generated: ", astar.get_point_count())

func _process(_delta: float) -> void:
	var path = calculate_path(
		Vector3(0, 0, 0),
		Vector3(10, 10, 10)
	)

	print(path)
	set_process(false)

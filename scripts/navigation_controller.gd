
class_name NavigationController
extends Node3D

signal grid_ready

@export var grid_origin := Vector3.ZERO
@export var cell_size := 2.0
@export var grid_size := Vector3i(20, 20, 20)
@export var collision_radius := 0.8

# Set this to the physics layer used by your environment geometry.
@export_flags_3d_physics var obstacle_collision_mask := 1

var astar := AStar3D.new()
var point_ids: Dictionary = {}

var is_ready := false


func _ready() -> void:
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if is_ready:
		return

	generate_grid()
	connect_grid()

	is_ready = true
	set_physics_process(false)

	print("Navigation grid generated: ", astar.get_point_count())

	grid_ready.emit()


func generate_grid() -> void:
	astar.clear()
	point_ids.clear()

	var total_points := grid_size.x * grid_size.y * grid_size.z
	astar.reserve_space(total_points)

	for x in range(grid_size.x):
		for y in range(grid_size.y):
			for z in range(grid_size.z):
				var cell := Vector3i(x, y, z)
				var point_position := grid_origin + Vector3(cell) * cell_size

				var id := astar.get_available_point_id()

				astar.add_point(id, point_position)
				point_ids[cell] = id

				if is_position_blocked(point_position):
					astar.set_point_disabled(id)


func connect_grid() -> void:
	var offsets := [
		Vector3i(1, 0, 0),
		Vector3i(0, 1, 0),
		Vector3i(0, 0, 1)
	]

	for cell_variant in point_ids:
		var cell: Vector3i = cell_variant
		var point_id: int = point_ids[cell]

		if astar.is_point_disabled(point_id):
			continue

		for offset in offsets:
			var neighbour_cell: Vector3i = cell + offset

			if not point_ids.has(neighbour_cell):
				continue

			var neighbour_id: int = point_ids[neighbour_cell]

			if astar.is_point_disabled(neighbour_id):
				continue

			astar.connect_points(point_id, neighbour_id)


func calculate_path(start_position: Vector3, target_position: Vector3) -> PackedVector3Array:
	var empty_path := PackedVector3Array()

	if not is_ready:
		return empty_path

	if astar.get_point_count() == 0:
		return empty_path

	var start_id := astar.get_closest_point(start_position)
	var target_id := astar.get_closest_point(target_position)

	if start_id == -1 or target_id == -1:
		return empty_path

	var result := astar.get_point_path(start_id, target_id)

	if result.is_empty():
		return empty_path

	if not result[result.size() - 1].is_equal_approx(target_position):
		result.append(target_position)

	return result


func is_position_blocked(point_position: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = collision_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point_position)
	query.collision_mask = obstacle_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var space_state := get_world_3d().direct_space_state
	var results := space_state.intersect_shape(query, 1)

	return not results.is_empty()

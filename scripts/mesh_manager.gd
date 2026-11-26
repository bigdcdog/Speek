extends Node3D

const CORNER_OFFSETS = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1)]
const TETRAHEDRA_A = [[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6], [0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]]
const TETRAHEDRA_B = [[1, 4, 0, 7], [1, 0, 3, 7], [1, 3, 2, 7], [1, 2, 6, 7], [1, 6, 5, 7], [1, 5, 4, 7]]

@onready var chunk_manager: Node3D = $".."
@onready var camera_holder: SpringArm3D = $"../target/camera_holder"
@onready var camera: Camera3D = $"../target/camera_holder/camera"
@onready var meta_mesh: MeshInstance3D = $mesh

@export_category("chunk visuals")

@export_group("Grid")
@export_range(0.05, 2.0, 0.05) var spacing := 0.5
@export_range(1.0, 100.0, 0.5) var x_length := 10.0
@export_range(1.0, 100.0, 0.5) var y_length := 10.0
@export_range(1.0, 100.0, 0.5) var z_length := 10.0

@export_group("Metaball")
@export_range(0.01, 100.0, 0.01) var meta_ball_density := 2.5

@export_range(0.01, 10.0, 0.01) var radius := 0.2

@export_group("Performance")
@export_range(0.01, 2.0, 0.01) var timer_interval := 0.1
@export_range(1000, 1000000, 1000) var max_grid_points := 250000

var vertices: PackedVector3Array = PackedVector3Array()
var indices: PackedInt32Array = PackedInt32Array()
var normals: PackedVector3Array = PackedVector3Array()
var vertex_keys: Array[int] = []

var timer := 0.0
const EPSILON := 0.000001

@export var mesh_lerp_speed := 12.0
var target_mesh_position := Vector3.ZERO

func get_density(point: Vector3, chunk_positions: PackedVector3Array) -> float:
	var density := 0.0
	var radius_squared := radius * radius
	
	for chunk_position in chunk_positions:
		var distance_squared := maxf(point.distance_squared_to(chunk_position), EPSILON)
		density += radius_squared / distance_squared
	return density

func get_density_normal(point: Vector3, chunk_positions: PackedVector3Array) -> Vector3:
	var normal := Vector3.ZERO
	var radius_squared := radius * radius
	
	for chunk_position in chunk_positions:
		var offset := point - chunk_position
		var distance_squared := maxf(offset.length_squared(), EPSILON)
		normal += offset * (radius_squared / (distance_squared * distance_squared))
	if normal.length_squared() < EPSILON:
		return Vector3.UP
	return normal.normalized()

func get_grid_index(x: int, y: int, z: int, points_x: int, points_y: int) -> int:
	return x + points_x * (y + points_y * z)

func generate_density_grid(grid_origin: Vector3, cells_x: int, cells_y: int, cells_z: int, chunk_positions: PackedVector3Array) -> PackedFloat32Array:
	var points_x := cells_x + 1
	var points_y := cells_y + 1
	var points_z := cells_z + 1
	var total_points := points_x * points_y * points_z
	var density_grid := PackedFloat32Array()
	
	density_grid.resize(total_points)
	for z in range(points_z):
		for y in range(points_y):
			for x in range(points_x):
				var point := grid_origin + Vector3(x * spacing, y * spacing, z * spacing)
				var index := get_grid_index(x, y, z, points_x, points_y)
				density_grid[index] = get_density(point, chunk_positions)
	return density_grid

func get_edge_vertex(local_a: int, local_b: int, tetra_ids: Array[int], tetra_values: Array[float], tetra_positions: Array[Vector3], total_grid_points: int, chunk_positions: PackedVector3Array, edge_cache: Dictionary) -> int:
	var id_a := tetra_ids[local_a]
	var id_b := tetra_ids[local_b]
	var cache_key := mini(id_a, id_b) * total_grid_points + maxi(id_a, id_b)
	if edge_cache.has(cache_key):
		return edge_cache[cache_key]
	var value_a := tetra_values[local_a]
	var value_b := tetra_values[local_b]
	var denominator := value_b - value_a
	var interpolation := 0.5
	if absf(denominator) > EPSILON:
		interpolation = clampf((meta_ball_density - value_a) / denominator, 0.0, 1.0)
	var world_position := tetra_positions[local_a].lerp(tetra_positions[local_b], interpolation)
	var local_position := world_position - meta_mesh.global_position
	var world_normal := get_density_normal(world_position, chunk_positions)
	var local_normal := (meta_mesh.global_transform.basis.transposed() * world_normal).normalized()
	var vertex_index := vertices.size()
	vertices.append(local_position)
	normals.append(local_normal)
	edge_cache[cache_key] = vertex_index
	return vertex_index

func add_triangle(a: int, b: int, c: int) -> void:
	var face_normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
	if face_normal.length_squared() < EPSILON:
		return
	var outward_normal := (normals[a] + normals[b] + normals[c]).normalized()
	if face_normal.dot(outward_normal) > 0.0:
		var temporary := b
		b = c
		c = temporary
	indices.append(a)
	indices.append(b)
	indices.append(c)

func polygonise_tetrahedron(tetra_ids: Array[int], tetra_values: Array[float], tetra_positions: Array[Vector3], total_grid_points: int, chunk_positions: PackedVector3Array, edge_cache: Dictionary) -> void:
	var inside: Array[int] = []
	var outside: Array[int] = []
	for i in range(4):
		if tetra_values[i] >= meta_ball_density:
			inside.append(i)
		else:
			outside.append(i)
	if inside.is_empty() or outside.is_empty():
		return
	if inside.size() == 1:
		var a := get_edge_vertex(inside[0], outside[0], tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)
		var b := get_edge_vertex(inside[0], outside[1], tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)
		var c := get_edge_vertex(inside[0], outside[2], tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)
		add_triangle(a, b, c)
		return
	if inside.size() == 3:
		var a := get_edge_vertex(outside[0], inside[0], tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)
		var b := get_edge_vertex(outside[0], inside[1], tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)
		var c := get_edge_vertex(outside[0], inside[2], tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)
		add_triangle(a, b, c)
		return
	if inside.size() == 2:
		var p00 := get_edge_vertex(inside[0], outside[0], tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)
		var p01 := get_edge_vertex(inside[0], outside[1], tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)
		var p10 := get_edge_vertex(inside[1], outside[0], tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)
		var p11 := get_edge_vertex(inside[1], outside[1], tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)
		add_triangle(p00, p01, p11)
		add_triangle(p00, p11, p10)

func polygonise_grid(grid_origin: Vector3, cells_x: int, cells_y: int, cells_z: int, density_grid: PackedFloat32Array, chunk_positions: PackedVector3Array) -> void:
	var points_x := cells_x + 1
	var points_y := cells_y + 1
	var total_grid_points := density_grid.size()
	var edge_cache: Dictionary = {}
	for z in range(cells_z):
		for y in range(cells_y):
			for x in range(cells_x):
				var corner_ids: Array[int] = []
				var corner_values: Array[float] = []
				var corner_positions: Array[Vector3] = []
				var has_inside := false
				var has_outside := false
				for offset in CORNER_OFFSETS:
					var gx: int = x + offset.x
					var gy: int = y + offset.y
					var gz: int = z + offset.z
					var grid_id := get_grid_index(gx, gy, gz, points_x, points_y)
					var density := density_grid[grid_id]
					corner_ids.append(grid_id)
					corner_values.append(density)
					corner_positions.append(grid_origin + Vector3(gx * spacing, gy * spacing, gz * spacing))
					if density >= meta_ball_density:
						has_inside = true
					else:
						has_outside = true
				if not has_inside or not has_outside:
					continue
				var tetrahedra = TETRAHEDRA_A if x % 2 == 0 else TETRAHEDRA_B
				for tetra in tetrahedra:
					var tetra_ids: Array[int] = [corner_ids[tetra[0]], corner_ids[tetra[1]], corner_ids[tetra[2]], corner_ids[tetra[3]]]
					var tetra_values: Array[float] = [corner_values[tetra[0]], corner_values[tetra[1]], corner_values[tetra[2]], corner_values[tetra[3]]]
					var tetra_positions: Array[Vector3] = [corner_positions[tetra[0]], corner_positions[tetra[1]], corner_positions[tetra[2]], corner_positions[tetra[3]]]
					polygonise_tetrahedron(tetra_ids, tetra_values, tetra_positions, total_grid_points, chunk_positions, edge_cache)

func apply_mesh() -> void:
	if vertices.is_empty() or indices.is_empty():
		meta_mesh.mesh = null
		return
	if vertices.size() != normals.size():
		push_error("Metaball mesh: vertex and normal counts differ.")
		meta_mesh.mesh = null
		return
	if indices.size() % 3 != 0:
		push_error("Metaball mesh: index count is not divisible by 3.")
		meta_mesh.mesh = null
		return
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mesh.get_surface_count() > 0:
		meta_mesh.mesh = mesh
	else:
		meta_mesh.mesh = null

func rebuild_mesh(central_position: Vector3, chunk_positions: PackedVector3Array) -> void:
	vertices.clear()
	indices.clear()
	normals.clear()
	vertex_keys.clear()
	if chunk_positions.is_empty():
		meta_mesh.mesh = null
		return
	if spacing <= 0.0 or radius <= 0.0:
		push_warning("Metaball mesh: spacing and radius must be positive.")
		return
	var cells_x := int(ceil(x_length / spacing))
	var cells_y := int(ceil(y_length / spacing))
	var cells_z := int(ceil(z_length / spacing))
	var grid_origin := central_position - Vector3(x_length / 2.0, y_length / 2.0, z_length / 2.0)
	var total_grid_points := (cells_x + 1) * (cells_y + 1) * (cells_z + 1)
	if total_grid_points > max_grid_points:
		push_warning("Metaball grid exceeds max_grid_points. Increase spacing or the limit.")
		return
	var density_grid := generate_density_grid(grid_origin, cells_x, cells_y, cells_z, chunk_positions)
	polygonise_grid(grid_origin, cells_x, cells_y, cells_z, density_grid, chunk_positions)
	apply_mesh()

func _physics_process(delta: float) -> void:
	timer += delta
	if timer < timer_interval:
		return
	timer = 0.0
	var chunk_positions := PackedVector3Array()
	var chunk_average_position := Vector3.ZERO
	for chunk in chunk_manager.chunks:
		if is_instance_valid(chunk) and chunk is Node3D:
			chunk_positions.append(chunk.global_position)
			chunk_average_position += chunk.global_position
	chunk_average_position = chunk_average_position / chunk_positions.size()
	target_mesh_position = chunk_average_position
	meta_mesh.global_position = meta_mesh.global_position.lerp(target_mesh_position, 1.0 - exp(-mesh_lerp_speed * delta))
	rebuild_mesh(chunk_average_position, chunk_positions)

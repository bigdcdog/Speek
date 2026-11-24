
extends Node3D

@onready var target: CharacterBody3D = $target

const CHUNK_SCENE = preload("res://scenes/chunk.tscn")

@export var chunk_count := 100

@export var chunks_far := 20
@export var chunks_mid := 60
@export var chunk_mid_size := 20
@export var chunks_near := 20

@export var near_colour := Color.AQUAMARINE
@export var far_colour := Color.DARK_RED

@export var spawn_position := Vector3(3.0, 3.0, 3.0)
@export var spawn_spacing_multiplier := 2.05

@export var max_connections := 5
@export var link_create_multiplier := 3.0
@export var link_break_multiplier := 3.5
@export var topology_interval := 0.2

var chunks: Array = []
var topology_timer := 0.0


func spawn_chunk(spawn_at: Vector3, chunk_name: int) -> void:
	var chunk = CHUNK_SCENE.instantiate()
	chunk.name = "chunk %s" % chunk_name
	add_child(chunk)
	var side: int = int(ceil(pow(float(chunk_count), 1.0 / 3.0)))
	var grid_position: Vector3 = Vector3(
		chunk_name % side,
		(chunk_name / side) % side,
		chunk_name / (side * side)
	)
	var offset: Vector3 = (
		grid_position - Vector3.ONE * float(side - 1) * 0.5
	) * chunk.radius * spawn_spacing_multiplier
	chunk.position = spawn_at + offset
	chunks.append(chunk)

func update_mesh() -> void:
	if max_connections <= 0 or chunks.is_empty():
		return
	var reference_radius: float = chunks[0].radius
	var create_distance: float = reference_radius * link_create_multiplier
	var break_distance: float = reference_radius * link_break_multiplier
	for chunk in chunks:
		for link in chunk.links.duplicate():
			if not is_instance_valid(link):
				chunk.unlink_from(link)
				continue
			var distance: float = chunk.global_position.distance_to(
				link.global_position
			)
			if distance > break_distance:
				chunk.unlink_from(link)
	var degrees: Dictionary = {}
	for chunk in chunks:
		degrees[chunk] = chunk.links.size()
	var candidates: Array[Dictionary] = []
	for i in range(chunks.size()):
		for j in range(i + 1, chunks.size()):
			var a = chunks[i]
			var b = chunks[j]
			if a.links.has(b):
				continue
			var distance: float = a.global_position.distance_to(
				b.global_position
			)
			if distance <= create_distance:
				candidates.append({
					"a": a,
					"b": b,
					"distance": distance
				})
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a["distance"] < b["distance"]
	)
	for candidate in candidates:
		var a = candidate["a"]
		var b = candidate["b"]
		if degrees[a] >= max_connections:
			continue
		if degrees[b] >= max_connections:
			continue
		var rest_length: float = a.radius + b.radius
		a.link_to(b, rest_length)
		degrees[a] += 1
		degrees[b] += 1
	for chunk in chunks:
		chunk.bake_links()

func update_integrity() -> void:
	var values: Dictionary = {}
	for chunk in chunks:
		values[chunk] = chunk.wall_integrity
	for iteration in range(chunks.size()):
		var next_values: Dictionary = values.duplicate()
		for chunk in chunks:
			var strongest := 0
			for link in chunk.links:
				strongest = maxi(
					strongest,
					int(values.get(link, 0))
				)
			next_values[chunk] = maxi(
				chunk.wall_integrity,
				strongest - chunk.integrity_loss
			)
		values = next_values
	for chunk in chunks:
		chunk.integrity = int(values.get(chunk, 0))
		chunk.supported = chunk.integrity > 0
		chunk.supporting = chunk.wall_integrity > 0
	for chunk in chunks:
		chunk.chunk_supports.clear()
		for link in chunk.links:
			if link.integrity > 0:
				chunk.chunk_supports.append(link)

func assign_targets() -> void:
	chunks.sort_custom(
		func(a, b) -> bool:
			var distance_a: float = a.global_position.distance_squared_to(
				target.global_position
			)
			var distance_b: float = b.global_position.distance_squared_to(
				target.global_position
			)
			if is_equal_approx(distance_a, distance_b):
				return a.get_instance_id() < b.get_instance_id()
			return distance_a < distance_b
	)
	var near_end: int = mini(chunks_near, chunks.size())
	var mid_end: int = mini(chunks_near + chunks_mid, chunks.size())
	for chunk_num in range(chunks.size()):
		var chunk = chunks[chunk_num]
		chunk.rank = chunk_num
		if chunk_num >= mid_end:
			var target_index: int = int(
				float(chunk_num) / float(chunk_mid_size)
			)
			target_index = clampi(target_index, 0, chunk_num - 1)
			var destination = chunks[target_index]
			chunk.target_direction = chunk.global_position.direction_to(
				destination.global_position
			)
			chunk.target_distance = chunk.global_position.distance_to(
				destination.global_position
			)
			chunk.colour = far_colour
			chunk.group = chunk.Group.FAR
		elif chunk_num >= near_end:
			var target_index: int = int(float(chunk_num) / float(chunk_mid_size))
			target_index = clampi(target_index, 0, chunk_num - 1)
			var destination = chunks[target_index]
			chunk.target_direction = chunk.global_position.direction_to(destination.global_position)
			
			chunk.target_distance = chunk.global_position.distance_to(
				destination.global_position
			)
			
			chunk.colour = near_colour.lerp(
				far_colour,
				clampf(
					float(chunk_num) / maxf(float(chunks.size() - 1), 1.0),
					0.0,
					1.0
				)
			)
			
			chunk.group = chunk.Group.MID
		
		else:
			chunk.target_direction = chunk.global_position.direction_to(
				target.global_position
			)
			
			chunk.target_distance = chunk.global_position.distance_to(
				target.global_position
			)
			
			chunk.colour = near_colour
			chunk.group = chunk.Group.NEAR
		
		chunk.pick_base()


func _ready() -> void:
	if chunks_near + chunks_mid + chunks_far != chunk_count:
		push_error(
			"NEAR, MID and FAR counts must add up to chunk_count."
		)
		return
	
	if chunk_mid_size <= 0:
		push_error("chunk_mid_size must be greater than zero.")
		return

	for i in range(chunk_count):
		spawn_chunk(spawn_position, i)

	update_mesh()
	assign_targets()
	update_integrity()


func _physics_process(delta: float) -> void:
	topology_timer += delta
	
	if topology_timer >= topology_interval:
		topology_timer = 0.0
		update_mesh()
	
	assign_targets()
	update_integrity()

extends Node3D

@onready var target: CharacterBody3D = $target

const CHUNK_SCENE = preload("res://scenes/chunk.tscn")

@export_category("chunk_settings")

@export_group("chunk initialisation")
@export var chunk_count := 100
@export var spawn_position := Vector3(0.0, 1.0, 0.0)

@export_group("chunk group sizes")
@export var near_end := 20
@export var mid_end := 80
@export var chunk_mid_size := 20

@export_group("chunk visuals")
@export var near_colour := Color.hex(0xf1ecddff)
@export var far_colour := Color.hex(0x8b0000ff)
@export var chunk_radius = 0.2

@export_group("chunk links")
@export var max_connections := 5
@export var link_create_multiplier := 3.0
@export var link_break_multiplier := 3.0
@export var topology_interval := 0.2

var chunks: Array = []
var topology_timer := 0.0

func spawn_chunk(chunk_name: int) -> void:
	var chunk = CHUNK_SCENE.instantiate()
	chunk.name = "chunk %s" % chunk_name
	add_child(chunk)
	chunk.position = spawn_position
	chunk.collision.shape = chunk.collision.shape.duplicate()
	chunk.radius = chunk_radius
	chunk.collision.shape.radius = chunk_radius
	chunk.mesh.mesh.radius = chunk_radius
	chunk.mesh.mesh.height = chunk_radius * 2
	chunks.append(chunk)

func update_mesh() -> void:
	var create_distance: float = chunk_radius * link_create_multiplier
	var break_distance: float = chunk_radius * link_break_multiplier
	for chunk in chunks:
		for link in chunk.links.duplicate():
			if not is_instance_valid(link):
				chunk.unlink_from(link)
				continue
			var distance: float = chunk.global_position.distance_to(link.global_position)
			if distance > break_distance:
				chunk.unlink_from(link)
	var connections: Dictionary = {}
	for chunk in chunks:
		connections[chunk] = chunk.links.size()
	var candidates: Array[Dictionary] = []
	for i in range(chunks.size()):
		for j in range(i + 1, chunks.size()):
			var a = chunks[i]
			var b = chunks[j]
			if a.links.has(b):
				continue
			var distance: float = a.global_position.distance_to(b.global_position)
			if distance <= create_distance:
				candidates.append({"a": a,"b": b,"distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	for candidate in candidates:
		var a = candidate["a"]
		var b = candidate["b"]
		if connections[a] >= max_connections:
			continue
		if connections[b] >= max_connections:
			continue
		var rest_length: float = a.radius + b.radius
		a.link_to(b, rest_length)
		connections[a] += 1
		connections[b] += 1
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
				strongest = maxi(strongest,int(values.get(link, 0)))
			next_values[chunk] = maxi(chunk.wall_integrity,strongest - chunk.integrity_loss)
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
	chunks.sort_custom(func(a, b): return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position))
	for chunk_num in range(chunks.size()):
		var chunk = chunks[chunk_num]
		chunk.rank = chunk_num
		if chunk_num >= mid_end:
			var target_index: int = int(float(chunk_num) / float(chunk_mid_size))
			var target_chunk = chunks[target_index]
			chunk.target_direction = chunk.global_position.direction_to(target_chunk.global_position)
			chunk.target_distance = chunk.global_position.distance_to(target_chunk.global_position)
			chunk.colour = far_colour
			chunk.group = chunk.Group.FAR
		elif chunk_num >= near_end:
			var target_index: int = int(float(chunk_num) / float(chunk_mid_size))
			var target_chunk = chunks[target_index]
			chunk.target_direction = chunk.global_position.direction_to(target_chunk.global_position)
			chunk.target_distance = chunk.global_position.distance_to(target_chunk.global_position)
			chunk.colour = near_colour.lerp(far_colour,clampf(float(chunk_num) / maxf(float(chunks.size() - 1), 1.0), 0.0, 1.0))
			chunk.group = chunk.Group.MID
		else:
			chunk.target_direction = chunk.global_position.direction_to(target.global_position)
			chunk.target_distance = chunk.global_position.distance_to(target.global_position)
			chunk.colour = near_colour
			chunk.group = chunk.Group.NEAR
		chunk.pick_base()

func _ready() -> void:
	for i in range(chunk_count):
		spawn_chunk(i)
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

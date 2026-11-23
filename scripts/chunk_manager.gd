extends Node3D

@onready var target: CharacterBody3D = $target

const CHUNK_SCENE = preload("res://scenes/chunk.tscn")

@export var chunk_count := 100

@export var chunks_far := 10
@export var chunks_mid := 80
@export var chunk_mid_size : = 10
@export var chunks_near := 10

@export var near_colour := Color.AQUAMARINE
@export var far_colour := Color.DARK_RED

@export var spawn_position := Vector3(3.0, 3.0, 3.0)

var chunks: Array = []

func spawn_chunk(spawn_at: Vector3, chunk_name: int) -> void:
	var chunk := CHUNK_SCENE.instantiate()
	
	chunk.position = spawn_at
	chunk.name = "chunk %s" % chunk_name
	
	add_child(chunk)
	chunks.append(chunk)

func _ready() -> void:
	for i in range(chunk_count):
		spawn_chunk(spawn_position, i)

func _physics_process(_delta: float) -> void:
	chunks.sort_custom(func(a, b): return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position))
	
	for chunk_num in chunks.size():
		if chunk_num >= chunks_near + chunks_mid:#far
			chunks[chunk_num].target_direction = chunks[chunk_num].global_position.direction_to(chunks[int(float(chunk_num) / chunk_mid_size)].global_position)
			chunks[chunk_num].target_distance = chunks[chunk_num].global_position.distance_squared_to(chunks[int(float(chunk_num) / chunk_mid_size)].global_position)
			chunks[chunk_num].colour = far_colour
			chunks[chunk_num].group = chunks[chunk_num].Group.FAR
		elif chunk_num >= chunks_near:#mid
			chunks[chunk_num].target_direction = chunks[chunk_num].global_position.direction_to(chunks[int(float(chunk_num) / chunk_mid_size)].global_position)
			chunks[chunk_num].target_distance = chunks[chunk_num].global_position.distance_squared_to(chunks[int(float(chunk_num) / chunk_mid_size)].global_position)
			chunks[chunk_num].colour = near_colour.lerp(far_colour, clamp(float(chunk_num) / (chunks.size() - 1), 0.0, 1.0))
			chunks[chunk_num].group = chunks[chunk_num].Group.MID
		else:#near
			chunks[chunk_num].target_direction = chunks[chunk_num].global_position.direction_to(target.global_position)
			chunks[chunk_num].target_distance = chunks[chunk_num].global_position.distance_squared_to(target.global_position)
			chunks[chunk_num].colour = near_colour
			chunks[chunk_num].group = chunks[chunk_num].Group.NEAR

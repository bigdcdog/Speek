extends Node3D

@onready var target: CharacterBody3D = $target

const CHUNK_SCENE = preload("res://scenes/chunk.tscn")

@export var chunk_count := 100
@export var chunk_size := 500
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
		chunks[chunk_num].target_position = target.global_position
		chunks[chunk_num].nearest = true 

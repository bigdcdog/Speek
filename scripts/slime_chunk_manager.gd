
extends Node3D

@onready var navigation_controller: Node3D = $navigation_controller
@onready var target: CharacterBody3D = $target

const CHUNK = preload("res://scenes/chunk.tscn")
const CHUNKS = 16

var chunks: Array[RigidBody3D] = []

var path: PackedVector3Array = []
var current_waypoint := 0
var next_position := Vector3.ZERO
var path_timer := 0.0
var last_target_position := Vector3.ZERO


func spawn_chunk(spawn_position: Vector3, chunk_name: int) -> void:
	var chunk = CHUNK.instantiate()
	chunk.position = spawn_position
	chunk.name = "chunk %s" % [chunk_name]
	add_child(chunk)
	chunks.append(chunk)


func _ready() -> void:
	for i in range(CHUNKS):
		spawn_chunk(Vector3(3, 3, 3), i)
	
	for chunk in chunks:
		chunk.chunks = chunks


func _physics_process(delta: float) -> void:
	path_timer += delta
	
	# Recalculate the path initially, or when the player moves far enough.
	if path.is_empty() or (path_timer >= 0.5 and target.global_position.distance_to(last_target_position) > 2.0):
		# Find the chunk closest to the character.
		var start_chunk: RigidBody3D = chunks[0]
		var shortest_distance := start_chunk.global_position.distance_squared_to(target.global_position)
	
		for chunk in chunks:
			var distance = chunk.global_position.distance_squared_to(target.global_position)
	
			if distance < shortest_distance:
				shortest_distance = distance
				start_chunk = chunk
	
		# Calculate path from that chunk to the character.
		path = navigation_controller.calculate_path(
			start_chunk.global_position,
			target.global_position
		)
	
		print("Full path: ", path)
	
		current_waypoint = 0
		last_target_position = target.global_position
		path_timer = 0.0
	
	# Follow the path.
	if current_waypoint < path.size():
		next_position = path[current_waypoint]
	
		# Find the chunk closest to the current waypoint.
		var nearest_chunk: RigidBody3D = chunks[0]
		var waypoint_distance := nearest_chunk.global_position.distance_squared_to(next_position)
	
		for chunk in chunks:
			var distance = chunk.global_position.distance_squared_to(next_position)
	
			if distance < waypoint_distance:
				waypoint_distance = distance
				nearest_chunk = chunk
	
		# Advance when the closest chunk reaches the waypoint.
		if waypoint_distance < 1.0:
			current_waypoint += 1
	
	# Send the current waypoint to every chunk.
	for chunk in chunks:
		chunk.target_position = next_position

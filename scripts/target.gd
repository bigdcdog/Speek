extends CharacterBody3D

@onready var chunk_manager: Node3D = $".."

@export var speed = 5.0
@export var max_distance := 2.0

func _physics_process(_delta: float) -> void:
	var nearest_chunk_pos = chunk_manager.chunks[0].global_position
	var nearest_chunk_direction = global_position.direction_to(nearest_chunk_pos)
	var distance_to_nearest_chunk = global_position.distance_to(nearest_chunk_pos)
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var vertical := Input.get_axis("down", "up")
	var direction := (transform.basis * Vector3(input_dir.x, vertical, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.y = direction.y * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.y = move_toward(velocity.y, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	if distance_to_nearest_chunk > max_distance:
		var target_velocity = nearest_chunk_direction * speed
		var lerp_speed = (distance_to_nearest_chunk ** 2) / 10.0
		velocity = velocity.lerp(target_velocity, lerp_speed)
	move_and_slide()

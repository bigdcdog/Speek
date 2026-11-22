extends CharacterBody3D

@export var speed = 5.0

func _physics_process(_delta: float) -> void:
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
	
	move_and_slide()

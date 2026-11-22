extends RigidBody3D

@export var max_distance := 10.0
@export var strength := 500.0
@export var integrity_loss := 1
@export var integrity_gain := 5

var integrity := 0
var supported := false
var grounded = false
var nearest := false

var target_position := Vector3.ZERO

func calculate_integrity(state: PhysicsDirectBodyState3D) -> void:
	integrity = 0
	grounded = false
	var integrity_affect = 0
	for collision in range(state.get_contact_count()):
		var collider = state.get_contact_collider_object(collision)
		
		if collider == null:
			continue
		
		if collider.is_in_group("speek"):
			integrity_affect -= integrity_loss
			if collider.grounded:
				integrity_affect += collider.integrity
		else:
			integrity = integrity_gain
			grounded = true
	if not grounded:
		integrity += integrity_affect
	supported = false
	if integrity > 0:
		supported = true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	calculate_integrity(state)
	
	if nearest and supported:
		var direction = global_position.direction_to(target_position)
		var distance = global_position.distance_to(target_position)
		var multiplier = pow(clamp((distance - 0.5) / (max_distance - 0.5), 0.0, 1.0), 0.5)
		state.linear_velocity *= 0.5
		state.apply_central_force(direction * multiplier * strength)
	nearest = false


extends RigidBody3D

# Settings
@export var adhesion_strength := 100.0
@export var strength := 10.0
@export var target_position := Vector3.ZERO
@export var chunks: Array = []
@export var integrity_loss := 1

# State
var integrity := 0
var supported := false
var nearest := false


# Find the chunk closest to the target.
func is_nearest() -> void:
	nearest = true
	var shortest_distance := global_position.distance_squared_to(target_position)
	
	for chunk in chunks:
		if chunk == self:
			continue
	
		var distance = chunk.global_position.distance_squared_to(target_position)
	
		if distance < shortest_distance:
			nearest = false
			break


# Calculate support from contact points.
func calculate_integrity(state: PhysicsDirectBodyState3D) -> void:
	for contact in state.get_contact_count():
		var collider = state.get_contact_collider_object(contact)
	
		if collider == null:
			continue
	
		if collider.is_in_group("speek"):
			integrity -= integrity_loss
		else:
			integrity += 5
	
	if integrity > 0:
		supported = true


# Update target and check position.
func _physics_process(_delta: float) -> void:
	target_position = get_tree().current_scene.get_node("slime_chunk_manager").next_position
	
	is_nearest()
	
	if global_position.y < -50:
		global_position = Vector3.ONE
		linear_velocity = Vector3.ZERO


# Apply physics forces.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	integrity = 0
	supported = false
	
	# Gravity and surface adhesion.
	gravity_scale = 5.0
	var surface_adhesion := Vector3.ZERO
	
	if not is_in_group("speek"):
		if state.get_contact_count() == 0:
			gravity_scale = 0.0
			supported = false
	
	apply_central_force(surface_adhesion)
	
	# Support calculation.
	calculate_integrity(state)
	
	# Movement towards target.
	var movement := Vector3.ZERO
	
	if nearest and supported:
		var direction = global_position.direction_to(target_position)
		var distance = global_position.distance_to(target_position)
		var movement_strength = strength * (1.0 - exp(-5.0 * distance))
		movement = direction * movement_strength
	
	apply_central_force(movement)

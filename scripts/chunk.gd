extends RigidBody3D

@onready var mesh: MeshInstance3D = $mesh

@export var max_distance := 10.0
@export var strength := 500.0
@export var integrity_loss := 1
@export var integrity_gain := 100

var material := StandardMaterial3D.new()
var colour := Color(1.0, 1.0, 1.0, 1.0)

var integrity := 0
var supported := false
var supporting := false
var grounded = false
var nearest := false

var target_direction := Vector3.ZERO
var target_distance := 0.0

var timer := 0.0

func calculate_integrity(state: PhysicsDirectBodyState3D) -> void:
	integrity = 0
	grounded = false
	supporting = false
	var integrity_affect = 0
	for collision in range(state.get_contact_count()):
		var collider = state.get_contact_collider_object(collision)
		
		if collider == null:
			continue
		
		if collider.is_in_group("speek"):
			integrity_affect -= integrity_loss
			if collider.grounded:
				integrity_affect += collider.integrity
			if collider.supporting:
				supporting = true
		else:
			integrity = integrity_gain
			grounded = true
			supporting = true
	if not grounded:
		integrity += integrity_affect
	supported = false
	if integrity > 0:
		supported = true


func _ready() -> void:
	mesh.material_override = material

func _physics_process(delta: float) -> void:
	timer += delta
	
	if timer > 1.0:
		material.albedo_color = colour
		timer = 0.0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	calculate_integrity(state)
	
	if supported:
		if target_distance < 0.2 and supporting:
			state.apply_central_force(Vector3(0.0, -linear_velocity.y, 0.0))
		else:
			var direction = target_direction
			var distance = target_distance
			var multiplier = pow(clamp((distance - 0.5) / (max_distance - 0.5), 0.0, 1.0), 0.5)
			state.linear_velocity *= 0.1
			state.apply_central_force(direction * multiplier * strength)
	nearest = false

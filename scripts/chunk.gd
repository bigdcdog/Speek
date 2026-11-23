extends RigidBody3D

@onready var mesh: MeshInstance3D = $mesh
@onready var collision: CollisionShape3D = $collision

@export var max_distance := 10.0
@export var strength := 100.0
@export var integrity_loss := 1
@export var integrity_gain := 5

var radius := 0.0

var material := StandardMaterial3D.new()
var colour := Color(1.0, 1.0, 1.0, 1.0)

var integrity := 0

var supported := false
var supporting := false

var supports := []

enum Group {
	NEAR,
	MID,
	FAR
}

var group : Group = Group.FAR

var target_direction := Vector3.ZERO
var target_distance := 0.0

var timer := 0.0

func calculate_integrity(state: PhysicsDirectBodyState3D) -> void:
	integrity = 0
	supporting = false
	supported = false
	supports = []
	for collision_point in state.get_contact_count():
		var collider = state.get_contact_collider_object(collision_point)
		
		if collider.is_in_group("speek"):
			integrity -= integrity_loss
			if collider.supporting and collider.integrity > 0:
				supported = true
		else:
			integrity += integrity_gain
			supporting = true
			supported = true
			supports.append(collider)
	if not supporting:
		integrity = 0


func far(state: PhysicsDirectBodyState3D) -> void:
	var direction = target_direction
	var distance = target_distance
	var multiplier = pow(clamp((distance - 0.5) / (max_distance - 0.5), 0.0, 1.0), 0.5)
	
	if supporting and target_distance < radius:
		state.linear_velocity *= 0.0
	elif supported:
		state.linear_velocity *= 0.5
		state.apply_central_force(direction * multiplier * strength)

func mid(state: PhysicsDirectBodyState3D) -> void:
	var direction = target_direction
	var distance = target_distance
	var multiplier = pow(clamp((distance - 0.5) / (max_distance - 0.5), 0.0, 1.0), 0.5)
	
	if supporting and target_distance < radius:#if supporting but too far move towards target
		state.linear_velocity *= 0.0
	elif supported:
		pass#idk i need a break
func near(state: PhysicsDirectBodyState3D) -> void:
	var direction = target_direction
	var distance = target_distance
	var multiplier = pow(clamp((distance - 0.5) / (max_distance - 0.5), 0.0, 1.0), 0.5)

	if supporting and target_distance < radius:
		state.linear_velocity *= 0.5
		state.apply_central_force(direction * multiplier * strength)
	elif supported:
		state.linear_velocity *= 0.5
		state.apply_central_force(direction * multiplier * strength)

func _ready() -> void:
	mesh.material_override = material
	radius = collision.shape.radius

func _physics_process(delta: float) -> void:
	timer += delta
	
	if timer > 1.0:
		material.albedo_color = colour
		timer = 0.0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	calculate_integrity(state)
	
	match group:
		Group.NEAR:
			near(state)
		Group.MID:
			mid(state)
		Group.FAR:
			far(state)

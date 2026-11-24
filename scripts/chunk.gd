extends RigidBody3D

@onready var mesh: MeshInstance3D = $mesh
@onready var collision: CollisionShape3D = $collision

@export var max_distance := 10.0
@export var strength := 100.0
@export var max_speed := 8.0

@export var integrity_loss := 1
@export var integrity_gain := 10

@export var reach_scale := 1.0
@export var carry_scale := 0.85
@export var follow_scale := 0.7
@export var grip := 0.5
@export var slide := 0.8
@export var slack := 1.1

@export_range(0.0, 1.0) var link_stiffness := 0.1
@export_range(0.0, 1.0) var link_damping := 0.8
@export var max_pull := 300.0
@export var recall_distance := 8.0
@export var enable_recall := false

@export var adhesion_strength := 200.0
@export var surface_damping := 8.0

var radius := 0.0

var material := StandardMaterial3D.new()
var colour := Color.WHITE

var integrity := 0
var wall_integrity := 0

var supported := false
var supporting := false

var wall_supports: Array[Vector3] = []
var chunk_supports: Array = []

var links: Array = []
var rests: Array[float] = []
var gains: Array[float] = []

var rank := 0
var base = null
var base_rest := 0.0

enum Group {
	NEAR,
	MID,
	FAR
}

var group: Group = Group.FAR

var target_direction := Vector3.ZERO
var target_distance := 0.0

var surface_normal := Vector3.ZERO
var timer := 0.0


func link_to(other, rest_length: float) -> void:
	if other == self or links.has(other):
		return

	links.append(other)
	rests.append(rest_length)
	gains.append(0.0)

	other.links.append(self)
	other.rests.append(rest_length)
	other.gains.append(0.0)


func unlink_from(other) -> void:
	var index: int = links.find(other)

	if index != -1:
		links.remove_at(index)
		rests.remove_at(index)
		gains.remove_at(index)

	if not is_instance_valid(other):
		return

	var other_index: int = other.links.find(self)

	if other_index != -1:
		other.links.remove_at(other_index)
		other.rests.remove_at(other_index)
		other.gains.remove_at(other_index)


func bake_links() -> void:
	for i in range(links.size()):
		var link = links[i]
		var busiest: int = maxi(links.size(), link.links.size())
		var combined_mass: float = mass + link.mass

		if combined_mass <= 0.0:
			gains[i] = 0.0
			continue

		gains[i] = (mass * link.mass / combined_mass) / (busiest + 1)


func pick_base() -> void:
	base = null
	base_rest = 0.0

	for i in range(links.size()):
		var link = links[i]

		if link.rank < rank:
			if base == null or link.rank > base.rank:
				base = link
				base_rest = rests[i]


func hold_distance() -> float:
	if group != Group.NEAR and base != null:
		return base_rest * slack

	return radius * 2.0 * slack


func capture_contacts(state: PhysicsDirectBodyState3D) -> void:
	wall_integrity = 0
	wall_supports.clear()

	var normal_sum := Vector3.ZERO

	for contact in state.get_contact_count():
		var collider = state.get_contact_collider_object(contact)

		if collider == null:
			continue

		if collider is Node and collider.is_in_group("speek"):
			continue

		wall_integrity += integrity_gain

		wall_supports.append(
			state.transform * state.get_contact_local_position(contact)
		)

		var local_normal: Vector3 = state.get_contact_local_normal(contact)
		var world_normal: Vector3 = state.transform.basis * local_normal

		if world_normal.length_squared() > 0.0001:
			normal_sum += world_normal.normalized()

	if normal_sum.length_squared() > 0.0001:
		surface_normal = normal_sum.normalized()
	else:
		surface_normal = Vector3.ZERO


func cohesion(state: PhysicsDirectBodyState3D) -> void:
	if links.is_empty():
		return

	var here: Vector3 = state.transform.origin

	var spring: float = link_stiffness / (state.step * state.step)
	var damper: float = link_damping / state.step

	var pull := Vector3.ZERO
	var nearest = null
	var nearest_distance: float = INF

	for i in range(links.size()):
		var link = links[i]

		if not is_instance_valid(link):
			continue

		var offset: Vector3 = link.global_position - here
		var distance: float = offset.length()

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = link

		if distance < 0.0001:
			continue

		var direction: Vector3 = offset / distance
		var stretch: float = distance - rests[i]

		var separating: float = (
			link.linear_velocity - state.linear_velocity
		).dot(direction)

		pull += direction * (
			stretch * spring + separating * damper
		) * gains[i]

	state.apply_central_force(pull.limit_length(max_pull))

	if enable_recall and nearest != null and nearest_distance > recall_distance:
		recall(state, nearest)


func recall(state: PhysicsDirectBodyState3D, to) -> void:
	state.transform.origin = to.global_position + Vector3.UP * radius * 2.0
	state.linear_velocity = to.linear_velocity
	state.angular_velocity = Vector3.ZERO


func adhesion(state: PhysicsDirectBodyState3D) -> void:
	if surface_normal == Vector3.ZERO:
		return

	state.apply_central_force(-surface_normal * adhesion_strength)

	var normal_velocity: Vector3 = (
		surface_normal * state.linear_velocity.dot(surface_normal)
	)

	var tangent_velocity: Vector3 = (
		state.linear_velocity - normal_velocity
	)

	state.apply_central_force(-tangent_velocity * surface_damping)


func drive(state: PhysicsDirectBodyState3D, chunk_scale: float) -> void:
	if integrity <= 0:
		return

	var hold: float = hold_distance()

	var multiplier: float = pow(
		clampf(
			(target_distance - hold) / maxf(max_distance - hold, 0.001),
			0.0,
			1.0
		),
		0.5
	)

	var held: float = clampf(
		float(integrity) / maxf(float(integrity_gain), 0.001),
		0.0,
		1.0
	)

	state.apply_central_force(
		target_direction * multiplier * held * strength * chunk_scale
	)


func far(state: PhysicsDirectBodyState3D) -> void:
	if supporting:
		state.linear_velocity *= slide

	drive(state, follow_scale)


func mid(state: PhysicsDirectBodyState3D) -> void:
	if supporting:
		state.linear_velocity *= grip

	drive(state, carry_scale)


func near(state: PhysicsDirectBodyState3D) -> void:
	if supporting:
		if target_distance < hold_distance():
			state.linear_velocity *= 0.0
			return

		state.linear_velocity *= grip

	drive(state, reach_scale)


func _ready() -> void:
	mesh.material_override = material

	radius = collision.shape.radius


	can_sleep = false
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 16)

	add_to_group("speek")


func _exit_tree() -> void:
	for link in links.duplicate():
		unlink_from(link)

	links.clear()
	rests.clear()
	gains.clear()


func _physics_process(delta: float) -> void:
	timer += delta

	if timer > 1.0:
		material.albedo_color = colour
		timer = 0.0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	capture_contacts(state)

	cohesion(state)
	adhesion(state)

	match group:
		Group.NEAR:
			near(state)

		Group.MID:
			mid(state)

		Group.FAR:
			far(state)

	state.linear_velocity = state.linear_velocity.limit_length(max_speed)

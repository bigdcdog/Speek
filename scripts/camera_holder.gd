extends SpringArm3D

@onready var slime_chunk_manager: Node3D = $".."
@onready var target: CharacterBody3D = $".."

@export var mouse_sensitivity_drag: float = 0.004
@export var mouse_sensitivity_zoom: float = 0.04
@export var mouse_zoom_intensity: float = 2.0
@export var min_zoom: float = 1.0
@export var max_zoom: float = 7.0

var dragging: bool = false
var zoom_distance_target: float = 10.0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("drag"):
		dragging = true
	elif event.is_action_released("drag"):
		dragging = false

	if dragging and event is InputEventMouseMotion:
		target.rotation.y -= event.relative.x * mouse_sensitivity_drag
		rotation.x -= event.relative.y * mouse_sensitivity_drag
		rotation.x = clamp(rotation.x, deg_to_rad(-50), deg_to_rad(30))
	
	if event.is_action("zoom_in"):
		zoom_distance_target = clampf(zoom_distance_target - mouse_sensitivity_zoom, min_zoom, max_zoom)
	if event.is_action("zoom_out"):
		zoom_distance_target = clampf(zoom_distance_target + mouse_sensitivity_zoom, min_zoom, max_zoom)

func _process(delta: float) -> void:
	spring_length = lerpf(spring_length, zoom_distance_target, delta * mouse_zoom_intensity)

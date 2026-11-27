extends Node3D

@onready var actuator_base: CSGBox3D = $actuator_base

@export var resistance := 5.0
@export var sensitivity := 1.0
@export var shrunk_height := 0.1
@export var original_height := 0.2
@export var actuator_color := Color.html("a00000")
@export var channel := 1

var colliders := []
var target_height := original_height

func update_actuator() -> void:
	var mass := 0.0
	target_height = original_height
	
	for collider in colliders:
		mass += collider.mass
	
	if mass >= resistance:
		target_height = shrunk_height
		global.actuator_activated.emit(channel)

func _on_area_body_entered(body: Node3D) -> void:
	if body != self and not body is CSGBox3D:
		colliders.append(body)
	update_actuator()

func _on_area_body_exited(body: Node3D) -> void:
	if body != self and not body is CSGBox3D:
		colliders.erase(body)
	update_actuator()

func _ready() -> void:
	actuator_base.material = StandardMaterial3D.new()
	actuator_base.material.albedo_color = actuator_color

func _process(delta: float) -> void:
	actuator_base.size.y = lerp(actuator_base.size.y,target_height,sensitivity * delta)
	actuator_base.position.y = lerp(actuator_base.position.y, (target_height-original_height) / 2.0 + 0.2, sensitivity * delta)

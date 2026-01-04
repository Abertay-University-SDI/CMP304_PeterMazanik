extends Node3D

var spawn_pos
func initialize(spawn_location: Vector3) -> void:
	spawn_pos = spawn_location
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	global_position = spawn_pos


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

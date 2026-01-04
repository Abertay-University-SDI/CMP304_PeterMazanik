extends ColorRect

const MAX_SAMPLES := 32

var deer_history: Array[int] = []
var wolf_history: Array[int] = []
var peak: int = 0
var time_accumulator: float = 0.0

func _ready() -> void:
	# Get the shader material reference
	if material is ShaderMaterial:
		material = material as ShaderMaterial
	else:
		push_error("ColorRect must have a ShaderMaterial assigned!")

func add_sample(deer_count: int, wolf_count: int) -> void:
	# Append new data
	peak = max(deer_count,wolf_count,peak)
	deer_history.append(deer_count)
	wolf_history.append(wolf_count)

	# Trim to latest 32 values
	if deer_history.size() > MAX_SAMPLES:
		deer_history.pop_front()
	if wolf_history.size() > MAX_SAMPLES:
		wolf_history.pop_front()

	# Pad with zeros if not full yet
	while deer_history.size() < MAX_SAMPLES:
		deer_history.insert(0, 0)
	while wolf_history.size() < MAX_SAMPLES:
		wolf_history.insert(0, 0)

	# Send to shader
	material.set_shader_parameter("deer", deer_history)
	material.set_shader_parameter("wolves", wolf_history)
	material.set_shader_parameter("peak", peak)


func _process(delta: float) -> void:
	time_accumulator += delta

	if time_accumulator >= 1.0:
		time_accumulator = 0.0

		# Get current counts once per second
		var deer_count = get_tree().get_nodes_in_group("Deer").size()
		var wolf_count = get_tree().get_nodes_in_group("Wolf").size()

		add_sample(deer_count, wolf_count)

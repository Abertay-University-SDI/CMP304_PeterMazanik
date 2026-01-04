extends Control

var world_scene: PackedScene = null
var world_path := "res://world_scene/World.tscn"
var loading := false
var start_pressed := false

func _ready() -> void:
	# Start loading in background
	var err = ResourceLoader.load_threaded_request(world_path)
	if err != OK:
		push_error("Failed to start threaded load: %s" % err)
	else:
		loading = true


func _process(_delta: float) -> void:
	if loading and world_scene == null:
		var status := ResourceLoader.load_threaded_get_status(world_path)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				pass
			ResourceLoader.THREAD_LOAD_LOADED:
				world_scene = ResourceLoader.load_threaded_get(world_path)
				loading = false
				print("✅ World scene loaded and ready!")
				if(start_pressed):
					_on_start()
			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("❌ Failed to load world scene!")
				loading = false


func _on_start() -> void:
	if world_scene:
		print("Switching instantly to world scene.")

		var world = world_scene.instantiate()
		get_tree().root.add_child(world)

		# Defer freeing the current scene to avoid the “locked object” error
		var old_scene = get_tree().current_scene
		get_tree().current_scene = world
		old_scene.call_deferred("free")
	else:
		print("World not ready yet — please wait.")
		start_pressed = true


func _on_exit() -> void:
	get_tree().quit()

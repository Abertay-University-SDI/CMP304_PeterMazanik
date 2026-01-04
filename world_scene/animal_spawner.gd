extends Node3D
@export var deer_scene: PackedScene
@export var wolf_scene: PackedScene
@export var bush_scene: PackedScene

@export var noise: FastNoiseLite:
	set(new_noise):
		noise = new_noise
		
func get_height(x:float,y:float) -> float:
	return noise.get_noise_2d(x,y)*16
	
func spawn_deer()->void:
	var deer = deer_scene.instantiate()
	var spawn_xy = Vector2(randf_range(-100,100),randf_range(-100,100)) 
	var spawn_location = Vector3(spawn_xy.x,get_height(spawn_xy.x,spawn_xy.y),spawn_xy.y)
	deer.initialize(spawn_location);
	add_child(deer)
	
func spawn_deer_at_pos(pos: Vector3)->void:
	var deer = deer_scene.instantiate()
	deer.initialize(pos);
	add_child(deer)
	

func spawn_wolf_at_pos(group_id: int,pos: Vector3)->void:
	var wolf = wolf_scene.instantiate()
	wolf.initialize(pos,group_id);
	add_child(wolf)

func spawn_wolf(group_id: int)->void:
	var wolf = wolf_scene.instantiate()
	var spawn_xy = Vector2(randf_range(-100,100),randf_range(-100,100)) 
	var spawn_location = Vector3(spawn_xy.x,get_height(spawn_xy.x,spawn_xy.y),spawn_xy.y)
	wolf.initialize(spawn_location,group_id);
	add_child(wolf)
	
	
func spawn_bush() ->void:
	var bush = bush_scene.instantiate()
	var spawn_xy = Vector2(randf_range(-100,100),randf_range(-100,100)) 
	var spawn_location = Vector3(spawn_xy.x,get_height(spawn_xy.x,spawn_xy.y),spawn_xy.y)
	bush.initialize(spawn_location)
	add_child(bush)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range (0,100):
		spawn_deer()	
	for j in range(0,10):
		spawn_wolf(j)
	for k in range (0,100):
		spawn_bush()

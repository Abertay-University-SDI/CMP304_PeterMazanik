extends CharacterBody3D

@export var speed: float = 8.0
@export var chase_speed_multiplier: float = 1.7
@export var update_group: int = 0
@export var detection_range: float = 200.0

# Thresholds
const THIRST_THRESHOLD := 35.0
const HUNGER_THRESHOLD := 30.0

# Breeding requirements
const BREED_VITALITY_THRESHOLD := 100.0
const BREED_MIN_WATER := 65.0
const BREED_MIN_FOOD := 70.0
const BREED_COOLDOWN := 10.0

# Eat cooldown
const EAT_COOLDOWN := 8.0

# Stats
var water := 100.0
var food := 50.0
var vitality := 0.0
var breed_cooldown_timer := 0.0
var eat_cooldown_timer := 0.0

# Targets
var current_target: Node3D = null
var current_spring: Node3D = null
var target_search_timer := 0.0
var target_search_interval := 1.0

# Behavior State
enum State { HUNT, SEEK_WATER, DRINK, IDLE, COOLDOWN }
var state := State.HUNT

var wander_target: Vector3 = Vector3.ZERO
var facing_dir := Vector3.FORWARD

var spawn_pos: Vector3
# --------------------------------------------------
# SETUP
# --------------------------------------------------

func initialize(spawn_location: Vector3, group_id: int) -> void:
	spawn_pos = spawn_location
	rotate_y(randf_range(-PI / 4, PI / 4))
	update_group = group_id % 4

func _ready() -> void:
	global_position = spawn_pos
	vitality = randf() * 100.0
	_pick_new_wander_target()

# --------------------------------------------------
# MAIN LOOPS
# --------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta * 10.0

	if Engine.get_physics_frames() % 4 != update_group:
		move_and_slide()
		return

	var adjusted_delta := delta * 4.0
	_update_behavior_state(adjusted_delta)

	match state:
		State.HUNT:
			_hunt_behavior(adjusted_delta)
		State.SEEK_WATER:
			_seek_water_behavior(adjusted_delta)
		State.DRINK:
			_drink_behavior(adjusted_delta)
		State.IDLE:
			_idle_behavior(adjusted_delta)
		State.COOLDOWN:
			_cooldown_behavior(adjusted_delta)

func _process(delta: float) -> void:
	water -= delta
	food -= delta
	vitality += delta * 0.4

	if breed_cooldown_timer > 0.0:
		breed_cooldown_timer -= delta

	if eat_cooldown_timer > 0.0:
		eat_cooldown_timer -= delta

	if water <= 0.0 or food <= 0.0:
		queue_free()
		return

	# Breeding
	if vitality >= BREED_VITALITY_THRESHOLD and breed_cooldown_timer <= 0.0:
		if water >= BREED_MIN_WATER and food >= BREED_MIN_FOOD:
			vitality = 0.0
			breed_cooldown_timer = BREED_COOLDOWN
			var spawn_pos = global_position + Vector3.UP * 2.0
			get_parent_node_3d().spawn_wolf_at_pos(update_group, spawn_pos)
		else:
			vitality = BREED_VITALITY_THRESHOLD - 15.0

	water = clamp(water, 0.0, 100.0)
	food = clamp(food, 0.0, 100.0)

# --------------------------------------------------
# STATE LOGIC
# --------------------------------------------------

func _update_behavior_state(delta: float) -> void:
	# Water overrides everything
	if water < THIRST_THRESHOLD:
		if state != State.DRINK:
			state = State.SEEK_WATER
		return

	if state == State.DRINK and water >= 95.0:
		state = State.HUNT
		current_spring = null
		return

	if state == State.COOLDOWN:
		if eat_cooldown_timer <= 0.0:
			state = State.HUNT
		return

	if food > 95.0 and water > 95.0:
		state = State.IDLE

# --------------------------------------------------
# BEHAVIORS
# --------------------------------------------------

func _hunt_behavior(delta: float) -> void:
	target_search_timer += delta
	if target_search_timer >= target_search_interval:
		current_target = find_closest_deer()
		target_search_timer = 0.0

	if current_target and is_instance_valid(current_target):
		chase_target(current_target)
	else:
		_move_toward_wander_target(0.5)
		if _reached_wander_target():
			_pick_new_wander_target()

func _seek_water_behavior(delta: float) -> void:
	if current_spring == null:
		current_spring = find_closest_spring()
		if current_spring:
			wander_target = current_spring.global_position

	if current_spring and _at_spring(current_spring):
		state = State.DRINK
		velocity = Vector3.ZERO
		return

	_move_toward_wander_target(1.0)

func _drink_behavior(delta: float) -> void:
	velocity = Vector3.ZERO
	water += delta * 45.0

	if water >= 100.0:
		water = 100.0
		current_spring = null
		state = State.HUNT
		_pick_new_wander_target()

func _idle_behavior(delta: float) -> void:
	_move_toward_wander_target(0.4)
	if _reached_wander_target():
		_pick_new_wander_target()

func _cooldown_behavior(delta: float) -> void:
	_move_toward_wander_target(0.25)
	if _reached_wander_target():
		_pick_new_wander_target()

# --------------------------------------------------
# MOVEMENT
# --------------------------------------------------

func chase_target(target: Node3D) -> void:
	var to_target := target.global_position - global_position
	to_target.y = 0.0

	if to_target.length_squared() < 10.0:
		target.queue_free()
		food = min(food + 100.0, 100.0)
		current_target = null
		eat_cooldown_timer = EAT_COOLDOWN
		state = State.COOLDOWN
		velocity = Vector3.ZERO
		return

	var dir := to_target.normalized()
	velocity.x = dir.x * speed * chase_speed_multiplier
	velocity.z = dir.z * speed * chase_speed_multiplier

	facing_dir = dir
	look_at(global_position + facing_dir, Vector3.UP)
	move_and_slide()

func _move_toward_wander_target(speed_mult: float) -> void:
	var to_target := wander_target - global_position
	to_target.y = 0.0

	if to_target.length() > 0.5:
		var dir := to_target.normalized()
		velocity.x = dir.x * speed * speed_mult
		velocity.z = dir.z * speed * speed_mult
		facing_dir = dir
		look_at(global_position + facing_dir, Vector3.UP)
		move_and_slide()
	else:
		velocity = Vector3.ZERO

# --------------------------------------------------
# TARGETING
# --------------------------------------------------

func find_closest_deer() -> Node3D:
	var closest: Node3D = null
	var best_dist := detection_range * detection_range

	for deer in get_tree().get_nodes_in_group("Deer"):
		if not is_instance_valid(deer):
			continue
		var d := global_position.distance_squared_to(deer.global_position)
		if d < best_dist:
			best_dist = d
			closest = deer

	return closest

func find_closest_spring() -> Node3D:
	var closest: Node3D = null
	var best_dist := detection_range * detection_range

	for spring in get_tree().get_nodes_in_group("Water"):
		if not is_instance_valid(spring):
			continue
		var d := global_position.distance_squared_to(spring.global_position)
		if d < best_dist:
			best_dist = d
			closest = spring

	return closest

func _at_spring(spring: Node3D) -> bool:
	return spring and global_position.distance_to(spring.global_position) < 5.0

# --------------------------------------------------
# WANDER
# --------------------------------------------------

func _pick_new_wander_target() -> void:
	var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	wander_target = global_position + dir * randf_range(8.0, 20.0)

func _reached_wander_target() -> bool:
	var t := wander_target
	t.y = global_position.y
	return global_position.distance_to(t) < 3.0

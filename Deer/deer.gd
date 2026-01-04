extends CharacterBody3D

# =========================
# Tuning
# =========================
@export var detection_range: float = 70.0
@export var move_speed: float = 5.0
@export var flee_speed_multiplier := 1.2
@export var flee_range := 20.0
@export var flee_duration := 6.0

const THIRST_THRESHOLD := 30.0
const HUNGER_THRESHOLD := 30.0

# Breeding requirements
const BREED_VITALITY_THRESHOLD := 100.0
const BREED_MIN_WATER := 60.0
const BREED_MIN_FOOD := 60.0
const BREED_COOLDOWN := 20.0

# =========================
# Movement / Stuck Handling
# =========================
const STUCK_DISTANCE_EPSILON := 0.25
const STUCK_TIME_LIMIT := 2.5

# =========================
# Stats
# =========================
var water := 100.0
var food := 100.0
var vitality := 0.0
var breed_cooldown_timer := 0.0

# =========================
# Environment
# =========================
var current_water_target: Node3D = null
var current_food_target: Node3D = null
var water_search_timer := 0.0
var water_search_interval := 1.0

# =========================
# Wander
# =========================
var wander_target: Vector3 = Vector3.ZERO

# =========================
# Stuck tracking
# =========================
var last_position: Vector3
var stuck_timer := 0.0

# =========================
# Rotation stability
# =========================
var facing_dir: Vector3 = Vector3.FORWARD

# =========================
# Fleeing
# =========================
var flee_timer := 0.0

# =========================
# Behavior State
# =========================
enum State { WANDER, SEEK_WATER, DRINK, SEEK_FOOD, EAT, FLEE }
var state := State.WANDER

# =========================
# Init
# =========================
var spawn_pos: Vector3

func initialize(spawn_location: Vector3) -> void:
	spawn_pos = spawn_location

func _ready() -> void:
	global_position = spawn_pos
	last_position = global_position
	vitality = randf() * 100.0
	rotate_y(randf_range(-PI / 4, PI / 4))
	facing_dir = -transform.basis.z
	_pick_new_wander_target()

# =========================
# Frame Update
# =========================
func _process(delta: float) -> void:
	
	
	if(global_position.length() > 1000 or global_position.y < -100):
		global_position = Vector3(0,100+randf()*20,0)
	# --- Stat decay ---
	water -= delta
	food -= delta

	if water > 40.0 and food > 40.0:
		vitality += delta * 1.9

	if breed_cooldown_timer > 0.0:
		breed_cooldown_timer -= delta

	# --- Death ---
	if water <= 0.0 or food <= 0.0:
		queue_free()
		return

	# --- Breeding ---
	if vitality >= BREED_VITALITY_THRESHOLD and breed_cooldown_timer <= 0.0:
		if water >= BREED_MIN_WATER and food >= BREED_MIN_FOOD:
			vitality = 0.0
			breed_cooldown_timer = BREED_COOLDOWN
			var temp_pos = global_position + Vector3.UP * 2.0
			get_parent_node_3d().spawn_deer_at_pos(temp_pos)
		else:
			vitality = BREED_VITALITY_THRESHOLD - 10.0

	water = clamp(water, 0.0, 100.0)
	food = clamp(food, 0.0, 100.0)

	# --- Wolf detection (highest priority) ---
	_detect_wolves(delta)

	_behavior_tick(delta)
	_move_toward_target(delta)
	_update_stuck_detection(delta)

# =========================
# Wolf Detection / Flee
# =========================
func _detect_wolves(delta: float) -> void:
	var flee_dir := Vector3.ZERO
	var count := 0

	for wolf in get_tree().get_nodes_in_group("Wolf"):
		if not is_instance_valid(wolf):
			continue

		var to_wolf = wolf.global_position - global_position
		var dist = to_wolf.length()

		if dist < flee_range:
			flee_dir -= to_wolf.normalized()
			count += 1

	if count > 0:
		flee_dir = flee_dir.normalized()
		wander_target = global_position + flee_dir * 20.0
		state = State.FLEE
		flee_timer = flee_duration

# =========================
# Behavior
# =========================
func _behavior_tick(delta: float) -> void:
	match state:

		State.FLEE:
			flee_timer -= delta
			if flee_timer <= 0.0:
				state = State.WANDER
				_pick_new_wander_target()

		State.WANDER:
			if water < THIRST_THRESHOLD + 10.0:
				state = State.SEEK_WATER
				return

			if food < HUNGER_THRESHOLD:
				state = State.SEEK_FOOD
				return

			if _reached_target():
				_pick_new_wander_target()

		State.SEEK_WATER:
			water_search_timer += delta
			if water_search_timer >= water_search_interval:
				current_water_target = find_closest_spring()
				water_search_timer = 0.0

			if current_water_target:
				wander_target = current_water_target.global_position
				if _at_spring(current_water_target):
					state = State.DRINK
			else:
				_pick_new_wander_target()

		State.DRINK:
			water += delta * 40.0

			if not current_water_target or not _at_spring(current_water_target):
				state = State.SEEK_WATER
				return

			if water >= 100.0:
				water = 100.0
				current_water_target = null
				state = State.WANDER
				_pick_new_wander_target()

		State.SEEK_FOOD:
			if not current_food_target:
				current_food_target = find_closest_bush()

			if not current_food_target:
				state = State.WANDER
				_pick_new_wander_target()
				return

			wander_target = current_food_target.global_position

			if global_position.distance_to(wander_target) < 3.0:
				state = State.EAT

		State.EAT:
			if not current_food_target:
				state = State.WANDER
				return

			food += delta * 25.0
			food = min(food, 100.0)

			if food >= 100.0:
				current_food_target = null
				state = State.WANDER
				_pick_new_wander_target()

# =========================
# Movement
# =========================
func _move_toward_target(delta: float) -> void:
	var dir := wander_target - global_position
	dir.y = 0.0

	if dir.length_squared() > 0.01:
		dir = dir.normalized()

		var speed_mult := 1.0
		if state == State.FLEE:
			speed_mult = flee_speed_multiplier
		elif state == State.SEEK_WATER and water < 20.0:
			speed_mult = 1.5

		velocity.x = dir.x * move_speed * speed_mult
		velocity.z = dir.z * move_speed * speed_mult

		facing_dir = dir
		look_at(global_position + facing_dir, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta

	move_and_slide()

# =========================
# Stuck Detection
# =========================
func _update_stuck_detection(delta: float) -> void:
	if state in [State.DRINK, State.EAT, State.FLEE]:
		stuck_timer = 0.0
		last_position = global_position
		return

	var moved = global_position.distance_to(last_position)
	if moved < STUCK_DISTANCE_EPSILON:
		stuck_timer += delta
	else:
		stuck_timer = 0.0

	last_position = global_position

	if stuck_timer >= STUCK_TIME_LIMIT:
		_handle_stuck()

func _handle_stuck() -> void:
	stuck_timer = 0.0
	current_water_target = null
	current_food_target = null
	state = State.WANDER
	_pick_new_wander_target()

# =========================
# Helpers
# =========================
func _pick_new_wander_target() -> void:
	var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	wander_target = global_position + dir * randf_range(10.0, 35.0)

func _reached_target() -> bool:
	var t := wander_target
	t.y = global_position.y
	return global_position.distance_to(t) < 2.5

func _at_spring(spring: Node3D) -> bool:
	return spring and global_position.distance_to(spring.global_position) < 5.0

# =========================
# Detection
# =========================
func find_closest_spring() -> Node3D:
	var closest: Node3D = null
	var best := detection_range * detection_range

	for water in get_tree().get_nodes_in_group("Water"):
		var d := global_position.distance_squared_to(water.global_position)
		if d < best:
			best = d
			closest = water

	return closest

func find_closest_bush() -> Node3D:
	var closest: Node3D = null
	var best := detection_range * detection_range

	for bush in get_tree().get_nodes_in_group("Bush"):
		var d := global_position.distance_squared_to(bush.global_position)
		if d < best:
			best = d
			closest = bush

	return closest

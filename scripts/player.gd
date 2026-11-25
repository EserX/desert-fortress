extends CharacterBody3D
## First-person survivor: walk, sprint (with stamina), jump, mouse look.

signal stamina_changed(value: float, max_value: float)

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.5
const JUMP_VELOCITY := 5.2
const GROUND_ACCEL := 10.0
const AIR_ACCEL := 2.5
const MOUSE_SENSITIVITY := 0.0022
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 22.0    # per second while sprinting
const STAMINA_REGEN := 14.0    # per second while not sprinting
const STAMINA_RECOVER := 25.0  # after running dry, sprint unlocks again at this value
const EYE_HEIGHT := 1.65

var stamina := STAMINA_MAX
var exhausted := false
var play_radius := 225.0
var spawn_point := Vector3.ZERO
var head: Node3D
var camera: Camera3D
var _bob_time := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 75.0
	camera.far = 900.0
	head.add_child(camera)
	camera.make_current()

	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.5
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var moving := input.length() > 0.1

	var sprinting := Input.is_action_pressed("sprint") and moving and not exhausted
	if sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, STAMINA_MAX)
		if exhausted and stamina >= STAMINA_RECOVER:
			exhausted = false
	stamina_changed.emit(stamina, STAMINA_MAX)

	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var t := clampf(accel * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, dir.x * speed, t)
	velocity.z = lerpf(velocity.z, dir.z * speed, t)
	move_and_slide()

	# Keep the player inside the mountain ring.
	var flat := Vector2(position.x, position.z)
	if flat.length() > play_radius:
		flat = flat.normalized() * play_radius
		position.x = flat.x
		position.z = flat.y
	# Safety net if something ever goes wrong with collisions.
	if position.y < -30.0:
		position = spawn_point
		velocity = Vector3.ZERO

	_update_head_bob(delta, moving and is_on_floor(), speed)


func _update_head_bob(delta: float, walking: bool, speed: float) -> void:
	if walking:
		_bob_time += delta * speed * 1.7
		camera.position.y = sin(_bob_time) * 0.045
		camera.position.x = cos(_bob_time * 0.5) * 0.03
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, clampf(delta * 8.0, 0.0, 1.0))


## Compass heading in degrees: 0 = north (-Z), 90 = east (+X).
func heading_degrees() -> float:
	var fwd := -global_transform.basis.z
	return fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)

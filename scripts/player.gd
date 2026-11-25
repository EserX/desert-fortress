extends CharacterBody3D
## First-person survivor: walk, sprint (with stamina), crouch, jump, mouse look.

signal stamina_changed(value: float, max_value: float)
signal footstep(sprinting: bool)
signal landed(fall_speed: float)

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
const CROUCH_EYE_HEIGHT := 1.0
const CROUCH_SPEED := 2.6
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const INTERACT_RANGE := 2.6

var stamina := STAMINA_MAX
var exhausted := false
var play_radius := 225.0
var spawn_point := Vector3.ZERO
var head: Node3D
var camera: Camera3D
var crouching := false
var _bob_time := 0.0
var _last_step_phase := 0
var _was_on_floor := true
var _fall_speed := 0.0
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	_shape = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.4
	_capsule.height = STAND_HEIGHT
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT * 0.5
	add_child(_shape)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = Settings.fov
	Settings.changed.connect(func(): camera.fov = Settings.fov)
	camera.far = 900.0
	head.add_child(camera)
	camera.make_current()

	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.5
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENSITIVITY * Settings.mouse_sensitivity
		rotate_y(-event.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sens, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	elif Input.is_action_just_pressed("jump") and not crouching:
		velocity.y = JUMP_VELOCITY

	_update_crouch(delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var moving := input.length() > 0.1

	var sprinting := Input.is_action_pressed("sprint") and moving and not exhausted and not crouching
	if sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, STAMINA_MAX)
		if exhausted and stamina >= STAMINA_RECOVER:
			exhausted = false
	stamina_changed.emit(stamina, STAMINA_MAX)

	var speed := WALK_SPEED
	if sprinting:
		speed = SPRINT_SPEED
	elif crouching:
		speed = CROUCH_SPEED
	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var t := clampf(accel * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, dir.x * speed, t)
	velocity.z = lerpf(velocity.z, dir.z * speed, t)
	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		landed.emit(_fall_speed)
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()

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

	_update_head_bob(delta, moving and is_on_floor(), speed, sprinting)


func _update_crouch(delta: float) -> void:
	var want := Input.is_action_pressed("crouch")
	if not want and crouching:
		# Only stand up if there is room above.
		var params := PhysicsShapeQueryParameters3D.new()
		var tall := CapsuleShape3D.new()
		tall.radius = _capsule.radius - 0.05
		tall.height = STAND_HEIGHT
		params.shape = tall
		params.transform = Transform3D(Basis(), global_position + Vector3(0, STAND_HEIGHT * 0.5 + 0.05, 0))
		params.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty():
			want = true
	crouching = want
	var h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	_capsule.height = h
	_shape.position.y = h * 0.5
	var eye := CROUCH_EYE_HEIGHT if crouching else EYE_HEIGHT
	head.position.y = lerpf(head.position.y, eye, clampf(delta * 12.0, 0.0, 1.0))


func _update_head_bob(delta: float, walking: bool, speed: float, sprinting: bool) -> void:
	if walking:
		_bob_time += delta * speed * 1.7
		camera.position.y = sin(_bob_time) * 0.045
		camera.position.x = cos(_bob_time * 0.5) * 0.03
		# One footstep at every low point of the bob.
		var phase := int(floor((_bob_time + PI * 0.5) / PI))
		if phase != _last_step_phase:
			_last_step_phase = phase
			footstep.emit(sprinting)
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, clampf(delta * 8.0, 0.0, 1.0))


## Compass heading in degrees: 0 = north (-Z), 90 = east (+X).
## Id of the searchable thing under the crosshair (within reach), or "".
## Walls block the ray, so you can't loot through them.
func interact_target() -> String:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * INTERACT_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, 0b11, [get_rid()])
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.collider.has_meta("interact_id"):
		return hit.collider.get_meta("interact_id")
	return ""


func heading_degrees() -> float:
	var fwd := -global_transform.basis.z
	return fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)

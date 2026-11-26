extends CharacterBody3D
## A mutant. The Walker (v0.13) shambles around its home spot, spots you when
## you come close in plain sight, chases you and claws at you. Takes melee hits
## through take_hit(); at 0 health it falls over and sinks into the sand.

const LowPoly = preload("res://scripts/lowpoly.gd")

enum State { WANDER, CHASE, ATTACK, DEAD }

## Stats per mutant type. Later versions add more types here.
const TYPES := {
	"walker": {
		"name": "Walker", "health": 100.0, "walk": 1.1, "march": 2.2, "run": 3.3,
		"sight": 24.0, "sight_night": 15.0, "hear": 9.0, "lose": 38.0,
		"damage": 12.0, "reach": 1.7, "windup": 0.45, "cooldown": 1.4,
	},
}
const LAYER := 8           # physics layer 4: mutants
const GRAVITY := 18.0
const CORPSE_SECONDS := 25.0

signal attacked(damage: float, from: Vector3)
signal died(mutant: Node)
signal spotted(mutant: Node)

var type := "walker"
var stats: Dictionary = TYPES.walker
var health := 100.0
var state := State.WANDER
var home := Vector3.ZERO
## Part of a night wave: marches to the base instead of idling, sees further.
var hunter := false
var target: Node3D            # the player
var target_dead := func(): return false
var _wander_to := Vector3.ZERO
var _wander_wait := 0.0
var _think := 0.0
var _attack_t := -1.0         # time into the current attack, or -1
var _cooldown := 0.0
var _anim_t := 0.0
var _dead_t := 0.0
var _stuck_t := 0.0
var _side_t := 0.0
var _side := 1.0
var _last_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _flash := 0.0
var _groan_t := 0.0
var _model: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _skin: StandardMaterial3D
var _shape: CollisionShape3D
var audio: AudioStreamPlayer3D
var sounds := {}              # shared generated sounds from the manager


func setup(kind: String, start: Vector3, seed_value: int) -> void:
	type = kind
	stats = TYPES[kind]
	health = stats.health
	position = start
	home = start
	_last_pos = start
	_rng.seed = seed_value
	_wander_to = start
	_groan_t = _rng.randf_range(3.0, 9.0)


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 1 | LAYER
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.4
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	_shape.shape = cap
	_shape.position.y = 0.9
	add_child(_shape)
	_build_model()
	audio = AudioStreamPlayer3D.new()
	audio.unit_size = 7.0
	audio.max_distance = 45.0
	audio.position.y = 1.6
	add_child(audio)


func _build_model() -> void:
	_skin = LowPoly.material(Color(0.46, 0.53, 0.38))
	var rags := LowPoly.material(Color(0.33, 0.28, 0.24))
	var pants := LowPoly.material(Color(0.24, 0.25, 0.28))
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(1.0, 0.75, 0.2)
	eye.emission_enabled = true
	eye.emission = Color(1.0, 0.55, 0.1)
	eye.emission_energy_multiplier = 3.0
	_model = Node3D.new()
	add_child(_model)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.13 * side, 0.92, 0)
		_model.add_child(hip)
		_box(hip, Vector3(0.17, 0.9, 0.19), Vector3(0, -0.45, 0), pants)
		_box(hip, Vector3(0.15, 0.08, 0.26), Vector3(0, -0.88, -0.04), _skin)
		_legs.append(hip)
	var torso := Node3D.new()
	torso.position.y = 0.92
	torso.rotation.x = -0.3  # hunched forward
	_model.add_child(torso)
	_box(torso, Vector3(0.5, 0.62, 0.28), Vector3(0, 0.33, 0), rags)
	_box(torso, Vector3(0.3, 0.14, 0.22), Vector3(0.06, 0.08, 0.02), _skin)  # a tear in the shirt
	var head := Node3D.new()
	head.position = Vector3(0, 0.74, -0.08)
	head.rotation = Vector3(0.25, 0, 0.18)  # lolling to one side
	torso.add_child(head)
	_box(head, Vector3(0.28, 0.32, 0.28), Vector3(0, 0.12, 0), _skin)
	_box(head, Vector3(0.2, 0.07, 0.05), Vector3(0, -0.0, -0.13), LowPoly.material(Color(0.2, 0.1, 0.1)))  # mouth
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.06, 0.04, 0.03), Vector3(0.07 * side, 0.16, -0.14), eye)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.31 * side, 0.56, 0)
		torso.add_child(shoulder)
		_box(shoulder, Vector3(0.13, 0.13, 0.62), Vector3(0, 0, -0.29), _skin)
		_box(shoulder, Vector3(0.15, 0.15, 0.24), Vector3(0, 0, -0.06), rags)
		_arms.append(shoulder)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


## Joins a night wave heading for the base at goal.
func make_hunter(goal: Vector3) -> void:
	hunter = true
	home = goal
	_wander_to = goal


## Dawn: the sun finishes off what is left of the wave (no kill counted).
func crumble() -> void:
	if is_dead():
		return
	state = State.DEAD
	collision_layer = 0
	collision_mask = 1
	_dead_t = CORPSE_SECONDS - 4.0
	var tw := _model.create_tween()
	tw.tween_property(_model, "rotation", Vector3(-1.45, 0, 0.2), 0.9).set_ease(Tween.EASE_IN)


func is_dead() -> bool:
	return state == State.DEAD


## A melee hit: lose health, flinch back, flash red. At 0 it falls over.
func take_hit(damage: float, point: Vector3, dir: Vector3) -> void:
	if is_dead():
		return
	health = maxf(health - damage, 0.0)
	_flash = 0.25
	var push := Vector3(dir.x, 0, dir.z).normalized() * 3.5
	velocity += push
	_attack_t = -1.0
	_cooldown = maxf(_cooldown, 0.5)
	_float_number(damage, point)
	if health <= 0.0:
		_die(dir)
		return
	_play("hurt", 0.9)
	if state == State.WANDER:
		_set_state(State.CHASE)


func _float_number(damage: float, point: Vector3) -> void:
	var l := Label3D.new()
	l.text = str(int(damage))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.outline_size = 12
	l.modulate = Color(1.0, 0.85, 0.4)
	l.pixel_size = 0.004
	get_parent().add_child(l)
	l.global_position = point + Vector3(0, 0.25, 0)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.7, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _die(dir: Vector3) -> void:
	state = State.DEAD
	collision_layer = 0
	collision_mask = 1
	_play("death", 0.8)
	# Topple away from the blow, pivoting at the feet.
	var local := global_transform.basis.inverse() * dir
	var fall := Vector3(-1.45 if local.z < 0.0 else 1.45, 0, 0)
	var tw := _model.create_tween()
	tw.set_ease(Tween.EASE_IN)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_model, "rotation", fall, 0.55)
	for l in _legs:
		l.rotation = Vector3.ZERO
	died.emit(self)


func _set_state(s: State) -> void:
	if s == State.CHASE and state == State.WANDER:
		_play("groan", 1.15)
		spotted.emit(self)
	state = s


## True if the walker can see or hear the target right now.
func notices_target(night: bool) -> bool:
	if target == null or target_dead.call():
		return false
	var to: Vector3 = target.global_position - global_position
	var d := to.length()
	var hear: float = stats.hear * (1.6 if target.get("sprinting") else (0.5 if target.get("crouching") else 1.0))
	if d < hear:
		return true
	var sight: float = stats.sight_night if night else stats.sight
	if hunter:
		sight *= 1.5
	if d > sight:
		return false
	# Only in front of it (a wide cone) and in plain sight.
	var fwd := -global_transform.basis.z
	if fwd.dot(Vector3(to.x, 0, to.z).normalized()) < -0.2:
		return false
	return has_line_of_sight()


func has_line_of_sight() -> bool:
	var from := global_position + Vector3(0, 1.6, 0)
	var to: Vector3 = target.global_position + Vector3(0, 1.4, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == target


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_skin.albedo_color = Color(0.46, 0.53, 0.38).lerp(Color(1.0, 0.25, 0.2), _flash / 0.25)
	if is_dead():
		_dead_t += delta
		if _dead_t > CORPSE_SECONDS:
			position.y -= delta * 0.3
			if _dead_t > CORPSE_SECONDS + 6.0:
				queue_free()
		return
	# Far from the player nothing happens (saves work with many mutants).
	if state == State.WANDER and not hunter and target and global_position.distance_squared_to(target.global_position) > 140.0 * 140.0:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_think -= delta
	var night: bool = get_parent().get("night") == true
	if _think <= 0.0:
		_think = 0.25
		_decide(night)
	var want := Vector3.ZERO
	var speed: float = stats.walk
	match state:
		State.WANDER:
			_wander_wait -= delta
			var to := _wander_to - global_position
			to.y = 0
			var far_from_home := Vector2(global_position.x - home.x, global_position.z - home.z).length() > 16.0
			if hunter and far_from_home:
				# March on the base.
				speed = stats.march
				_wander_to = home
				want = to.normalized()
			elif to.length() < 0.6 or _wander_wait > 0.0:
				if _wander_wait <= 0.0:
					_wander_wait = _rng.randf_range(2.0, 6.0)
					var a := _rng.randf() * TAU
					_wander_to = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, 14.0)
			else:
				want = to.normalized()
		State.CHASE:
			speed = stats.run
			var to: Vector3 = target.global_position - global_position
			to.y = 0
			want = to.normalized()
			if to.length() < stats.reach and _cooldown <= 0.0:
				_attack_t = 0.0
				_play("attack", 1.0)
				state = State.ATTACK
		State.ATTACK:
			_attack_t += delta
			var to: Vector3 = target.global_position - global_position
			to.y = 0
			_face(to, delta * 8.0)
			if _attack_t >= stats.windup and _attack_t - delta < stats.windup:
				if to.length() < stats.reach + 0.6 and not target_dead.call():
					attacked.emit(stats.damage, global_position)
			if _attack_t > stats.windup + 0.35:
				_attack_t = -1.0
				_cooldown = stats.cooldown
				state = State.CHASE
	# Walk around whatever is in the way: sidestep for a moment when stuck.
	if want != Vector3.ZERO and _side_t > 0.0:
		_side_t -= delta
		want = (want + want.cross(Vector3.UP) * _side * 1.4).normalized()
	if want != Vector3.ZERO:
		_face(want, delta * 5.0)
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.lerp(want * speed, clampf(delta * 6.0, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if want != Vector3.ZERO:
		_stuck_t += delta
		if _stuck_t > 0.8:
			if global_position.distance_to(_last_pos) < speed * 0.25:
				_side_t = 1.2
				_side = -_side if _rng.randf() < 0.4 else _side
			_stuck_t = 0.0
			_last_pos = global_position
	_animate(delta, hv.length())
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = _rng.randf_range(5.0, 12.0) * (0.5 if state != State.WANDER else 1.0)
		_play("groan", _rng.randf_range(0.85, 1.05))


func _decide(night: bool) -> void:
	match state:
		State.WANDER:
			if notices_target(night):
				_set_state(State.CHASE)
		State.CHASE:
			if target == null or target_dead.call():
				state = State.WANDER
				_wander_to = home
				return
			var d: float = target.global_position.distance_to(global_position)
			if d > stats.lose * (1.5 if hunter else 1.0):
				state = State.WANDER
				if not hunter:
					home = global_position
				_wander_to = home


func _face(dir: Vector3, t: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	var yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(t, 0.0, 1.0))


## Shambling legs and swaying arms; arms rise to claw when attacking.
func _animate(delta: float, speed: float) -> void:
	_anim_t += delta * (2.0 + speed * 2.4)
	var swing := sin(_anim_t) * clampf(speed / 2.0, 0.0, 1.0) * 0.55
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_model.rotation.z = sin(_anim_t * 0.5) * 0.06
	var reach := -0.15 + sin(_anim_t * 0.7) * 0.1
	if _attack_t >= 0.0:
		var t: float = _attack_t / stats.windup
		reach = lerpf(-0.15, 0.9, clampf(t, 0.0, 1.0)) if t < 1.0 else lerpf(0.9, -0.6, clampf((t - 1.0) * 3.0, 0.0, 1.0))
	_arms[0].rotation.x = reach + sin(_anim_t) * 0.1
	_arms[1].rotation.x = reach - sin(_anim_t) * 0.1


func _play(name: String, pitch: float) -> void:
	if audio == null or not sounds.has(name):
		return
	audio.stream = sounds[name]
	audio.pitch_scale = pitch * _rng.randf_range(0.92, 1.08)
	audio.play()


func save_data() -> Dictionary:
	return {"type": type, "pos": [position.x, position.y, position.z], "home": [home.x, home.y, home.z], "hp": health, "hunter": hunter}

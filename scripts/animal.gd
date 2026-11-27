extends CharacterBody3D
## A desert animal drawn in by water and green land (v1.16). Gazelles graze
## and bolt when you come close, jackals stay bold and bite if you get near,
## and birds fly in, peck on the green and take off when disturbed. Shot or
## hit, it falls over and can be butchered for raw meat (E). At dusk they all
## head back out into the desert.

const LowPoly = preload("res://scripts/lowpoly.gd")

enum State { GO, GRAZE, FLEE, ATTACK, LEAVE, DEAD }

## Stats per animal. shy: how close you can come before it runs (half that
## crouching); bold: a jackal comes for you this close; meat: raw meat it gives.
const TYPES := {
	"gazelle": {"name": "Gazelle", "health": 55.0, "walk": 1.5, "run": 8.5, "shy": 20.0, "meat": 3,
		"color": Color(0.78, 0.6, 0.38), "belly": Color(0.93, 0.88, 0.78)},
	"jackal": {"name": "Jackal", "health": 40.0, "walk": 1.7, "run": 6.2, "shy": 0.0, "bold": 9.0, "meat": 1,
		"bite": 6.0, "reach": 1.4, "cooldown": 1.3, "color": Color(0.6, 0.48, 0.33), "belly": Color(0.82, 0.75, 0.62)},
	"bird": {"name": "Sandgrouse", "health": 10.0, "walk": 0.7, "run": 7.0, "shy": 9.0, "meat": 1, "fly": true,
		"color": Color(0.7, 0.62, 0.45), "belly": Color(0.55, 0.45, 0.32)},
}
const LAYER := 32           # physics layer 6: animals (guns and melee hit it)
const DEAD_LAYER := 2       # a body is found by the interact ray like loot
const GRAVITY := 18.0
const GRAZE_R := 5.0        # wanders this far round its goal
const FLY_H := 7.0          # birds fly this high over the sand
const FLEE_SECONDS := 7.0
const CORPSE_SECONDS := 240.0

signal attacked(damage: float, from: Vector3)
signal died(animal: Node)

var type := "gazelle"
var stats: Dictionary = TYPES.gazelle
var health := 55.0
var state := State.GO
## Where it is heading: a green square or the main well.
var goal := Vector3.ZERO
var terrain  # Terrain
var target: Node3D            # the player
var target_dead := func(): return false
var dead_t := 0.0
## Far from the player: it stands still (set by the manager).
var asleep := false
var _flee_t := 0.0
var _flee_from := Vector3.ZERO
var _wander_to := Vector3.ZERO
var _wait := 0.0
var _think := 0.0
var _cooldown := 0.0
var _anim_t := 0.0
var _flash := 0.0
var _rng := RandomNumberGenerator.new()
var _model: Node3D
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _skin: StandardMaterial3D


func setup(kind: String, start: Vector3, to: Vector3, seed_value: int) -> void:
	type = kind
	stats = TYPES[kind]
	health = stats.health
	position = start
	goal = to
	_wander_to = to
	_rng.seed = seed_value
	_anim_t = _rng.randf() * TAU


func is_dead() -> bool:
	return state == State.DEAD


func flies() -> bool:
	return stats.get("fly", false)


func _ready() -> void:
	collision_layer = LAYER if not is_dead() else DEAD_LAYER
	collision_mask = 1
	floor_max_angle = deg_to_rad(55.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	match type:
		"gazelle":
			box.size = Vector3(0.45, 1.1, 1.2)
		"jackal":
			box.size = Vector3(0.35, 0.7, 0.9)
		_:
			box.size = Vector3(0.45, 0.35, 0.45)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	add_child(shape)
	_build_model()
	set_meta("interact_id", "animal:" + name)


func _build_model() -> void:
	_skin = LowPoly.material(stats.color)
	var belly := LowPoly.material(stats.belly)
	var dark := LowPoly.material(Color(0.18, 0.15, 0.12))
	_model = Node3D.new()
	add_child(_model)
	match type:
		"gazelle":
			_box(_model, Vector3(0.36, 0.38, 0.95), Vector3(0, 0.95, 0), _skin)
			_box(_model, Vector3(0.3, 0.12, 0.8), Vector3(0, 0.78, 0), belly)
			var neck := _box(_model, Vector3(0.14, 0.5, 0.16), Vector3(0, 1.25, -0.48), _skin)
			neck.rotation.x = 0.45
			_box(_model, Vector3(0.16, 0.18, 0.32), Vector3(0, 1.52, -0.66), _skin)
			for side in [-1.0, 1.0]:
				var horn := _box(_model, Vector3(0.03, 0.36, 0.03), Vector3(0.05 * side, 1.74, -0.58), dark)
				horn.rotation.x = 0.5
			_legs_for(Vector3(0.12, 0.78, 0.36), 0.78, 0.07, _skin)
		"jackal":
			_box(_model, Vector3(0.28, 0.28, 0.7), Vector3(0, 0.55, 0), _skin)
			_box(_model, Vector3(0.22, 0.2, 0.3), Vector3(0, 0.68, -0.45), _skin)
			_box(_model, Vector3(0.1, 0.1, 0.2), Vector3(0, 0.64, -0.66), dark)  # snout
			for side in [-1.0, 1.0]:
				_box(_model, Vector3(0.06, 0.14, 0.04), Vector3(0.07 * side, 0.85, -0.42), _skin)  # ears
			var tail := _box(_model, Vector3(0.08, 0.08, 0.4), Vector3(0, 0.5, 0.5), dark)
			tail.rotation.x = 0.5
			_legs_for(Vector3(0.09, 0.45, 0.25), 0.45, 0.06, belly)
		_:
			_box(_model, Vector3(0.2, 0.18, 0.32), Vector3(0, 0.16, 0), _skin)
			_box(_model, Vector3(0.12, 0.12, 0.12), Vector3(0, 0.26, -0.18), belly)
			_box(_model, Vector3(0.04, 0.04, 0.06), Vector3(0, 0.25, -0.27), dark)  # beak
			for side in [-1.0, 1.0]:
				var w := Node3D.new()
				w.position = Vector3(0.1 * side, 0.2, 0)
				_model.add_child(w)
				_box(w, Vector3(0.36, 0.03, 0.2), Vector3(0.18 * side, 0, 0), _skin)
				_wings.append(w)


## Four legs hanging from hips at (x, y, z) mirrored, leg_len long.
func _legs_for(hip: Vector3, leg_len: float, thick: float, mat: Material) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var h := Node3D.new()
			h.position = Vector3(hip.x * sx, hip.y, hip.z * sz)
			_model.add_child(h)
			_box(h, Vector3(thick, leg_len, thick), Vector3(0, -leg_len * 0.5, 0), mat)
			_legs.append(h)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A hit from a weapon: lose health, run away (a jackal bites back while it is
## healthy), fall over at 0.
func take_hit(damage: float, _point: Vector3, dir: Vector3, _force := 0.0, _stagger := 0.0) -> void:
	if is_dead():
		return
	health = maxf(health - damage, 0.0)
	_flash = 0.25
	if health <= 0.0:
		_die(dir)
		return
	if type == "jackal" and health > stats.health * 0.5:
		state = State.ATTACK
	else:
		flee(global_position - dir)


## Something scary at `from` (you, a gunshot): run (or fly) away for a while.
func flee(from: Vector3) -> void:
	if is_dead() or state == State.LEAVE:
		return
	state = State.FLEE
	_flee_t = FLEE_SECONDS
	_flee_from = from


## Dusk: head back out into the desert.
func leave() -> void:
	if not is_dead():
		state = State.LEAVE


func _die(dir: Vector3) -> void:
	state = State.DEAD
	dead_t = 0.0
	collision_layer = DEAD_LAYER
	var local := global_transform.basis.inverse() * dir
	var tw := _model.create_tween()
	tw.tween_property(_model, "rotation:z", 1.5 if local.x > 0.0 else -1.5, 0.45).set_ease(Tween.EASE_IN)
	for w in _wings:
		w.rotation.z = 0.0
	died.emit(self)


## Made dead straight away (loading a save).
func set_dead() -> void:
	state = State.DEAD
	collision_layer = DEAD_LAYER
	if _model:
		_model.rotation.z = 1.5


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	if _skin:
		_skin.albedo_color = (stats.color as Color).lerp(Color(1.0, 0.3, 0.25), _flash / 0.25)
	if is_dead():
		dead_t += delta
		# A shot bird falls out of the sky; a body settles on the sand.
		if not is_on_floor():
			velocity = Vector3(0, velocity.y - GRAVITY * delta, 0)
			move_and_slide()
		return
	if asleep:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		_decide()
	var want := Vector3.ZERO
	var speed: float = stats.walk
	match state:
		State.GO:
			speed = stats.walk * 1.6
			var to := goal - global_position
			to.y = 0.0
			if to.length() < 2.0:
				state = State.GRAZE
				_wait = _rng.randf_range(1.0, 4.0)
			else:
				want = to.normalized()
		State.GRAZE:
			_wait -= delta
			var to := _wander_to - global_position
			to.y = 0.0
			if to.length() < 0.5 or _wait > 0.0:
				if _wait <= 0.0:
					_wait = _rng.randf_range(3.0, 9.0)
					var a := _rng.randf() * TAU
					_wander_to = goal + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.5, GRAZE_R)
			else:
				want = to.normalized()
		State.FLEE:
			speed = stats.run
			_flee_t -= delta
			var away := global_position - _flee_from
			away.y = 0.0
			want = away.normalized() if away.length() > 0.1 else -global_transform.basis.z
			if _flee_t <= 0.0:
				state = State.GO
		State.LEAVE:
			speed = stats.run * 0.6
			var out := Vector3(global_position.x, 0, global_position.z)
			want = out.normalized() if out.length() > 1.0 else Vector3.FORWARD
		State.ATTACK:
			speed = stats.run
			if target == null or target_dead.call():
				state = State.GO
			else:
				var to: Vector3 = target.global_position - global_position
				to.y = 0.0
				if to.length() > stats.reach:
					want = to.normalized()
				else:
					_face(to, delta * 8.0)
					if _cooldown <= 0.0:
						_cooldown = stats.cooldown
						attacked.emit(stats.bite, global_position)
	if want != Vector3.ZERO:
		_face(want, delta * 5.0)
	var hv := Vector3(velocity.x, 0, velocity.z).lerp(want * speed, clampf(delta * 5.0, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	var ground: float = terrain.surface_height(global_position.x, global_position.z) if terrain else 0.0
	if flies():
		# Up in the air on the way and when scared, down to peck when grazing.
		var up: bool = state in [State.GO, State.FLEE, State.LEAVE] and (state != State.GO or Vector2(goal.x - global_position.x, goal.z - global_position.z).length() > 6.0)
		var h := ground + (FLY_H if up else 0.0)
		velocity.y = clampf((h - global_position.y) * 2.0, -4.0, 5.0)
		move_and_slide()
		if global_position.y < ground:
			global_position.y = ground
	else:
		velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
	_animate(delta, hv.length())


func _decide() -> void:
	if target == null or target_dead.call() or state == State.LEAVE:
		return
	var d: float = target.global_position.distance_to(global_position)
	if type == "jackal":
		if state != State.ATTACK and state != State.FLEE and d < float(stats.bold) and health > stats.health * 0.5:
			state = State.ATTACK
		elif state == State.ATTACK and (d > float(stats.bold) * 2.5 or health <= stats.health * 0.5):
			flee(target.global_position)
		return
	var shy: float = stats.shy * (0.5 if target.get("crouching") else 1.0)
	if state != State.FLEE and d < shy:
		flee(target.global_position)


func _face(dir: Vector3, t: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(t, 0.0, 1.0))


func _animate(delta: float, speed: float) -> void:
	_anim_t += delta * (3.0 + speed * 2.5)
	var swing := sin(_anim_t) * clampf(speed / 2.0, 0.0, 1.0) * 0.6
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 3 == 0 else -1.0)
	if not _wings.is_empty():
		var g: float = terrain.surface_height(global_position.x, global_position.z) if terrain else 0.0
		var airborne: bool = global_position.y > g + 0.3
		var flap := sin(_anim_t * 4.0) * 0.8 if airborne else 0.0
		_wings[0].rotation.z = flap
		_wings[1].rotation.z = -flap
	elif state == State.GRAZE and speed < 0.3:
		_model.rotation.x = lerpf(_model.rotation.x, 0.25, clampf(delta * 3.0, 0.0, 1.0))  # head down to graze
	else:
		_model.rotation.x = lerpf(_model.rotation.x, 0.0, clampf(delta * 6.0, 0.0, 1.0))


func save_data() -> Dictionary:
	return {"type": type, "pos": [position.x, position.y, position.z], "goal": [goal.x, goal.z],
		"hp": health, "dead": is_dead(), "dead_t": dead_t, "leaving": state == State.LEAVE}

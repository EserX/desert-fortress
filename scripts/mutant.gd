extends CharacterBody3D
## A mutant. Wanders around its home spot (or marches on the base in a wave),
## spots you when you come close in plain sight, chases you and claws at you.
## Types: Walker, Runner (fast, weak), Brute (slow, tanky, wrecks walls) and
## Spitter (keeps its distance and lobs acid). Takes melee hits through
## take_hit(); at 0 health it falls over and sinks into the sand.

const LowPoly = preload("res://scripts/lowpoly.gd")

enum State { WANDER, CHASE, ATTACK, DEAD, BREAK, SPIT }

## Stats per mutant type. Later versions add more types here.
## scale: model size (x, y, z); push: how far hits knock it back; spit: ranged acid.
const TYPES := {
	"walker": {
		"name": "Walker", "health": 100.0, "walk": 1.1, "march": 2.2, "run": 3.3,
		"sight": 24.0, "sight_night": 15.0, "hear": 9.0, "lose": 38.0,
		"damage": 12.0, "reach": 1.7, "windup": 0.45, "cooldown": 1.4, "wall_damage": 20.0,
		"skin": Color(0.46, 0.53, 0.38), "scale": Vector3(1, 1, 1), "push": 1.0, "pitch": 1.0, "climb": 0.35,
	},
	"runner": {
		"name": "Runner", "health": 45.0, "walk": 1.6, "march": 3.4, "run": 6.4,
		"sight": 28.0, "sight_night": 18.0, "hear": 11.0, "lose": 45.0,
		"damage": 7.0, "reach": 1.6, "windup": 0.25, "cooldown": 0.8, "wall_damage": 8.0,
		"skin": Color(0.62, 0.42, 0.36), "scale": Vector3(0.82, 0.95, 0.82), "push": 1.6, "pitch": 1.45, "climb": 0.55,
	},
	"brute": {
		"name": "Brute", "health": 420.0, "walk": 0.9, "march": 1.7, "run": 2.5,
		"sight": 22.0, "sight_night": 14.0, "hear": 8.0, "lose": 34.0,
		"damage": 30.0, "reach": 2.3, "windup": 0.8, "cooldown": 2.2, "wall_damage": 95.0,
		"skin": Color(0.48, 0.44, 0.52), "scale": Vector3(1.55, 1.35, 1.45), "push": 0.2, "pitch": 0.62, "climb": 0.22,
	},
	"spitter": {
		"name": "Spitter", "health": 70.0, "walk": 1.0, "march": 2.0, "run": 2.8,
		"sight": 30.0, "sight_night": 20.0, "hear": 9.0, "lose": 40.0,
		"damage": 6.0, "reach": 1.6, "windup": 0.45, "cooldown": 1.4, "wall_damage": 10.0,
		"skin": Color(0.6, 0.62, 0.3), "scale": Vector3(1.05, 0.95, 1.05), "push": 1.0, "pitch": 1.15, "climb": 0.35,
		"spit": {"range": 17.0, "keep": 9.0, "cooldown": 3.2, "windup": 0.7, "damage": 14.0, "wall_damage": 25.0, "speed": 15.0},
	},
}
const LAYER := 8           # physics layer 4: mutants
const GRAVITY := 18.0
const CORPSE_SECONDS := 25.0
const SPIKE_DAMAGE := 8.0   # a mutant hurts itself this much clawing at a spike barricade
const SMELL := 30.0         # wave mutants know where you are this close, walls or not
## Pits: a steep sand wall up to CLIMB_MAX high is climbed slowly ("climb" in m/s);
## anything higher holds them. Smaller rises than CLIMB_STEP are just walked.
const CLIMB_MAX := 1.9
const CLIMB_STEP := 0.15

signal attacked(damage: float, from: Vector3, kind: String)
## Lobbed a glob of acid (the manager adds it to the world).
signal spat(from: Vector3, velocity: Vector3, mutant: Node)
signal died(mutant: Node)
signal spotted(mutant: Node)
## Clawed at a building piece.
signal piece_hit(key: String)

var type := "walker"
var stats: Dictionary = TYPES.walker
var health := 100.0
var state := State.WANDER
var home := Vector3.ZERO
## Part of a night wave: marches to the base instead of idling, sees further.
var hunter := false
var target: Node3D            # the player
var target_dead := func(): return false
var building  # Building
var terrain  # Terrain (for climbing out of pits)
## Scrambling up a pit wall right now.
var climbing := false
var _climb_base := 0.0        # where the climb started (the pit floor)
var break_key := ""           # the piece it is tearing at in BREAK
var _blocked_t := 0.0
var _wreck_key := ""          # the piece a wave mutant has picked to wreck
var _wreck_t := 0.0
var _spit_cd := 0.0
var slow_mult := 1.0          # barbed wire and spike strips slow it down for a moment
var _los := false             # line of sight to the target, refreshed a few times a second
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
	var sc: Vector3 = stats.scale
	cap.radius = 0.35 * maxf(sc.x, sc.z)
	cap.height = maxf(1.8 * sc.y, cap.radius * 2.0 + 0.1)
	_shape.shape = cap
	_shape.position.y = cap.height * 0.5
	add_child(_shape)
	_build_model()
	audio = AudioStreamPlayer3D.new()
	audio.unit_size = 7.0
	audio.max_distance = 45.0
	audio.position.y = 1.6
	add_child(audio)


func _build_model() -> void:
	_skin = LowPoly.material(stats.skin)
	var rags := LowPoly.material(Color(0.33, 0.28, 0.24))
	var pants := LowPoly.material(Color(0.24, 0.25, 0.28))
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(1.0, 0.75, 0.2)
	eye.emission_enabled = true
	eye.emission = Color(1.0, 0.55, 0.1)
	eye.emission_energy_multiplier = 3.0
	_model = Node3D.new()
	add_child(_model)
	var body := Node3D.new()  # carries the type's proportions; _model tilts when it falls
	body.scale = stats.scale
	_model.add_child(body)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.13 * side, 0.92, 0)
		body.add_child(hip)
		_box(hip, Vector3(0.17, 0.9, 0.19), Vector3(0, -0.45, 0), pants)
		_box(hip, Vector3(0.15, 0.08, 0.26), Vector3(0, -0.88, -0.04), _skin)
		_legs.append(hip)
	var torso := Node3D.new()
	torso.position.y = 0.92
	torso.rotation.x = {"runner": -0.6, "brute": -0.4}.get(type, -0.3)  # hunched forward
	body.add_child(torso)
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
		if type == "brute":
			_box(shoulder, Vector3(0.22, 0.22, 0.24), Vector3(0, 0, -0.62), _skin)  # huge fists
		elif type == "runner":
			_box(shoulder, Vector3(0.05, 0.05, 0.14), Vector3(0.03, 0, -0.66), LowPoly.material(Color(0.85, 0.8, 0.7)))  # claws
	match type:
		"brute":
			_box(torso, Vector3(0.62, 0.36, 0.36), Vector3(0, 0.5, 0.02), _skin)  # hulking shoulders
			_box(torso, Vector3(0.52, 0.12, 0.34), Vector3(0, 0.12, 0), LowPoly.material(Color(0.25, 0.22, 0.2)))  # belt
		"spitter":
			var sac := StandardMaterial3D.new()
			sac.albedo_color = Color(0.6, 0.95, 0.2)
			sac.emission_enabled = true
			sac.emission = Color(0.45, 0.9, 0.1)
			sac.emission_energy_multiplier = 1.4
			_box(torso, Vector3(0.36, 0.3, 0.2), Vector3(0.05, 0.42, 0.22), sac)   # bulging back
			_box(torso, Vector3(0.16, 0.18, 0.14), Vector3(-0.14, 0.2, 0.2), sac)
			_box(head, Vector3(0.22, 0.14, 0.16), Vector3(0, -0.06, -0.08), sac)  # swollen throat
		"runner":
			_box(head, Vector3(0.24, 0.05, 0.08), Vector3(0, -0.04, -0.14), LowPoly.material(Color(0.85, 0.8, 0.7)))  # teeth


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


## True if a hit at this point is on the head (the top of the body).
func is_headshot(point: Vector3) -> bool:
	return point.y - global_position.y > 1.5 * float(stats.scale.y)


## Heard a gunshot: come after the player.
func hear_noise() -> void:
	if not is_dead() and state == State.WANDER and target and not target_dead.call():
		_set_state(State.CHASE)


func is_dead() -> bool:
	return state == State.DEAD


## A melee hit: lose health, flinch back, flash red. At 0 it falls over.
func take_hit(damage: float, point: Vector3, dir: Vector3) -> void:
	if is_dead():
		return
	health = maxf(health - damage, 0.0)
	_flash = 0.25
	var push: Vector3 = Vector3(dir.x, 0, dir.z).normalized() * 3.5 * float(stats.push)
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
	_skin.albedo_color = (stats.skin as Color).lerp(Color(1.0, 0.25, 0.2), _flash / 0.25)
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
	_spit_cd = maxf(_spit_cd - delta, 0.0)
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
			elif hunter and _wreck_target(delta):
				# At the base with nobody about: go and wreck the nearest building.
				speed = stats.march
				var tw := _wander_to - global_position
				tw.y = 0
				want = tw.normalized() if tw.length() > 0.3 else -global_transform.basis.z
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
			if stats.has("spit") and to.length() > stats.reach:
				# Keep some distance and lob acid when there is a clear shot.
				var sp: Dictionary = stats.spit
				var d := to.length()
				if _los and d <= sp.range and _spit_cd <= 0.0:
					want = Vector3.ZERO
					_attack_t = 0.0
					_play("attack", 1.3)
					state = State.SPIT
				elif _los and d < sp.keep:
					want = -want
					speed = stats.walk
				elif _los and d < sp.range * 0.85:
					want = Vector3.ZERO
					_face(to, delta * 5.0)
			elif to.length() < stats.reach and _cooldown <= 0.0 and has_line_of_sight():
				_attack_t = 0.0
				_play("attack", 1.0)
				state = State.ATTACK
		State.ATTACK:
			_attack_t += delta
			var to: Vector3 = target.global_position - global_position
			to.y = 0
			_face(to, delta * 8.0)
			if _attack_t >= stats.windup and _attack_t - delta < stats.windup:
				if to.length() < stats.reach + 0.6 and not target_dead.call() and has_line_of_sight():
					attacked.emit(stats.damage, global_position, type)
			if _attack_t > stats.windup + 0.35:
				_attack_t = -1.0
				_cooldown = stats.cooldown
				state = State.CHASE
		State.BREAK:
			_break(delta)
		State.SPIT:
			_attack_t += delta
			var to: Vector3 = target.global_position - global_position
			_face(Vector3(to.x, 0, to.z), delta * 8.0)
			if _attack_t >= stats.spit.windup and _attack_t - delta < stats.spit.windup:
				var mouth := global_position + Vector3(0, 1.45 * stats.scale.y, 0) - global_transform.basis.z * 0.35
				spat.emit(mouth, launch_velocity(mouth, target.global_position + Vector3(0, 1.0, 0), stats.spit.speed), self)
			if _attack_t > stats.spit.windup + 0.4:
				_attack_t = -1.0
				_spit_cd = stats.spit.cooldown
				state = State.CHASE
	speed *= slow_mult
	slow_mult = move_toward(slow_mult, 1.0, delta * 2.0)
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
	if is_on_floor():
		_climb_base = global_position.y
	climbing = false
	if want != Vector3.ZERO and is_on_wall() and terrain:
		var rise := rim_ahead(want) - _climb_base
		if rise > CLIMB_STEP and rise < CLIMB_MAX:
			climbing = true
			velocity.y = float(stats.climb) * slow_mult
			velocity.x = want.x * 0.6
			velocity.z = want.z * 0.6
		elif rise >= CLIMB_MAX:
			# Too high: don't let the push slide it up the sand.
			var n := get_wall_normal()
			var nh := Vector3(n.x, 0, n.z).normalized()
			var into := Vector3(velocity.x, 0, velocity.z).dot(nh)
			if into < 0.0:
				velocity.x -= nh.x * into
				velocity.z -= nh.z * into
	move_and_slide()
	# Walked into a wall, gate or barricade: tear it down.
	var slow := Vector2(get_real_velocity().x, get_real_velocity().z).length() < speed * 0.4
	if want != Vector3.ZERO and building and slow and (state == State.CHASE or state == State.WANDER):
		var key := _blocking_piece(want)
		_blocked_t = _blocked_t + delta if key != "" else 0.0
		if _blocked_t > 0.35:
			_blocked_t = 0.0
			break_key = key
			_attack_t = -1.0
			state = State.BREAK
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


## A wave mutant at the base picks the nearest building piece (not a trap)
## to tear down and heads for it. Returns false when there is none.
func _wreck_target(delta: float) -> bool:
	if building == null:
		return false
	_wreck_t -= delta
	if _wreck_t > 0.0 and _wreck_key != "" and building.pieces.has(_wreck_key):
		return true
	_wreck_t = 2.0
	_wreck_key = ""
	var best := 30.0
	for key in building.pieces:
		var rec: Dictionary = building.pieces[key]
		if building.PIECES[rec.type].get("trap", false) or rec.slot.level > 0:
			continue
		var d: float = rec.node.global_position.distance_to(global_position)
		if d < best:
			best = d
			_wreck_key = key
	if _wreck_key == "":
		return false
	_wander_to = building.pieces[_wreck_key].node.global_position
	return true


## Highest ground a little way ahead (the top of a pit wall it is facing).
func rim_ahead(dir: Vector3) -> float:
	var h := -INF
	for d in [0.5, 1.0, 1.5]:
		var p: Vector3 = global_position + dir * d
		h = maxf(h, terrain.surface_height(p.x, p.z))
	return h


## The building piece it is pushing against while walking in direction want, or "".
func _blocking_piece(want: Vector3) -> String:
	var space := get_world_3d().direct_space_state
	for h in [1.1, 0.4]:
		var from := global_position + Vector3(0, h, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + want * 0.9, 1, [get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var key: String = building.piece_key_of(hit.collider)
			if key != "":
				return key
	return ""


## Clawing at a piece: the same swing as an attack, but the damage goes to the piece.
func _break(delta: float) -> void:
	if not building.pieces.has(break_key):
		break_key = ""
		_attack_t = -1.0
		state = State.CHASE if hunter and not target_dead.call() else State.WANDER
		return
	var to: Vector3 = building.pieces[break_key].node.global_position - global_position
	to.y = 0
	_face(to, delta * 6.0)
	if _attack_t < 0.0:
		if _cooldown <= 0.0:
			_attack_t = 0.0
			_play("attack", 0.9)
		return
	_attack_t += delta
	if _attack_t >= stats.windup and _attack_t - delta < stats.windup:
		var spiky: bool = building.pieces[break_key].type == "spikes"
		piece_hit.emit(break_key)
		building.damage(break_key, stats.wall_damage)
		if spiky:
			hurt(SPIKE_DAMAGE)
	if _attack_t > stats.windup + 0.35:
		_attack_t = -1.0
		_cooldown = stats.cooldown


## Caught in wire or on spikes: move at this share of the normal speed for a moment.
func slow(f: float) -> void:
	slow_mult = minf(slow_mult, f)


## Damage without the flinch (spikes, traps).
func hurt(amount: float) -> void:
	if is_dead():
		return
	health = maxf(health - amount, 0.0)
	_flash = 0.25
	if health <= 0.0:
		_die(-global_transform.basis.z)


## Lob velocity that lands a glob (falling at 9.8 m/s²) on to, flying at about speed.
static func launch_velocity(from: Vector3, to: Vector3, speed: float) -> Vector3:
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var h := flat.length()
	var t := clampf(h / speed, 0.25, 1.8)
	var vy := (to.y - from.y) / t + 0.5 * 9.8 * t
	return flat / t + Vector3(0, vy, 0)


func _decide(night: bool) -> void:
	_los = state != State.WANDER and target != null and has_line_of_sight()
	match state:
		State.BREAK:
			# Someone in reach and in plain sight? Go for them instead.
			if target and not target_dead.call() and target.global_position.distance_to(global_position) < stats.reach and has_line_of_sight():
				state = State.CHASE
		State.WANDER:
			if notices_target(night):
				_set_state(State.CHASE)
			elif hunter and target and not target_dead.call() and target.global_position.distance_to(global_position) < SMELL:
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
	audio.pitch_scale = pitch * stats.pitch * _rng.randf_range(0.92, 1.08)
	audio.play()


func save_data() -> Dictionary:
	return {"type": type, "pos": [position.x, position.y, position.z], "home": [home.x, home.y, home.z], "hp": health, "hunter": hunter}

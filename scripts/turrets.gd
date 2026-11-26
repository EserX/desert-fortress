extends Node3D
## Auto-turrets. Each one swings its gun toward the nearest mutant it can see
## within range and fires short bursts of 9mm from its ammo box. It needs no
## power, only rounds (E on it loads what you carry). Every shot is loud.

const RANGE := 22.0
const RATE := 0.22          # seconds between shots
const DAMAGE := 16.0
const SPREAD := 0.025       # radians
const TURN := 5.0           # radians per second
const AIM_OK := 0.08        # fires once the gun points this close to the target
const RETARGET := 0.3
const MIX_RATE := 22050.0

signal fired(pos: Vector3, loudness: float)

var building  # Building
var mutants   # Mutants
var _state := {}            # turret key -> {"target", "cd", "think", "flash"}
var _rng := RandomNumberGenerator.new()
var _shot: AudioStreamWAV


func _physics_process(delta: float) -> void:
	for key in building.keys_of(["turret"]):
		update_turret(key, building.pieces[key], delta)
	for k in _state.keys():
		if not building.pieces.has(k):
			_state.erase(k)


func update_turret(key: String, rec: Dictionary, delta: float) -> void:
	if not _state.has(key):
		_state[key] = {"target": null, "cd": 0.0, "think": 0.0, "flash": 0.0}
	var st: Dictionary = _state[key]
	st.cd = maxf(st.cd - delta, 0.0)
	st.flash -= delta
	if st.flash <= 0.0 and rec.flash.visible:
		rec.flash.visible = false
	st.think -= delta
	if st.think <= 0.0:
		st.think = RETARGET
		st.target = find_target(rec) if rec.ammo > 0 else null
	var t = st.target
	if t == null or not is_instance_valid(t) or t.is_dead():
		st.target = null
		# Idle: a slow look around.
		rec.head.rotation.y += delta * 0.4
		rec.gun.rotation.x = move_toward(rec.gun.rotation.x, 0.0, delta)
		return
	var aim: Vector3 = _aim_point(t)
	var local: Vector3 = rec.node.global_transform.basis.inverse() * (aim - rec.head.global_position)
	var want_yaw := atan2(-local.x, -local.z)
	var want_pitch := atan2(local.y, Vector2(local.x, local.z).length())
	rec.head.rotation.y = rotate_toward(rec.head.rotation.y, want_yaw, TURN * delta)
	rec.gun.rotation.x = move_toward(rec.gun.rotation.x, want_pitch, TURN * delta)
	var off := absf(angle_difference(rec.head.rotation.y, want_yaw)) + absf(rec.gun.rotation.x - want_pitch)
	if off < AIM_OK and st.cd <= 0.0 and rec.ammo > 0:
		st.cd = RATE
		shoot(rec, st)


## Upper chest: from up on its mast the turret sees more of it over walls.
static func _aim_point(m: Node3D) -> Vector3:
	return m.global_position + Vector3(0, 1.35 * float(m.stats.scale.y), 0)


## The closest living mutant in range that the turret can see.
func find_target(rec: Dictionary) -> Node:
	var best: Node = null
	var best_d := RANGE
	var from: Vector3 = rec.head.global_position + Vector3(0, 0.1, 0)
	for m in mutants.alive():
		var d: float = from.distance_to(m.global_position)
		if d >= best_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(from, _aim_point(m), 1 | 8, [rec.node.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit.collider == m:
			best = m
			best_d = d
	return best


## One round down the barrel.
func shoot(rec: Dictionary, st: Dictionary) -> Dictionary:
	rec.ammo -= 1
	var muzzle: Vector3 = rec.flash.global_position
	var dir: Vector3 = -rec.gun.global_transform.basis.z
	dir = (dir + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * SPREAD).normalized()
	rec.flash.visible = true
	rec.flash.rotation.z = _rng.randf() * TAU
	st.flash = 0.05
	_play(muzzle)
	fired.emit(muzzle, 35.0)
	var q := PhysicsRayQueryParameters3D.create(muzzle, muzzle + dir * (RANGE + 4.0), 1 | 8, [rec.node.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var n: Node = hit.collider
	while n and not n.has_method("take_hit"):
		n = n.get_parent()
	if n:
		n.take_hit(DAMAGE, hit.position, dir)
	return hit


func _play(at: Vector3) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = _shot_sound()
	a.unit_size = 8.0
	a.max_distance = 80.0
	a.pitch_scale = _rng.randf_range(1.1, 1.25)
	a.volume_db = -4.0
	add_child(a)
	a.global_position = at
	a.play()
	a.finished.connect(a.queue_free)


func _shot_sound() -> AudioStreamWAV:
	if _shot:
		return _shot
	var n := int(MIX_RATE * 0.3)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		lp += (_rng.randf_range(-1, 1) - lp) * lerpf(0.9, 0.1, minf(t / 0.05, 1.0))
		var s := lp * exp(-t * 25.0) * 1.5 + sin(TAU * 90.0 * t) * exp(-t * 40.0) * 0.7
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 26000.0))
	_shot = AudioStreamWAV.new()
	_shot.format = AudioStreamWAV.FORMAT_16_BITS
	_shot.mix_rate = int(MIX_RATE)
	_shot.data = data
	return _shot

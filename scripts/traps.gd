extends Node3D
## Makes the trap pieces bite. Ten times a second it checks which mutants are
## standing on a spike strip, in barbed wire, on a landmine or in a spiked pit. Traps wear out
## as they work (their hit points go down) and mines go off once.
## The player can walk over traps safely (they are set for mutant weight),
## but a mine's blast hurts anyone close.

const TICK := 0.1
const STRIP_DAMAGE := 18.0     # per bite
const STRIP_EVERY := 0.8       # seconds between bites on the same mutant
const STRIP_WEAR := 12.0
const WIRE_DPS := 4.0
const WIRE_SLOW := 0.35
const WIRE_WEAR := 3.0         # per second per mutant caught
const MINE_FUSE := 0.25
const MINE_RADIUS := 5.0
const MINE_DAMAGE := 220.0     # at the centre, less further out
const MINE_PLAYER_DAMAGE := 70.0
const MINE_PIECE_DAMAGE := 120.0
const SHOCK_DAMAGE := 20.0     # electric fence, per jolt
const SHOCK_EVERY := 0.5
const FIRE_DPS := 12.0
const PIT_DAMAGE := 30.0       # spiked pit, per bite
const PIT_EVERY := 1.0
const PIT_WEAR := 8.0
const STAKE_DAMAGE := 26.0     # log stakes, per bite
const STAKE_EVERY := 1.0
const STAKE_WEAR := 5.0

signal player_hurt(damage: float, from: Vector3, cause: String)
signal exploded(pos: Vector3)

var building  # Building
var mutants   # Mutants
var player: Node3D
var _t := 0.0
var _bites := {}     # "trapkey|mutant id" -> seconds until it can bite again
var _fuses := {}     # mine key -> seconds left
var _boom: AudioStreamWAV


## True if the mutant is standing on (or in) the trap.
func _on_trap(rec: Dictionary, m: Node3D) -> bool:
	var local: Vector3 = rec.node.global_transform.affine_inverse() * m.global_position
	if absf(local.y) > 1.0:
		return false
	match rec.type:
		"landmine":
			return Vector2(local.x, local.z).length() < 0.9
		"electric_fence":
			return absf(local.x) < 1.05 and absf(local.z) < 0.8 and local.y > -0.5 and local.y < 2.0
		"fire_pit":
			return Vector2(local.x, local.z).length() < 0.85
		"spiked_pit":
			return absf(local.x) < 1.0 and absf(local.z) < 1.0 and local.y < 0.9
		_:
			return absf(local.x) < 1.0 and absf(local.z) < 0.55


func _physics_process(delta: float) -> void:
	for k in _fuses.keys():
		_fuses[k] -= delta
		if _fuses[k] <= 0.0:
			_fuses.erase(k)
			detonate(k)
	for k in _bites.keys():
		_bites[k] -= delta
		if _bites[k] <= 0.0:
			_bites.erase(k)
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	tick(TICK)


## One check of every trap against every mutant.
func tick(dt: float) -> void:
	var traps: Array = []
	for key in building.keys_of(["spike_strip", "barbed_wire", "landmine", "electric_fence", "fire_pit", "spiked_pit", "log_stakes"]):
		var rec: Dictionary = building.pieces[key]
		if building.PIECES[rec.type].get("trap", false) or rec.get("powered", false) or rec.get("burn", 0.0) > 0.0:
			traps.append(key)
	if traps.is_empty():
		return
	for m in mutants.alive():
		for key in traps:
			if not building.pieces.has(key):
				continue
			var rec: Dictionary = building.pieces[key]
			if not _on_trap(rec, m):
				continue
			match rec.type:
				"spike_strip":
					m.slow(0.6)
					var bk := "%s|%d" % [key, m.get_instance_id()]
					if not _bites.has(bk):
						_bites[bk] = STRIP_EVERY
						m.hurt(STRIP_DAMAGE)
						building.damage(key, STRIP_WEAR)
				"spiked_pit":
					m.slow(0.3)
					var bk := "%s|%d" % [key, m.get_instance_id()]
					if not _bites.has(bk):
						_bites[bk] = PIT_EVERY
						m.hurt(PIT_DAMAGE)
						building.damage(key, PIT_WEAR)
				"log_stakes":
					m.slow(0.45)
					var bk := "%s|%d" % [key, m.get_instance_id()]
					if not _bites.has(bk):
						_bites[bk] = STAKE_EVERY
						m.hurt(STAKE_DAMAGE)
						building.damage(key, STAKE_WEAR)
				"barbed_wire":
					m.slow(WIRE_SLOW)
					m.hurt(WIRE_DPS * dt)
					building.damage(key, WIRE_WEAR * dt)
				"electric_fence":
					var bk := "%s|%d" % [key, m.get_instance_id()]
					if rec.get("powered", false) and not _bites.has(bk):
						_bites[bk] = SHOCK_EVERY
						m.hurt(SHOCK_DAMAGE)
						m.slow(0.15)
						building.damage(key, 2.0)
						_zap(m.global_position + Vector3(0, 1.0, 0))
				"fire_pit":
					m.hurt(FIRE_DPS * dt)
				"landmine":
					if not _fuses.has(key):
						_fuses[key] = MINE_FUSE
						_beep(rec.node.global_position)


## A mine goes off: hurts mutants, you and nearby pieces, then it is gone.
func detonate(key: String) -> void:
	if not building.pieces.has(key):
		return
	var pos: Vector3 = building.pieces[key].node.global_position
	building.remove(key)
	for m in mutants.alive():
		var d: float = m.global_position.distance_to(pos)
		if d < MINE_RADIUS:
			var away: Vector3 = (m.global_position - pos).normalized()
			m.take_hit(MINE_DAMAGE * (1.0 - d / MINE_RADIUS), m.global_position + Vector3(0, 1.2, 0), away)
	if player:
		var pd := player.global_position.distance_to(pos)
		if pd < MINE_RADIUS:
			player_hurt.emit(MINE_PLAYER_DAMAGE * (1.0 - pd / MINE_RADIUS), pos, "Caught in your own landmine.")
	for k in building.pieces.keys():
		if building.pieces.has(k) and building.pieces[k].node.global_position.distance_to(pos) < 3.0 \
				and not building.PIECES[building.pieces[k].type].get("trap", false):
			building.damage(k, MINE_PIECE_DAMAGE)
	_explosion(pos)
	exploded.emit(pos)


## Blue sparks and a crackle where a mutant touches a live fence.
func _zap(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	var q := BoxMesh.new()
	q.size = Vector3(0.03, 0.03, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.6, 0.9, 1.0)
	q.material = mat
	p.mesh = q
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)
	var a := AudioStreamPlayer3D.new()
	var wav := AudioStreamWAV.new()
	var n := int(22050 * 0.25)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	for i in n:
		var t := float(i) / 22050.0
		var s := (rng.randf_range(-1, 1) * 0.6 + signf(sin(TAU * 120.0 * t)) * 0.3) * exp(-t * 10.0)
		data.encode_s16(i * 2, int(s * 20000.0))
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = data
	a.stream = wav
	add_child(a)
	a.global_position = at
	a.play()
	a.finished.connect(a.queue_free)


func _beep(at: Vector3) -> void:
	var a := AudioStreamPlayer3D.new()
	var wav := AudioStreamWAV.new()
	var n := int(22050 * 0.12)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(sin(TAU * 1800.0 * i / 22050.0) * 12000.0))
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = data
	a.stream = wav
	add_child(a)
	a.global_position = at
	a.play()
	a.finished.connect(a.queue_free)


## Fireball, flash, smoke and a deep boom.
func _explosion(at: Vector3) -> void:
	var fire := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	fire.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1.0, 0.65, 0.2, 0.9)
	fire.material_override = fm
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fire)
	fire.global_position = at + Vector3(0, 0.6, 0)
	var tw := fire.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fire, "scale", Vector3.ONE * 5.0, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(fire.queue_free)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 8.0
	light.omni_range = 14.0
	add_child(light)
	light.global_position = at + Vector3(0, 1.0, 0)
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.4)
	lt.tween_callback(light.queue_free)
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.amount = 20
	smoke.lifetime = 2.5
	smoke.explosiveness = 0.95
	smoke.direction = Vector3.UP
	smoke.spread = 60.0
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 4.0
	smoke.gravity = Vector3(0, -1.5, 0)
	smoke.damping_min = 2.0
	smoke.damping_max = 3.0
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.4
	# Puffs of smoke as little low-poly balls, in keeping with the look.
	var q := SphereMesh.new()
	q.radius = 0.3
	q.height = 0.6
	q.radial_segments = 6
	q.rings = 3
	var mm := StandardMaterial3D.new()
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(0.42, 0.38, 0.33, 0.55)
	q.material = mm
	smoke.mesh = q
	add_child(smoke)
	smoke.global_position = at + Vector3(0, 0.3, 0)
	smoke.emitting = true
	get_tree().create_timer(3.0).timeout.connect(smoke.queue_free)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = _boom_sound()
	snd.unit_size = 25.0
	snd.max_distance = 250.0
	add_child(snd)
	snd.global_position = at
	snd.play()
	snd.finished.connect(snd.queue_free)


func _boom_sound() -> AudioStreamWAV:
	if _boom:
		return _boom
	var rate := 22050
	var n := int(rate * 1.8)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += (rng.randf_range(-1, 1) - lp) * lerpf(0.5, 0.03, minf(t / 0.3, 1.0))
		var s := lp * 3.0 * exp(-t * 2.2) + sin(TAU * (45.0 - t * 15.0) * t) * exp(-t * 3.0) * 0.8
		data.encode_s16(i * 2, int(clampf(s * minf(t / 0.003, 1.0), -1.0, 1.0) * 30000.0))
	_boom = AudioStreamWAV.new()
	_boom.format = AudioStreamWAV.FORMAT_16_BITS
	_boom.mix_rate = rate
	_boom.data = data
	return _boom

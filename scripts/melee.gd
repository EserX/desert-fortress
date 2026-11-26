extends Node3D
## First-person hands and melee weapons. Sits on the camera. Shows your hands
## holding the hammer, the rusty pipe or the machete; left click swings a
## weapon (costs stamina). The hit lands a moment into the swing.

const LowPoly = preload("res://scripts/lowpoly.gd")

## Weapon stats: damage per hit, stamina per swing, seconds between swings, reach in m.
const WEAPONS := {
	"pipe": {"damage": 25.0, "stamina": 12.0, "cooldown": 0.75, "reach": 2.4},
	"machete": {"damage": 40.0, "stamina": 9.0, "cooldown": 0.55, "reach": 2.2},
}
## Held in the hands but not swung at things (has its own left click).
const TOOLS := ["hammer"]
const HIT_TIME := 0.16  # seconds from the click to the hit
const MIX_RATE := 22050.0
const REST_POS := Vector3(0.3, -0.27, -0.5)
const ITEM_TILT := -0.35  # the held item leans forward a little at rest

## Emitted when a swing connects: "target" (something that takes hits) or "solid".
signal hit_landed(kind: String)

var player  # Player
var item := ""            # what the hands hold now ("" = hands hidden)
var swing_time := -1.0    # seconds since the swing started, or -1
var _swing_len := 0.5
var _pending_hit := false
var _hand: Node3D          # right hand pivot, holds the item
var _left: Node3D
var _models := {}
var _idle_t := 0.0
var _rng := RandomNumberGenerator.new()
var _audio: AudioStreamPlayer
var _sounds := {}


func _ready() -> void:
	var skin := LowPoly.material(Color(0.78, 0.56, 0.42))
	var sleeve := LowPoly.material(Color(0.4, 0.37, 0.28))
	var wood := LowPoly.material(Color(0.45, 0.31, 0.18))
	var metal := LowPoly.material(Color(0.6, 0.62, 0.64), 0.4)
	var rust := LowPoly.material(Color(0.5, 0.3, 0.17), 0.85)
	var grip := LowPoly.material(Color(0.15, 0.12, 0.1))

	_hand = Node3D.new()
	_hand.position = REST_POS
	add_child(_hand)
	_arm(_hand, skin, sleeve)
	_left = Node3D.new()
	_left.position = Vector3(-0.3, -0.36, -0.44)
	_left.rotation = Vector3(0.2, -0.3, 0.3)
	add_child(_left)
	_arm(_left, skin, sleeve)

	var pipe := Node3D.new()
	_box(pipe, Vector3(0.045, 0.75, 0.045), Vector3(0, 0.24, 0), rust)
	_box(pipe, Vector3(0.06, 0.06, 0.06), Vector3(0, 0.6, 0), metal)
	var machete := Node3D.new()
	_box(machete, Vector3(0.04, 0.16, 0.045), Vector3(0, 0.0, 0), grip)
	_box(machete, Vector3(0.1, 0.025, 0.06), Vector3(0, 0.09, 0), metal)
	_box(machete, Vector3(0.012, 0.5, 0.075), Vector3(0, 0.35, 0.01), metal)
	_box(machete, Vector3(0.014, 0.12, 0.06), Vector3(0, 0.62, 0.0), metal)
	var hammer := Node3D.new()
	_box(hammer, Vector3(0.035, 0.42, 0.035), Vector3(0, 0.12, 0), wood)
	_box(hammer, Vector3(0.07, 0.07, 0.17), Vector3(0, 0.33, -0.02), metal)
	_models = {"pipe": pipe, "machete": machete, "hammer": hammer}
	for k in _models:
		_models[k].rotation.x = ITEM_TILT
		_models[k].visible = false
		_hand.add_child(_models[k])
	visible = false

	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -6.0
	add_child(_audio)
	_sounds.whoosh = _make_sound(0.22, "whoosh")
	_sounds.thud = _make_sound(0.18, "thud")
	_sounds.clank = _make_sound(0.3, "clank")
	_set_shadows(self)


## Forearm and fist pointing forward from a pivot.
func _arm(pivot: Node3D, skin: Material, sleeve: Material) -> void:
	_box(pivot, Vector3(0.1, 0.11, 0.12), Vector3.ZERO, skin)
	_box(pivot, Vector3(0.11, 0.11, 0.4), Vector3(0.0, -0.03, 0.24), sleeve)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


func _set_shadows(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_set_shadows(c)


static func is_weapon(id: String) -> bool:
	return WEAPONS.has(id)


## Shows the hands with this item ("" or anything that isn't a tool hides them).
func set_item(id: String) -> void:
	if not (is_weapon(id) or id in TOOLS):
		id = ""
	if id == item:
		return
	item = id
	visible = id != ""
	for k in _models:
		_models[k].visible = k == id
	swing_time = -1.0
	_pending_hit = false


## Left click with a weapon. Returns false while the last swing is still going
## or you are too out of breath.
func try_swing() -> bool:
	if not is_weapon(item) or (swing_time >= 0.0 and swing_time < _swing_len):
		return false
	var w: Dictionary = WEAPONS[item]
	if player.stamina < w.stamina:
		return false
	player.stamina -= w.stamina
	play_swing(w.cooldown)
	_pending_hit = true
	return true


## Just the swing animation (the hammer uses it too).
func play_swing(length := 0.5) -> void:
	swing_time = 0.0
	_swing_len = length
	_audio.stream = _sounds.whoosh
	_audio.pitch_scale = _rng.randf_range(0.9, 1.15) * (1.15 if item == "machete" else 1.0)
	_audio.play()


## Checks what the swing hits right now and deals the damage.
## Returns {"kind": "target"/"solid"/"", "node"}.
func strike() -> Dictionary:
	_pending_hit = false
	if not is_weapon(item):
		return {"kind": ""}
	var w: Dictionary = WEAPONS[item]
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * w.reach, 0b1011, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {"kind": ""}
	var n: Node = hit.collider
	while n and not n.has_method("take_hit"):
		n = n.get_parent()
	var kind := "target" if n else "solid"
	if n:
		n.take_hit(w.damage, hit.position, dir)
	_audio.stream = _sounds.thud if n else _sounds.clank
	_audio.pitch_scale = _rng.randf_range(0.9, 1.1)
	_audio.play()
	hit_landed.emit(kind)
	return {"kind": kind, "node": n}


func _process(delta: float) -> void:
	if not visible:
		return
	_idle_t += delta
	var pos := REST_POS + Vector3(0, sin(_idle_t * 1.6) * 0.006, 0)
	var rot := Vector3.ZERO
	if swing_time >= 0.0:
		swing_time += delta
		if _pending_hit and swing_time >= HIT_TIME:
			strike()
		var wind := 0.1
		var chop := 0.24
		if swing_time < wind:
			var t := swing_time / wind
			rot = Vector3(0.7, -0.15, -0.25) * t
			pos += Vector3(0.04, 0.06, 0.05) * t
		elif swing_time < chop:
			var t := (swing_time - wind) / (chop - wind)
			rot = Vector3(0.7, -0.15, -0.25).lerp(Vector3(-1.4, 0.55, 0.35), t)
			pos += Vector3(0.04, 0.06, 0.05).lerp(Vector3(-0.2, -0.04, -0.12), t)
		elif swing_time < _swing_len:
			var t := smoothstep(chop, _swing_len, swing_time)
			rot = Vector3(-1.4, 0.55, 0.35).lerp(Vector3.ZERO, t)
			pos += Vector3(-0.2, -0.04, -0.12).lerp(Vector3.ZERO, t)
		else:
			swing_time = -1.0
	# The hand moves, the item in it turns (turning the whole arm would swing it into view).
	_hand.position = pos
	_hand.rotation = Vector3(0, rot.y * 0.3, 0)
	if _models.has(item):
		_models[item].rotation = Vector3(ITEM_TILT + rot.x, rot.y, rot.z)


## Generated sounds: a swish of air, a dull thud on straw, a clank on stone or metal.
func _make_sound(length: float, kind: String) -> AudioStreamWAV:
	var n := int(MIX_RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var s := 0.0
		match kind:
			"whoosh":
				var env := sin(PI * t / length)
				lp += (_rng.randf_range(-1, 1) - lp) * lerpf(0.05, 0.25, t / length)
				s = lp * env * 2.2
			"thud":
				var env := minf(t / 0.004, 1.0) * exp(-t * 28.0)
				lp += (_rng.randf_range(-1, 1) - lp) * 0.12
				s = (sin(TAU * 85.0 * t) * 0.8 + lp * 1.4) * env
			"clank":
				var env := minf(t / 0.002, 1.0) * exp(-t * 14.0)
				s = (sin(TAU * 820.0 * t) * 0.5 + sin(TAU * 1370.0 * t) * 0.3 + sin(TAU * 2210.0 * t) * 0.2) * env
				s += _rng.randf_range(-1, 1) * exp(-t * 90.0) * 0.4
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.data = data
	return wav

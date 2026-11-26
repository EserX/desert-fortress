extends Node3D
## The delivery drone. Orders from the shop's drone page wait in a queue; the
## drone flies in from the edge of the map with everything ordered so far,
## lowers a parcel onto the landing pad and flies off again.

const LowPoly = preload("res://scripts/lowpoly.gd")

const CRUISE := 28.0        # flight height above the pad
const SPEED := 22.0         # m/s
const START_DIST := 230.0
const HOVER := 2.5          # seconds over the pad while the parcel goes down
const MIX_RATE := 22050.0

signal delivered(items: Dictionary, pos: Vector3)

var building  # Building
var orders: Array = []      # item dictionaries waiting to fly
var cargo := {}             # what is on board right now
var phase := "idle"         # idle, in, down, out
var _from := Vector3.ZERO
var _pad := Vector3.ZERO
var _t := 0.0
var _body: Node3D
var _rotors: Array[Node3D] = []
var _parcel: Node3D
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_body = Node3D.new()
	_body.visible = false
	add_child(_body)
	var shell := LowPoly.material(Color(0.85, 0.82, 0.75))
	var dark := LowPoly.material(Color(0.15, 0.15, 0.16))
	var stripe := LowPoly.material(Color(0.95, 0.55, 0.15))
	_box(_body, Vector3(0.9, 0.3, 0.9), Vector3.ZERO, shell)
	_box(_body, Vector3(0.92, 0.08, 0.3), Vector3(0, 0.1, 0), stripe)
	for d in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		var arm := _box(_body, Vector3(0.1, 0.08, 1.0), d * 0.45, dark)
		arm.rotation.y = atan2(d.x, d.z)
		var rotor := Node3D.new()
		rotor.position = d * 0.75 + Vector3(0, 0.12, 0)
		_body.add_child(rotor)
		_box(rotor, Vector3(1.0, 0.02, 0.1), Vector3.ZERO, dark)
		_box(rotor, Vector3(0.1, 0.02, 1.0), Vector3.ZERO, dark)
		_rotors.append(rotor)
	_parcel = Node3D.new()
	_body.add_child(_parcel)
	_box(_parcel, Vector3(0.6, 0.45, 0.6), Vector3(0, -0.5, 0), LowPoly.material(Color(0.42, 0.45, 0.3)))
	_box(_parcel, Vector3(0.02, 0.3, 0.02), Vector3(0, -0.2, 0), dark)  # tether
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = _buzz()
	_audio.unit_size = 12.0
	_audio.max_distance = 140.0
	_body.add_child(_audio)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Where parcels land: the first landing pad, or null if there is none.
func pad_position() -> Variant:
	for key in building.pieces:
		if building.pieces[key].type == "landing_pad":
			return building.pieces[key].node.global_position + Vector3(0, 0.15, 0)
	return null


func order(items: Dictionary) -> void:
	orders.append(items.duplicate())


func busy() -> bool:
	return phase != "idle" or not orders.is_empty()


func _process(delta: float) -> void:
	for r in _rotors:
		r.rotation.y += delta * 40.0
	match phase:
		"idle":
			if not orders.is_empty():
				var pad = pad_position()
				if pad != null:
					_launch(pad)
		"in":
			_t += delta * SPEED / _from.distance_to(_pad + Vector3(0, CRUISE, 0))
			_body.global_position = _from.lerp(_pad + Vector3(0, CRUISE, 0), minf(_t, 1.0))
			if _t >= 1.0:
				phase = "down"
				_t = 0.0
		"down":
			_t += delta
			var k := clampf(_t / 3.0, 0.0, 1.0)
			_body.global_position = _pad + Vector3(0, lerpf(CRUISE, 1.6, smoothstep(0.0, 1.0, k)), 0)
			if _t >= 3.0 + HOVER * 0.5 and _parcel.visible:
				_drop()
			if _t >= 3.0 + HOVER:
				phase = "out"
				_t = 0.0
				_from = _body.global_position
		"out":
			_t += delta
			_body.global_position = _from + Vector3(_t * SPEED * 0.7, _t * 6.0, _t * SPEED * 0.4)
			if _t > 9.0:
				phase = "idle"
				_body.visible = false
				_audio.stop()


func _launch(pad: Vector3) -> void:
	cargo = {}
	for o in orders:
		for item in o:
			cargo[item] = cargo.get(item, 0) + o[item]
	orders.clear()
	_pad = pad
	var a := atan2(pad.z, pad.x) + PI * 0.75
	_from = Vector3(cos(a) * START_DIST, pad.y + CRUISE + 10.0, sin(a) * START_DIST)
	_t = 0.0
	phase = "in"
	_body.visible = true
	_parcel.visible = true
	_body.global_position = _from
	_audio.play()


func _drop() -> void:
	_parcel.visible = false
	var pad = pad_position()
	var at: Vector3 = pad if pad != null else _pad
	delivered.emit(cargo, at)
	cargo = {}


## Skips the flight (tests, and loading a save with a parcel in the air).
func finish_now() -> void:
	if phase == "idle" and not orders.is_empty() and pad_position() != null:
		_launch(pad_position())
	if phase == "in" or phase == "down":
		_drop()
	phase = "idle"
	_body.visible = false
	_audio.stop()


func save_data() -> Dictionary:
	var pending := orders.duplicate(true)
	if not cargo.is_empty():
		pending.push_front(cargo.duplicate())
	return {"orders": pending}


func load_data(data: Dictionary) -> void:
	orders = []
	cargo = {}
	phase = "idle"
	_body.visible = false
	for o in data.get("orders", []):
		var d := {}
		for item in o:
			d[str(item)] = int(o[item])
		orders.append(d)


## A whiny buzz of four rotors.
func _buzz() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var s := sin(TAU * 180.0 * t) * 0.3 + sin(TAU * 186.0 * t) * 0.3 + sin(TAU * 360.0 * t) * 0.15 + sin(TAU * 540.0 * t) * 0.08
		data.encode_s16(i * 2, int(s * 14000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav

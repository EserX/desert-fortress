extends Node3D
## Generators, power and fire pits. A generator with fuel runs at night (and
## during a wave), burning a fuel can every FUEL_SECONDS. Floodlights and
## electric fences within POWER_RANGE of a running generator have power.
## Fire pits burn down the wood put in them. Wells fill up with water.

const TICK := 0.25
const POWER_RANGE := 18.0
const FUEL_SECONDS := 90.0   # one can runs a generator this long
const MIX_RATE := 22050.0

var building  # Building
var day_night  # DayNight
var waves  # Waves
var _t := 0.0
var _hums := {}   # generator key -> AudioStreamPlayer3D
var _hum: AudioStreamWAV
var _flicker := 0.0


## True when generators should be running: at night or while a wave is on.
func power_wanted() -> bool:
	return (day_night and day_night.is_night()) or (waves and waves.active)


func _process(delta: float) -> void:
	_flicker += delta
	for key in building.keys_of(["fire_pit"]):
		var rec: Dictionary = building.pieces[key]
		if rec.flame.visible:
			# Flicker the flames and their light.
			var f := 1.0 + sin(_flicker * 13.0 + rec.node.position.x) * 0.08 + sin(_flicker * 7.3) * 0.06
			rec.flame.scale = Vector3(1.0, f, 1.0)
			rec.flame.get_child(rec.flame.get_child_count() - 1).light_energy = 1.8 * f
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	tick(TICK)


## One update: burn fuel and wood, work out what has power.
func tick(dt: float) -> void:
	var running: Array = []
	var want := power_wanted()
	for key in building.keys_of(["well"]):
		var w: Dictionary = building.pieces[key]
		w.water = minf(w.water + dt / building.WELL_SECONDS, building.WELL_MAX)
	for key in building.keys_of(["generator", "fire_pit"]):
		var rec: Dictionary = building.pieces.get(key, {})
		if rec.is_empty():
			continue
		match rec.type:
			"generator":
				var run: bool = want and rec.fuel > 0.0
				if run:
					rec.fuel = maxf(rec.fuel - dt / FUEL_SECONDS, 0.0)
					run = rec.fuel > 0.0
				if run:
					running.append(rec.node.global_position)
				if run != rec.running:
					rec.running = run
					building.set_powered(rec, run)
					_set_hum(key, rec, run)
			"fire_pit":
				if rec.burn > 0.0:
					rec.burn = maxf(rec.burn - dt, 0.0)
				var lit: bool = rec.burn > 0.0
				if rec.flame.visible != lit:
					rec.flame.visible = lit
	for key in building.keys_of(["floodlight", "electric_fence"]):
		var rec: Dictionary = building.pieces[key]
		if rec.has("powered"):
			var on := false
			for g in running:
				if (g as Vector3).distance_to(rec.node.global_position) <= POWER_RANGE:
					on = true
					break
			building.set_powered(rec, on)
	for k in _hums.keys():
		if not building.pieces.has(k):
			_hums[k].queue_free()
			_hums.erase(k)


## E on a generator: pour in a fuel can from the inventory. Returns true if one went in.
func add_fuel(key: String, inventory) -> bool:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty() or rec.fuel > building.GEN_TANK - 1.0 or inventory.count_of("fuel") <= 0:
		return false
	inventory.remove("fuel", 1)
	rec.fuel += 1.0
	return true


## E on a fire pit: put in a piece of wood (lighting it if it was out).
func add_wood(key: String, inventory) -> bool:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty() or rec.burn > building.FIRE_MAX - building.FIRE_PER_WOOD or inventory.count_of("wood") <= 0:
		return false
	inventory.remove("wood", 1)
	rec.burn += building.FIRE_PER_WOOD
	rec.flame.visible = true
	return true


func _set_hum(key: String, rec: Dictionary, on: bool) -> void:
	if not _hums.has(key):
		var a := AudioStreamPlayer3D.new()
		a.stream = _hum_sound()
		a.unit_size = 4.0
		a.max_distance = 35.0
		a.volume_db = -6.0
		add_child(a)
		_hums[key] = a
	var p: AudioStreamPlayer3D = _hums[key]
	p.global_position = rec.node.global_position
	if on and not p.playing:
		p.play()
	elif not on:
		p.stop()


## A looping two-stroke putter.
func _hum_sound() -> AudioStreamWAV:
	if _hum:
		return _hum
	var length := 1.0
	var n := int(MIX_RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var beat := fposmod(t * 25.0, 1.0)  # 25 firings a second
		lp += (rng.randf_range(-1, 1) - lp) * 0.2
		var s := (sin(TAU * 50.0 * t) * 0.5 + sin(TAU * 100.0 * t) * 0.25) * (0.6 + 0.4 * exp(-beat * 6.0)) + lp * 0.3 * exp(-beat * 4.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 16000.0))
	_hum = AudioStreamWAV.new()
	_hum.format = AudioStreamWAV.FORMAT_16_BITS
	_hum.mix_rate = int(MIX_RATE)
	_hum.data = data
	_hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_hum.loop_end = n
	return _hum

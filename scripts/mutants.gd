extends Node3D
## Keeps the mutants in the world: spawns them, tops them up each morning,
## shares their generated sounds and saves where they are.

const Mutant = preload("res://scripts/mutant.gd")
const Spit = preload("res://scripts/spit.gd")

const WANDERERS := 5         # walkers roaming the desert by day
const MIN_BASE_DIST := 70.0  # never spawn closer than this to the flag
const MIN_PLAYER_DIST := 45.0
const MIX_RATE := 22050.0

signal player_hit(damage: float, from: Vector3, kind: String)
signal mutant_killed(mutant: Node)
signal piece_hit(key: String)

var terrain  # Terrain
var building  # Building
var player: Node3D
var player_dead := func(): return false
var world_seed := 1337
var night := false
var kills := 0
var _sounds := {}
var _count := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = world_seed
	_sounds.groan = _make_sound("groan", 0.9)
	_sounds.attack = _make_sound("attack", 0.45)
	_sounds.hurt = _make_sound("hurt", 0.3)
	_sounds.death = _make_sound("death", 1.0)


func alive() -> Array:
	return get_children().filter(func(m): return m is Mutant and not m.is_dead())


## Adds one mutant at a spot on the sand.
func spawn(kind: String, pos: Vector3, hp := -1.0) -> Mutant:
	var m := Mutant.new()
	_count += 1
	m.name = "%s%d" % [kind.capitalize(), _count]
	pos.y = terrain.surface_height(pos.x, pos.z) + 0.05 if terrain else pos.y
	m.setup(kind, pos, hash("%d:%d" % [world_seed, _count]))
	if hp > 0.0:
		m.health = hp
	m.target = player
	m.target_dead = player_dead
	m.building = building
	m.piece_hit.connect(func(k): piece_hit.emit(k))
	m.sounds = _sounds
	m.rotation.y = _rng.randf() * TAU
	m.attacked.connect(func(dmg, from, k): player_hit.emit(dmg, from, k))
	m.spat.connect(_on_spat)
	m.died.connect(_on_died)
	add_child(m)
	return m


## A random spot out in the desert, away from the base and the player.
func random_spot(rng: RandomNumberGenerator) -> Vector3:
	var p := Vector3.ZERO
	for i in 30:
		var a := rng.randf() * TAU
		var r := rng.randf_range(MIN_BASE_DIST, 200.0)
		p = Vector3(cos(a) * r, 0, sin(a) * r)
		if player == null or Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() > MIN_PLAYER_DIST:
			break
	return p


## Brings the roaming walkers back up to WANDERERS (on a new game and each morning).
func top_up(day: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mutants:%d:%d" % [world_seed, day])
	var n := 0
	while alive().filter(func(m): return not m.hunter).size() < WANDERERS:
		spawn("walker", random_spot(rng))
		n += 1
	return n


## A Spitter's glob of acid flies off on its own.
func _on_spat(from: Vector3, vel: Vector3, m: Node) -> void:
	var g := Spit.new()
	g.velocity = vel
	g.damage = m.stats.spit.damage
	g.wall_damage = m.stats.spit.wall_damage
	g.target = player
	g.building = building
	g.exclude = [m.get_rid()]
	g.hit_player.connect(func(dmg, origin): player_hit.emit(dmg, origin, "spitter"))
	add_child(g)
	g.global_position = from


func spits() -> Array:
	return get_children().filter(func(c): return c is Spit)


## A loud noise (a gunshot): mutants within radius come to look.
func alert(pos: Vector3, radius: float) -> int:
	var n := 0
	for m in alive():
		if m.state == Mutant.State.WANDER and m.global_position.distance_to(pos) < radius:
			m.hear_noise()
			n += 1
	return n


func _on_died(m: Node) -> void:
	kills += 1
	mutant_killed.emit(m)


func clear() -> void:
	for c in get_children():
		if c is Mutant or c is Spit:
			remove_child(c)
			c.queue_free()


func save_data() -> Dictionary:
	var list: Array = []
	for m in alive():
		list.append(m.save_data())
	return {"list": list, "kills": kills}


func load_data(data: Dictionary) -> void:
	clear()
	kills = int(data.get("kills", 0))
	for d in data.get("list", []):
		var p: Array = d.get("pos", [])
		if p.size() != 3 or not Mutant.TYPES.has(str(d.get("type", ""))):
			continue
		var m := spawn(str(d.type), Vector3(p[0], p[1], p[2]), float(d.get("hp", -1.0)))
		var h: Array = d.get("home", [])
		if h.size() == 3:
			m.home = Vector3(h[0], h[1], h[2])
		if d.get("hunter", false):
			m.make_hunter(m.home)


## Generated voices: a low groan, a snarl when it lunges, a grunt when hit,
## and a long falling moan when it dies.
func _make_sound(kind: String, length: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var n := int(MIX_RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var u := t / length
		var f := 90.0
		var env := sin(PI * u)
		var noise := 0.25
		match kind:
			"groan":
				f = 95.0 + sin(TAU * 3.1 * t) * 8.0 - u * 20.0
				env = sin(PI * u) * (0.7 + 0.3 * sin(TAU * 5.0 * t))
			"attack":
				f = 150.0 + u * 60.0
				env = minf(u * 8.0, 1.0) * (1.0 - u)
				noise = 0.6
			"hurt":
				f = 130.0 - u * 40.0
				env = minf(u * 20.0, 1.0) * exp(-u * 4.0)
				noise = 0.4
			"death":
				f = 120.0 - u * 65.0
				env = sin(PI * minf(u * 1.2, 1.0)) * (1.0 - u * 0.5)
		phase += f / MIX_RATE
		# A buzzy, throaty tone: sawtooth with a bit of filtered noise.
		var saw := fposmod(phase, 1.0) * 2.0 - 1.0
		lp += (rng.randf_range(-1, 1) - lp) * 0.15
		var s := (saw * 0.55 + sin(TAU * phase * 2.0) * 0.2 + lp * noise * 2.0) * env * 0.8
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.data = data
	return wav

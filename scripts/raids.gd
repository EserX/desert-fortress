extends Node
## The night side of water (v1.16): the main well's water and the green land
## draw the mutants. A night wave marches on the main well, grows with the
## water you drew that day and the green you have made (the "lure"), and some
## of its groups go for your fields instead. Mutants trample the plants they
## walk over and tear up the water pipes they cross.

const Water = preload("res://scripts/water.gd")
const Farming = preload("res://scripts/farming.gd")

const LURE_WATER := 40.0     # one extra mutant for every this many litres drawn today
const LURE_GREEN := 4.0      # and for every this much green (summed over squares)
const LURE_MAX := 12
const RAID_EVERY := 3        # every third group of a night wave heads for a field
const RAID_R := 30.0         # a mutant at the base goes for plants and pipes this close
const TICK := 0.25
const TRAMPLE_R := 0.9       # a mutant this close to a plant tramples it
const TRAMPLE := 1.2         # plant health lost per second under its feet (a plant has 1)
const PIPE_R := 0.7          # and this close to a pipe tears at it
const PIPE_SECONDS := 2.0    # seconds of tearing to break a pipe

signal message(text: String)

var water  # Water
var farming  # Farming
var mutants  # Mutants
var waves  # Waves (the night's summary counts what was wrecked)
## func() -> float: green round wild oases (oases.gd), not counted in the lure.
var wild_green := Callable()
## Plants trampled and pipes broken tonight (for the summary and tests).
var trampled := 0
var pipes_broken := 0
var _t := 0.0
var _pipe_wear := {}      # "a|b" -> seconds torn at
var _warned := -100000


## The main well, where a night wave heads.
static func well_goal() -> Vector3:
	return Vector3(Water.WELL_POS.x, 0, Water.WELL_POS.y)


## Extra mutants tonight from water drawn today and green land.
static func lure_for(drawn: float, green: float) -> int:
	return mini(int(drawn / LURE_WATER) + int(green / LURE_GREEN), LURE_MAX)


func lure() -> int:
	if water == null:
		return 0
	var wild: float = wild_green.call() if wild_green.is_valid() else 0.0
	return lure_for(water.drawn_today(), maxf(water.green_total() - wild, 0.0))


## Where group `i` of a night wave heads: the main well, or for every third
## group a field (a living plant, picked with the wave's rng) if there is one.
func goal_for(i: int, rng: RandomNumberGenerator) -> Vector3:
	if farming == null or i % RAID_EVERY != RAID_EVERY - 1:
		return well_goal()
	var spots: Array = farming.plants.keys().filter(func(s): return not farming.plants[s].dead)
	if spots.is_empty():
		return well_goal()
	spots.sort()  # dictionary order isn't part of the seed
	var c: Vector2 = Farming.spot_center(spots[rng.randi_range(0, spots.size() - 1)])
	return Vector3(c.x, 0, c.y)


## The nearest living plant or pipe within RAID_R of `from` (Vector3.INF if none).
## Asked by each wave mutant at the base every 2 s (up to 30 mutants, a few
## hundred plants and a few dozen pipes).
func raid_point(from: Vector3) -> Vector3:
	var best := RAID_R
	var out := Vector3.INF
	if farming:
		for s in farming.plants:
			if farming.plants[s].dead:
				continue
			var c: Vector2 = Farming.spot_center(s)
			var d := Vector2(from.x, from.z).distance_to(c)
			if d < best:
				best = d
				out = Vector3(c.x, 0, c.y)
	if water:
		for p in water.pipes:
			var q := _closest_on(water.pipe_anchor(p[0]), water.pipe_anchor(p[1]), from)
			var d := Vector2(from.x - q.x, from.z - q.z).length()
			if d < best:
				best = d
				out = Vector3(q.x, 0, q.z)
	return out


static func _closest_on(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 0.0001 else clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / l2, 0.0, 1.0)
	return Vector3(a.x + ab.x * t, 0, a.z + ab.y * t)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	tick(TICK)


## One update: wave mutants trample plants and tear at pipes under them.
func tick(dt: float) -> void:
	if mutants == null:
		return
	var hunters: Array = mutants.alive().filter(func(m): return m.hunter)
	if hunters.is_empty():
		return
	var hit_plants := 0
	var anchors: Array = []
	if water:
		for p in water.pipes:  # a few dozen pipes, each tick while a wave is out
			anchors.append([p[0], p[1], water.pipe_anchor(p[0]), water.pipe_anchor(p[1])])
	for m in hunters:  # up to 30 mutants, 4 times a second
		var pos: Vector3 = m.global_position
		if farming:
			var s0: Vector2i = Farming.spot_of(pos.x, pos.z)
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var s: Vector2i = s0 + Vector2i(dx, dz)
					if farming.plants.has(s) and not farming.plants[s].dead \
							and Farming.spot_center(s).distance_to(Vector2(pos.x, pos.z)) < TRAMPLE_R:
						if farming.trample(s, TRAMPLE * dt):
							trampled += 1
							_note("trampled")
						hit_plants += 1
		for e in anchors:
			var q := _closest_on(e[2], e[3], pos)
			if Vector2(pos.x - q.x, pos.z - q.z).length() < PIPE_R:
				var k: String = "%s|%s" % [e[0], e[1]]
				_pipe_wear[k] = float(_pipe_wear.get(k, 0.0)) + dt
				if _pipe_wear[k] >= PIPE_SECONDS and water.break_pipe(e[0], e[1]):
					_pipe_wear.erase(k)
					pipes_broken += 1
					_note("pipes")
					message.emit("Mutants tore up a water pipe!")
	if hit_plants > 0 and Time.get_ticks_msec() - _warned > 20000:
		_warned = Time.get_ticks_msec()
		message.emit("Mutants are trampling your fields!")


func _note(key: String) -> void:
	if waves and waves.active:
		waves.stats[key] = int(waves.stats.get(key, 0)) + 1


## A new night: the counts start again.
func on_night(_d := 0) -> void:
	trampled = 0
	pipes_broken = 0
	_pipe_wear = {}

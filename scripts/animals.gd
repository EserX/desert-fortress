extends Node3D
## Wildlife (v1.16): water and green land draw animals in by day. The more
## green there is round the base, the more gazelles, jackals and birds come in
## from the desert to graze on it and drink at the main well. Hunted, they
## give raw meat, which is cooked at a burning fire pit (camp.gd). At dusk they leave.

const Animal = preload("res://scripts/animal.gd")
const Water = preload("res://scripts/water.gd")

const CHECK_EVERY := 6.0     # seconds between "does another animal come?" checks
const FIRST_HOUR := 7        # they come between these hours
const LAST_HOUR := 17
const MAX_GROUND := 8        # gazelles and jackals at once
const MAX_BIRDS := 9
const FLOCK := 3             # birds come in threes
const LIFE_PER_GROUND := 3.0 # green (summed over squares) for each gazelle or jackal
const LIFE_PER_BIRD := 2.0
const SPAWN_MIN := 80.0      # they walk in from this far out
const SPAWN_MAX := 115.0
const GONE_DIST := 150.0     # a leaving animal this far from the well is gone
const FAR := 140.0           # far from the player nothing moves

signal attacked(damage: float, from: Vector3, kind: String)
signal pickup(lines: Array)
signal message(text: String)
signal spilled(items: Dictionary, pos: Vector3)

var terrain  # Terrain
var water  # Water: the green squares and the main well
var inventory  # Inventory (the meat)
var player: Node3D
var player_dead := func(): return false
var world_seed := 1337
var day := 1
## Animals that came in today (seeds the next one, so the same world gets the same animals).
var spawned_today := 0
var _check := 0.0
var _count := 0


## All animals, living and dead.
func all() -> Array:
	return get_children().filter(func(a): return a is Animal)


func alive() -> Array:
	return all().filter(func(a): return not a.is_dead())


## How much life the land holds: the green of every square, plus a little for bare soil.
func life_score() -> float:
	if water == null:
		return 0.0
	return water.green_total() + 0.25 * water.soil_count()


## How many of each animal the land draws in: {"gazelle", "jackal", "bird"}.
## Jackals follow the herd: one for every four grazers.
static func wanted(life: float) -> Dictionary:
	var ground := mini(int(life / LIFE_PER_GROUND), MAX_GROUND)
	var jackals := ground / 4
	var birds := mini(int(life / LIFE_PER_BIRD) / FLOCK * FLOCK, MAX_BIRDS)
	return {"gazelle": ground - jackals, "jackal": jackals, "bird": birds}


func count_of(kind: String) -> int:
	return alive().filter(func(a): return a.type == kind).size()


## Adds one animal walking (or flying) from `pos` to `to`.
func spawn(kind: String, pos: Vector3, to: Vector3) -> Animal:
	var a := Animal.new()
	_count += 1
	a.name = "%s%d" % [kind.capitalize(), _count]
	if terrain:
		pos.y = terrain.surface_height(pos.x, pos.z) + 0.05
	a.setup(kind, pos, to, hash("animal:%d:%d" % [world_seed, _count]))
	a.terrain = terrain
	a.target = player
	a.target_dead = player_dead
	a.attacked.connect(func(dmg, from): attacked.emit(dmg, from, a.type))
	a.rotation.y = atan2(pos.x - to.x, pos.z - to.z)
	add_child(a)
	return a


## Somewhere green to head for: a square weighted by how green it is, or now
## and then the main well itself (to drink). The well when nothing is green.
func pick_goal(rng: RandomNumberGenerator) -> Vector3:
	var well := Vector3(Water.WELL_POS.x, 0, Water.WELL_POS.y)
	if water == null or rng.randf() < 0.25:
		return well + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(2.0, 4.0))
	var total := 0.0
	var list: Array = []
	for c in water.cells:  # every watered square (a few hundred at most), once per new animal
		var g: float = water.cells[c].green
		if g >= 0.2:
			list.append([c, g])
			total += g
	if list.is_empty():
		return well + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(2.0, 4.0))
	var r := rng.randf() * total
	for e in list:
		r -= e[1]
		if r <= 0.0:
			var p: Vector2 = Water.cell_center(e[0])
			return Vector3(p.x + rng.randf_range(-1.5, 1.5), 0, p.y + rng.randf_range(-1.5, 1.5))
	var last: Vector2 = Water.cell_center(list[-1][0])
	return Vector3(last.x, 0, last.y)


## One check: if the land wants more animals than there are, one more comes in
## (a flock of birds counts as one). Returns the kind that came, or "".
func try_spawn(hour: float) -> String:
	if hour < FIRST_HOUR or hour >= LAST_HOUR:
		return ""
	var want := wanted(life_score())
	var kind := ""
	for k in ["gazelle", "bird", "jackal"]:
		if count_of(k) < int(want[k]):
			kind = k
			break
	if kind == "":
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("animals:%d:%d:%d" % [world_seed, day, spawned_today])
	spawned_today += 1
	var a := rng.randf() * TAU
	var r := rng.randf_range(SPAWN_MIN, SPAWN_MAX)
	var from := Vector3(cos(a) * r, 0, sin(a) * r)
	var to := pick_goal(rng)
	var n := FLOCK if kind == "bird" else 1
	for i in n:
		var off := Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
		spawn(kind, from + off, to + off * 0.6)
	return kind


## Each frame from main with the hour of the day.
func tick(delta: float, hour: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_EVERY
		try_spawn(hour)
		_tidy()
	_sleep_far()


## Leaving animals far enough out are gone; old bodies rot away.
func _tidy() -> void:
	var well := Vector3(Water.WELL_POS.x, 0, Water.WELL_POS.y)
	for a in all():  # every animal (under 20), every few seconds
		var gone: bool = a.state == Animal.State.LEAVE and Vector2(a.position.x - well.x, a.position.z - well.z).length() > GONE_DIST
		if gone or (a.is_dead() and a.dead_t > Animal.CORPSE_SECONDS):
			remove_child(a)
			a.queue_free()


## Animals far from the player stand still (saves work).
func _sleep_far() -> void:
	if player == null:
		return
	for a in all():  # every animal (under 20), each frame
		var far: bool = a.global_position.distance_squared_to(player.global_position) > FAR * FAR
		a.asleep = far and a.state != Animal.State.LEAVE


## Dusk: everything heads back out into the desert.
func on_dusk(_d := 0) -> void:
	for a in alive():
		a.leave()


## Night: whatever hasn't made it out yet is gone (bodies stay).
func on_night(_d := 0) -> void:
	for a in alive():
		remove_child(a)
		a.queue_free()


func on_morning(d: int) -> void:
	day = d
	spawned_today = 0


## A loud noise (a gunshot): animals within radius run.
func alert(pos: Vector3, radius: float) -> int:
	var n := 0
	for a in alive():
		if a.global_position.distance_to(pos) < radius and a.type != "jackal":
			a.flee(pos)
			n += 1
	return n


func find(animal_name: String) -> Animal:
	var a := get_node_or_null(NodePath(animal_name))
	return a if a is Animal else null


func prompt(id: String) -> String:
	var a := find(id.trim_prefix("animal:"))
	if a == null or not a.is_dead():
		return ""
	return "[E] Butcher the %s (%d raw meat)" % [a.stats.name.to_lower(), int(a.stats.meat)]


## E on a body: raw meat into your bag (what doesn't fit drops). Returns the meat.
func butcher(id: String) -> int:
	var a := find(id.trim_prefix("animal:"))
	if a == null or not a.is_dead():
		return 0
	var n: int = a.stats.meat
	var left: Dictionary = inventory.add_all({"raw_meat": n})
	if not left.is_empty():
		spilled.emit(left, a.global_position)
	pickup.emit(["+%d Raw meat" % n])
	remove_child(a)
	a.queue_free()
	return n


func clear() -> void:
	for a in all():
		remove_child(a)
		a.queue_free()


func save_data() -> Dictionary:
	var list: Array = []
	for a in all():
		list.append(a.save_data())
	return {"list": list, "day": day, "spawned": spawned_today}


static func _num(v, fallback := 0.0) -> float:
	return float(v) if (v is float or v is int) else fallback


## Older saves (no "animals"): none about; they come in through the day.
func load_data(data: Dictionary, today: int) -> void:
	clear()
	day = today
	spawned_today = int(_num(data.get("spawned", 0))) if int(_num(data.get("day", -1))) == today else 0
	var list = data.get("list", [])
	for d in (list if list is Array else []):
		if not d is Dictionary or not Animal.TYPES.has(str(d.get("type", ""))):
			continue
		var p = d.get("pos", [])
		var g = d.get("goal", [])
		if not (p is Array and p.size() == 3 and g is Array and g.size() == 2):
			continue
		var a := spawn(str(d.type), Vector3(_num(p[0]), _num(p[1]), _num(p[2])), Vector3(_num(g[0]), 0, _num(g[1])))
		a.position.y = _num(p[1])  # keep birds up in the air
		a.health = clampf(_num(d.get("hp", a.health), a.health), 0.0, float(a.stats.health))
		if d.get("dead", false) == true or a.health <= 0.0:
			a.set_dead()
			a.dead_t = _num(d.get("dead_t", 0.0))
		elif d.get("leaving", false) == true:
			a.leave()

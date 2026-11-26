extends Node
## Caches buried around the base: a metal detector beeps faster the closer you
## get, and digging the spot 1 m down brings the cache up (a bag of loot).
## A few are buried at the start and one more most mornings.

const Items = preload("res://scripts/items.gd")

const START := 6
const MAX_HIDDEN := 6
const DEPTH := 1.0        # dig the cache's square this deep to find it
const RANGE := 20.0       # the detector hears nothing further away
const MIN_R := 8.0        # not right next to the flag
const SPACING := 8.0      # nor next to another hidden cache

signal found(pos: Vector3, items: Dictionary)

var terrain  # Terrain
var world_seed := 0
## {"x", "z" (a grid square's centre), "found": bool}
var caches: Array = []


## The caches of a new world (the same spots for a seed).
func setup() -> void:
	caches = []
	for i in START:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("cache:%d:%d" % [world_seed, i])
		_bury(rng)


## Buries a cache at a random free spot near the base. Returns true if it found one.
func _bury(rng: RandomNumberGenerator) -> bool:
	var lim: float = terrain.DIG_HALF - 2.0
	for attempt in 40:
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		if Vector2(x, z).length() < MIN_R or terrain.dig_blocked(x, z) != "":
			continue
		var c: Vector2 = terrain.cell_center(terrain.dig_cell(x, z))
		if terrain.cell_depth(terrain.dig_cell(x, z)) > 0.05:
			continue  # not under ground that is already dug
		if nearest(Vector3(c.x, 0, c.y)) < SPACING:
			continue
		caches.append({"x": c.x, "z": c.y, "found": false})
		return true
	return false


## New morning: another cache, unless enough are still hidden.
func on_morning(day: int) -> void:
	if hidden_count() >= MAX_HIDDEN:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cache_day:%d:%d" % [world_seed, day])
	_bury(rng)


func hidden_count() -> int:
	return caches.filter(func(c): return not c.found).size()


## Flat distance from pos to the nearest hidden cache (INF if none).
func nearest(pos: Vector3) -> float:
	var best := INF
	for c in caches:
		if not c.found:
			best = minf(best, Vector2(c.x - pos.x, c.z - pos.z).length())
	return best


## The ground changed: any hidden cache in the area dug deep enough comes up.
func check(area: Rect2) -> int:
	var n := 0
	for c in caches:
		if c.found or not area.grow(0.5).has_point(Vector2(c.x, c.z)):
			continue
		if terrain.cell_depth(terrain.dig_cell(c.x, c.z)) >= DEPTH - 0.01:
			c.found = true
			n += 1
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("cache_loot:%d:%.1f:%.1f" % [world_seed, c.x, c.z])
			found.emit(Vector3(c.x, terrain.surface_height(c.x, c.z), c.z), Items.roll("cache", rng))
	return n


func save_data() -> Dictionary:
	var out: Array = []
	for c in caches:
		out.append([c.x, c.z, c.found])
	return {"list": out}


## Older saves get the caches of a new world.
func load_data(data: Dictionary) -> void:
	if not data.has("list"):
		setup()
		return
	caches = []
	for e in data.list:
		if e is Array and e.size() == 3:
			caches.append({"x": float(e[0]), "z": float(e[1]), "found": bool(e[2])})

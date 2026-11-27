extends Node
## Mutant navigation round the base: a 1 m grid over the build zone (and a
## margin round it) with a flow field towards a goal, worked out with
## Dijkstra from the goal outwards. Every mutant heading the same way follows
## the same field, so a group picks the same way in.
##
## Costs, in metres of walking: open sand 1 per cell; climbing out of a dip
## costs more, and a rise higher than a mutant can climb can't be taken (pits
## and trenches); traps cost a bit so they walk round them if it's short.
## A wall, closed gate or fence between two cells costs its hit points times
## BREAK_COST (tearing it down takes time), so a damaged or weak wall is
## cheaper than a strong one and an open gate costs nothing.
##
## The fields are worked out a slice at a time (no hitch) and only while
## mutants ask for them. They are redone when the base or the ground changes,
## and the player's field when the player moves.

const CLIMB_MAX := 1.9      # as in mutant.gd: higher rises can't be climbed
const CLIMB_FREE := 0.3     # smaller rises are just walked
const CLIMB_COST := 6.0     # extra cost per metre of climbing
const BREAK_COST := 0.4     # metres of walking one hit point of a wall is worth
const FENCE_EXTRA := 15.0   # an electric fence bites while they tear it down
const LOCK_MULT := 2.0      # locked metal doors take half damage
const STEP_COST := 0.5      # stepping up onto a foundation
const MARGIN := 16          # cells of open sand round the build zone
const BUDGET := 350         # cells settled per physics frame (about 1 ms)
const WANT_SECONDS := 3.0   # a field nobody asked for this long isn't kept up
const REDO_GAP := 0.4       # seconds between rebuilds of the map
const GOAL_MOVE := 2.0      # the player's field is redone when they move this far
const NEAR_GOAL := 1.6      # this close, mutants go straight for it
const LOOKAHEAD := 4        # cells ahead a mutant aims along a straight stretch

## Cost per cell of things standing in it (level 0 objects); anything else that
## blocks costs OBJ_DEFAULT. Landmines and ladders cost nothing (they don't know).
const OBJ_COST := {
	"spikes": 14.0, "barbed_wire": 7.0, "spike_strip": 5.0, "log_stakes": 9.0, "spiked_pit": 16.0, "fire_pit": 4.0,
	"landmine": 0.0, "ladder": 0.0, "landing_pad": 0.0, "switch": 0.5, "sprinkler": 0.5,
}
const OBJ_DEFAULT := 4.0
const DECK_FREE := ["floor", "trapdoor", "roof", "tri_roof", "stairs", "ramp"]

var terrain   # Terrain
var building  # Building
var player: Node3D
var player_dead := func(): return false

## Grid: n x n cells of 1 m, cell (i, j) covers x in [i - half, i - half + 1).
var half := 0
var n := 0
var heights := PackedFloat32Array()
var cell_cost := PackedFloat32Array()
## Cost of crossing into (i, j) from (i - 1, j) and from (i, j - 1).
var cross_x := PackedFloat32Array()
var cross_z := PackedFloat32Array()
## Cost of stepping from cell i in direction NEIGH[k]: steps[i * 8 + k] (INF: can't).
## Worked out from the arrays above when the map changes, only round what changed.
var steps := PackedFloat32Array()
## Crossings through an open gate -> the gate's middle (x, z), to aim at.
var gates := {}
## Crossings -> the piece key in the way.
var cross_piece := {}
var map_version := 0
var _map_ok := false
var _build_rev := -1
var _terrain_rev := -1
var _dirty_rects: Array = []
var _redo_t := 0.0
var _clock := 0.0

## name -> Field. "base" leads to the flag, "player" to the player.
var fields := {}

const NEIGH := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


class Field:
	var goal := Vector3.ZERO
	var dist := PackedFloat32Array()   # ready field: cost to the goal (INF: no way)
	var next := PackedInt32Array()     # ready field: the next cell towards the goal
	var ready := false
	var map_version := -1
	var wanted := -100.0
	# Working copy while it is being worked out.
	var computing := false
	var work_map := -1
	var work_goal := Vector3.ZERO
	var wd := PackedFloat32Array()
	var wn := PackedInt32Array()
	var heap_p := PackedFloat32Array()
	var heap_i := PackedInt32Array()
	var heap_n := 0

	func push(p: float, i: int) -> void:
		if heap_n >= heap_p.size():
			heap_p.resize(maxi(64, heap_p.size() * 2))
			heap_i.resize(heap_p.size())
		var k := heap_n
		heap_n += 1
		while k > 0:
			var up := (k - 1) >> 1
			if heap_p[up] <= p:
				break
			heap_p[k] = heap_p[up]
			heap_i[k] = heap_i[up]
			k = up
		heap_p[k] = p
		heap_i[k] = i

	## Takes the cheapest entry off the heap; returns its cell (call top_p first for the cost).
	func pop() -> int:
		var top := heap_i[0]
		heap_n -= 1
		if heap_n > 0:
			var p := heap_p[heap_n]
			var i := heap_i[heap_n]
			var k := 0
			while true:
				var c := k * 2 + 1
				if c >= heap_n:
					break
				if c + 1 < heap_n and heap_p[c + 1] < heap_p[c]:
					c += 1
				if heap_p[c] >= p:
					break
				heap_p[k] = heap_p[c]
				heap_i[k] = heap_i[c]
				k = c
			heap_p[k] = p
			heap_i[k] = i
		return top


func _ready() -> void:
	fields.base = Field.new()
	fields.player = Field.new()
	if terrain and terrain.has_signal("ground_changed"):
		terrain.ground_changed.connect(func(r: Rect2): _dirty_rects.append(r))


# --- The map -------------------------------------------------------------------

func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x) + half, floori(z) + half)


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < n and c.y < n


func inside(p: Vector3) -> bool:
	return n > 0 and in_grid(cell_of(p.x, p.z))


## World (x, z) of a cell's middle, at its ground height.
func cell_point(c: Vector2i) -> Vector3:
	var i := c.y * n + c.x
	return Vector3(c.x - half + 0.5, heights[i] if i >= 0 and i < heights.size() else 0.0, c.y - half + 0.5)


## True if the base or the ground changed since the map was made.
func map_stale() -> bool:
	if not _map_ok:
		return true
	if building and building.revision != _build_rev:
		return true
	if terrain and terrain.revision != _terrain_rev:
		return true
	return not _dirty_rects.is_empty()


## Makes the cost map again from the ground and the pieces at ground level.
func rebuild_map() -> void:
	var want_half: int = int(ceil(building.zone_radius if building else 26.0)) + MARGIN
	var full: bool = want_half != half or not _map_ok or (terrain and terrain.revision != _terrain_rev)
	var old_h := heights.duplicate()
	var old_c := cell_cost.duplicate()
	var old_x := cross_x.duplicate()
	var old_z := cross_z.duplicate()
	if full:
		half = want_half
		n = half * 2
		heights.resize(n * n)
		for j in n:
			for i in n:
				heights[j * n + i] = terrain.surface_height(i - half + 0.5, j - half + 0.5) if terrain else 0.0
	else:
		for r in _dirty_rects:
			var a := cell_of(r.position.x, r.position.y)
			var b := cell_of(r.end.x, r.end.y)
			for j in range(maxi(a.y, 0), mini(b.y + 1, n)):
				for i in range(maxi(a.x, 0), mini(b.x + 1, n)):
					heights[j * n + i] = terrain.surface_height(i - half + 0.5, j - half + 0.5)
	_dirty_rects.clear()
	_terrain_rev = terrain.revision if terrain else 0
	cell_cost.resize(n * n)
	cell_cost.fill(0.0)
	cross_x.resize(n * n)
	cross_x.fill(0.0)
	cross_z.resize(n * n)
	cross_z.fill(0.0)
	gates.clear()
	cross_piece.clear()
	if building:
		_build_rev = building.revision
		_add_pieces()
	if full or steps.size() != n * n * 8:
		steps.resize(n * n * 8)
		for i in n * n:
			_cell_steps(i)
	else:
		# Only round the cells that changed (a step looks up to two cells ahead).
		var mark := PackedByteArray()
		mark.resize(n * n)
		for i in n * n:
			if heights[i] != old_h[i] or cell_cost[i] != old_c[i] or cross_x[i] != old_x[i] or cross_z[i] != old_z[i]:
				var ci := i % n
				var cj := i / n
				for j in range(maxi(cj - 2, 0), mini(cj + 3, n)):
					for k in range(maxi(ci - 2, 0), mini(ci + 3, n)):
						mark[j * n + k] = 1
		for i in n * n:
			if mark[i] == 1:
				_cell_steps(i)
	_map_ok = true
	map_version += 1


## Works out the eight step costs out of cell i.
func _cell_steps(i: int) -> void:
	var a := Vector2i(i % n, i / n)
	for k in 8:
		var b: Vector2i = a + NEIGH[k]
		steps[i * 8 + k] = step_cost(a, b) if in_grid(b) else INF


func _add_pieces() -> void:
	var cs: float = building.CELL
	var per := int(cs)  # nav cells per building cell side (2)
	for key in building.pieces:
		var rec: Dictionary = building.pieces[key]
		var slot: Dictionary = rec.slot
		if int(slot.get("level", 0)) != 0:
			continue
		var def: Dictionary = building.PIECES[rec.type]
		var ox: int = slot.cx * per + half
		var oz: int = slot.cz * per + half
		match slot.kind:
			"edge":
				var cost := piece_cost(rec)
				for k in per:
					var c := Vector2i(ox + k, oz) if slot.dir == 0 else Vector2i(ox, oz + k)
					if not in_grid(c):
						continue
					var idx := c.y * n + c.x
					if slot.dir == 0:
						cross_z[idx] = maxf(cross_z[idx], cost)
					else:
						cross_x[idx] = maxf(cross_x[idx], cost)
					var ck := (idx * 2) + (0 if slot.dir == 0 else 1)
					if cost <= 0.0:
						var mid: Vector3 = building.slot_center(slot)
						gates[ck] = Vector2(mid.x, mid.z)
					else:
						cross_piece[ck] = key
			"cell", "obj":
				var extra := 0.0
				if slot.kind == "obj":
					extra = OBJ_COST.get(rec.type, OBJ_DEFAULT)
					if def.get("noblock", false):
						extra = 0.0
				elif rec.type in building.FOUNDATIONS:
					extra = STEP_COST
				elif not rec.type in DECK_FREE:
					extra = OBJ_DEFAULT
				for kc in building.slot_keys(rec.type, slot):
					var p: Array = str(kc).split(":")
					var bx := int(p[1]) * per + half
					var bz := int(p[2]) * per + half
					for dz in per:
						for dx in per:
							var c := Vector2i(bx + dx, bz + dz)
							if in_grid(c):
								var idx := c.y * n + c.x
								cell_cost[idx] = maxf(cell_cost[idx], extra)


## What it costs a mutant to get past an edge piece (0: an open gate).
func piece_cost(rec: Dictionary) -> float:
	if rec.has("hinge") and rec.get("open", false):
		return 0.0
	var c: float = maxf(float(rec.get("hp", 100.0)), 1.0) * BREAK_COST
	if rec.type == "electric_fence":
		c += FENCE_EXTRA
	if rec.get("locked", false):
		c *= LOCK_MULT
	return c


## Cost of crossing from cell a into the next cell b straight (dx or dz is 1).
func _cross(a: Vector2i, b: Vector2i) -> float:
	if b.x != a.x:
		var i := maxi(a.x, b.x)
		return cross_x[a.y * n + i]
	var j := maxi(a.y, b.y)
	return cross_z[j * n + a.x]


func _climb(ha: float, hb: float) -> float:
	var rise := hb - ha
	if rise > CLIMB_MAX:
		return INF
	if rise > CLIMB_FREE:
		return rise * CLIMB_COST
	return 0.0


## Cost of a mutant moving from cell a to the neighbouring cell b (INF: it can't).
func step_cost(a: Vector2i, b: Vector2i) -> float:
	var ia := a.y * n + a.x
	var ib := b.y * n + b.x
	# Look one cell further too: a mutant can't climb a slope it can't stand on,
	# so the rise counts from where it last stood (as rim_ahead() in mutant.gd).
	var hb := heights[ib]
	var far := b + (b - a)
	if hb - heights[ia] > CLIMB_FREE and far.x >= 0 and far.y >= 0 and far.x < n and far.y < n:
		hb = maxf(hb, heights[far.y * n + far.x])
	var climb := _climb(heights[ia], hb)
	if climb == INF:
		return INF
	if a.x == b.x or a.y == b.y:
		return 1.0 + cell_cost[ib] + _cross(a, b) + climb
	# Diagonal: only past open corners (both cells beside it clear, no wall on the way).
	var m1 := Vector2i(b.x, a.y)
	var m2 := Vector2i(a.x, b.y)
	var i1 := m1.y * n + m1.x
	var i2 := m2.y * n + m2.x
	if cell_cost[i1] > 0.0 or cell_cost[i2] > 0.0:
		return INF
	if _cross(a, m1) > 0.0 or _cross(m1, b) > 0.0 or _cross(a, m2) > 0.0 or _cross(m2, b) > 0.0:
		return INF
	if is_inf(_climb(heights[ia], heights[i1])) or is_inf(_climb(heights[ia], heights[i2])):
		return INF
	return 1.41421 * (1.0 + cell_cost[ib]) + climb


# --- Fields --------------------------------------------------------------------

## Starts working out a field towards goal.
func _begin(f: Field, goal: Vector3) -> void:
	f.computing = true
	f.work_goal = goal
	f.wd.resize(n * n)
	f.wd.fill(INF)
	f.wn.resize(n * n)
	f.wn.fill(-1)
	f.heap_n = 0
	var g := cell_of(goal.x, goal.z)
	g.x = clampi(g.x, 0, n - 1)
	g.y = clampi(g.y, 0, n - 1)
	var gi := g.y * n + g.x
	f.wd[gi] = 0.0
	f.wn[gi] = gi
	f.push(0.0, gi)
	f.work_map = map_version


## Settles up to budget cells. Returns true when the field is done (and swapped in).
func _advance(f: Field, budget: int) -> bool:
	var count := 0
	while f.heap_n > 0 and count < budget:
		var p := f.heap_p[0]
		var ci := f.pop()
		if p > f.wd[ci]:
			continue
		count += 1
		var cx := ci % n
		var cz := ci / n
		# Each neighbour a = c - NEIGH[k] that steps into c in direction k.
		for k in 8:
			var o: Vector2i = NEIGH[k]
			var ax := cx - o.x
			var az := cz - o.y
			if ax < 0 or az < 0 or ax >= n or az >= n:
				continue
			var ai := az * n + ax
			var nd := p + steps[ai * 8 + k]
			if nd < f.wd[ai]:
				f.wd[ai] = nd
				f.wn[ai] = ci
				f.push(nd, ai)
	if f.heap_n > 0:
		return false
	f.dist = f.wd.duplicate()
	f.next = f.wn.duplicate()
	f.goal = f.work_goal
	f.map_version = f.work_map
	f.ready = true
	f.computing = false
	return true


## Works out a field right away (tests, and the first time after loading).
func compute_now(name: String, goal: Vector3) -> Field:
	if map_stale():
		rebuild_map()
	var f: Field = fields[name]
	_begin(f, goal)
	_advance(f, 1 << 30)
	return f


func _player_goal() -> Variant:
	if player == null or player_dead.call() or not inside(player.global_position):
		return null
	return player.global_position


func _physics_process(delta: float) -> void:
	_clock += delta
	_redo_t -= delta
	var any := false
	for name in fields:
		if _clock - fields[name].wanted < WANT_SECONDS:
			any = true
	if not any:
		return
	if map_stale() and _redo_t <= 0.0 and not fields.values().any(func(f): return f.computing):
		rebuild_map()
		_redo_t = REDO_GAP
	for name in fields:
		var f: Field = fields[name]
		if _clock - f.wanted >= WANT_SECONDS:
			continue
		var goal: Variant = Vector3.ZERO if name == "base" else _player_goal()
		if goal == null:
			f.ready = false
			f.computing = false
			continue
		if not f.computing:
			var moved: bool = f.ready and Vector2(f.goal.x - goal.x, f.goal.z - goal.z).length() > GOAL_MOVE
			if not f.ready or f.map_version != map_version or moved:
				_begin(f, goal)
		if f.computing:
			_advance(f, BUDGET)


# --- Steering ------------------------------------------------------------------

## Which way a mutant at pos should walk to follow field `name`, or ZERO when the
## field can't help (not ready, outside the grid, no way from here, or close
## enough to just go straight). Also asks for the field to be kept up.
func direction(name: String, pos: Vector3) -> Vector3:
	var f: Field = fields.get(name)
	if f == null:
		return Vector3.ZERO
	f.wanted = _clock
	if not f.ready or n == 0 or f.dist.size() != n * n:
		return Vector3.ZERO
	var c := cell_of(pos.x, pos.z)
	if not in_grid(c):
		return Vector3.ZERO
	if Vector2(pos.x - f.goal.x, pos.z - f.goal.z).length() < NEAR_GOAL:
		return Vector3.ZERO
	var ci := c.y * n + c.x
	if is_inf(f.dist[ci]) or f.next[ci] == ci:
		return Vector3.ZERO
	var aim := _aim(f, ci)
	var to := Vector3(aim.x - pos.x, 0, aim.y - pos.z)
	if to.length() < 0.05:
		return Vector3.ZERO
	return to.normalized()


## The point to aim at: along the path while it runs straight over open cells,
## the middle of an open gate, or the next cell when a wall is in the way (so
## the mutant walks into it and tears it down).
func _aim(f: Field, ci: int) -> Vector2:
	var cur := ci
	var first_dir := Vector2i.ZERO
	var aim := Vector2.ZERO
	for s in LOOKAHEAD:
		var nx: int = f.next[cur]
		if nx < 0 or nx == cur:
			break
		var a := Vector2i(cur % n, cur / n)
		var b := Vector2i(nx % n, nx / n)
		var d := b - a
		if s == 0:
			first_dir = d
		elif d != first_dir:
			break
		var gate := _gate_between(a, b)
		if gate != Vector2.INF:
			return gate if s == 0 else aim
		var pt := Vector2(b.x - half + 0.5, b.y - half + 0.5)
		if s > 0 and (cell_cost[nx] > 0.0 or (d.x != 0 and d.y == 0 and _cross(a, b) > 0.0) or (d.y != 0 and d.x == 0 and _cross(a, b) > 0.0)):
			break
		aim = pt
		if s == 0 and (cell_cost[nx] > 0.0 or ((d.x == 0 or d.y == 0) and _cross(a, b) > 0.0)):
			break
		cur = nx
	return aim


func _gate_between(a: Vector2i, b: Vector2i) -> Vector2:
	if a.x != b.x and a.y != b.y:
		return Vector2.INF
	var ck: int
	if b.x != a.x:
		ck = (a.y * n + maxi(a.x, b.x)) * 2 + 1
	else:
		ck = (maxi(a.y, b.y) * n + a.x) * 2
	return gates.get(ck, Vector2.INF)


## True if the next step from pos along field `name` is open (no wall to tear
## down), so a mutant bumping into something should go round it, not wreck it.
func way_clear(name: String, pos: Vector3) -> bool:
	var f: Field = fields.get(name)
	if f == null or not f.ready or f.dist.size() != n * n:
		return false
	var c := cell_of(pos.x, pos.z)
	if not in_grid(c):
		return false
	var ci := c.y * n + c.x
	var nx: int = f.next[ci]
	if nx < 0 or nx == ci or is_inf(f.dist[ci]):
		return false
	var b := Vector2i(nx % n, nx / n)
	return (c.x != b.x and c.y != b.y) or _cross(c, b) <= 0.0


## The cells from pos to the goal along a field (tests and debugging).
func trace(f: Field, pos: Vector3, limit := 4000) -> Array:
	var out: Array = []
	var c := cell_of(pos.x, pos.z)
	if not in_grid(c):
		return out
	var ci := c.y * n + c.x
	if is_inf(f.dist[ci]):
		return out
	for s in limit:
		out.append(Vector2i(ci % n, ci / n))
		var nx: int = f.next[ci]
		if nx < 0 or nx == ci:
			break
		ci = nx
	return out


## Piece keys a path crosses (walls it would tear down), and "gate:<key>" for open gates.
func pieces_on(path: Array) -> Array:
	var out: Array = []
	for k in range(1, path.size()):
		var a: Vector2i = path[k - 1]
		var b: Vector2i = path[k]
		if a.x != b.x and a.y != b.y:
			continue
		var ck: int = (a.y * n + maxi(a.x, b.x)) * 2 + 1 if b.x != a.x else (maxi(a.y, b.y) * n + a.x) * 2
		if cross_piece.has(ck):
			out.append(cross_piece[ck])
		elif gates.has(ck):
			out.append("gate")
	return out

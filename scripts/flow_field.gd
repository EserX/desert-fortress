extends RefCounted
## Mutant pathfinding round the base: a 1 m grid (a flow field) holding, for
## every cell, how costly it is to reach the goal from there. Open sand costs
## a metre; walls, gates and fences on the building grid's lines cost what it
## takes to claw through them (more hit points, more cost); an open gate costs
## nothing. Traps and pits make cells dearer, a pit deeper than a mutant can
## climb out of very dear. Mutants then walk downhill: round to an open gate,
## or through the weakest wall on the cheapest way in, all of them through the
## same one.

const N := 96            # cells across; the grid is centred on the flag
const HALF := 48
const PIT_DEEP := 1.9    # a mutant can't climb out of this (mutant CLIMB_MAX)
const PIT_DEEP_COST := 80.0
const PIT_COST := 10.0   # per pit cell it can climb out of, slowly
const TRAP_COST := 8.0
const WALL_BASE := 4.0   # cost to start clawing at a wall...
const WALL_PER_HP := 1.0 / 12.0  # ...and per hit point (a walker does ~14 hp/s)
const LIVE_FENCE := 30.0 # extra for an electric fence with the power on
const FOUNDATION_COST := 0.5
const GATE_COST := 0.01  # an open gate: walked straight through

## Goal cell (grid coordinates).
var goal := Vector2i(HALF, HALF)
## Cost per cell to step into it (1 = open sand).
var cell_cost := PackedFloat32Array()
## Extra cost to cross the line between cell (x, z) and (x + 1, z) / (x, z + 1).
var edge_x := PackedFloat32Array()
var edge_z := PackedFloat32Array()
## Edge index -> world point to aim at when passing (the middle of an open gate).
var portal_x := {}
var portal_z := {}
## Cost from each cell to the goal.
var dist := PackedFloat32Array()
## Building version and when it was worked out, to know when to redo it.
var built_version := -1
var built_at := -1000.0

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


static func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x) + HALF, floori(p.z) + HALF)


static func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x - HALF + 0.5, 0, c.y - HALF + 0.5)


static func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


## A field being worked out on a worker thread, and its task id (-1: none).
var _job: RefCounted
var _job_id := -1


## Works the field out again for goal point g, right now.
func rebuild(building, terrain, g: Vector3) -> void:
	finish_job()
	goal = _goal_cell(g)
	_costs(building, terrain)
	_dijkstra()
	built_version = building.version if building and "version" in building else 0


static func _goal_cell(g: Vector3) -> Vector2i:
	var c := to_cell(g)
	return Vector2i(clampi(c.x, 0, N - 1), clampi(c.y, 0, N - 1))


## Works the field out again on a worker thread (the search takes tens of
## milliseconds); the old field is used until poll() finds it done.
func rebuild_async(building, terrain, g: Vector3) -> void:
	if _job_id != -1:
		return
	var f = get_script().new()
	f.goal = _goal_cell(g)
	f._costs(building, terrain)
	_job = f
	built_version = building.version if building and "version" in building else 0
	_job_id = WorkerThreadPool.add_task(f._dijkstra, false, "mutant pathfinding")


## Takes over a finished background field. Returns true if one came in.
func poll() -> bool:
	if _job_id == -1 or not WorkerThreadPool.is_task_completed(_job_id):
		return false
	finish_job()
	return true


## Waits for a background field and takes it over.
func finish_job() -> void:
	if _job_id == -1:
		return
	WorkerThreadPool.wait_for_task_completion(_job_id)
	_job_id = -1
	var f = _job
	_job = null
	goal = f.goal
	cell_cost = f.cell_cost
	edge_x = f.edge_x
	edge_z = f.edge_z
	portal_x = f.portal_x
	portal_z = f.portal_z
	dist = f.dist


## Lays the costs of the ground, traps and building pieces on the grid.
func _costs(building, terrain) -> void:
	cell_cost.resize(N * N)
	cell_cost.fill(1.0)
	edge_x.resize(N * N)
	edge_x.fill(0.0)
	edge_z.resize(N * N)
	edge_z.fill(0.0)
	portal_x = {}
	portal_z = {}
	if terrain and "delta" in terrain and terrain.delta.size() == (N + 1) * (N + 1):
		# The dug ground shares this grid (1 m cells from -48 m): average its corners.
		var dl: PackedFloat32Array = terrain.delta
		var w := N + 1
		for z in N:
			for x in N:
				var d := -(dl[z * w + x] + dl[z * w + x + 1] + dl[(z + 1) * w + x] + dl[(z + 1) * w + x + 1]) * 0.25
				if d >= PIT_DEEP:
					cell_cost[z * N + x] += PIT_DEEP_COST
				elif d > 0.8:
					cell_cost[z * N + x] += PIT_COST
	if building == null:
		return
	for key in building.pieces:
		var rec: Dictionary = building.pieces[key]
		var s: Dictionary = rec.slot
		if int(s.get("level", 0)) != 0:
			continue
		var info: Dictionary = building.PIECES[rec.type]
		if s.kind == "edge":
			var cost := 0.0
			var portal := Vector3.INF
			if info.get("gate", false) and rec.get("open", false):
				# Next to nothing, but enough that no diagonal cuts past the gate posts.
				cost = GATE_COST
				portal = building.slot_center(s)
			else:
				cost = WALL_BASE + float(rec.hp) * WALL_PER_HP
				if rec.get("powered", false):
					cost += LIVE_FENCE
			_edge(s, cost, portal)
		elif s.kind == "cell" or s.kind == "obj":
			var add := 0.0
			if rec.type in building.FOUNDATIONS:
				add = FOUNDATION_COST
			elif info.get("trap", false):
				add = TRAP_COST
			elif rec.type == "spikes":
				add = WALL_BASE + float(rec.hp) * WALL_PER_HP + TRAP_COST
			if add > 0.0:
				for oz in 2:
					for ox in 2:
						var c := Vector2i(int(s.cx) * 2 + ox + HALF, int(s.cz) * 2 + oz + HALF)
						if inside(c):
							cell_cost[c.y * N + c.x] += add


## A piece on a building-grid line (2 m long) between two rows or columns of cells.
func _edge(s: Dictionary, cost: float, portal: Vector3) -> void:
	for i in 2:
		if int(s.dir) == 0:
			# Runs along x at z = cz * 2: between rows z - 1 and z.
			var c := Vector2i(int(s.cx) * 2 + i + HALF, int(s.cz) * 2 - 1 + HALF)
			if inside(c) and c.y + 1 < N:
				edge_z[c.y * N + c.x] = maxf(edge_z[c.y * N + c.x], cost)
				if portal != Vector3.INF:
					portal_z[c.y * N + c.x] = portal
		else:
			var c := Vector2i(int(s.cx) * 2 - 1 + HALF, int(s.cz) * 2 + i + HALF)
			if inside(c) and c.x + 1 < N:
				edge_x[c.y * N + c.x] = maxf(edge_x[c.y * N + c.x], cost)
				if portal != Vector3.INF:
					portal_x[c.y * N + c.x] = portal


## Extra cost of crossing from cell a to its orthogonal neighbour b.
func _cross(a: Vector2i, b: Vector2i) -> float:
	if b.x != a.x:
		var x := mini(a.x, b.x)
		return edge_x[a.y * N + x]
	var z := mini(a.y, b.y)
	return edge_z[z * N + a.x]


## Cost of one step from a to neighbour b (diagonals only past open corners),
## or INF if it can't be taken that way.
func step_cost(a: Vector2i, b: Vector2i) -> float:
	if not inside(b):
		return INF
	var d := b - a
	if d.x != 0 and d.y != 0:
		var m1 := Vector2i(b.x, a.y)
		var m2 := Vector2i(a.x, b.y)
		if _cross(a, m1) > 0.0 or _cross(m1, b) > 0.0 or _cross(a, m2) > 0.0 or _cross(m2, b) > 0.0:
			return INF
		return cell_cost[b.y * N + b.x] * 1.4142
	return cell_cost[b.y * N + b.x] + _cross(a, b)


## Cheapest cost from every cell to the goal (Dijkstra from the goal outwards;
## steps cost the same both ways round). Written with flat indices: it runs
## for 9216 cells whenever the base changes.
func _dijkstra() -> void:
	dist.resize(N * N)
	dist.fill(INF)
	var heap_k := PackedFloat32Array()
	var heap_v := PackedInt32Array()
	var gi := goal.y * N + goal.x
	dist[gi] = 0.0
	_push(heap_k, heap_v, 0.0, gi)
	var cc := cell_cost
	var ex := edge_x
	var ez := edge_z
	while heap_v.size() > 0:
		var k := heap_k[0]
		var i := heap_v[0]
		_pop(heap_k, heap_v)
		if k > dist[i]:
			continue
		var ax := i % N
		var az := i / N
		var ca: float = cc[i]
		# Orthogonal: from neighbour j into a, crossing the line between them.
		if ax + 1 < N:
			_relax(heap_k, heap_v, i + 1, k + ca + ex[i])
		if ax > 0:
			_relax(heap_k, heap_v, i - 1, k + ca + ex[i - 1])
		if az + 1 < N:
			_relax(heap_k, heap_v, i + N, k + ca + ez[i])
		if az > 0:
			_relax(heap_k, heap_v, i - N, k + ca + ez[i - N])
		# Diagonal: only where no line is crossed round the corner.
		var dc := ca * 1.4142
		for d in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var bx: int = ax + d.x
			var bz: int = az + d.y
			if bx < 0 or bz < 0 or bx >= N or bz >= N:
				continue
			var x0 := mini(ax, bx)
			var z0 := mini(az, bz)
			# The four lines round the 2x2 block of a, b and the two corner cells.
			if ex[z0 * N + x0] > 0.0 or ex[(z0 + 1) * N + x0] > 0.0 or ez[z0 * N + x0] > 0.0 or ez[z0 * N + x0 + 1] > 0.0:
				continue
			_relax(heap_k, heap_v, bz * N + bx, k + dc)


func _relax(hk: PackedFloat32Array, hv: PackedInt32Array, j: int, nd: float) -> void:
	if nd < dist[j]:
		dist[j] = nd
		_push(hk, hv, nd, j)


static func _push(hk: PackedFloat32Array, hv: PackedInt32Array, k: float, v: int) -> void:
	hk.append(k)
	hv.append(v)
	var i := hk.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if hk[p] <= hk[i]:
			break
		var tk := hk[p]
		hk[p] = hk[i]
		hk[i] = tk
		var tv := hv[p]
		hv[p] = hv[i]
		hv[i] = tv
		i = p


static func _pop(hk: PackedFloat32Array, hv: PackedInt32Array) -> void:
	var last := hk.size() - 1
	hk[0] = hk[last]
	hv[0] = hv[last]
	hk.resize(last)
	hv.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		if l >= last:
			break
		var m := l
		if l + 1 < last and hk[l + 1] < hk[l]:
			m = l + 1
		if hk[i] <= hk[m]:
			break
		var tk := hk[m]
		hk[m] = hk[i]
		hk[i] = tk
		var tv := hv[m]
		hv[m] = hv[i]
		hv[i] = tv
		i = m


## Cost to the goal from world point p (INF outside the grid).
func cost_from(p: Vector3) -> float:
	var c := to_cell(p)
	return dist[c.y * N + c.x] if inside(c) and dist.size() == N * N else INF


## The neighbour cell to walk to from cell c, or c itself at the goal.
func next_cell(c: Vector2i) -> Vector2i:
	var best := c
	if dist[c.y * N + c.x] <= 0.0 or dist[c.y * N + c.x] == INF:
		return c
	var best_d := INF
	for d in DIRS:
		var b: Vector2i = c + d
		var sc := step_cost(c, b)
		if sc == INF:
			continue
		var nd: float = dist[b.y * N + b.x] + sc
		if nd < best_d - 0.001:
			best_d = nd
			best = b
	return best


## Which way to walk from p (flat, normalised), or ZERO outside the grid or at
## the goal. Through an open gate it aims at the middle of the gateway.
func direction(p: Vector3) -> Vector3:
	var c := to_cell(p)
	if not inside(c) or dist.size() != N * N:
		return Vector3.ZERO
	var n := next_cell(c)
	if n == c:
		return Vector3.ZERO
	var aim := cell_center(n)
	if n.x != c.x and n.y == c.y and portal_x.has(c.y * N + mini(c.x, n.x)):
		aim = _through(portal_x[c.y * N + mini(c.x, n.x)], p, Vector3(signf(n.x - c.x), 0, 0))
	elif n.y != c.y and n.x == c.x and portal_z.has(mini(c.y, n.y) * N + c.x):
		aim = _through(portal_z[mini(c.y, n.y) * N + c.x], p, Vector3(0, 0, signf(n.y - c.y)))
	var to := aim - p
	to.y = 0
	return to.normalized() if to.length() > 0.01 else Vector3.ZERO


## Where to aim to pass through a gateway (middle g, crossing in direction
## dir): first in line in front of it, then straight through, so the posts
## aren't clipped.
static func _through(g: Vector3, p: Vector3, dir: Vector3) -> Vector3:
	var side := Vector3(dir.z, 0, -dir.x)  # along the wall
	var off := (p - g).dot(side)
	if absf(off) > 0.2:
		return g - dir * 0.9
	return g + dir * 1.0


## The cells walked from p to the goal (at most max_steps), for tests and the map.
func path_from(p: Vector3, max_steps := 400) -> Array:
	var out: Array = []
	var c := to_cell(p)
	if not inside(c):
		return out
	out.append(c)
	for i in max_steps:
		var n := next_cell(c)
		if n == c:
			break
		out.append(n)
		c = n
	return out


## Total wall cost crossed along a path (0 if it only goes through open ways).
func wall_cost_on(path: Array) -> float:
	var t := 0.0
	for i in range(1, path.size()):
		var a: Vector2i = path[i - 1]
		var b: Vector2i = path[i]
		if a.x != b.x and a.y != b.y:
			continue
		t += _cross(a, b)
	return t

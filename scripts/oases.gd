extends Node3D
## Oases and outposts (v1.18).
## Three to five oases lie hidden out in the desert, each round a spring: a pond
## with reeds to cut, a clay bank to dig, a few wild palms and an old stash of
## rare seeds. Mutant guards come out when you get close. Some oases also have a
## **nest**: while it stands the land round it stays dead (no green, the palms
## are dead stumps) and it keeps sending out guards. Burn it with a fuel can.
## Once the nest is gone and the guards are dead, claim the oasis at its marker
## post: it becomes an **outpost** with its own build zone, and its spring
## waters the land round it every morning.
## Where the oases lie comes from the world seed, so the same world has the
## same oases.

const LowPoly = preload("res://scripts/lowpoly.gd")
const Water = preload("res://scripts/water.gd")
const Items = preload("res://scripts/items.gd")
const BaseZone = preload("res://scripts/base_zone.gd")

const MIN_R := 85.0           # oases lie this far from the base...
const MAX_R := 195.0          # ...and no further (the mountains start past 210 m)
const SPACING := 70.0         # and this far apart
const CLEAR_R := 11.0         # no rock, tree, wreck or ruin this close to the pond
const FLAT_R := 8.0           # the ground this far round is fairly flat
const FLAT_MAX := 1.4         # (highest minus lowest point, metres)
const POND_R := 4.5
const SPRING_R := 10.0        # a wild spring keeps the land this close green
const OUTPOST_SPRING_R := 14.0  # and a claimed one waters further
const OUTPOST_R := 16.0       # an outpost's build zone round its marker post
const NEST_DIST := 10.0       # the nest stands this far from the pond
const NEST_R := 26.0          # a living nest keeps the land this close to it dead
const FIND_R := 35.0          # you find an oasis when you come this close
const WAKE_R := 55.0          # its guards come out when you are this close
const GUARD_CAP := 3          # guards out at once at an oasis
const GUARDS := 3             # guards at an oasis without a nest
const NEST_GUARDS := 4        # and with one (a nest breeds more, up to this many)
const NEST_BREED := 60.0      # seconds a living nest takes to breed another guard
const BURN_TIME := 6.0        # seconds a nest burns before it's gone
const REEDS_DAY := 8          # reeds you can cut a day at one oasis
const CLAY_DAY := 6           # clay you can dig a day
const TAKE := 2               # reeds or clay one press gives
const CLAIM_COST := {"wood": 6, "cloth": 2}
const TICK := 0.5
const GUARD_KINDS := ["walker", "runner", "walker", "spitter"]

signal message(text: String)
signal pickup(lines: Array)
signal spilled(items: Dictionary, pos: Vector3)
## An oasis became an outpost (main tells building and saving).
signal claimed(index: int)

var terrain  # Terrain
var water  # Water (the spring greens the land, the nest kills it)
var building  # Building (outposts' build zones)
var mutants  # Mutants (the guards)
var inventory  # Inventory
var survival  # Survival (drinking at the spring)
var player: Node3D
var player_dead := func(): return false
## func(cost) -> bool and func(cost) -> bool: pay from pockets and chests in reach (main's pay_near / has_near).
var pay := Callable()
var has_cost := Callable()
var world_seed := 1337
## Peaceful mode (v1.19): no guards come out and nests don't breed (they still kill the land).
var peaceful := false
## One entry per oasis: {"pos": Vector3 (pond centre), "nest_pos", "post_pos",
## "stash_pos", "clay_pos", "has_nest": bool (from the seed), "nest": "alive",
## "burning" or "gone" ("none" without one), "guards": guards still to come,
## "found", "claimed", "stash" (searched), "reeds" / "clay" (taken today),
## "breed" (seconds towards the next guard), "burn" (seconds burning)}.
var list: Array = []
var _nodes: Array = []  # per oasis: {"root", "pond_area", "reeds", "reed_mm", "stash", "nest", "flames", "post", "flag", "palms", "stumps", "zone", "ash"}
var _t := 0.0
var _avoid: Array = []
var _mats := {}


# --- Where they lie -----------------------------------------------------------------

## The oasis spots for a world: 3 to 5 pond centres (y = ground), away from the
## base, from each other and from the props in `avoid` (Vector3s).
static func find_spots(seed_value: int, ground: Object, avoid: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("oases:%d" % seed_value)
	var want := rng.randi_range(3, 5)
	var out: Array = []
	for pass_i in 2:  # a second, less fussy pass if the dunes are rough
		var flat_max := FLAT_MAX * (1.0 + pass_i * 1.5)
		for attempt in 500:
			if out.size() >= want:
				break
			var a := rng.randf() * TAU
			var r := rng.randf_range(MIN_R, MAX_R)
			var p := Vector2(cos(a) * r, sin(a) * r)
			if out.any(func(o): return Vector2(o.x, o.z).distance_to(p) < SPACING):
				continue
			var lo := INF
			var hi := -INF
			for k in 9:
				var q := p if k == 8 else p + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * FLAT_R
				var h: float = ground.surface_height(q.x, q.y)
				lo = minf(lo, h)
				hi = maxf(hi, h)
			if hi - lo > flat_max:
				continue
			var clear := true
			for v in avoid:  # a few hundred props, for a few hundred tries, once per world
				if absf(v.x - p.x) < CLEAR_R and absf(v.z - p.y) < CLEAR_R and Vector2(v.x, v.z).distance_to(p) < CLEAR_R:
					clear = false
					break
			if clear:
				out.append(Vector3(p.x, ground.surface_height(p.x, p.y), p.y))
	return out


## Builds the oases of this world (positions, nests, looks). `avoid`: props.
func setup(avoid: Array) -> void:
	_avoid = avoid
	for n in _nodes:
		n.root.queue_free()
	_nodes = []
	list = []
	var spots := find_spots(world_seed, terrain, avoid)
	# Nearest first, so the first one you're likely to meet has no nest.
	spots.sort_custom(func(a, b): return Vector2(a.x, a.z).length() < Vector2(b.x, b.z).length())
	var nests: Array = []
	for i in spots.size():
		var nr := RandomNumberGenerator.new()
		nr.seed = hash("oasis_nest:%d:%d" % [world_seed, i])
		nests.append(i > 0 and nr.randf() < 0.6)
	if spots.size() > 1 and not nests.has(true):
		nests[nests.size() - 1] = true  # always at least one nest to burn
	for i in spots.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("oasis:%d:%d" % [world_seed, i])
		var c: Vector3 = spots[i]
		var has_nest: bool = nests[i]
		var an := rng.randf() * TAU
		var o := {"pos": c, "has_nest": has_nest,
			"nest_pos": _on_ground(c, an, NEST_DIST),
			"post_pos": _on_ground(c, an + PI, POND_R + 3.0),
			"stash_pos": _on_ground(c, an + PI * 0.6, POND_R + 2.0),
			"clay_pos": _on_ground(c, an - PI * 0.55, POND_R + 1.2),
			"reed_a": an + PI * 1.45}
		_reset_state(o)
		list.append(o)
		_nodes.append(_build(i, rng))
	for i in list.size():
		_refresh(i)


func _on_ground(c: Vector3, a: float, d: float) -> Vector3:
	var x := c.x + cos(a) * d
	var z := c.z + sin(a) * d
	return Vector3(x, terrain.surface_height(x, z), z)


## A new world's state for an oasis.
static func _reset_state(o: Dictionary) -> void:
	o.nest = "alive" if o.has_nest else "none"
	o.guards = NEST_GUARDS if o.has_nest else GUARDS
	o.found = false
	o.claimed = false
	o.stash = false
	o.reeds = 0
	o.clay = 0
	o.breed = 0.0
	o.burn = 0.0


## The land round the wild springs of a new world: green round the oases
## without a nest (a nest keeps its oasis dead).
func green_new_world() -> void:
	for o in list:
		if o.nest != "none":
			continue
		for c in _cells_near(Vector2(o.pos.x, o.pos.z), SPRING_R):
			var d := Water.cell_center(c).distance_to(Vector2(o.pos.x, o.pos.z))
			water.add_life(c, Water.SOIL_NEED * 2.0, clampf(1.2 - d / SPRING_R, 0.3, 1.0))


## The ground squares whose centre is within r of p.
static func _cells_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var a := Water.cell_of(p.x - r, p.y - r)
	var b := Water.cell_of(p.x + r, p.y + r)
	for x in range(a.x, b.x + 1):
		for z in range(a.y, b.y + 1):
			var c := Vector2i(x, z)
			if Water.cell_center(c).distance_to(p) <= r:
				out.append(c)
	return out


func count() -> int:
	return list.size()


func nest_alive(i: int) -> bool:
	return list[i].nest == "alive" or list[i].nest == "burning"


# --- Every half second ---------------------------------------------------------------

func _process(delta: float) -> void:
	for i in list.size():  # the burning flames flicker every frame (3 to 5 oases)
		if list[i].nest == "burning":
			_burn_step(i, delta)
	_t += delta
	if _t < TICK:
		return
	tick(_t)
	_t = 0.0


## Finding oases, guards coming out, nests breeding. Every TICK s over 3 to 5 oases.
func tick(dt: float) -> void:
	if player == null:
		return
	var pp := Vector2(player.global_position.x, player.global_position.z)
	for i in list.size():
		var o: Dictionary = list[i]
		var d := pp.distance_to(Vector2(o.pos.x, o.pos.z))
		if not o.found and d < FIND_R:
			o.found = true
			var text := "You found an oasis! A spring, reeds, clay and an old stash." + ("" if peaceful else " Guards are about.")
			if nest_alive(i):
				text = "You found an oasis, but a mutant nest keeps it dead. Burn the nest (a fuel can and E)."
			message.emit(text)
		if o.nest == "alive" and o.guards < NEST_GUARDS and not peaceful:
			o.breed += dt
			if o.breed >= NEST_BREED:
				o.breed = 0.0
				o.guards += 1
		if not o.claimed and d < WAKE_R and not player_dead.call():
			wake_guards(i)


## Mutants guarding oasis i (alive).
func guards_of(i: int) -> Array:
	if mutants == null:
		return []
	return mutants.alive().filter(func(m): return m.guard_of == i)


## Sends out guards until GUARD_CAP are about (or none are left). Returns how many came.
func wake_guards(i: int) -> int:
	var o: Dictionary = list[i]
	if peaceful:
		return 0
	var out := guards_of(i).size()
	var n := 0
	while out < GUARD_CAP and o.guards > 0:
		var rng := RandomNumberGenerator.new()
		var k: int = (NEST_GUARDS if o.has_nest else GUARDS) - o.guards
		rng.seed = hash("guard:%d:%d:%d:%d" % [world_seed, i, k, o.guards])
		var kinds: Array = GUARD_KINDS if o.has_nest else GUARD_KINDS.slice(0, 3)
		var from: Vector3 = o.nest_pos if nest_alive(i) else o.pos
		var a := rng.randf() * TAU
		var p := from + Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.5, 6.0)
		var m = mutants.spawn(kinds[k % kinds.size()], p)
		m.guard_of = i
		m.home = Vector3(o.pos.x, m.position.y, o.pos.z)
		o.guards -= 1
		out += 1
		n += 1
	return n


# --- Mornings ------------------------------------------------------------------------

## New day (water.gd's morning_tally, before the squares' litres are cleared):
## springs water the land round them, living nests keep theirs dead, and the
## reeds and clay come back.
func on_tally() -> void:
	for o in list:  # 3 to 5 oases, each over a few dozen ground squares
		o.reeds = 0
		o.clay = 0
		if o.nest == "alive":
			for c in _cells_near(Vector2(o.nest_pos.x, o.nest_pos.z), NEST_R):
				water.clear_cell(c)
			continue
		for c in _cells_near(Vector2(o.pos.x, o.pos.z), OUTPOST_SPRING_R if o.claimed else SPRING_R):
			water.add_life(c, Water.SOIL_NEED, 0.0)
			water.water_cell(c, Water.DAY_NEED)
	for i in list.size():
		_refresh(i)


## Green on the squares round wild (unclaimed) oases: the desert's own, so it
## doesn't draw the night waves (raids.gd takes it off the lure).
func wild_green() -> float:
	var g := 0.0
	for o in list:  # 3 to 5 oases, a few dozen squares each, at the dusk siren
		if o.claimed:
			continue
		for c in _cells_near(Vector2(o.pos.x, o.pos.z), SPRING_R + Water.CELL):
			g += water.green_of(c)
	return g


# --- E -------------------------------------------------------------------------------

## "oasis:<what>:<i>" -> [what, i], or ["", -1].
func _parse(id: String) -> Array:
	var p := id.split(":")
	if p.size() != 3 or not p[2].is_valid_int() or int(p[2]) < 0 or int(p[2]) >= list.size():
		return ["", -1]
	return [p[1], int(p[2])]


func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		parts.append("%d %s" % [cost[k], Items.display_name(k).to_lower()])
	return ", ".join(parts)


## Why oasis i can't be claimed yet ("" if it can, or is already).
func claim_problem(i: int) -> String:
	var o: Dictionary = list[i]
	if o.claimed:
		return ""
	if nest_alive(i):
		return "Burn out the mutant nest first"
	var left: int = guards_of(i).size() + (0 if peaceful else int(o.guards))
	if left > 0:
		return "Kill the guards first (%d left)" % left
	if has_cost.is_valid() and not has_cost.call(CLAIM_COST):
		return "You need %s to claim it" % _cost_text(CLAIM_COST)
	return ""


func prompt(id: String) -> String:
	var w: Array = _parse(id)
	if w[1] < 0:
		return ""
	var i: int = w[1]
	var o: Dictionary = list[i]
	match w[0]:
		"spring":
			var can: bool = inventory != null and inventory.count_of("watering_can") > 0
			if survival and survival.water >= survival.MAX - 0.5 and (not can or water.can >= Water.CAN_MAX - 0.01):
				return "Spring: fresh water\nYou've had your fill"
			return "Spring: fresh water\n[E] Drink" + (" and fill the watering can" if can else "")
		"reeds":
			if o.reeds >= REEDS_DAY:
				return "Reeds\nCut for today (they grow back by morning)"
			return "Reeds (%d left today)\n[E] Cut reeds" % (REEDS_DAY - o.reeds)
		"clay":
			if o.clay >= CLAY_DAY:
				return "Clay bank\nDug out for today (the spring brings more by morning)"
			return "Clay bank (%d left today)\n[E] Dig clay" % (CLAY_DAY - o.clay)
		"stash":
			return "" if o.stash else "An old stash, half buried\n[E] Search it"
		"nest":
			if o.nest == "burning":
				return "The nest is burning"
			if o.nest != "alive":
				return ""
			if inventory == null or inventory.count_of("fuel") <= 0:
				return "Mutant nest: it keeps the land round it dead\nYou need a fuel can to burn it (car trunks, the shop)"
			return "Mutant nest: it keeps the land round it dead\n[E] Burn it (uses 1 fuel can)"
		"post":
			if o.claimed:
				return "Outpost %d: build within %d m of this flag" % [i + 1, int(OUTPOST_R)]
			var why := claim_problem(i)
			var head := "Claim this oasis as an outpost (its own %d m build zone, its spring waters the land)" % int(OUTPOST_R)
			if why != "":
				return head + "\n" + why
			return head + "\n[E] Claim it (%s)" % _cost_text(CLAIM_COST)
	return ""


func interact(id: String) -> bool:
	var w: Array = _parse(id)
	if w[1] < 0:
		return false
	match w[0]:
		"spring":
			return drink(w[1])
		"reeds":
			return take(w[1], "reeds") > 0
		"clay":
			return take(w[1], "clay") > 0
		"stash":
			return not search_stash(w[1]).is_empty()
		"nest":
			return burn_nest(w[1])
		"post":
			return claim(w[1])
	return false


## Drinks your fill at the spring and fills the watering can.
func drink(_i: int) -> bool:
	var lines: Array = []
	if survival and survival.water < survival.MAX - 0.5:
		survival.water = survival.MAX
		lines.append("You drink your fill")
	if inventory and inventory.count_of("watering_can") > 0 and water.can < Water.CAN_MAX - 0.01:
		water.can = Water.CAN_MAX
		lines.append("Watering can filled (%d L)" % int(Water.CAN_MAX))
	if not lines.is_empty():
		pickup.emit(lines)
	return not lines.is_empty()


## Cuts reeds or digs clay ("reeds" / "clay"). Returns how many you got.
func take(i: int, what: String) -> int:
	var o: Dictionary = list[i]
	var cap: int = REEDS_DAY if what == "reeds" else CLAY_DAY
	var n := mini(TAKE, cap - int(o[what]))
	if n <= 0:
		message.emit("Nothing left here today")
		return 0
	var left: int = inventory.add(what, n)
	var got := n - left
	if got <= 0:
		message.emit("No room in your bag")
		return 0
	o[what] += got
	pickup.emit(["+%d %s" % [got, Items.display_name(what)]])
	_refresh(i)
	return got


## Searches the old stash: rare and exotic seeds (once per oasis).
func search_stash(i: int) -> Dictionary:
	var o: Dictionary = list[i]
	if o.stash:
		return {}
	o.stash = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("oasis_stash:%d:%d" % [world_seed, i])
	var items := Items.roll("oasis", rng)
	var left: Dictionary = inventory.add_all(items)
	var lines: Array = []
	for k in items:
		var got: int = items[k] - int(left.get(k, 0))
		if got > 0:
			lines.append("+%d %s" % [got, Items.display_name(k)])
	if not left.is_empty():
		spilled.emit(left, o.stash_pos)
		lines.append("(the rest is in a bag on the ground)")
	pickup.emit(lines)
	_refresh(i)
	return items


## Sets the nest alight with a fuel can. It burns for BURN_TIME seconds.
func burn_nest(i: int) -> bool:
	var o: Dictionary = list[i]
	if o.nest != "alive" or inventory == null or inventory.remove("fuel", 1) < 1:
		return false
	o.nest = "burning"
	o.burn = 0.0
	message.emit("The nest is burning!")
	_refresh(i)
	return true


func _burn_step(i: int, delta: float) -> void:
	var o: Dictionary = list[i]
	o.burn += delta
	var n: Dictionary = _nodes[i]
	if n.flames:
		for f in n.flames.get_children():
			f.scale = Vector3.ONE * (0.7 + 0.4 * absf(sin(o.burn * 7.0 + f.position.x * 3.0)))
	if o.burn >= BURN_TIME:
		finish_burn(i)


## The nest burned out: no more guards from it, the land can come back to life.
func finish_burn(i: int) -> void:
	var o: Dictionary = list[i]
	o.nest = "gone"
	o.breed = 0.0
	message.emit("The nest burned out. The spring will bring the oasis back to life.")
	_refresh(i)


## Claims oasis i as an outpost (pays CLAIM_COST). Returns true if it did.
func claim(i: int) -> bool:
	var why := claim_problem(i)
	var o: Dictionary = list[i]
	if o.claimed:
		return false
	if why != "":
		message.emit(why)
		return false
	if pay.is_valid() and not pay.call(CLAIM_COST):
		return false
	o.claimed = true
	_apply_zones()
	_refresh(i)
	message.emit("Outpost %d claimed! Build within %d m of its flag. Its spring waters the land round it." % [i + 1, int(OUTPOST_R)])
	claimed.emit(i)
	return true


## Gives the building system every claimed outpost's build zone.
func _apply_zones() -> void:
	if building == null:
		return
	building.outposts = []
	for o in list:
		if o.claimed:
			building.outposts.append([Vector2(o.post_pos.x, o.post_pos.z), OUTPOST_R])


## Shows the outposts' zone edges (in build mode).
func set_highlight(on: bool) -> void:
	for n in _nodes:
		if n.zone:
			n.zone.set_highlight(on)


# --- Looks ---------------------------------------------------------------------------

func _mat(key: String, col: Color, emit := false) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := LowPoly.material(col)
		if emit:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = 1.6
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	return _mats[key]


func _area(parent: Node3D, id: String, size: Vector3, pos: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.set_meta("interact_id", id)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	parent.add_child(area)
	area.global_position = pos
	return area


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _blob(parent: Node3D, scale_v: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 7
	s.rings = 3
	mi.mesh = LowPoly.flat(s)
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_v
	parent.add_child(mi)
	return mi


## A flat patch following the ground: a disc of radius r at p, lifted by lift.
func _ground_disc(p: Vector3, r: float, lift: float, col: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 3
	var segs := 14
	var pts := func(ri: int, si: int) -> Vector3:
		var rr := r * float(ri) / rings
		var a := TAU * si / segs
		var x: float = p.x + cos(a) * rr
		var z: float = p.z + sin(a) * rr
		return Vector3(x, terrain.surface_height(x, z) + lift, z)
	for ri in rings:
		for si in segs:
			var a: Vector3 = pts.call(ri, si)
			var b: Vector3 = pts.call(ri + 1, si)
			var c: Vector3 = pts.call(ri + 1, si + 1)
			var d: Vector3 = pts.call(ri, si + 1)
			for t in [[a, c, b], [a, d, c]]:
				st.set_normal(Vector3.UP)
				st.set_color(col)
				for v in t:
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	if col.b > col.r:  # water: glossy, with a little light of its own so it reads as water
		m.roughness = 0.15
		m.metallic_specular = 0.9
		m.emission_enabled = true
		m.emission = Color(0.05, 0.2, 0.32)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _multi(mesh: Mesh, mat: Material, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


## Everything you see at oasis i (built once per world).
func _build(i: int, rng: RandomNumberGenerator) -> Dictionary:
	var o: Dictionary = list[i]
	var root := Node3D.new()
	root.name = "Oasis%d" % i
	add_child(root)
	var n := {"root": root}
	var c: Vector3 = o.pos
	# The pond and the spring: E anywhere on the water.
	root.add_child(_ground_disc(c, POND_R, 0.07, Color(0.14, 0.42, 0.66)))
	n.pond_area = _area(root, "oasis:spring:%d" % i, Vector3(POND_R * 1.5, 0.6, POND_R * 1.5), c + Vector3(0, 0.2, 0))
	for k in 7:  # stones round the spring
		var a := TAU * k / 7.0 + rng.randf() * 0.4
		var sp := _on_ground(c, a, POND_R + 0.2)
		_blob(root, Vector3(0.6, 0.35, 0.5) * rng.randf_range(0.7, 1.2), sp, _mat("stone", Color(0.55, 0.5, 0.45)))
	# Reeds: thin stalks in a clump at the water's edge (fewer once cut).
	var stalk := BoxMesh.new()
	stalk.size = Vector3(0.05, 1.6, 0.05)
	var xf: Array = []
	var ra: float = o.reed_a
	for k in 48:
		var a := ra + rng.randf_range(-0.6, 0.6)
		var p := _on_ground(c, a, POND_R + rng.randf_range(-1.2, 0.4))
		var h := rng.randf_range(0.7, 1.2)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
		xf.append(Transform3D(b.scaled(Vector3(1, h, 1)), p + Vector3(0, 0.8 * h, 0)))
	xf.shuffle()
	var reeds := _multi(stalk, _mat("reed", Color(0.45, 0.55, 0.25)), xf)
	root.add_child(reeds)
	n.reeds = reeds
	n.reed_mm = reeds.multimesh
	_area(root, "oasis:reeds:%d" % i, Vector3(3.0, 2.0, 3.0), _on_ground(c, ra, POND_R - 0.3) + Vector3(0, 0.8, 0))
	# The clay bank: a red-brown hump by the water.
	var clay := Node3D.new()
	root.add_child(clay)
	clay.global_position = o.clay_pos
	_blob(clay, Vector3(2.4, 0.7, 1.6), Vector3.ZERO, _mat("clay", Color(0.6, 0.32, 0.2)))
	_area(root, "oasis:clay:%d" % i, Vector3(2.4, 1.2, 2.0), o.clay_pos + Vector3(0, 0.3, 0))
	# The old stash: a half-buried crate.
	var stash := StaticBody3D.new()
	stash.set_meta("interact_id", "oasis:stash:%d" % i)
	root.add_child(stash)
	stash.global_position = o.stash_pos
	stash.rotation.y = rng.randf() * TAU
	_box(stash, Vector3(1.0, 0.5, 0.7), Vector3(0, 0.15, 0), _mat("crate", Color(0.4, 0.28, 0.17)), Vector3(0.12, 0, 0.05))
	_box(stash, Vector3(1.05, 0.06, 0.12), Vector3(0, 0.42, 0), _mat("band", Color(0.3, 0.3, 0.32)), Vector3(0.12, 0, 0.05))
	var scol := CollisionShape3D.new()
	var sshape := BoxShape3D.new()
	sshape.size = Vector3(1.0, 0.6, 0.7)
	scol.shape = sshape
	scol.position = Vector3(0, 0.2, 0)
	stash.add_child(scol)
	n.stash = stash
	# Wild palms round the pond (dead stumps while a nest stands).
	var palms := Node3D.new()
	var stumps := Node3D.new()
	root.add_child(palms)
	root.add_child(stumps)
	for k in 4:
		var a := TAU * k / 4.0 + rng.randf_range(0.2, 1.2)
		var p := _on_ground(c, a, POND_R + rng.randf_range(2.0, 4.0))
		if p.distance_to(o.post_pos) < 2.5 or p.distance_to(o.stash_pos) < 2.0 or p.distance_to(o.clay_pos) < 2.0:
			p = _on_ground(c, a + 0.6, POND_R + 4.5)
		var h := rng.randf_range(3.5, 5.0)
		var lean := rng.randf_range(0.0, 0.15)
		var palm := Node3D.new()
		palms.add_child(palm)
		palm.position = p
		palm.rotation = Vector3(lean, rng.randf() * TAU, 0)
		_box(palm, Vector3(0.28, h, 0.28), Vector3(0, h * 0.5, 0), _mat("trunk", Color(0.48, 0.36, 0.22)))
		for f in 7:
			var fa := f * TAU / 7.0
			var leaf := _box(palm, Vector3(0.35, 0.06, 1.7), Vector3(cos(fa) * 0.75, h - 0.15, sin(fa) * 0.75), _mat("leaf", Color(0.3, 0.5, 0.2)))
			leaf.rotation = Vector3(0.35, -fa + PI * 0.5, 0)
		var stump := _box(stumps, Vector3(0.3, 1.1, 0.3), p + Vector3(0, 0.5, 0), _mat("deadwood", Color(0.35, 0.32, 0.3)), Vector3(lean * 2.0, 0, 0.1))
		stump.name = "Stump%d" % k
	n.palms = palms
	n.stumps = stumps
	# The marker post where you claim it (a flag once it's yours).
	var post := Node3D.new()
	root.add_child(post)
	post.global_position = o.post_pos
	_box(post, Vector3(0.12, 2.2, 0.12), Vector3(0, 1.1, 0), _mat("post", Color(0.42, 0.3, 0.18)))
	_box(post, Vector3(0.04, 0.3, 0.4), Vector3(0, 1.8, 0.22), _mat("rag", Color(0.85, 0.82, 0.72)))
	var flag := _box(post, Vector3(0.04, 0.6, 0.95), Vector3(0, 2.2, 0.5), _mat("flag", Color(0.75, 0.16, 0.1)))
	n.flag = flag
	n.post = post
	_area(root, "oasis:post:%d" % i, Vector3(0.8, 2.4, 0.8), o.post_pos + Vector3(0, 1.1, 0))
	n.zone = null
	# The nest: dark lumps on a patch of dead, blackened ground.
	n.ash = null
	n.nest = null
	n.flames = null
	if o.has_nest:
		var ash := _ground_disc(o.nest_pos, 5.0, 0.05, Color(0.2, 0.17, 0.17))
		root.add_child(ash)
		n.ash = ash
		var nest := StaticBody3D.new()
		nest.set_meta("interact_id", "oasis:nest:%d" % i)
		root.add_child(nest)
		nest.global_position = o.nest_pos
		var flesh := _mat("nest", Color(0.32, 0.14, 0.3))
		_blob(nest, Vector3(3.2, 1.4, 2.8), Vector3(0, 0.3, 0), flesh)
		for k in 6:
			var a := TAU * k / 6.0 + rng.randf() * 0.5
			_blob(nest, Vector3(1.0, 0.9, 1.0) * rng.randf_range(0.7, 1.2), Vector3(cos(a) * 1.3, 0.75, sin(a) * 1.1), _mat("nest2", Color(0.42, 0.2, 0.35)))
		for k in 5:
			var a := TAU * k / 5.0 + 0.3
			_box(nest, Vector3(0.12, 1.2, 0.12), Vector3(cos(a) * 0.8, 1.2, sin(a) * 0.7), _mat("spine", Color(0.75, 0.7, 0.55)), Vector3(cos(a) * 0.4, 0, sin(a) * 0.4))
		var ncol := CollisionShape3D.new()
		var nshape := BoxShape3D.new()
		nshape.size = Vector3(3.0, 1.6, 2.6)
		ncol.shape = nshape
		ncol.position = Vector3(0, 0.6, 0)
		nest.add_child(ncol)
		n.nest = nest
		var flames := Node3D.new()
		nest.add_child(flames)
		for k in 7:
			var a := TAU * k / 7.0
			_box(flames, Vector3(0.45, 1.1, 0.45), Vector3(cos(a) * 1.0, 1.1 + (k % 3) * 0.25, sin(a) * 0.9),
				_mat("fire%d" % (k % 2), Color(1.0, 0.45, 0.08) if k % 2 == 0 else Color(1.0, 0.75, 0.2), true), Vector3(0, a, 0.2))
		n.flames = flames
	return n


## Brings oasis i's looks in line with its state.
func _refresh(i: int) -> void:
	if i >= _nodes.size():
		return
	var o: Dictionary = list[i]
	var n: Dictionary = _nodes[i]
	var dead := nest_alive(i)
	n.palms.visible = not dead
	n.stumps.visible = dead
	n.reed_mm.visible_instance_count = int(n.reed_mm.instance_count * (1.0 - 0.8 * float(o.reeds) / REEDS_DAY))
	n.stash.visible = not o.stash
	n.stash.collision_layer = 0 if o.stash else 1
	n.flag.visible = o.claimed
	if n.nest:
		n.nest.visible = o.nest != "gone"
		n.nest.collision_layer = 1 if o.nest != "gone" else 0
		n.flames.visible = o.nest == "burning"
		n.ash.material_override.albedo_color = Color.WHITE if dead else Color(0.55, 0.55, 0.55)  # burnt black
	if o.claimed and n.zone == null:
		var z := BaseZone.new()
		z.terrain = terrain
		z.center = Vector2(o.post_pos.x, o.post_pos.z)
		z.radius = OUTPOST_R
		z.name = "OutpostZone"
		n.root.add_child(z)
		n.zone = z
	elif not o.claimed and n.zone != null:
		n.zone.queue_free()
		n.zone = null


# --- Saving --------------------------------------------------------------------------

func save_data() -> Dictionary:
	var out: Array = []
	for o in list:
		out.append({"nest": "gone" if o.nest == "burning" else o.nest, "guards": o.guards, "found": o.found,
			"claimed": o.claimed, "stash": o.stash, "reeds": o.reeds, "clay": o.clay, "breed": snappedf(o.breed, 0.1)})
	return {"list": out}


## A true/false field from a save (anything else is false).
static func _flag(e: Dictionary, key: String) -> bool:
	var v = e.get(key, false)
	return v is bool and v


static func _int(v, fallback: int) -> int:
	return int(v) if (v is int or v is float) else fallback


## Older saves (no "oases") get the oases of a new world, with green round the
## wild springs. Broken entries fall back to a new world's state.
func load_data(data: Dictionary) -> void:
	for o in list:
		_reset_state(o)
	var saved = data.get("list", null)
	if not saved is Array:
		green_new_world()
	else:
		for i in mini(saved.size(), list.size()):
			var e = saved[i]
			if not e is Dictionary:
				continue
			var o: Dictionary = list[i]
			if o.has_nest:
				o.nest = "gone" if str(e.get("nest", "alive")) == "gone" else "alive"
			o.guards = clampi(_int(e.get("guards", o.guards), o.guards), 0, NEST_GUARDS)
			o.found = _flag(e, "found")
			o.claimed = _flag(e, "claimed")
			o.stash = _flag(e, "stash")
			o.reeds = clampi(_int(e.get("reeds", 0), 0), 0, REEDS_DAY)
			o.clay = clampi(_int(e.get("clay", 0), 0), 0, CLAY_DAY)
			var b = e.get("breed", 0.0)
			o.breed = clampf(float(b), 0.0, NEST_BREED) if (b is float or b is int) else 0.0
	_apply_zones()
	for i in list.size():
		_refresh(i)

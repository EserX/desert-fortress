extends RefCounted
## Ready-made buildings (build mode, T): a cabin, a watchtower and so on, laid
## out as a list of ordinary pieces. Placing one is free and puts up a blue
## blueprint of every piece; E at the blueprint then builds it piece by piece
## (foundations first), paid from your pockets and chests in reach.
## Offsets are grid squares from the square you aim at; the whole layout
## turns with R in 90° steps.

const ORDER := ["shelter", "cabin", "long_cabin", "watchtower", "gatehouse", "compound", "bunker"]
const NAMES := {
	"shelter": "Shelter (1×1)",
	"cabin": "Cabin (2×2)",
	"long_cabin": "Big cabin (3×3)",
	"watchtower": "Watchtower",
	"gatehouse": "Gatehouse",
	"compound": "Walled compound (5×5)",
	"bunker": "Bunker with a well (3×3)",
}


static func display_name(id: String) -> String:
	return NAMES.get(id, id)


## The pieces of a ready-made building in build order, each
## {"type", "kind", "cx", "cz", "dir", "level"} relative to square (0, 0).
static func entries(id: String) -> Array:
	match id:
		"shelter":
			return _cabin(1, 1, [])
		"cabin":
			return _cabin(2, 2, [["s", 1], ["w", 0]])
		"long_cabin":
			return _cabin(3, 3, [["s", 0], ["s", 2], ["w", 1], ["e", 1], ["n", 1]])
		"watchtower":
			return _tower()
		"gatehouse":
			return _gatehouse()
		"compound":
			return _compound(5)
		"bunker":
			return _bunker()
	return []


static func _e(type: String, kind: String, cx: int, cz: int, dir := 0, level := 0) -> Dictionary:
	return {"type": type, "kind": kind, "cx": cx, "cz": cz, "dir": dir, "level": level}


## A w × d cabin: foundations, walls round it with a doorway in the middle of
## the south side, windows where asked ([side, index along it]), a roof.
static func _cabin(w: int, d: int, windows: Array) -> Array:
	var out: Array = []
	for z in d:
		for x in w:
			out.append(_e("foundation", "cell", x, z))
	var door := int(w / 2)
	var walls: Array = []
	for x in w:
		walls.append(["n", x, _e("wall", "edge", x, 0, 0)])
		walls.append(["s", x, _e("doorway" if x == door else "wall", "edge", x, d, 0)])
	for z in d:
		walls.append(["w", z, _e("wall", "edge", 0, z, 1)])
		walls.append(["e", z, _e("wall", "edge", w, z, 1)])
	for wl in walls:
		var e: Dictionary = wl[2]
		for win in windows:
			if win[0] == wl[0] and win[1] == wl[1] and e.type == "wall":
				e.type = "window"
		out.append(e)
	# Roof: edge squares first (they rest on the walls), then the middle.
	var mid: Array = []
	for z in d:
		for x in w:
			var r := _e("roof", "cell", x, z, 0, 1)
			if x == 0 or z == 0 or x == w - 1 or z == d - 1:
				out.append(r)
			else:
				mid.append(r)
	out.append_array(mid)
	return out


## A lookout on four pillars: a ladder up through a trapdoor, half walls to
## shoot over, and a roof on four more pillars.
static func _tower() -> Array:
	var out: Array = [_e("foundation", "cell", 0, 0)]
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		out.append(_e("pillar", "post", c.x, c.y))
	out.append(_e("ladder", "obj", 0, 0))
	out.append(_e("trapdoor", "cell", 0, 0, 0, 1))
	# Corner pillars before the walls between them (a pillar needs its corner clear).
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		out.append(_e("pillar", "post", c.x, c.y, 0, 1))
	out.append(_e("half_wall", "edge", 0, 1, 0, 1))
	out.append(_e("half_wall", "edge", 0, 0, 1, 1))
	out.append(_e("half_wall", "edge", 1, 0, 1, 1))
	out.append(_e("low_wall", "edge", 0, 0, 0, 1))  # low on the hatch side, to climb past
	out.append(_e("roof", "cell", 0, 0, 0, 2))
	return out


## Three squares wide: a gate between two walls, side walls, a walkway on top
## with gun slits along the front and a ladder up inside.
static func _gatehouse() -> Array:
	var out: Array = []
	for x in 3:
		out.append(_e("foundation", "cell", x, 0))
	out.append(_e("wall", "edge", 0, 0, 0))
	out.append(_e("doorway", "edge", 1, 0, 0))
	out.append(_e("wall", "edge", 2, 0, 0))
	out.append(_e("wall", "edge", 0, 0, 1))
	out.append(_e("wall", "edge", 3, 0, 1))
	out.append(_e("ladder", "obj", 0, 0))
	for x in 3:
		out.append(_e("floor", "cell", x, 0, 0, 1))
	for x in 3:
		out.append(_e("half_wall", "edge", x, 0, 0, 1))
	out.append(_e("half_wall", "edge", 0, 0, 1, 1))
	out.append(_e("half_wall", "edge", 3, 0, 1, 1))
	return out


## An open yard n squares across: a ring of foundations with walls round the
## outside, a gun slit in the middle of the north, west and east sides and a
## gate in the middle of the south side. The yard inside stays bare sand (to
## farm, dig or build in).
static func _compound(n: int) -> Array:
	var out: Array = []
	for z in n:
		for x in n:
			if x == 0 or z == 0 or x == n - 1 or z == n - 1:
				out.append(_e("foundation", "cell", x, z))
	var mid := int(n / 2)
	for x in n:
		out.append(_e("slit_wall" if x == mid else "wall", "edge", x, 0, 0))
		out.append(_e("doorway" if x == mid else "wall", "edge", x, n, 0))
	for z in n:
		out.append(_e("slit_wall" if z == mid else "wall", "edge", 0, z, 1))
		out.append(_e("slit_wall" if z == mid else "wall", "edge", n, z, 1))
	return out


## A squat 3 × 3 strongpoint round a well: foundations on the eight outer
## squares, the middle one left as sand for the well shaft (dig it 3.5 m deep
## with the pickaxe, the well goes up last). Gun slits in the middle of three
## sides, a metal door in the fourth, and a roof over everything.
static func _bunker() -> Array:
	var out: Array = []
	for z in 3:
		for x in 3:
			if x != 1 or z != 1:
				out.append(_e("foundation", "cell", x, z))
	for x in 3:
		out.append(_e("slit_wall" if x == 1 else "wall", "edge", x, 0, 0))
		out.append(_e("metal_door" if x == 1 else "wall", "edge", x, 3, 0))
	for z in 3:
		out.append(_e("slit_wall" if z == 1 else "wall", "edge", 0, z, 1))
		out.append(_e("slit_wall" if z == 1 else "wall", "edge", 3, z, 1))
	for z in 3:
		for x in 3:
			if x != 1 or z != 1:
				out.append(_e("roof", "cell", x, z, 0, 1))
	out.append(_e("roof", "cell", 1, 1, 0, 1))
	out.append(_e("well", "obj", 1, 1))
	return out


## One grid slot turned 90° clockwise (seen from above) about the grid origin:
## (x, z) -> (-z, x).
static func turn_slot(s: Dictionary) -> Dictionary:
	var o := s.duplicate()
	match str(s.kind):
		"cell", "obj":
			o.cx = -int(s.cz) - 1
			o.cz = int(s.cx)
			o.dir = (int(s.dir) + 1) % 4
		"post":
			o.cx = -int(s.cz)
			o.cz = int(s.cx)
		"edge":
			if int(s.dir) == 0:
				o.cx = -int(s.cz)
				o.cz = int(s.cx)
				o.dir = 1
			else:
				o.cx = -int(s.cz) - 1
				o.cz = int(s.cx)
				o.dir = 0
	return o


## The pieces of a ready-made building placed with its (0, 0) square at
## (cx, cz), turned `turns` × 90°. Each: {"type", "slot"}. `pieces` is
## Building.PIECES (for how many ways each piece turns).
static func placed(id: String, cx: int, cz: int, turns: int, pieces: Dictionary) -> Array:
	var out: Array = []
	for e in entries(id):
		var s: Dictionary = {"kind": e.kind, "cx": e.cx, "cz": e.cz, "dir": e.dir, "level": e.level}
		for i in posmod(turns, 4):
			s = turn_slot(s)
		s.cx += cx
		s.cz += cz
		if s.kind != "edge":
			s.dir = posmod(int(s.dir), int(pieces[e.type].dirs))
		out.append({"type": e.type, "slot": s})
	return out


## Everything the whole building costs, at the cheapest tier.
static func total_cost(id: String, pieces: Dictionary) -> Dictionary:
	var out := {}
	for e in entries(id):
		var c: Dictionary = pieces[e.type].cost
		for item in c:
			out[item] = int(out.get(item, 0)) + int(c[item])
	return out

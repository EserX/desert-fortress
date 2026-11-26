extends Node3D
## Player-built fortress pieces on a 2 m grid, stacked in levels 2.4 m apart.
## Cell pieces (foundation, floor, roof, stairs, ramp) fill a grid square;
## edge pieces (wall, doorway, window) stand on the line between two squares.
## Each slot holds at most one piece. Stairs and ramps are 2 squares long.

const LowPoly = preload("res://scripts/lowpoly.gd")

const CELL := 2.0
const WALL_H := 2.4
const WALL_T := 0.2
const FOUNDATION_H := 0.6
const FLOOR_T := 0.15
const MAX_SLOPE := 1.1     # biggest ground height difference under a piece
const MAX_LEVEL := 3
const REACH := 9.0
const DOOR_W := 1.1
const DOOR_H := 2.05

## Material tiers: hit points, the item used to upgrade to and repair each.
const TIER_NAMES := ["wood", "scrap metal", "concrete"]
const TIER_HP := [250.0, 600.0, 1500.0]
const TIER_ITEM := ["wood", "scrap", "cement"]
const REFUND := 0.5          # share of what a piece cost you get back when demolished
const UNDO_SECONDS := 60.0   # build-mode right click gives everything back this soon after building

signal piece_destroyed(key: String, type: String)

## type -> {"name", "slot": "cell"/"edge", "cost", "dirs": how many ways R turns it}
const PIECES := {
	"foundation": {"name": "Wooden foundation", "slot": "cell", "cost": {"wood": 4, "nails": 4}, "dirs": 1},
	"wall": {"name": "Wooden wall", "slot": "edge", "cost": {"wood": 3, "nails": 3}, "dirs": 2},
	"doorway": {"name": "Doorway with gate", "slot": "edge", "cost": {"wood": 4, "nails": 4}, "dirs": 2},
	"window": {"name": "Wall with window", "slot": "edge", "cost": {"wood": 3, "nails": 3}, "dirs": 2},
	"floor": {"name": "Wooden floor", "slot": "cell", "cost": {"wood": 3, "nails": 3}, "dirs": 1},
	"stairs": {"name": "Wooden stairs", "slot": "cell", "cost": {"wood": 5, "nails": 4}, "dirs": 4, "long": true},
	"ramp": {"name": "Scrap ramp", "slot": "cell", "cost": {"scrap": 3, "wood": 2, "nails": 3}, "dirs": 4, "long": true},
	"roof": {"name": "Scrap roof", "slot": "cell", "cost": {"scrap": 3, "nails": 2}, "dirs": 1},
}
const ORDER := ["foundation", "wall", "doorway", "window", "floor", "stairs", "ramp", "roof"]
## Edge pieces that hold up whatever is built above them.
const WALLISH := ["wall", "doorway", "window"]
## Cell pieces you can stand on at an upper level.
const DECKS := ["floor", "roof"]

var terrain  # Terrain
## main slot key -> {"type", "slot", "y", "node", "open" (gates), "tier", "hp", "built_at"}
var pieces := {}
## every slot key a piece takes up (stairs take two) -> main slot key
var occupied := {}
var _mats := {}


func _ready() -> void:
	_mats.wood = LowPoly.material(Color(0.52, 0.36, 0.22))
	_mats.wood_dark = LowPoly.material(Color(0.36, 0.24, 0.14))
	_mats.plank = LowPoly.material(Color(0.60, 0.43, 0.27))
	_mats.metal = LowPoly.material(Color(0.36, 0.38, 0.4), 0.55)
	_mats.rust = LowPoly.material(Color(0.5, 0.28, 0.14), 0.8)
	_mats.concrete = LowPoly.material(Color(0.5, 0.49, 0.46))
	_mats.concrete_dark = LowPoly.material(Color(0.38, 0.37, 0.35))
	_mats.crack = LowPoly.material(Color(0.08, 0.06, 0.05))


## The material a mesh part uses at a tier (parts are designed in wood).
func _tier_mat(tier: int, key: String) -> Material:
	if tier == 1:
		return _mats[{"wood": "metal", "plank": "metal", "wood_dark": "rust"}.get(key, key)]
	if tier == 2:
		return _mats[{"wood": "concrete", "plank": "concrete", "metal": "concrete", "wood_dark": "concrete_dark", "rust": "concrete_dark"}.get(key, key)]
	return _mats[key]


# --- Slots ----------------------------------------------------------------------

## The grid slot a piece type would use when aimed at world point p (level 0).
## dir: edges 0 = runs along X, 1 = along Z. Stairs/ramps 0..3 = rises to N, E, S, W.
static func slot_for(type: String, p: Vector3, dir: int) -> Dictionary:
	var cx := int(floor(p.x / CELL))
	var cz := int(floor(p.z / CELL))
	if PIECES[type].slot == "cell":
		return {"kind": "cell", "cx": cx, "cz": cz, "dir": dir % PIECES[type].dirs, "level": 0}
	if dir % 2 == 0:
		return {"kind": "edge", "cx": cx, "cz": int(round(p.z / CELL)), "dir": 0, "level": 0}
	return {"kind": "edge", "cx": int(round(p.x / CELL)), "cz": cz, "dir": 1, "level": 0}


## Slot key. Cell keys ignore dir (one piece per square, whichever way it faces).
static func slot_key(slot: Dictionary) -> String:
	var d: int = slot.dir if slot.kind == "edge" else 0
	return "%s:%d:%d:%d:%d" % [slot.kind, slot.cx, slot.cz, d, slot.get("level", 0)]


static func cell_key(cx: int, cz: int, level: int) -> String:
	return slot_key({"kind": "cell", "cx": cx, "cz": cz, "dir": 0, "level": level})


## Which way stairs climb: grid step to the upper square.
static func climb_step(dir: int) -> Vector2i:
	return [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][dir]


## Every slot key a piece in this slot would take up.
static func slot_keys(type: String, slot: Dictionary) -> Array:
	var keys := [slot_key(slot)]
	if PIECES[type].get("long", false):
		var s := climb_step(slot.dir)
		keys.append(cell_key(slot.cx + s.x, slot.cz + s.y, slot.level))
	return keys


## Centre of a slot on the ground plane (y = 0). Long pieces: between their squares.
static func slot_center(slot: Dictionary, type := "") -> Vector3:
	if slot.kind == "cell":
		var c := Vector3((slot.cx + 0.5) * CELL, 0, (slot.cz + 0.5) * CELL)
		if type != "" and PIECES[type].get("long", false):
			var s := climb_step(slot.dir)
			c += Vector3(s.x, 0, s.y) * CELL * 0.5
		return c
	if slot.dir == 0:
		return Vector3((slot.cx + 0.5) * CELL, 0, slot.cz * CELL)
	return Vector3(slot.cx * CELL, 0, (slot.cz + 0.5) * CELL)


## Transform of a piece standing at base height y.
static func piece_transform(type: String, slot: Dictionary, y: float) -> Transform3D:
	var c := slot_center(slot, type)
	var yaw := 0.0
	if slot.kind == "edge":
		yaw = 0.0 if slot.dir == 0 else PI / 2
	elif PIECES[type].get("long", false):
		yaw = -slot.dir * PI / 2
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.z))


## Ground heights under a slot (both squares for long pieces).
func _ground_samples(type: String, slot: Dictionary) -> Array:
	var out: Array = []
	var h := CELL * 0.5
	var centers: Array = []
	var pts: Array
	if slot.kind == "cell":
		centers.append(slot_center(slot))
		if PIECES[type].get("long", false):
			var s := climb_step(slot.dir)
			centers.append(slot_center({"kind": "cell", "cx": slot.cx + s.x, "cz": slot.cz + s.y, "dir": 0}))
		pts = [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h), Vector2.ZERO]
	else:
		centers.append(slot_center(slot))
		pts = [Vector2(-h, 0), Vector2(h, 0), Vector2.ZERO] if slot.dir == 0 else [Vector2(0, -h), Vector2(0, h), Vector2.ZERO]
	for c in centers:
		for o in pts:
			out.append(terrain.surface_height(c.x + o.x, c.z + o.y))
	return out


## The piece record in a slot, or {}.
func piece_at(key: String) -> Dictionary:
	return pieces.get(occupied.get(key, ""), {})


func foundation_top(cx: int, cz: int) -> float:
	var p := piece_at(cell_key(cx, cz, 0))
	return p.y if not p.is_empty() and p.type == "foundation" else NAN


## The two squares either side of an edge.
static func edge_cells(slot: Dictionary) -> Array:
	if slot.dir == 0:
		return [Vector2i(slot.cx, slot.cz - 1), Vector2i(slot.cx, slot.cz)]
	return [Vector2i(slot.cx - 1, slot.cz), Vector2i(slot.cx, slot.cz)]


## The four edges around a square.
static func cell_edges(cx: int, cz: int, level: int) -> Array:
	return [
		{"kind": "edge", "cx": cx, "cz": cz, "dir": 0, "level": level},
		{"kind": "edge", "cx": cx, "cz": cz + 1, "dir": 0, "level": level},
		{"kind": "edge", "cx": cx, "cz": cz, "dir": 1, "level": level},
		{"kind": "edge", "cx": cx + 1, "cz": cz, "dir": 1, "level": level},
	]


## Height of the ground floor (level 0) for a slot, from foundations or sand.
func _ground_level(type: String, slot: Dictionary) -> Dictionary:
	var g := _ground_samples(type, slot)
	var lo: float = g.min()
	var hi: float = g.max()
	var steep := hi - lo > MAX_SLOPE
	if slot.kind == "cell":
		var t := foundation_top(slot.cx, slot.cz)
		if type != "foundation" and not is_nan(t):
			return {"y": t, "steep": false}
		return {"y": hi + 0.12 if type == "foundation" else lo, "steep": steep}
	var top := -INF
	for c in edge_cells(slot):
		var t := foundation_top(c.x, c.y)
		if not is_nan(t):
			top = maxf(top, t)
	if top > -INF:
		return {"y": top, "steep": false}
	return {"y": lo - 0.1, "steep": steep}


## Base height of what holds up an upper-level slot, or NAN if nothing does.
func _support_y(slot: Dictionary) -> float:
	var lv: int = slot.level
	if slot.kind == "cell":
		# Walls on any edge below, or a floor next door at the same level.
		for e in cell_edges(slot.cx, slot.cz, lv - 1):
			var w := piece_at(slot_key(e))
			if not w.is_empty() and w.type in WALLISH:
				return w.y + WALL_H
		for s in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var f := piece_at(cell_key(slot.cx + s.x, slot.cz + s.y, lv))
			if not f.is_empty() and f.type in DECKS:
				return f.y
		return NAN
	var below := piece_at(slot_key({"kind": "edge", "cx": slot.cx, "cz": slot.cz, "dir": slot.dir, "level": lv - 1}))
	if not below.is_empty() and below.type in WALLISH:
		return below.y + WALL_H
	for c in edge_cells(slot):
		var f := piece_at(cell_key(c.x, c.y, lv))
		if not f.is_empty() and f.type in DECKS:
			return f.y
	return NAN


## Which level a piece goes on when the crosshair hits height hit_y.
func level_for(type: String, slot: Dictionary, hit_y: float) -> int:
	if type == "foundation":
		return 0
	var base: float = _ground_level(type, slot).y
	return clampi(int(round((hit_y - base) / WALL_H)), 0, MAX_LEVEL)


## Where a piece would stand: {"y": base height, "ok": bool, "reason": String}.
func evaluate(type: String, slot: Dictionary) -> Dictionary:
	for k in slot_keys(type, slot):
		if occupied.has(k):
			return {"y": piece_at(k).y, "ok": false, "reason": "Something is already built here"}
	if slot.get("level", 0) > 0:
		if type == "foundation":
			return {"y": 0.0, "ok": false, "reason": "Foundations go on the ground"}
		var sy := _support_y(slot)
		if is_nan(sy):
			return {"y": _ground_level(type, slot).y + slot.level * WALL_H, "ok": false, "reason": "Needs a wall or floor to hold it up"}
		return {"y": sy, "ok": true, "reason": ""}
	var g := _ground_level(type, slot)
	if g.steep:
		return {"y": g.y, "ok": false, "reason": "Ground too steep"}
	return {"y": g.y, "ok": true, "reason": ""}


# --- Piece shapes ---------------------------------------------------------------

## Boxes making up a piece in local space: [size, centre, material, rotation x].
static func piece_boxes(type: String) -> Array:
	var out: Array = []
	match type:
		"foundation":
			out.append([Vector3(CELL, FOUNDATION_H, CELL), Vector3(0, -FOUNDATION_H * 0.5, 0), "wood_dark"])
			out.append([Vector3(CELL - 0.06, 0.04, CELL - 0.06), Vector3(0, 0.0, 0), "plank"])
		"wall":
			out.append([Vector3(CELL, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, 0), "wood"])
			for i in 3:
				out.append([Vector3(CELL - 0.02, 0.05, WALL_T + 0.02), Vector3(0, 0.6 * (i + 1), 0), "wood_dark"])
			out.append_array(_posts())
		"doorway":
			var side := (CELL - DOOR_W) * 0.5
			for s in [-1.0, 1.0]:
				out.append([Vector3(side, WALL_H, WALL_T), Vector3(s * (DOOR_W + side) * 0.5, WALL_H * 0.5, 0), "wood"])
			out.append([Vector3(DOOR_W, WALL_H - DOOR_H, WALL_T), Vector3(0, (WALL_H + DOOR_H) * 0.5, 0), "wood"])
			out.append_array(_posts())
		"window":
			var bottom := 1.0
			var top := 1.75
			var hole := 0.9
			var side := (CELL - hole) * 0.5
			out.append([Vector3(CELL, bottom, WALL_T), Vector3(0, bottom * 0.5, 0), "wood"])
			out.append([Vector3(CELL, WALL_H - top, WALL_T), Vector3(0, (WALL_H + top) * 0.5, 0), "wood"])
			for s in [-1.0, 1.0]:
				out.append([Vector3(side, top - bottom, WALL_T), Vector3(s * (hole + side) * 0.5, (top + bottom) * 0.5, 0), "wood"])
			out.append([Vector3(hole + 0.1, 0.06, WALL_T + 0.1), Vector3(0, bottom, 0), "wood_dark"])
			out.append_array(_posts())
		"floor":
			out.append([Vector3(CELL, FLOOR_T, CELL), Vector3(0, -FLOOR_T * 0.5, 0), "plank"])
			for i in 3:
				out.append([Vector3(0.04, FLOOR_T + 0.01, CELL), Vector3(-0.5 + 0.5 * i, -FLOOR_T * 0.5, 0), "wood_dark"])
		"roof":
			out.append([Vector3(CELL + 0.1, 0.08, CELL + 0.1), Vector3(0, -0.04, 0), "metal"])
			for i in 4:
				out.append([Vector3(0.06, 0.05, CELL + 0.1), Vector3(-0.75 + 0.5 * i, 0.02, 0), "rust"])
		"stairs":
			var steps := 8
			var run := CELL * 2.0 / steps
			var rise := WALL_H / steps
			for i in steps:
				var h := rise * (i + 1)
				out.append([Vector3(CELL - 0.3, h, run), Vector3(0, h * 0.5, CELL - run * (i + 0.5)), "plank" if i % 2 == 0 else "wood"])
			for s in [-1.0, 1.0]:
				out.append([Vector3(0.15, 0.25, _ramp_len()), Vector3(s * (CELL * 0.5 - 0.075), WALL_H * 0.5 + 0.1, 0), "wood_dark", _ramp_angle()])
		"ramp":
			out.append([Vector3(CELL - 0.1, 0.12, _ramp_len()), Vector3(0, WALL_H * 0.5, 0), "metal", _ramp_angle()])
			for i in 4:
				out.append([Vector3(CELL - 0.1, 0.03, 0.08), Vector3(0, WALL_H * 0.5 + 0.07, 0), "rust", _ramp_angle(), Vector3(0, 0, -1.6 + i * 1.07)])
	return out


static func _posts() -> Array:
	var out: Array = []
	for s in [-1.0, 1.0]:
		out.append([Vector3(0.16, WALL_H, WALL_T + 0.06), Vector3(s * (CELL * 0.5 - 0.08), WALL_H * 0.5, 0), "wood_dark"])
	return out


static func _ramp_len() -> float:
	return Vector2(CELL * 2.0, WALL_H).length()


## Slope of stairs and ramps: they climb one level over two squares.
static func _ramp_angle() -> float:
	return atan2(WALL_H, CELL * 2.0)


## Collision boxes: [size, centre, rotation x]. Stairs walk like a ramp.
static func piece_colliders(type: String) -> Array:
	match type:
		"wall", "foundation", "floor", "roof":
			var b: Array = piece_boxes(type)[0]
			return [[b[0], b[1], 0.0]]
		"doorway", "window":
			var out: Array = []
			for b in piece_boxes(type):
				if b[2] == "wood":
					out.append([b[0], b[1], 0.0])
			return out
		"stairs", "ramp":
			return [[Vector3(CELL, 0.2, _ramp_len()), Vector3(0, WALL_H * 0.5, 0), _ramp_angle()]]
	return []


## The box used to check that a piece has room: [size, centre].
static func piece_bounds(type: String) -> Array:
	match type:
		"doorway", "window":
			return [Vector3(CELL, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, 0)]
		"stairs", "ramp":
			return [Vector3(CELL, WALL_H * 0.5, CELL * 2.0), Vector3(0, WALL_H * 0.25, 0)]
	var c: Array = piece_colliders(type)[0]
	return [c[0], c[1]]


static func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


# --- Building and removing ------------------------------------------------------

## Builds a piece (no cost or validity checks). Returns its slot key.
func place(type: String, slot: Dictionary, y: float, gate_open := false, tier := -1, hp := -1.0) -> String:
	slot = slot.duplicate()
	slot.level = int(slot.get("level", 0))
	var key := slot_key(slot)
	var body := StaticBody3D.new()
	body.transform = piece_transform(type, slot, y)
	body.set_meta("piece_key", key)
	for b in piece_boxes(type):
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(b[0])
		mi.position = b[1]
		if b.size() > 3:
			mi.rotation.x = b[3]
		if b.size() > 4:
			mi.position += Basis(Vector3.RIGHT, b[3]) * b[4]
		mi.set_meta("mat", b[2])
		body.add_child(mi)
	for c in piece_colliders(type):
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = c[0]
		col.shape = shape
		col.position = c[1]
		col.rotation.x = c[2]
		body.add_child(col)
	add_child(body)
	if tier < 0:
		tier = base_tier(type)
	var rec := {"type": type, "slot": slot, "y": y, "node": body, "open": false, "tier": tier,
		"hp": 0.0, "built_at": Time.get_ticks_msec()}
	rec.hp = max_hp(rec) if hp < 0.0 else minf(hp, max_hp(rec))
	_add_cracks(rec)
	_apply_tier(rec)
	pieces[key] = rec
	for k in slot_keys(type, slot):
		occupied[k] = key
	if type == "doorway":
		_add_gate(rec, gate_open)
	return key


## A plank gate on a hinge inside a doorway. E opens and closes it.
func _add_gate(rec: Dictionary, open: bool) -> void:
	var hinge := Node3D.new()
	hinge.position = Vector3(-DOOR_W * 0.5, 0, 0)
	rec.node.add_child(hinge)
	var gate := StaticBody3D.new()
	gate.set_meta("interact_id", "gate:" + slot_key(rec.slot))
	gate.position = Vector3(DOOR_W * 0.5, DOOR_H * 0.5, 0)
	hinge.add_child(gate)
	for i in 4:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(Vector3(DOOR_W / 4.0 - 0.03, DOOR_H - 0.06, 0.08))
		mi.position.x = -DOOR_W * 0.5 + DOOR_W / 8.0 + i * DOOR_W / 4.0
		mi.set_meta("mat", "plank" if i % 2 == 0 else "wood")
		gate.add_child(mi)
	for yb in [-0.6, 0.6]:
		var brace := MeshInstance3D.new()
		brace.mesh = _box_mesh(Vector3(DOOR_W - 0.05, 0.12, 0.1))
		brace.position = Vector3(0, yb, 0.03)
		brace.set_meta("mat", "wood_dark")
		gate.add_child(brace)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOOR_W - 0.04, DOOR_H - 0.06, 0.1)
	col.shape = shape
	gate.add_child(col)
	rec.hinge = hinge
	_apply_tier(rec)
	set_gate(slot_key(rec.slot), open)


func set_gate(key: String, open: bool) -> void:
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty() or not rec.has("hinge"):
		return
	rec.open = open
	rec.hinge.rotation.y = -PI * 0.5 if open else 0.0


## E on a gate: open it if closed, close it if open.
func toggle_gate(key: String) -> void:
	if pieces.has(key):
		set_gate(key, not pieces[key].open)


## Prompt text for a gate's interact id ("gate:<key>"), or "".
func prompt(id: String) -> String:
	if not id.begins_with("gate:"):
		return ""
	var key := id.trim_prefix("gate:")
	if not pieces.has(key):
		return ""
	return "[E] Close gate" if pieces[key].open else "[E] Open gate"


func remove(key: String) -> String:
	key = occupied.get(key, key)
	if not pieces.has(key):
		return ""
	var rec: Dictionary = pieces[key]
	rec.node.queue_free()
	for k in slot_keys(rec.type, rec.slot):
		occupied.erase(k)
	pieces.erase(key)
	return rec.type


## True if the space a piece needs is free of props, other pieces and the player.
## The terrain is ignored (pieces sink into the sand a little).
func space_free(type: String, slot: Dictionary, y: float) -> bool:
	var b := piece_bounds(type)
	var shape := BoxShape3D.new()
	shape.size = b[0] - Vector3(0.12, 0.12, 0.12)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = piece_transform(type, slot, y) * Transform3D(Basis.IDENTITY, b[1])
	q.collision_mask = 1
	q.exclude = [terrain.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## True if a standing person (feet at pos) would be inside the piece.
## Also counts standing on the spot where a foundation would come up under you.
func blocks_person(type: String, slot: Dictionary, y: float, pos: Vector3, radius := 0.4, height := 1.8) -> bool:
	var b := piece_bounds(type)
	var local: Vector3 = piece_transform(type, slot, y).affine_inverse() * pos - b[1]
	var half: Vector3 = b[0] * 0.5
	if absf(local.x) > half.x + radius or absf(local.z) > half.z + radius:
		return false
	return local.y < half.y + 0.3 and local.y + height > -half.y


# --- Tiers, damage and the hammer ------------------------------------------------

## Roofs and ramps are made of scrap from the start.
static func base_tier(type: String) -> int:
	return 1 if type in ["roof", "ramp"] else 0


func max_hp(rec: Dictionary) -> float:
	return TIER_HP[rec.tier]


## Short name like "Scrap metal wall".
func describe(rec: Dictionary) -> String:
	var noun: String = PIECES[rec.type].name.replace("Wooden ", "").replace("Scrap ", "")
	var tier_name: String = TIER_NAMES[rec.tier]
	return "%s%s %s" % [tier_name[0].to_upper(), tier_name.substr(1), noun.to_lower()]


## How much a piece's wood cost is worth in the next tier's material.
static func _size(type: String) -> int:
	var cost: Dictionary = PIECES[type].cost
	return maxi(2, int(cost.get("wood", 0)) + int(cost.get("scrap", 0)))


## What it costs to raise a piece one tier ({} at concrete).
func upgrade_cost(rec: Dictionary) -> Dictionary:
	if rec.tier >= TIER_NAMES.size() - 1:
		return {}
	if rec.tier == 0:
		return {"scrap": _size(rec.type) + 1, "nails": 2}
	return {"cement": _size(rec.type), "scrap": 1}


## One unit of the tier's material per started quarter of missing hit points.
func repair_cost(rec: Dictionary) -> Dictionary:
	var missing: float = 1.0 - rec.hp / max_hp(rec)
	if missing <= 0.001:
		return {}
	return {TIER_ITEM[rec.tier]: int(ceil(missing * 4.0))}


## What demolishing gives back: half of everything put into it, rounded down.
func refund(rec: Dictionary) -> Dictionary:
	var spent: Dictionary = PIECES[rec.type].cost.duplicate()
	var r := {"tier": base_tier(rec.type)}
	while r.tier < rec.tier:
		var up := upgrade_cost(r.merged({"type": rec.type}))
		for item in up:
			spent[item] = int(spent.get(item, 0)) + up[item]
		r.tier += 1
	var out := {}
	for item in spent:
		var n := int(floor(spent[item] * REFUND))
		if n > 0:
			out[item] = n
	return out


func upgrade(key: String) -> void:
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty() or upgrade_cost(rec).is_empty():
		return
	rec.tier += 1
	rec.hp = max_hp(rec)
	_apply_tier(rec)


func repair(key: String) -> void:
	var rec: Dictionary = pieces.get(key, {})
	if not rec.is_empty():
		rec.hp = max_hp(rec)
		_update_cracks(rec)


## Hurts a piece. At 0 hit points it breaks and is gone. Returns true if it broke.
func damage(key: String, amount: float) -> bool:
	key = occupied.get(key, key)
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty():
		return false
	rec.hp = maxf(rec.hp - amount, 0.0)
	if rec.hp <= 0.0:
		var type: String = rec.type
		remove(key)
		piece_destroyed.emit(key, type)
		return true
	_update_cracks(rec)
	return false


## True while a fresh piece can still be taken back for a full refund.
func can_undo(rec: Dictionary) -> bool:
	return (Time.get_ticks_msec() - rec.built_at) / 1000.0 < UNDO_SECONDS and rec.tier == base_tier(rec.type) and rec.hp >= max_hp(rec)


func _apply_tier(rec: Dictionary) -> void:
	for mi in _meshes(rec.node):
		mi.material_override = _tier_mat(rec.tier, mi.get_meta("mat"))
	_update_cracks(rec)


func _meshes(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is MeshInstance3D and c.has_meta("mat"):
			out.append(c)
		if not (c is CollisionShape3D):
			out.append_array(_meshes(c))
	return out


## Dark crack lines on both faces of a piece, hidden until it is damaged.
func _add_cracks(rec: Dictionary) -> void:
	var b := piece_bounds(rec.type)
	var size: Vector3 = b[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(slot_key(rec.slot))
	var cracks := Node3D.new()
	cracks.name = "Cracks"
	rec.node.add_child(cracks)
	var flat: bool = size.y < 1.0  # floors, foundations, roofs: cracks on top
	for i in 6:
		var mi := MeshInstance3D.new()
		var crack_len := rng.randf_range(0.4, 0.9)
		var pos: Vector3 = b[1]
		if flat:
			mi.mesh = _box_mesh(Vector3(crack_len, 0.02, 0.04))
			pos += Vector3(rng.randf_range(-0.6, 0.6) * size.x * 0.5, size.y * 0.5 + 0.01, rng.randf_range(-0.6, 0.6) * size.z * 0.5)
			mi.rotation.y = rng.randf() * PI
		else:
			mi.mesh = _box_mesh(Vector3(crack_len, 0.025, size.z + 0.02))
			pos += Vector3(rng.randf_range(-0.35, 0.35) * size.x, rng.randf_range(-0.35, 0.35) * size.y, 0)
			mi.rotation.z = rng.randf_range(-1.2, 1.2)
		mi.position = pos
		mi.material_override = _mats.crack
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cracks.add_child(mi)
	rec.cracks = cracks


## Damage stage: 0 fine, 1 cracked (below 2/3), 2 badly cracked (below 1/3).
func crack_stage(rec: Dictionary) -> int:
	var f: float = rec.hp / max_hp(rec)
	return 0 if f > 0.66 else (1 if f > 0.33 else 2)


func _update_cracks(rec: Dictionary) -> void:
	if not rec.has("cracks"):
		return
	var shown: int = [0, 3, 6][crack_stage(rec)]
	for i in rec.cracks.get_child_count():
		rec.cracks.get_child(i).visible = i < shown


func save_data() -> Array:
	var out: Array = []
	for key in pieces:
		var p: Dictionary = pieces[key]
		out.append({"type": p.type, "kind": p.slot.kind, "cx": p.slot.cx, "cz": p.slot.cz, "dir": p.slot.dir, "level": p.slot.level, "y": p.y, "open": p.open, "tier": p.tier, "hp": p.hp})
	return out


func load_data(data: Array) -> void:
	for key in pieces.keys():
		remove(key)
	for p in data:
		if PIECES.has(p.get("type", "")):
			var slot := {"kind": str(p.kind), "cx": int(p.cx), "cz": int(p.cz), "dir": int(p.dir), "level": int(p.get("level", 0))}
			place(p.type, slot, float(p.y), bool(p.get("open", false)), int(p.get("tier", -1)), float(p.get("hp", -1.0)))

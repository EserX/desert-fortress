extends Node3D
## Player-built fortress pieces on a 2 m grid. Cell pieces (foundations) fill
## a grid square; edge pieces (walls) stand on the line between two squares.
## Each grid slot holds at most one piece.

const LowPoly = preload("res://scripts/lowpoly.gd")

const CELL := 2.0
const WALL_H := 2.4
const WALL_T := 0.2
const FOUNDATION_H := 0.6
const MAX_SLOPE := 1.1     # biggest ground height difference under a piece
const REACH := 9.0

## type -> {"name", "slot": "cell"/"edge", "cost": {item: n}}
const PIECES := {
	"foundation": {"name": "Wooden foundation", "slot": "cell", "cost": {"wood": 4, "nails": 4}},
	"wall": {"name": "Wooden wall", "slot": "edge", "cost": {"wood": 3, "nails": 3}},
}
const ORDER := ["foundation", "wall"]

var terrain  # Terrain
## slot key -> {"type": String, "slot": Dictionary, "y": float, "node": StaticBody3D}
var pieces := {}
var _mats := {}


func _ready() -> void:
	_mats.wood = LowPoly.material(Color(0.52, 0.36, 0.22))
	_mats.wood_dark = LowPoly.material(Color(0.36, 0.24, 0.14))
	_mats.plank = LowPoly.material(Color(0.60, 0.43, 0.27))


# --- Slots ----------------------------------------------------------------------

## The grid slot a piece type would use when aimed at world point p.
## dir (edges only): 0 = wall runs along X, 1 = wall runs along Z.
static func slot_for(type: String, p: Vector3, dir: int) -> Dictionary:
	var cx := int(floor(p.x / CELL))
	var cz := int(floor(p.z / CELL))
	if PIECES[type].slot == "cell":
		return {"kind": "cell", "cx": cx, "cz": cz, "dir": 0}
	# Nearest grid line in the wall's direction.
	if dir == 0:
		return {"kind": "edge", "cx": cx, "cz": int(round(p.z / CELL)), "dir": 0}
	return {"kind": "edge", "cx": int(round(p.x / CELL)), "cz": cz, "dir": 1}


static func slot_key(slot: Dictionary) -> String:
	return "%s:%d:%d:%d" % [slot.kind, slot.cx, slot.cz, slot.dir]


## Centre of a slot on the ground plane (y = 0).
static func slot_center(slot: Dictionary) -> Vector3:
	if slot.kind == "cell":
		return Vector3((slot.cx + 0.5) * CELL, 0, (slot.cz + 0.5) * CELL)
	if slot.dir == 0:
		return Vector3((slot.cx + 0.5) * CELL, 0, slot.cz * CELL)
	return Vector3(slot.cx * CELL, 0, (slot.cz + 0.5) * CELL)


## Ground heights at the corners/ends of a slot.
func _ground_samples(slot: Dictionary) -> Array:
	var c := slot_center(slot)
	var h := CELL * 0.5
	var pts: Array
	if slot.kind == "cell":
		pts = [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h), Vector2.ZERO]
	elif slot.dir == 0:
		pts = [Vector2(-h, 0), Vector2(h, 0), Vector2.ZERO]
	else:
		pts = [Vector2(0, -h), Vector2(0, h), Vector2.ZERO]
	var out: Array = []
	for o in pts:
		out.append(terrain.surface_height(c.x + o.x, c.z + o.y))
	return out


## Top of the foundation in a cell, or NAN if there is none.
func foundation_top(cx: int, cz: int) -> float:
	var key := slot_key({"kind": "cell", "cx": cx, "cz": cz, "dir": 0})
	if pieces.has(key) and pieces[key].type == "foundation":
		return pieces[key].y
	return NAN


## The two cells either side of an edge.
static func edge_cells(slot: Dictionary) -> Array:
	if slot.dir == 0:
		return [Vector2i(slot.cx, slot.cz - 1), Vector2i(slot.cx, slot.cz)]
	return [Vector2i(slot.cx - 1, slot.cz), Vector2i(slot.cx, slot.cz)]


## Where a piece would stand: {"y": base height, "ok": bool, "reason": String}.
func evaluate(type: String, slot: Dictionary) -> Dictionary:
	var key := slot_key(slot)
	if pieces.has(key):
		return {"y": pieces[key].y, "ok": false, "reason": "Something is already built here"}
	var g := _ground_samples(slot)
	var lo: float = g.min()
	var hi: float = g.max()
	if type == "foundation":
		var ok := hi - lo <= MAX_SLOPE
		return {"y": hi + 0.12, "ok": ok, "reason": "" if ok else "Ground too steep"}
	# Edge piece: on top of a neighbouring foundation if there is one.
	var top := -INF
	for c in edge_cells(slot):
		var t := foundation_top(c.x, c.y)
		if not is_nan(t):
			top = maxf(top, t)
	if top > -INF:
		return {"y": top, "ok": true, "reason": ""}
	var ok := hi - lo <= MAX_SLOPE
	return {"y": lo - 0.1, "ok": ok, "reason": "" if ok else "Ground too steep"}


# --- Building pieces ------------------------------------------------------------

## Transform of a piece standing at base height y.
static func piece_transform(slot: Dictionary, y: float) -> Transform3D:
	var c := slot_center(slot)
	var basis := Basis.IDENTITY if slot.dir == 0 else Basis(Vector3.UP, PI / 2)
	return Transform3D(basis, Vector3(c.x, y, c.z))


## Boxes making up a piece in its local space: [size, centre, material key].
static func piece_boxes(type: String) -> Array:
	match type:
		"foundation":
			return [
				[Vector3(CELL, FOUNDATION_H, CELL), Vector3(0, -FOUNDATION_H * 0.5, 0), "wood_dark"],
				[Vector3(CELL - 0.06, 0.04, CELL - 0.06), Vector3(0, 0.0, 0), "plank"],
			]
		"wall":
			var out: Array = [[Vector3(CELL, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, 0), "wood"]]
			# Darker seams between planks, and posts at both ends.
			for i in 3:
				out.append([Vector3(CELL - 0.02, 0.05, WALL_T + 0.02), Vector3(0, 0.6 * (i + 1), 0), "wood_dark"])
			for s in [-1.0, 1.0]:
				out.append([Vector3(0.16, WALL_H, WALL_T + 0.06), Vector3(s * (CELL * 0.5 - 0.08), WALL_H * 0.5, 0), "wood_dark"])
			return out
	return []


## Collision boxes: [size, centre]. The first one is also the overlap check box.
static func piece_colliders(type: String) -> Array:
	match type:
		"foundation":
			return [[Vector3(CELL, FOUNDATION_H, CELL), Vector3(0, -FOUNDATION_H * 0.5, 0)]]
		"wall":
			return [[Vector3(CELL, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, 0)]]
	return []


## Builds a piece (no cost or validity checks). Returns its slot key.
func place(type: String, slot: Dictionary, y: float) -> String:
	var key := slot_key(slot)
	var body := StaticBody3D.new()
	body.transform = piece_transform(slot, y)
	body.set_meta("piece_key", key)
	for b in piece_boxes(type):
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = b[0]
		mi.mesh = mesh
		mi.position = b[1]
		mi.material_override = _mats[b[2]]
		body.add_child(mi)
	for c in piece_colliders(type):
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = c[0]
		col.shape = shape
		col.position = c[1]
		body.add_child(col)
	add_child(body)
	pieces[key] = {"type": type, "slot": slot, "y": y, "node": body}
	return key


func remove(key: String) -> String:
	if not pieces.has(key):
		return ""
	var type: String = pieces[key].type
	pieces[key].node.queue_free()
	pieces.erase(key)
	return type


## True if the space a piece needs is free of props, other pieces and the player.
## The terrain is ignored (pieces sink into the sand a little).
func space_free(type: String, slot: Dictionary, y: float) -> bool:
	var c: Array = piece_colliders(type)[0]
	var shape := BoxShape3D.new()
	shape.size = c[0] - Vector3(0.12, 0.12, 0.12)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = piece_transform(slot, y) * Transform3D(Basis.IDENTITY, c[1])
	q.collision_mask = 1
	q.exclude = [terrain.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## True if a standing person (feet at pos) would be inside the piece.
## Also counts standing on the spot where a foundation would come up under you.
func blocks_person(type: String, slot: Dictionary, y: float, pos: Vector3, radius := 0.4, height := 1.8) -> bool:
	var c: Array = piece_colliders(type)[0]
	var local: Vector3 = piece_transform(slot, y).affine_inverse() * pos - c[1]
	var half: Vector3 = c[0] * 0.5
	if absf(local.x) > half.x + radius or absf(local.z) > half.z + radius:
		return false
	return local.y < half.y + 0.3 and local.y + height > -half.y


func save_data() -> Array:
	var out: Array = []
	for key in pieces:
		var p: Dictionary = pieces[key]
		out.append({"type": p.type, "kind": p.slot.kind, "cx": p.slot.cx, "cz": p.slot.cz, "dir": p.slot.dir, "y": p.y})
	return out


func load_data(data: Array) -> void:
	for key in pieces.keys():
		remove(key)
	for p in data:
		if PIECES.has(p.get("type", "")):
			var slot := {"kind": str(p.kind), "cx": int(p.cx), "cz": int(p.cz), "dir": int(p.dir)}
			place(p.type, slot, float(p.y))

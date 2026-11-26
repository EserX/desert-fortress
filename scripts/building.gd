extends Node3D
## Player-built fortress pieces on a 2 m grid, stacked in levels 2.4 m apart.
## Cell pieces (foundation, floor, roof, stairs, ramp) fill a grid square;
## edge pieces (wall, doorway, window) stand on the line between two squares.
## Each slot holds at most one piece. Stairs and ramps are 2 squares long.
## Objects (chest, workbench, spike barricade) stand in a square too, on the
## sand, a foundation or a floor, in a slot of their own ("obj").
## Everything must be built inside the base zone around the flag.

const LowPoly = preload("res://scripts/lowpoly.gd")
const Inventory = preload("res://scripts/inventory.gd")

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
const ZONE_RADIUS := 26.0    # base build zone around the flag at the origin (before upgrades)
const CHEST_SLOTS := 20      # before upgrades

signal piece_destroyed(key: String, type: String)
## A piece fell down because what held it up was destroyed.
signal piece_collapsed(key: String, type: String)
## A chest was taken down with things inside: drop them in a bag here.
signal spilled(items: Dictionary, pos: Vector3)

## type -> {"name", "slot": "cell"/"edge"/"obj", "cost", "dirs": how many ways R turns it,
## "fixed": no material tiers, "pickup": demolishing gives the whole cost back}
const PIECES := {
	"foundation": {"name": "Wooden foundation", "slot": "cell", "cost": {"wood": 4, "nails": 4}, "dirs": 1},
	"wall": {"name": "Wooden wall", "slot": "edge", "cost": {"wood": 3, "nails": 3}, "dirs": 2},
	"doorway": {"name": "Doorway with gate", "slot": "edge", "cost": {"wood": 4, "nails": 4}, "dirs": 2},
	"window": {"name": "Wall with window", "slot": "edge", "cost": {"wood": 3, "nails": 3}, "dirs": 2},
	"floor": {"name": "Wooden floor", "slot": "cell", "cost": {"wood": 3, "nails": 3}, "dirs": 1},
	"stairs": {"name": "Wooden stairs", "slot": "cell", "cost": {"wood": 5, "nails": 4}, "dirs": 4, "long": true},
	"ramp": {"name": "Scrap ramp", "slot": "cell", "cost": {"scrap": 3, "wood": 2, "nails": 3}, "dirs": 4, "long": true},
	"roof": {"name": "Scrap roof", "slot": "cell", "cost": {"scrap": 3, "nails": 2}, "dirs": 1},
	"chest": {"name": "Storage chest", "slot": "obj", "cost": {"wood": 6, "nails": 4}, "dirs": 4, "fixed": true},
	"workbench": {"name": "Workbench", "slot": "obj", "cost": {"wood": 6, "scrap": 3, "nails": 4}, "dirs": 4, "fixed": true},
	"spikes": {"name": "Spike barricade", "slot": "obj", "cost": {"spike_barricade": 1}, "dirs": 2, "fixed": true, "pickup": true},
	"spike_strip": {"name": "Spike strip", "slot": "obj", "cost": {"wood": 2, "nails": 8}, "dirs": 2, "fixed": true, "trap": true},
	"barbed_wire": {"name": "Barbed wire", "slot": "obj", "cost": {"scrap": 3, "nails": 4}, "dirs": 2, "fixed": true, "trap": true},
	"landmine": {"name": "Landmine", "slot": "obj", "cost": {"scrap": 4, "nails": 4, "cloth": 1}, "dirs": 1, "fixed": true, "trap": true},
	"fire_pit": {"name": "Fire pit", "slot": "obj", "cost": {"wood": 4}, "dirs": 1, "fixed": true},
	"generator": {"name": "Fuel generator", "slot": "obj", "cost": {"scrap": 12, "nails": 8}, "dirs": 4, "fixed": true},
	"electric_fence": {"name": "Electric fence", "slot": "edge", "cost": {"scrap": 5, "nails": 6}, "dirs": 2, "fixed": true, "blueprint": true},
	"floodlight": {"name": "Floodlight", "slot": "obj", "cost": {"scrap": 4, "wood": 2, "nails": 2}, "dirs": 4, "fixed": true},
	"turret": {"name": "Auto-turret", "slot": "obj", "cost": {"scrap": 18, "nails": 10, "wood": 2}, "dirs": 4, "fixed": true, "blueprint": true},
	"landing_pad": {"name": "Drone landing pad", "slot": "obj", "cost": {"wood": 4, "scrap": 2, "nails": 4}, "dirs": 1, "fixed": true},
	"sandbags": {"name": "Sandbag wall", "slot": "edge", "cost": {"cloth": 4, "cement": 2}, "dirs": 2, "fixed": true, "hp": 900.0, "blueprint": true},
}
const ORDER := ["foundation", "wall", "doorway", "window", "floor", "stairs", "ramp", "roof", "chest", "workbench", "spikes", "spike_strip", "barbed_wire", "landmine", "fire_pit", "generator", "electric_fence", "floodlight", "turret", "landing_pad", "sandbags"]
## Pieces marked "blueprint" must be unlocked first (blueprints come by drone).
const TURRET_RANGE := 22.0
const TURRET_AMMO := 240     # 9mm rounds its ammo box holds
const FENCE_H := 1.7
const GEN_TANK := 10.0       # fuel cans a generator holds
const FIRE_MAX := 300.0      # seconds of burning a fire pit holds
const FIRE_PER_WOOD := 60.0
## Traps don't block anyone: their bodies sit on their own physics layer (5),
## which only the hammer's aim ray looks at.
const TRAP_LAYER := 16
## Edge pieces that hold up whatever is built above them.
const WALLISH := ["wall", "doorway", "window"]
## Cell pieces you can stand on at an upper level.
const DECKS := ["floor", "roof"]

var terrain  # Terrain
## Grown by base upgrades from the shop.
var zone_radius := ZONE_RADIUS
var chest_slots := CHEST_SLOTS
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
	_mats.stone = LowPoly.material(Color(0.45, 0.41, 0.37))
	_mats.cloth = LowPoly.material(Color(0.7, 0.6, 0.42))
	_mats.cloth_dark = LowPoly.material(Color(0.6, 0.51, 0.36))
	_mats.live = StandardMaterial3D.new()  # electric fence wire with the power on
	_mats.live.albedo_color = Color(0.6, 0.9, 1.0)
	_mats.live.emission_enabled = true
	_mats.live.emission = Color(0.4, 0.8, 1.0)
	_mats.live.emission_energy_multiplier = 1.6
	_mats.lamp = StandardMaterial3D.new()
	_mats.lamp.albedo_color = Color(1.0, 0.97, 0.85)
	_mats.lamp.emission_enabled = true
	_mats.lamp.emission = Color(1.0, 0.95, 0.8)
	_mats.lamp.emission_energy_multiplier = 0.0
	_mats.lamp_on = _mats.lamp.duplicate()
	_mats.lamp_on.emission_energy_multiplier = 4.0
	_mats.flame = StandardMaterial3D.new()
	_mats.flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats.flame.albedo_color = Color(1.0, 0.6, 0.15)


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
	if PIECES[type].slot != "edge":
		return {"kind": PIECES[type].slot, "cx": cx, "cz": cz, "dir": dir % PIECES[type].dirs, "level": 0}
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
	if slot.kind != "edge":
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
	elif PIECES[type].get("long", false) or slot.kind == "obj":
		yaw = -slot.dir * PI / 2
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.z))


## Ground heights under a slot (both squares for long pieces).
func _ground_samples(type: String, slot: Dictionary) -> Array:
	var out: Array = []
	var h := CELL * 0.5
	var centers: Array = []
	var pts: Array
	if slot.kind != "edge":
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
	if slot.kind == "obj":
		var under := piece_at(cell_key(slot.cx, slot.cz, 0))
		if not under.is_empty() and under.type in ["foundation", "floor"]:
			return {"y": under.y, "steep": false}
		return {"y": lo, "steep": steep}
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
	if slot.kind == "obj":
		var deck := piece_at(cell_key(slot.cx, slot.cz, lv))
		return deck.y if not deck.is_empty() and deck.type in DECKS else NAN
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
	if not in_zone(type, slot):
		return {"y": _ground_level(type, slot).y, "ok": false, "reason": "Outside the base zone (stay within %d m of the flag)" % int(zone_radius)}
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


## True if a piece in this slot is inside the base build zone.
func in_zone(type: String, slot: Dictionary) -> bool:
	var c := slot_center(slot, type)
	return Vector2(c.x, c.z).length() <= zone_radius


## Storage upgrade: every chest (and every new one) gets n slots.
func set_chest_slots(n: int) -> void:
	chest_slots = maxi(n, chest_slots)
	for key in pieces:
		if pieces[key].has("storage"):
			pieces[key].storage.resize(chest_slots)


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
		"chest":
			out.append([Vector3(1.1, 0.6, 0.65), Vector3(0, 0.3, 0), "wood"])
			out.append([Vector3(1.14, 0.12, 0.69), Vector3(0, 0.66, 0), "wood_dark"])
			for s in [-1.0, 1.0]:
				out.append([Vector3(0.06, 0.74, 0.7), Vector3(s * 0.4, 0.36, 0), "metal"])
			out.append([Vector3(0.14, 0.16, 0.05), Vector3(0, 0.56, -0.34), "metal"])
		"workbench":
			out.append([Vector3(1.7, 0.1, 0.8), Vector3(0, 0.9, 0), "plank"])
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					out.append([Vector3(0.1, 0.85, 0.1), Vector3(sx * 0.75, 0.425, sz * 0.32), "wood_dark"])
			out.append([Vector3(1.6, 0.06, 0.7), Vector3(0, 0.3, 0), "wood"])
			out.append([Vector3(0.2, 0.16, 0.2), Vector3(0.62, 1.03, -0.25), "metal"])
			out.append([Vector3(0.5, 0.02, 0.4), Vector3(-0.35, 0.96, 0.05), "rust"])
			out.append([Vector3(0.08, 0.3, 0.06), Vector3(-0.1, 1.1, 0.25), "wood_dark"])
		"spikes":
			out.append([Vector3(1.9, 0.18, 0.18), Vector3(0, 0.35, 0), "wood_dark"])
			for i in 5:
				var x := -0.8 + i * 0.4
				out.append([Vector3(0.08, 0.08, 1.4), Vector3(x, 0.5, 0), "plank", 0.6])
				out.append([Vector3(0.08, 0.08, 1.4), Vector3(x + 0.1, 0.5, 0), "wood", -0.6])
		"spike_strip":
			out.append([Vector3(1.8, 0.05, 0.5), Vector3(0, 0.03, 0), "wood_dark"])
			for i in 8:
				for j in [-1.0, 0.0, 1.0]:
					out.append([Vector3(0.025, 0.13, 0.025), Vector3(-0.77 + i * 0.22 + j * 0.05, 0.11, j * 0.15), "metal"])
		"barbed_wire":
			for sx in [-1.0, 1.0]:
				out.append([Vector3(0.07, 0.95, 0.07), Vector3(sx * 0.85, 0.47, 0), "wood_dark"])
			for h in [0.22, 0.45, 0.7, 0.9]:
				out.append([Vector3(1.75, 0.02, 0.02), Vector3(0, h, 0), "metal"])
			for z in [-0.2, 0.2]:
				for h in [0.3, 0.6]:
					out.append([Vector3(1.75, 0.02, 0.02), Vector3(0, h + z * 0.2, z), "metal"])
			for i in 9:
				out.append([Vector3(0.05, 0.05, 0.05), Vector3(-0.8 + i * 0.2, [0.22, 0.45, 0.7][i % 3], 0), "rust"])
		"landmine":
			out.append([Vector3(0.36, 0.07, 0.36), Vector3(0, 0.02, 0), "rust"])
			out.append([Vector3(0.12, 0.04, 0.12), Vector3(0, 0.07, 0), "metal"])
			out.append([Vector3(0.025, 0.45, 0.025), Vector3(0.3, 0.22, 0.3), "wood"])  # a little marker flag
			out.append([Vector3(0.14, 0.09, 0.01), Vector3(0.37, 0.4, 0.3), "rust"])
		"fire_pit":
			for i in 8:
				var a := i * TAU / 8.0
				out.append([Vector3(0.28, 0.2, 0.22), Vector3(cos(a) * 0.5, 0.1, sin(a) * 0.5), "stone"])
			out.append([Vector3(0.8, 0.12, 0.12), Vector3(0, 0.1, 0), "wood_dark"])
			out.append([Vector3(0.12, 0.12, 0.8), Vector3(0, 0.2, 0), "wood_dark"])
		"generator":
			out.append([Vector3(1.0, 0.55, 0.6), Vector3(0, 0.38, 0), "metal"])
			out.append([Vector3(0.7, 0.2, 0.5), Vector3(-0.1, 0.75, 0), "rust"])     # fuel tank
			out.append([Vector3(1.1, 0.08, 0.7), Vector3(0, 0.07, 0), "wood_dark"])  # skid
			out.append([Vector3(0.08, 0.4, 0.08), Vector3(0.4, 0.85, 0.2), "metal"])  # exhaust
			out.append([Vector3(0.08, 0.08, 0.02), Vector3(0.35, 0.5, -0.31), "lamp"])  # running light
		"electric_fence":
			for sx in [-1.0, 1.0]:
				out.append([Vector3(0.1, FENCE_H, 0.1), Vector3(sx * (CELL * 0.5 - 0.05), FENCE_H * 0.5, 0), "wood_dark"])
			for i in 5:
				out.append([Vector3(CELL - 0.1, 0.025, 0.025), Vector3(0, 0.3 + i * 0.32, 0), "metal"])
				for sx in [-1.0, 1.0]:
					out.append([Vector3(0.05, 0.06, 0.06), Vector3(sx * (CELL * 0.5 - 0.12), 0.3 + i * 0.32, 0), "rust"])
		"floodlight":
			out.append([Vector3(0.5, 0.1, 0.5), Vector3(0, 0.05, 0), "concrete_dark"])
			out.append([Vector3(0.1, 3.2, 0.1), Vector3(0, 1.6, 0), "metal"])
			out.append([Vector3(0.7, 0.07, 0.07), Vector3(0, 3.2, -0.05), "metal"])
			for sx in [-1.0, 1.0]:
				out.append([Vector3(0.3, 0.22, 0.18), Vector3(sx * 0.28, 3.2, -0.15), "metal"])
				out.append([Vector3(0.26, 0.18, 0.02), Vector3(sx * 0.28, 3.2, -0.25), "lamp"])
		"turret":
			out.append([Vector3(0.9, 0.1, 0.9), Vector3(0, 0.05, 0), "concrete_dark"])
			out.append([Vector3(0.2, 0.85, 0.2), Vector3(0, 0.5, 0), "metal"])
			out.append([Vector3(0.45, 0.32, 0.3), Vector3(0.0, 0.26, 0.42), "rust"])   # ammo box
			out.append([Vector3(0.36, 0.04, 0.26), Vector3(0.0, 0.44, 0.42), "metal"])
			out.append([Vector3(0.04, 0.5, 0.04), Vector3(0.0, 0.7, 0.3), "metal"])     # feed belt
		"landing_pad":
			out.append([Vector3(1.9, 0.12, 1.9), Vector3(0, 0.06, 0), "concrete_dark"])
			for sx in [-1.0, 1.0]:
				out.append([Vector3(0.16, 0.02, 0.9), Vector3(sx * 0.3, 0.125, 0), "lamp"])  # the H
			out.append([Vector3(0.6, 0.02, 0.16), Vector3(0, 0.125, 0), "lamp"])
			for c in [Vector3(-0.85, 0.14, -0.85), Vector3(0.85, 0.14, -0.85), Vector3(-0.85, 0.14, 0.85), Vector3(0.85, 0.14, 0.85)]:
				out.append([Vector3(0.1, 0.06, 0.1), c, "rust"])
		"sandbags":
			for row in 3:
				for i in 4:
					var x := -0.75 + i * 0.5 + (0.25 if row % 2 == 1 else 0.0)
					if x > 0.9:
						continue
					out.append([Vector3(0.52, 0.3, 0.42 - row * 0.06), Vector3(x, 0.15 + row * 0.3, 0), "cloth" if (i + row) % 2 == 0 else "cloth_dark"])
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
		"chest":
			return [[Vector3(1.1, 0.72, 0.65), Vector3(0, 0.36, 0), 0.0]]
		"workbench":
			return [[Vector3(1.7, 0.95, 0.8), Vector3(0, 0.475, 0), 0.0]]
		"spikes":
			return [[Vector3(1.9, 1.0, 1.2), Vector3(0, 0.5, 0), 0.0]]
		"spike_strip":
			return [[Vector3(1.8, 0.25, 0.5), Vector3(0, 0.12, 0), 0.0]]
		"barbed_wire":
			return [[Vector3(1.8, 0.95, 0.5), Vector3(0, 0.47, 0), 0.0]]
		"landmine":
			return [[Vector3(0.5, 0.3, 0.5), Vector3(0, 0.15, 0), 0.0]]
		"fire_pit":
			return [[Vector3(1.2, 0.3, 1.2), Vector3(0, 0.15, 0), 0.0]]
		"generator":
			return [[Vector3(1.1, 0.9, 0.7), Vector3(0, 0.45, 0), 0.0]]
		"electric_fence":
			return [[Vector3(CELL, FENCE_H, 0.15), Vector3(0, FENCE_H * 0.5, 0), 0.0]]
		"floodlight":
			return [[Vector3(0.5, 3.4, 0.5), Vector3(0, 1.7, 0), 0.0]]
		"turret":
			return [[Vector3(0.9, 1.3, 1.0), Vector3(0, 0.65, 0.1), 0.0]]
		"landing_pad":
			return [[Vector3(1.9, 0.14, 1.9), Vector3(0, 0.07, 0), 0.0]]
		"sandbags":
			return [[Vector3(CELL, 0.95, 0.45), Vector3(0, 0.47, 0), 0.0]]
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
	if PIECES[type].get("trap", false):
		body.collision_layer = TRAP_LAYER
		body.collision_mask = 0
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
	elif type == "chest":
		rec.storage = Inventory.new(chest_slots)
		body.set_meta("interact_id", "chest:" + key)
	elif type == "workbench":
		body.set_meta("interact_id", "bench:" + key)
	elif type == "generator":
		rec.fuel = 0.0
		rec.running = false
		body.set_meta("interact_id", "gen:" + key)
	elif type == "fire_pit":
		rec.burn = 0.0
		body.set_meta("interact_id", "fire:" + key)
		_add_flame(rec)
	elif type == "floodlight":
		var spot := SpotLight3D.new()
		spot.position = Vector3(0, 3.1, -0.3)
		spot.rotation.x = -0.45
		spot.spot_range = 30.0
		spot.spot_angle = 38.0
		spot.light_energy = 5.0
		spot.light_color = Color(1.0, 0.96, 0.85)
		spot.visible = false
		body.add_child(spot)
		rec.light = spot
	elif type == "turret":
		rec.ammo = 0
		body.set_meta("interact_id", "turret:" + key)
		_add_turret_head(rec)
	if type in ["floodlight", "electric_fence"]:
		rec.powered = false
	return key


## The part that turns: a swivel with a gun on it and a muzzle flash.
func _add_turret_head(rec: Dictionary) -> void:
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 1.0
	head.scale = Vector3.ONE * 1.4
	rec.node.add_child(head)
	var gun := Node3D.new()
	head.add_child(gun)
	for b in [[Vector3(0.34, 0.24, 0.5), Vector3(0, 0.05, 0.02), "metal"], [Vector3(0.07, 0.07, 0.7), Vector3(0, 0.07, -0.55), "rust"],
			[Vector3(0.1, 0.1, 0.12), Vector3(0, 0.07, -0.88), "metal"], [Vector3(0.3, 0.03, 0.3), Vector3(0, 0.19, 0.0), "rust"],
			[Vector3(0.36, 0.22, 0.04), Vector3(0, 0.12, -0.24), "metal"]]:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(b[0])
		mi.position = b[1]
		mi.set_meta("mat", b[2])
		mi.material_override = _mats[b[2]]
		gun.add_child(mi)
	var flash := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.18, 0.18, 0.25)
	flash.mesh = fm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	flash.material_override = mat
	flash.position = Vector3(0, 0.07, -1.05)
	flash.visible = false
	gun.add_child(flash)
	rec.head = head
	rec.gun = gun
	rec.flash = flash


## Lamps glow and fence wires look live while the piece has power.
func set_powered(rec: Dictionary, on: bool) -> void:
	if rec.get("powered", null) == null and rec.type != "generator":
		return
	if rec.has("powered"):
		if rec.powered == on:
			return
		rec.powered = on
	for mi in _meshes(rec.node):
		var m: String = mi.get_meta("mat")
		if m == "lamp":
			mi.material_override = _mats.lamp_on if on else _mats.lamp
		elif m == "metal" and rec.type == "electric_fence" and mi.mesh.size.x > 1.0:
			mi.material_override = _mats.live if on else _mats.metal
	if rec.has("light"):
		rec.light.visible = on


## Flames (a few unshaded wedges) and a flickering light, shown while it burns.
func _add_flame(rec: Dictionary) -> void:
	var flame := Node3D.new()
	flame.name = "Flame"
	flame.position.y = 0.25
	rec.node.add_child(flame)
	for i in 4:
		var mi := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.22 - i * 0.03
		cone.height = 0.7 - i * 0.08
		cone.radial_segments = 5
		cone.rings = 1
		mi.mesh = cone
		mi.material_override = _mats.flame
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(i * 2.1) * 0.12, cone.height * 0.5, sin(i * 2.1) * 0.12) if i > 0 else Vector3(0, cone.height * 0.5, 0)
		flame.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position.y = 0.6
	flame.add_child(light)
	flame.visible = false
	rec.flame = flame


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


## Prompt text for a gate, chest or workbench interact id ("gate:<key>"...), or "".
func prompt(id: String) -> String:
	var key := id.substr(id.find(":") + 1)
	if not pieces.has(key):
		return ""
	if id.begins_with("gate:"):
		return "[E] Close gate" if pieces[key].open else "[E] Open gate"
	if id.begins_with("chest:"):
		return "[E] Open storage chest"
	if id.begins_with("bench:"):
		return "[E] Use workbench"
	var rec: Dictionary = pieces[key]
	if id.begins_with("gen:"):
		var state := "running" if rec.running else ("idle, runs at night" if rec.fuel > 0.0 else "out of fuel")
		return "[E] Add a fuel can   Generator %d/%d cans, %s" % [ceili(rec.fuel), int(GEN_TANK), state]
	if id.begins_with("turret:"):
		return "[E] Load 9mm rounds   Auto-turret %d/%d rounds%s" % [rec.ammo, TURRET_AMMO, "" if rec.ammo > 0 else ", EMPTY"]
	if id.begins_with("fire:"):
		if rec.burn <= 0.0:
			return "[E] Light the fire (1 wood)"
		return "[E] Add wood   Burning %d:%02d" % [int(rec.burn) / 60, int(rec.burn) % 60]
	return ""


## The storage of a chest piece, or null.
func storage_of(key: String) -> Inventory:
	return pieces.get(key, {}).get("storage", null)


## Takes a piece away. A chest's contents spill into a bag unless spill is false.
func remove(key: String, spill := true) -> String:
	key = occupied.get(key, key)
	if not pieces.has(key):
		return ""
	var rec: Dictionary = pieces[key]
	if spill and rec.has("storage") and not rec.storage.contents().is_empty():
		spilled.emit(rec.storage.contents(), rec.node.global_position)
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
	return float(PIECES[rec.type].get("hp", TIER_HP[rec.tier]))


## Short name like "Scrap metal wall".
func describe(rec: Dictionary) -> String:
	if PIECES[rec.type].get("fixed", false):
		return PIECES[rec.type].name
	var noun: String = PIECES[rec.type].name.replace("Wooden ", "").replace("Scrap ", "")
	var tier_name: String = TIER_NAMES[rec.tier]
	return "%s%s %s" % [tier_name[0].to_upper(), tier_name.substr(1), noun.to_lower()]


## How much a piece's wood cost is worth in the next tier's material.
static func _size(type: String) -> int:
	var cost: Dictionary = PIECES[type].cost
	return maxi(2, int(cost.get("wood", 0)) + int(cost.get("scrap", 0)))


## What it costs to raise a piece one tier ({} at concrete).
func upgrade_cost(rec: Dictionary) -> Dictionary:
	if rec.tier >= TIER_NAMES.size() - 1 or PIECES[rec.type].get("fixed", false):
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
	if PIECES[rec.type].get("pickup", false):
		return PIECES[rec.type].cost.duplicate()
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
		_debris(rec)
		remove(key)
		piece_destroyed.emit(key, type)
		collapse_unsupported()
		return true
	_update_cracks(rec)
	return false


## Key of the built piece a collider belongs to (walls, gates...), or "".
func piece_key_of(n: Node) -> String:
	while n and n != self:
		if n.has_meta("piece_key"):
			return n.get_meta("piece_key")
		n = n.get_parent()
	return ""


## Keys of the pieces that could hold up an upper-level slot (same rules as _support_y).
func _supporters(slot: Dictionary) -> Array:
	var out: Array = []
	var lv: int = slot.level
	if slot.kind == "obj":
		var deck := piece_at(cell_key(slot.cx, slot.cz, lv))
		if not deck.is_empty() and deck.type in DECKS:
			out.append(slot_key(deck.slot))
		return out
	if slot.kind == "cell":
		for e in cell_edges(slot.cx, slot.cz, lv - 1):
			var w := piece_at(slot_key(e))
			if not w.is_empty() and w.type in WALLISH:
				out.append(slot_key(w.slot))
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var f := piece_at(cell_key(slot.cx + d.x, slot.cz + d.y, lv))
			if not f.is_empty() and f.type in DECKS:
				out.append(slot_key(f.slot))
		return out
	var below := piece_at(slot_key({"kind": "edge", "cx": slot.cx, "cz": slot.cz, "dir": slot.dir, "level": lv - 1}))
	if not below.is_empty() and below.type in WALLISH:
		out.append(slot_key(below.slot))
	for c in edge_cells(slot):
		var f := piece_at(cell_key(c.x, c.y, lv))
		if not f.is_empty() and f.type in DECKS:
			out.append(slot_key(f.slot))
	return out


## Upstairs pieces with no chain of support down to the ground fall down
## (two floors can't hold each other up in the air). Returns how many fell.
func collapse_unsupported() -> int:
	var grounded := {}
	for key in pieces:
		if pieces[key].slot.level == 0:
			grounded[key] = true
	var changed := true
	while changed:
		changed = false
		for key in pieces:
			if grounded.has(key):
				continue
			for k in _supporters(pieces[key].slot):
				if grounded.has(k):
					grounded[key] = true
					changed = true
					break
	var fell := 0
	for key in pieces.keys():
		if not grounded.has(key):
			var rec: Dictionary = pieces[key]
			_debris(rec)
			remove(key)
			piece_collapsed.emit(key, rec.type)
			fell += 1
	return fell


## Broken boards and chunks tumble to the ground in a puff of dust, with a crash.
func _debris(rec: Dictionary) -> void:
	if not is_inside_tree():
		return
	var b := piece_bounds(rec.type)
	var size: Vector3 = b[0]
	var xf: Transform3D = rec.node.global_transform
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(slot_key(rec.slot)) + Time.get_ticks_msec()
	var mat: Material = _tier_mat(rec.tier, "plank")
	var ground: float = terrain.surface_height(xf.origin.x, xf.origin.z) if terrain else xf.origin.y
	for i in 9:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(Vector3(rng.randf_range(0.2, 0.7), rng.randf_range(0.08, 0.3), rng.randf_range(0.1, 0.3)))
		mi.material_override = mat
		add_child(mi)
		var local: Vector3 = b[1] + Vector3(rng.randf_range(-0.5, 0.5) * size.x, rng.randf_range(-0.4, 0.4) * size.y, rng.randf_range(-0.5, 0.5) * size.z)
		mi.global_position = xf * local
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		var land := mi.global_position + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
		land.y = maxf(ground, xf.origin.y) + 0.1
		var t := rng.randf_range(0.45, 0.8)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "global_position", land, t).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(mi, "rotation", mi.rotation + Vector3(rng.randf_range(-3, 3), rng.randf_range(-3, 3), 0), t)
		tw.chain().tween_interval(2.0)
		tw.chain().tween_property(mi, "scale", Vector3.ONE * 0.01, 0.6)
		tw.chain().tween_callback(mi.queue_free)
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = 24
	dust.lifetime = 1.6
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = size * 0.5
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 0.5
	dust.initial_velocity_max = 2.0
	dust.gravity = Vector3(0, -0.6, 0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	var q := SphereMesh.new()
	q.radius = 0.3
	q.height = 0.6
	q.radial_segments = 6
	q.rings = 3
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.8, 0.68, 0.5, 0.5)
	q.material = dm
	dust.mesh = q
	add_child(dust)
	dust.global_position = xf * b[1]
	get_tree().create_timer(2.0).timeout.connect(dust.queue_free)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = _crash_sound()
	snd.unit_size = 10.0
	snd.max_distance = 70.0
	add_child(snd)
	snd.global_position = xf.origin
	snd.pitch_scale = rng.randf_range(0.85, 1.1)
	snd.play()
	snd.finished.connect(snd.queue_free)


var _crash: AudioStreamWAV

## Generated crash: a burst of crackling noise over a low rumble.
func _crash_sound() -> AudioStreamWAV:
	if _crash:
		return _crash
	var rate := 22050
	var n := int(rate * 1.1)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += (rng.randf_range(-1, 1) - lp) * 0.08
		var crackle := rng.randf_range(-1, 1) * (1.0 if rng.randf() < 0.08 else 0.25) * exp(-t * 5.0)
		var s := (lp * 2.2 * exp(-t * 2.5) + crackle * 0.6 + sin(TAU * 55.0 * t) * 0.4 * exp(-t * 4.0)) * minf(t / 0.005, 1.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	_crash = AudioStreamWAV.new()
	_crash.format = AudioStreamWAV.FORMAT_16_BITS
	_crash.mix_rate = rate
	_crash.data = data
	return _crash


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
		var d := {"type": p.type, "kind": p.slot.kind, "cx": p.slot.cx, "cz": p.slot.cz, "dir": p.slot.dir, "level": p.slot.level, "y": p.y, "open": p.open, "tier": p.tier, "hp": p.hp}
		if p.has("storage"):
			d.items = p.storage.save_data()
		for k in ["fuel", "burn", "ammo"]:
			if p.has(k):
				d[k] = p[k]
		out.append(d)
	return out


func load_data(data: Array) -> void:
	for key in pieces.keys():
		remove(key, false)
	for p in data:
		if PIECES.has(p.get("type", "")):
			var slot := {"kind": str(p.kind), "cx": int(p.cx), "cz": int(p.cz), "dir": int(p.dir), "level": int(p.get("level", 0))}
			var key := place(p.type, slot, float(p.y), bool(p.get("open", false)), int(p.get("tier", -1)), float(p.get("hp", -1.0)))
			if pieces[key].has("storage") and p.has("items"):
				pieces[key].storage.load_data(p.items)
			if pieces[key].has("fuel"):
				pieces[key].fuel = clampf(float(p.get("fuel", 0.0)), 0.0, GEN_TANK)
			if pieces[key].has("ammo"):
				pieces[key].ammo = clampi(int(p.get("ammo", 0)), 0, TURRET_AMMO)
			if pieces[key].has("burn"):
				pieces[key].burn = clampf(float(p.get("burn", 0.0)), 0.0, FIRE_MAX)

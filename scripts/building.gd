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
const Prefabs = preload("res://scripts/prefabs.gd")
const Furnace = preload("res://scripts/furnace.gd")

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
const TIER_NAMES := ["wood", "scrap metal", "stone", "concrete"]
const TIER_HP := [250.0, 600.0, 1000.0, 1500.0]
const TIER_ITEM := ["wood", "scrap", "stone", "cement"]
const REFUND := 0.5          # share of what a piece cost you get back when demolished
const UNDO_SECONDS := 60.0   # build-mode right click gives everything back this soon after building
const ZONE_RADIUS := 26.0    # base build zone around the flag at the origin (before upgrades)
const CHEST_SLOTS := 20      # before upgrades
## Power: cables (laid with cable from a reel) join wired pieces; power flows from
## running generators along them, through switches that are on. Pieces within
## PLUG_RANGE of a running generator are plugged straight into it.
const WIRED := ["generator", "switch", "floodlight", "electric_fence", "turret", "sawmill", "crusher", "nail_press"]
## Machines (bought by drone, run on power): E loads what they take from your
## pockets and takes what they made. Every `secs` seconds with power they turn
## `need` of `in` into `make` of `out`.
const MACHINES := {
	"sawmill": {"in": "log", "need": 1, "out": "wood", "make": 5, "secs": 6.0},
	"crusher": {"in": "stone", "need": 3, "out": "cement", "make": 1, "secs": 15.0},
	"nail_press": {"in": "scrap", "need": 1, "out": "nails", "make": 8, "secs": 8.0},
}
const MACHINE_IN_MAX := 30   # items a machine's hopper takes
const MACHINE_OUT_MAX := 60  # items it holds before it stops
const PLUG_RANGE := 4.0
const CABLE_MAX := 24.0      # longest single cable
const CABLE_PER := 2.0       # metres of cable one cable item covers
## Gates (not trapdoors) left open at night close by themselves after this long.
const AUTO_CLOSE := 8.0
## Structural support, counted from the ground: pieces at ground level have 100%.
## Resting on what is below costs LOSS_UP, hanging off a floor next to it
## LOSS_SIDE, times the piece's tier weight (heavier tiers need more support).
## Below MIN_SUPPORT a piece comes down.
const MIN_SUPPORT := 20.0
const LOSS_UP := 10.0
const LOSS_SIDE := 25.0
const TIER_WEIGHT := [1.0, 1.15, 1.4, 1.3]
## A spiked pit goes in a hole at least this deep. A ladder is this tall.
const PIT_DEPTH := 0.9
const LADDER_H := 4.2
## A well goes over a shaft dug this deep (down into the stone) and fills a
## bottle of water every WELL_SECONDS, holding up to WELL_MAX.
const WELL_DEPTH := 3.5
const WELL_SECONDS := 75.0
const WELL_MAX := 6.0
## Dig more than this out from under a piece standing on the sand and it falls
## (foundations take 0.4 m more).
const UNDERMINE_GAP := 0.6

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
	"doorway": {"name": "Doorway with gate", "slot": "edge", "cost": {"wood": 4, "nails": 4}, "dirs": 2, "gate": true},
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
	"sandbags": {"name": "Sandbag wall", "slot": "edge", "cost": {"sand": 6, "cloth": 2}, "dirs": 2, "fixed": true, "hp": 900.0, "blueprint": true},
	"ladder": {"name": "Ladder", "slot": "obj", "cost": {"wood": 4, "nails": 4}, "dirs": 4, "fixed": true, "steep_ok": true, "noblock": true},
	"half_wall": {"name": "Wooden half wall", "slot": "edge", "cost": {"wood": 2, "nails": 2}, "dirs": 2},
	"low_wall": {"name": "Wooden low wall", "slot": "edge", "cost": {"wood": 1, "nails": 2}, "dirs": 2},
	"slit_wall": {"name": "Wooden gun slit wall", "slot": "edge", "cost": {"wood": 3, "nails": 3}, "dirs": 2},
	"pillar": {"name": "Wooden pillar", "slot": "post", "cost": {"wood": 2, "nails": 2}, "dirs": 1},
	"trapdoor": {"name": "Floor with trapdoor", "slot": "cell", "cost": {"wood": 4, "nails": 4}, "dirs": 4},
	"tri_foundation": {"name": "Wooden triangle foundation", "slot": "cell", "cost": {"wood": 2, "nails": 2}, "dirs": 4},
	"tri_roof": {"name": "Scrap triangle roof", "slot": "cell", "cost": {"scrap": 2, "nails": 1}, "dirs": 4},
	"metal_door": {"name": "Metal door", "slot": "edge", "cost": {"scrap": 8, "nails": 4}, "dirs": 2, "fixed": true, "hp": 1400.0, "gate": true},
	"switch": {"name": "Power switch", "slot": "obj", "cost": {"scrap": 2, "nails": 2}, "dirs": 4, "fixed": true},
	"well": {"name": "Water well", "slot": "obj", "cost": {"stone": 8, "wood": 4, "scrap": 2}, "dirs": 4, "fixed": true, "steep_ok": true, "pit": WELL_DEPTH, "over_pit": true},
	"log_stakes": {"name": "Log stakes", "slot": "obj", "cost": {"log": 3, "nails": 2}, "dirs": 2, "fixed": true, "trap": true},
	"sawmill": {"name": "Sawmill", "slot": "obj", "cost": {"kit_sawmill": 1}, "dirs": 4, "fixed": true, "pickup": true},
	"crusher": {"name": "Rock crusher", "slot": "obj", "cost": {"kit_crusher": 1}, "dirs": 4, "fixed": true, "pickup": true},
	"nail_press": {"name": "Nail press", "slot": "obj", "cost": {"kit_press": 1}, "dirs": 4, "fixed": true, "pickup": true},
	"sprinkler": {"name": "Sprinkler", "slot": "obj", "cost": {"scrap": 3, "nails": 2}, "dirs": 1, "fixed": true},
	"dew_collector": {"name": "Dew collector", "slot": "obj", "cost": {"kit_dew": 1}, "dirs": 4, "fixed": true, "pickup": true},
	"weather_station": {"name": "Weather station", "slot": "obj", "cost": {"kit_weather": 1}, "dirs": 4, "fixed": true, "pickup": true},
	# v2.2 crafting chain: the furnace and pieces made from what it smelts.
	"furnace": {"name": "Furnace", "slot": "obj", "cost": {"stone": 10, "clay": 4}, "dirs": 4, "fixed": true, "hp": 1000.0, "repair": "stone"},
	"brick_wall": {"name": "Brick wall", "slot": "edge", "cost": {"brick": 12, "clay": 2}, "dirs": 2, "fixed": true, "hp": 1200.0, "repair": "brick"},
	"glass_window": {"name": "Brick wall with glass window", "slot": "edge", "cost": {"brick": 9, "glass_pane": 1, "clay": 2}, "dirs": 2, "fixed": true, "hp": 1000.0, "repair": "brick"},
	"spiked_pit": {"name": "Spiked pit", "slot": "obj", "cost": {"wood": 4, "nails": 6}, "dirs": 1, "fixed": true, "trap": true, "steep_ok": true, "pit": PIT_DEPTH},
}
const ORDER := ["foundation", "wall", "doorway", "window", "floor", "stairs", "ramp", "roof", "chest", "workbench", "spikes", "spike_strip", "barbed_wire", "landmine", "fire_pit", "generator", "electric_fence", "floodlight", "turret", "landing_pad", "sandbags", "ladder", "spiked_pit", "well", "half_wall", "low_wall", "slit_wall", "pillar", "trapdoor", "tri_foundation", "tri_roof", "metal_door", "switch", "log_stakes", "sawmill", "crusher", "nail_press", "sprinkler", "dew_collector", "weather_station", "furnace", "brick_wall", "glass_window"]
## Pieces marked "blueprint" must be unlocked first (blueprints come by drone).
const TURRET_RANGE := 22.0
const TURRET_AMMO := 240     # 9mm rounds its ammo box holds
const FENCE_H := 1.7
const GEN_TANK := 10.0       # fuel cans a generator holds
const FIRE_MAX := 300.0      # seconds of burning a fire pit holds
const FIRE_PER_WOOD := 60.0
## Collapse debris: rigid chunks on their own physics layer (6), gone after a while.
const DEBRIS_LAYER := 32
const DEBRIS_SECONDS := 4.0
const MAX_DEBRIS := 72
## Traps don't block anyone: their bodies sit on their own physics layer (5),
## which only the hammer's aim ray looks at.
const TRAP_LAYER := 16
## Edge pieces that hold up whatever is built above them.
const WALLISH := ["wall", "doorway", "window", "slit_wall", "metal_door", "brick_wall", "glass_window"]
## Cell pieces you can stand on at an upper level.
const DECKS := ["floor", "roof", "trapdoor", "tri_roof"]
## Ground pieces that walls and floors stand on.
const FOUNDATIONS := ["foundation", "tri_foundation"]
## Prism pieces: half a square, cut corner to corner.
const TRIS := ["tri_foundation", "tri_roof"]
const HALF_H := 1.2   # half wall
const LOW_H := 0.7    # low wall
const SLIT_Y := 1.4   # gun slit: bottom and height
const SLIT_H := 0.16
const SLIT_W := 1.0
const PILLAR_T := 0.3
const HATCH := 1.0    # trapdoor opening, on the north side of its square
## Objects that turn freely in TURN_STEP steps (Z / X in build mode), not just
## the four grid ways: slot "turn" holds the extra steps (0..5) past "dir".
const FREE_TURN := ["chest", "workbench", "spikes", "spike_strip", "barbed_wire", "landmine", "fire_pit", "generator", "floodlight", "turret", "switch", "log_stakes", "sawmill", "crusher", "nail_press", "furnace"]
const TURN_STEP := PI / 12.0
## Blueprints of ready-made buildings (see prefabs.gd) sit on interact layer 2.
const SITE_LAYER := 2

var terrain  # Terrain
## type -> {key: true}, kept up to date by place() and remove(), so systems
## that only care about turrets or traps don't scan every piece.
var _by_type := {}
## Grown by base upgrades from the shop.
var zone_radius := ZONE_RADIUS
## v1.18: claimed outposts' build zones, [Vector2 centre, radius] (set by oases.gd).
var outposts: Array = []
var chest_slots := CHEST_SLOTS
## main slot key -> {"type", "slot", "y", "node", "open" (gates), "tier", "hp", "built_at"}
var pieces := {}
## every slot key a piece takes up (stairs take two) -> main slot key
var occupied := {}
## main slot key -> support in % (see MIN_SUPPORT), kept up to date
var support := {}
var _bulk := false  # loading: work out support once at the end
## Goes up whenever something changes that mutants' paths care about (a piece
## built, gone, opened, upgraded or badly damaged). See nav.gd.
var revision := 0
## Cables: [key, key] pairs.
var cables: Array = []
var _cable_root: Node3D
var _mats := {}
## Blueprints of ready-made buildings still going up: id -> {"prefab", "y"
## (top of its foundations), "todo": [{"type", "slot"}] in build order, "node"}.
var sites := {}
var _site_next := 1


func _ready() -> void:
	_cable_root = Node3D.new()
	_cable_root.name = "Cables"
	add_child(_cable_root)
	_mats.wood = LowPoly.material(Color(0.52, 0.36, 0.22))
	_mats.wood_dark = LowPoly.material(Color(0.36, 0.24, 0.14))
	_mats.plank = LowPoly.material(Color(0.60, 0.43, 0.27))
	_mats.metal = LowPoly.material(Color(0.36, 0.38, 0.4), 0.55)
	_mats.rust = LowPoly.material(Color(0.5, 0.28, 0.14), 0.8)
	_mats.concrete = LowPoly.material(Color(0.5, 0.49, 0.46))
	_mats.concrete_dark = LowPoly.material(Color(0.38, 0.37, 0.35))
	_mats.crack = LowPoly.material(Color(0.08, 0.06, 0.05))
	_mats.stone = LowPoly.material(Color(0.45, 0.41, 0.37))
	_mats.stone_block = LowPoly.material(Color(0.47, 0.39, 0.31))
	_mats.stone_dark = LowPoly.material(Color(0.33, 0.27, 0.22))
	_mats.cloth = LowPoly.material(Color(0.7, 0.6, 0.42))
	_mats.cloth_dark = LowPoly.material(Color(0.6, 0.51, 0.36))
	_mats.water = LowPoly.material(Color(0.18, 0.32, 0.38), 0.1)
	_mats.cable = LowPoly.material(Color(0.12, 0.12, 0.13))
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
	_mats.blueprint = StandardMaterial3D.new()
	_mats.blueprint.albedo_color = Color(0.35, 0.7, 1.0, 0.28)
	_mats.blueprint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats.blueprint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats.blueprint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.brick = LowPoly.material(Color(0.62, 0.3, 0.2))
	_mats.brick_dark = LowPoly.material(Color(0.54, 0.25, 0.17))
	_mats.mortar = LowPoly.material(Color(0.72, 0.66, 0.56))
	_mats.glass = StandardMaterial3D.new()
	_mats.glass.albedo_color = Color(0.7, 0.88, 0.95, 0.3)
	_mats.glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats.glass.metallic_specular = 0.9
	_mats.glass.roughness = 0.05
	_mats.ember = StandardMaterial3D.new()
	_mats.ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats.ember.albedo_color = Color(1.0, 0.45, 0.1)
	_mats.flame = StandardMaterial3D.new()
	_mats.flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats.flame.albedo_color = Color(1.0, 0.6, 0.15)


## The material a mesh part uses at a tier (parts are designed in wood).
func _tier_mat(tier: int, key: String) -> Material:
	if tier == 1:
		return _mats[{"wood": "metal", "plank": "metal", "wood_dark": "rust"}.get(key, key)]
	if tier == 2:
		return _mats[{"wood": "stone_block", "plank": "stone_block", "metal": "stone_block", "wood_dark": "stone_dark", "rust": "stone_dark"}.get(key, key)]
	if tier == 3:
		return _mats[{"wood": "concrete", "plank": "concrete", "metal": "concrete", "wood_dark": "concrete_dark", "rust": "concrete_dark"}.get(key, key)]
	return _mats[key]


# --- Slots ----------------------------------------------------------------------

## The grid slot a piece type would use when aimed at world point p (level 0).
## dir: edges 0 = runs along X, 1 = along Z. Stairs/ramps 0..3 = rises to N, E, S, W.
static func slot_for(type: String, p: Vector3, dir: int) -> Dictionary:
	var cx := int(floor(p.x / CELL))
	var cz := int(floor(p.z / CELL))
	if PIECES[type].slot == "post":
		return {"kind": "post", "cx": int(round(p.x / CELL)), "cz": int(round(p.z / CELL)), "dir": 0, "level": 0}
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
	if slot.kind == "post":
		return Vector3(slot.cx * CELL, 0, slot.cz * CELL)
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
	elif PIECES[type].get("long", false) or slot.kind == "obj" or type in TRIS or type == "trapdoor":
		yaw = -slot.dir * PI / 2 - int(slot.get("turn", 0)) * TURN_STEP
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.z))


## Ground heights under a slot (both squares for long pieces).
func _ground_samples(type: String, slot: Dictionary) -> Array:
	var out: Array = []
	var h := CELL * 0.5
	var centers: Array = []
	var pts: Array
	if slot.kind == "post":
		centers.append(slot_center(slot))
		pts = [Vector2.ZERO, Vector2(0.15, 0.15), Vector2(-0.15, -0.15)]
	elif slot.kind != "edge":
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
	return p.y if not p.is_empty() and p.type in FOUNDATIONS else NAN


## The two squares either side of an edge.
static func edge_cells(slot: Dictionary) -> Array:
	if slot.dir == 0:
		return [Vector2i(slot.cx, slot.cz - 1), Vector2i(slot.cx, slot.cz)]
	return [Vector2i(slot.cx - 1, slot.cz), Vector2i(slot.cx, slot.cz)]


## The four squares around a grid corner (a post slot).
static func post_cells(slot: Dictionary) -> Array:
	return [Vector2i(slot.cx - 1, slot.cz - 1), Vector2i(slot.cx, slot.cz - 1), Vector2i(slot.cx - 1, slot.cz), Vector2i(slot.cx, slot.cz)]


static func post_key(cx: int, cz: int, level: int) -> String:
	return slot_key({"kind": "post", "cx": cx, "cz": cz, "dir": 0, "level": level})


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
	if slot.kind == "obj" and PIECES[type].get("over_pit", false):
		# Stands at the original ground level, over the shaft dug under it.
		var c := slot_center(slot)
		return {"y": terrain.original_height(c.x, c.z) if terrain.has_method("original_height") else hi, "steep": false}
	if slot.kind == "obj":
		var under := piece_at(cell_key(slot.cx, slot.cz, 0))
		if not under.is_empty() and under.type in FOUNDATIONS + ["floor", "trapdoor"]:
			return {"y": under.y, "steep": false}
		return {"y": lo, "steep": steep}
	if slot.kind == "post":
		var ptop := -INF
		for c in post_cells(slot):
			var t := foundation_top(c.x, c.y)
			if not is_nan(t):
				ptop = maxf(ptop, t)
		if ptop > -INF:
			return {"y": ptop, "steep": false}
		return {"y": lo - 0.1, "steep": steep}
	if slot.kind == "cell":
		var t := foundation_top(slot.cx, slot.cz)
		if not type in FOUNDATIONS and not is_nan(t):
			return {"y": t, "steep": false}
		return {"y": hi + 0.12 if type in FOUNDATIONS else lo, "steep": steep}
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
	if slot.kind == "post":
		var pb := piece_at(post_key(slot.cx, slot.cz, lv - 1))
		if not pb.is_empty():
			return pb.y + WALL_H
		for c in post_cells(slot):
			var f := piece_at(cell_key(c.x, c.y, lv))
			if not f.is_empty() and f.type in DECKS:
				return f.y
		return NAN
	if slot.kind == "obj":
		var deck := piece_at(cell_key(slot.cx, slot.cz, lv))
		return deck.y if not deck.is_empty() and deck.type in DECKS else NAN
	if slot.kind == "cell":
		# Walls on any edge below, or a floor next door at the same level.
		for e in cell_edges(slot.cx, slot.cz, lv - 1):
			var w := piece_at(slot_key(e))
			if not w.is_empty() and w.type in WALLISH:
				return w.y + WALL_H
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var pl := piece_at(post_key(slot.cx + o.x, slot.cz + o.y, lv - 1))
			if not pl.is_empty():
				return pl.y + WALL_H
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
	if type in FOUNDATIONS:
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
		if type in FOUNDATIONS:
			return {"y": 0.0, "ok": false, "reason": "Foundations go on the ground"}
		var sy := _support_y(slot)
		if is_nan(sy):
			return {"y": _ground_level(type, slot).y + slot.level * WALL_H, "ok": false, "reason": "Needs a wall or floor to hold it up"}
		var s := support_for({"type": type, "slot": slot, "tier": base_tier(type)})
		if s < MIN_SUPPORT:
			return {"y": sy, "ok": false, "reason": "Too far from support (%d%%): build closer to walls" % maxi(int(s), 0), "support": s}
		return {"y": sy, "ok": true, "reason": "", "support": s}
	var g := _ground_level(type, slot)
	if g.steep and not PIECES[type].get("steep_ok", false):
		return {"y": g.y, "ok": false, "reason": "Ground too steep"}
	if PIECES[type].has("pit") and terrain and terrain.has_method("depth_at"):
		var c := slot_center(slot)
		if terrain.depth_at(c.x, c.z) < float(PIECES[type].pit) - 0.001:
			return {"y": g.y, "ok": false, "reason": "Dig a pit at least %s m deep here first (%s)" % [str(PIECES[type].pit).trim_suffix(".0").replace("0.9", "1"), "pickaxe" if PIECES[type].pit > 2.7 else "shovel"]}
	return {"y": g.y, "ok": true, "reason": ""}


## True if a piece in this slot is inside the base build zone or an outpost's.
func in_zone(type: String, slot: Dictionary) -> bool:
	var c := slot_center(slot, type)
	var p := Vector2(c.x, c.z)
	if p.length() <= zone_radius:
		return true
	for o in outposts:
		if p.distance_to(o[0]) <= o[1]:
			return true
	return false


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
		"half_wall", "low_wall":
			var h := HALF_H if type == "half_wall" else LOW_H
			out.append([Vector3(CELL, h, WALL_T), Vector3(0, h * 0.5, 0), "wood"])
			out.append([Vector3(CELL - 0.02, 0.06, WALL_T + 0.04), Vector3(0, h - 0.03, 0), "wood_dark"])
		"slit_wall":
			var side := (CELL - SLIT_W) * 0.5
			out.append([Vector3(CELL, SLIT_Y, WALL_T), Vector3(0, SLIT_Y * 0.5, 0), "wood"])
			out.append([Vector3(CELL, WALL_H - SLIT_Y - SLIT_H, WALL_T), Vector3(0, (WALL_H + SLIT_Y + SLIT_H) * 0.5, 0), "wood"])
			for sx in [-1.0, 1.0]:
				out.append([Vector3(side, SLIT_H, WALL_T), Vector3(sx * (SLIT_W + side) * 0.5, SLIT_Y + SLIT_H * 0.5, 0), "wood"])
			out.append([Vector3(SLIT_W + 0.1, 0.04, WALL_T + 0.06), Vector3(0, SLIT_Y - 0.02, 0), "wood_dark"])
			out.append_array(_posts())
		"pillar":
			out.append([Vector3(PILLAR_T, WALL_H, PILLAR_T), Vector3(0, WALL_H * 0.5, 0), "wood"])
			out.append([Vector3(PILLAR_T + 0.06, 0.08, PILLAR_T + 0.06), Vector3(0, WALL_H - 0.04, 0), "wood_dark"])
		"trapdoor":
			# A floor with a HATCH x HATCH hole at its north edge (the lid is added on its own).
			var rest := CELL - HATCH - 0.1
			out.append([Vector3(CELL, FLOOR_T, rest), Vector3(0, -FLOOR_T * 0.5, CELL * 0.5 - rest * 0.5), "plank"])
			for sx in [-1.0, 1.0]:
				out.append([Vector3((CELL - HATCH) * 0.5, FLOOR_T, HATCH + 0.1), Vector3(sx * (CELL + HATCH) * 0.25, -FLOOR_T * 0.5, -CELL * 0.5 + (HATCH + 0.1) * 0.5), "plank"])
		"metal_door":
			var mside := (CELL - DOOR_W) * 0.5
			for sx in [-1.0, 1.0]:
				out.append([Vector3(mside, WALL_H, WALL_T), Vector3(sx * (DOOR_W + mside) * 0.5, WALL_H * 0.5, 0), "wood"])
			out.append([Vector3(DOOR_W, WALL_H - DOOR_H, WALL_T), Vector3(0, (WALL_H + DOOR_H) * 0.5, 0), "wood"])
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
		"log_stakes":
			# Sharpened logs crossed over a rail, points out both ways.
			out.append([Vector3(1.9, 0.18, 0.18), Vector3(0, 0.45, 0), "wood_dark"])
			for i in 4:
				var x := -0.72 + i * 0.48
				out.append([Vector3(0.16, 0.16, 1.5), Vector3(x, 0.45, 0), "wood", 0.55])
				out.append([Vector3(0.16, 0.16, 1.5), Vector3(x + 0.12, 0.45, 0), "plank", -0.55])
		"furnace":
			# A squat stone oven: a body, a darker hearth mouth at the front, a chimney.
			out.append([Vector3(1.3, 1.2, 1.2), Vector3(0, 0.6, 0), "stone_block"])
			out.append([Vector3(1.4, 0.15, 1.3), Vector3(0, 1.27, 0), "stone_dark"])
			out.append([Vector3(1.0, 0.18, 0.9), Vector3(0, 1.43, 0), "stone_block"])
			out.append([Vector3(0.6, 0.45, 0.05), Vector3(0, 0.45, 0.6), "stone_dark"])  # mouth
			out.append([Vector3(0.7, 0.06, 0.12), Vector3(0, 0.2, 0.62), "metal"])       # grate lip
			out.append([Vector3(0.4, 1.2, 0.4), Vector3(0.3, 2.1, -0.3), "stone_dark"])  # chimney
			out.append([Vector3(0.46, 0.08, 0.46), Vector3(0.3, 2.72, -0.3), "metal"])
		"brick_wall", "glass_window":
			# Brick courses (alternate rows of a lighter and darker red) with mortar lines.
			# The window hole (glass_window) is 0.94 m wide, from 0.9 to 1.8 m up.
			if type == "brick_wall":
				out.append([Vector3(CELL, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, 0), "mortar"])
			else:
				out.append([Vector3(CELL, 0.9, WALL_T), Vector3(0, 0.45, 0), "mortar"])
				out.append([Vector3(CELL, WALL_H - 1.8, WALL_T), Vector3(0, (WALL_H + 1.8) * 0.5, 0), "mortar"])
				for s in [-1.0, 1.0]:
					out.append([Vector3(0.53, 0.9, WALL_T), Vector3(s * 0.735, 1.35, 0), "mortar"])
			var rows := 8
			var rh := WALL_H / rows
			for r in rows:
				var mid := (r + 0.5) * rh
				if type == "glass_window" and mid > 0.9 and mid < 1.8:
					for s in [-1.0, 1.0]:
						out.append([Vector3(0.52, rh - 0.04, WALL_T + 0.02), Vector3(s * 0.73, mid, 0), "brick" if r % 2 == 0 else "brick_dark"])
					continue
				out.append([Vector3(CELL - 0.02, rh - 0.04, WALL_T + 0.02), Vector3(0, mid, 0), "brick" if r % 2 == 0 else "brick_dark"])
			if type == "glass_window":
				out.append([Vector3(1.0, 0.06, WALL_T + 0.08), Vector3(0, 0.9, 0), "metal"])    # sill
				out.append([Vector3(1.0, 0.06, WALL_T + 0.04), Vector3(0, 1.8, 0), "metal"])    # lintel
				out.append([Vector3(0.04, 0.88, 0.06), Vector3(0, 1.35, 0), "metal"])           # glazing bar
				out.append([Vector3(0.94, 0.88, 0.03), Vector3(0, 1.35, 0), "glass"])
		"sawmill":
			out.append([Vector3(1.8, 0.75, 0.8), Vector3(0, 0.375, 0), "wood_dark"])   # bench
			out.append([Vector3(1.8, 0.06, 0.7), Vector3(0, 0.78, 0), "plank"])        # table
			out.append([Vector3(0.5, 0.4, 0.4), Vector3(0.5, 0.35, 0.45), "metal"])     # motor
			out.append([Vector3(0.06, 0.08, 0.02), Vector3(0.5, 0.45, 0.66), "lamp"])
			out.append([Vector3(0.9, 0.3, 0.3), Vector3(-0.3, 0.98, 0), "wood"])        # a log on it
		"crusher":
			out.append([Vector3(1.3, 0.9, 1.1), Vector3(0, 0.45, 0), "metal"])          # body
			out.append([Vector3(1.4, 0.45, 1.2), Vector3(0, 1.15, 0), "rust"])          # hopper
			out.append([Vector3(0.5, 0.25, 0.6), Vector3(0, 0.2, 0.75), "rust"])        # chute
			out.append([Vector3(0.4, 0.35, 0.35), Vector3(0.75, 0.4, 0), "metal"])      # motor
			out.append([Vector3(0.06, 0.08, 0.02), Vector3(0.4, 0.75, 0.56), "lamp"])
		"nail_press":
			out.append([Vector3(0.9, 0.8, 0.8), Vector3(0, 0.4, 0), "metal"])          # base
			out.append([Vector3(0.18, 1.2, 0.18), Vector3(0, 1.2, -0.25), "rust"])     # column
			out.append([Vector3(0.7, 0.25, 0.5), Vector3(0, 1.75, -0.1), "metal"])      # head
			out.append([Vector3(0.4, 0.15, 0.4), Vector3(0, 0.88, 0.1), "rust"])        # die
			out.append([Vector3(0.06, 0.08, 0.02), Vector3(0.3, 0.6, 0.41), "lamp"])
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
			# A mast tall enough to fire over a wall (walls are 2.4 m).
			out.append([Vector3(0.2, 3.3, 0.2), Vector3(0, 1.7, 0), "metal"])
			for sx in [-1.0, 1.0]:
				out.append([Vector3(0.06, 2.2, 0.06), Vector3(sx * 0.3, 1.0, 0), "rust", 0.0])  # braces
			out.append([Vector3(0.66, 0.06, 0.06), Vector3(0, 2.1, 0), "rust"])
			out.append([Vector3(0.45, 0.32, 0.3), Vector3(0.0, 0.26, 0.42), "rust"])   # ammo box
			out.append([Vector3(0.36, 0.04, 0.26), Vector3(0.0, 0.44, 0.42), "metal"])
			out.append([Vector3(0.04, 2.9, 0.04), Vector3(0.0, 1.9, 0.12), "metal"])    # feed belt up the mast
		"ladder":
			# Two rails leaning on the pit wall to the north (of the way it faces), with rungs.
			var lean := 0.1
			for sx in [-0.28, 0.28]:
				out.append([Vector3(0.07, LADDER_H, 0.07), Vector3(sx, LADDER_H * 0.5, -0.8), "wood_dark", lean])
			for i in int(LADDER_H / 0.35):
				var h := 0.3 + i * 0.35
				out.append([Vector3(0.56, 0.05, 0.05), Vector3(0, h, -0.8 + (h - LADDER_H * 0.5) * -tan(lean)), "wood"])
		"sprinkler":
			out.append([Vector3(0.4, 0.06, 0.4), Vector3(0, 0.03, 0), "concrete_dark"])
			out.append([Vector3(0.06, 0.55, 0.06), Vector3(0, 0.3, 0), "metal"])
			out.append([Vector3(0.16, 0.08, 0.16), Vector3(0, 0.6, 0), "rust"])
			out.append([Vector3(0.36, 0.03, 0.04), Vector3(0, 0.66, 0), "metal"])
		"dew_collector":
			# A fine net stretched between two poles over a little tank.
			out.append([Vector3(0.9, 0.5, 0.5), Vector3(0, 0.25, 0), "rust"])          # tank
			out.append([Vector3(1.0, 0.06, 0.12), Vector3(0, 0.55, 0), "metal"])        # gutter
			for s in [-1.0, 1.0]:
				out.append([Vector3(0.07, 2.4, 0.07), Vector3(s * 0.8, 1.2, 0), "wood_dark"])
			out.append([Vector3(1.5, 1.6, 0.02), Vector3(0, 1.45, 0), "plank"])         # the net
			for i in 4:
				out.append([Vector3(1.5, 0.02, 0.03), Vector3(0, 0.75 + i * 0.47, 0), "metal"])
		"weather_station":
			# A mast with wind cups and a vane, a box of instruments and a solar panel.
			out.append([Vector3(1.0, 0.12, 1.0), Vector3(0, 0.06, 0), "concrete_dark"])
			out.append([Vector3(0.12, 4.2, 0.12), Vector3(0, 2.2, 0), "metal"])
			out.append([Vector3(0.5, 0.6, 0.35), Vector3(0, 1.4, 0.2), "metal"])        # instrument box
			out.append([Vector3(0.06, 0.08, 0.02), Vector3(0.15, 1.55, 0.38), "lamp"])
			out.append([Vector3(0.9, 0.04, 0.6), Vector3(0, 2.6, -0.3), "rust", -0.6])   # solar panel
			out.append([Vector3(0.9, 0.04, 0.04), Vector3(0, 4.3, 0), "metal"])          # cup arms
			out.append([Vector3(0.04, 0.04, 0.9), Vector3(0, 4.3, 0), "metal"])
			for c in [Vector3(0.45, 4.3, 0), Vector3(-0.45, 4.3, 0), Vector3(0, 4.3, 0.45), Vector3(0, 4.3, -0.45)]:
				out.append([Vector3(0.14, 0.14, 0.14), c, "rust"])
			out.append([Vector3(0.04, 0.04, 0.7), Vector3(0, 3.9, 0.2), "metal"])        # vane
			out.append([Vector3(0.02, 0.2, 0.2), Vector3(0, 3.9, 0.5), "rust"])
		"switch":
			out.append([Vector3(0.1, 1.2, 0.1), Vector3(0, 0.6, 0.1), "wood_dark"])
			out.append([Vector3(0.28, 0.36, 0.14), Vector3(0, 1.1, 0), "metal"])
			out.append([Vector3(0.06, 0.06, 0.01), Vector3(0.09, 1.22, -0.075), "lamp"])
		"well":
			# A ring of stone covering the shaft (first four boxes: also its colliders),
			# two posts, a crank bar and a bucket.
			for s in [-1.0, 1.0]:
				out.append([Vector3(2.0, 0.85, 0.45), Vector3(0, 0.42, s * 0.775), "stone"])
				out.append([Vector3(0.45, 0.85, 1.1), Vector3(s * 0.775, 0.42, 0), "stone"])
			for s in [-1.0, 1.0]:
				out.append([Vector3(0.1, 1.5, 0.1), Vector3(s * 0.78, 1.6, 0), "wood_dark"])
			out.append([Vector3(1.66, 0.08, 0.08), Vector3(0, 2.3, 0), "wood"])
			out.append([Vector3(0.02, 0.9, 0.02), Vector3(0, 1.85, 0), "cloth_dark"])
			out.append([Vector3(0.28, 0.3, 0.28), Vector3(0, 1.3, 0), "wood"])
			out.append([Vector3(1.1, 0.04, 1.1), Vector3(0, 0.3, 0), "water"])
		"spiked_pit":
			out.append([Vector3(1.9, 0.05, 1.9), Vector3(0, 0.03, 0), "wood_dark"])
			for i in 4:
				for j in 4:
					var p := Vector3(-0.72 + i * 0.48, 0.0, -0.72 + j * 0.48)
					out.append([Vector3(0.07, 0.6, 0.07), p + Vector3(0, 0.3, 0), "wood", 0.12 * (1 if (i + j) % 2 == 0 else -1)])
					out.append([Vector3(0.035, 0.12, 0.035), p + Vector3(0, 0.64, 0), "plank"])
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
		"doorway", "window", "slit_wall", "metal_door", "half_wall", "low_wall", "trapdoor", "pillar":
			var out: Array = []
			for b in piece_boxes(type):
				if b[2] == "wood" or (type == "trapdoor" and b[2] == "plank"):
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
		"log_stakes":
			return [[Vector3(1.9, 0.9, 1.3), Vector3(0, 0.45, 0), 0.0]]
		"sawmill":
			return [[Vector3(1.8, 1.0, 1.0), Vector3(0, 0.5, 0.1), 0.0]]
		"furnace":
			return [[Vector3(1.3, 1.5, 1.2), Vector3(0, 0.75, 0), 0.0], [Vector3(0.4, 1.2, 0.4), Vector3(0.3, 2.1, -0.3), 0.0]]
		"brick_wall", "glass_window":
			return [[Vector3(CELL, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, 0), 0.0]]
		"crusher":
			return [[Vector3(1.5, 1.4, 1.3), Vector3(0, 0.7, 0.1), 0.0]]
		"nail_press":
			return [[Vector3(0.9, 1.9, 0.9), Vector3(0, 0.95, 0), 0.0]]
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
			return [[Vector3(0.9, 3.4, 1.0), Vector3(0, 1.7, 0.1), 0.0]]
		"landing_pad":
			return [[Vector3(1.9, 0.14, 1.9), Vector3(0, 0.07, 0), 0.0]]
		"sandbags":
			return [[Vector3(CELL, 0.95, 0.45), Vector3(0, 0.47, 0), 0.0]]
		"ladder":
			return [[Vector3(0.7, LADDER_H, 0.3), Vector3(0, LADDER_H * 0.5, -0.8), 0.0]]
		"spiked_pit":
			return [[Vector3(1.8, 0.6, 1.8), Vector3(0, 0.3, 0), 0.0]]
		"switch":
			return [[Vector3(0.3, 1.3, 0.3), Vector3(0, 0.65, 0.05), 0.0]]
		"sprinkler":
			return [[Vector3(0.4, 0.7, 0.4), Vector3(0, 0.35, 0), 0.0]]
		"dew_collector":
			return [[Vector3(1.7, 2.4, 0.5), Vector3(0, 1.2, 0), 0.0]]
		"weather_station":
			return [[Vector3(1.0, 4.4, 1.0), Vector3(0, 2.2, 0), 0.0]]
		"well":
			var out: Array = []
			for b in piece_boxes("well").slice(0, 4):
				out.append([b[0], b[1], 0.0])
			return out
	return []


## The box used to check that a piece has room: [size, centre].
static func piece_bounds(type: String) -> Array:
	match type:
		"doorway", "window", "slit_wall", "metal_door":
			return [Vector3(CELL, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, 0)]
		"tri_foundation":
			return [Vector3(CELL, FOUNDATION_H, CELL), Vector3(0, -FOUNDATION_H * 0.5, 0)]
		"tri_roof":
			return [Vector3(CELL, FLOOR_T, CELL), Vector3(0, -FLOOR_T * 0.5, 0)]
		"trapdoor":
			return [Vector3(CELL, FLOOR_T, CELL), Vector3(0, -FLOOR_T * 0.5, 0)]
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
	revision += 1
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
	if type in TRIS:
		_add_prism(body, type)
	for c in piece_colliders(type):
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = c[0]
		col.shape = shape
		col.position = c[1]
		col.rotation.x = c[2]
		body.add_child(col)
	if PIECES[type].get("trap", false) or PIECES[type].get("noblock", false):
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
	if not _by_type.has(type):
		_by_type[type] = {}
	_by_type[type][key] = true
	for k in slot_keys(type, slot):
		occupied[k] = key
	if PIECES[type].get("gate", false):
		_add_gate(rec, gate_open)
	elif type == "trapdoor":
		_add_hatch(rec, gate_open)
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
	elif type == "switch":
		rec.open = gate_open  # "open" holds whether the switch is on
		body.set_meta("interact_id", "switch:" + key)
		var lever := Node3D.new()
		lever.position = Vector3(0, 1.1, -0.08)
		body.add_child(lever)
		var handle := MeshInstance3D.new()
		handle.mesh = _box_mesh(Vector3(0.05, 0.22, 0.05))
		handle.position = Vector3(0, 0.11, 0)
		handle.material_override = _mats.rust
		lever.add_child(handle)
		rec.lever = lever
		_set_lever(rec)
	elif type == "well":
		rec.water = 0.0
		body.set_meta("interact_id", "well:" + key)
	elif type in ["dew_collector", "weather_station"]:
		body.set_meta("interact_id", "weather:" + key)
	elif type == "sprinkler":
		rec.open = true  # "open": the valve is on (see water.gd)
		body.set_meta("interact_id", "sprinkler:" + key)
		_add_spray(rec)
	elif MACHINES.has(type):
		rec.input = 0
		rec.output = 0
		rec.progress = 0.0
		rec.powered = false
		body.set_meta("interact_id", "machine:" + key)
		_add_rotor(rec)
	elif type == "furnace":
		Furnace.init_rec(rec)
		body.set_meta("interact_id", "furnace:" + key)
		_add_glow(rec)
	elif type == "turret":
		rec.ammo = 0
		body.set_meta("interact_id", "turret:" + key)
		_add_turret_head(rec)
	if type in ["floodlight", "electric_fence"]:
		rec.powered = false
	if not _bulk:
		_refresh_support()
	return key


## The fan of droplets a sprinkler throws while it waters.
func _add_spray(rec: Dictionary) -> void:
	var p := CPUParticles3D.new()
	p.position = Vector3(0, 0.68, 0)
	p.amount = 40
	p.lifetime = 0.9
	p.emitting = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := BoxMesh.new()
	m.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.85, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	rec.node.add_child(p)
	rec.spray = p


## A part that turns while a machine works (a saw blade, crusher jaws, a flywheel).
func _add_rotor(rec: Dictionary) -> void:
	var rotor := Node3D.new()
	var mi := MeshInstance3D.new()
	match rec.type:
		"sawmill":
			rotor.position = Vector3(0.35, 0.9, 0)
			rotor.rotation.x = PI * 0.5
			var c := CylinderMesh.new()
			c.top_radius = 0.32
			c.bottom_radius = 0.32
			c.height = 0.02
			c.radial_segments = 10
			mi.mesh = c
		"crusher":
			rotor.position = Vector3(0.95, 0.4, 0)
			rotor.rotation.z = PI * 0.5
			var c := CylinderMesh.new()
			c.top_radius = 0.3
			c.bottom_radius = 0.3
			c.height = 0.08
			c.radial_segments = 8
			mi.mesh = c
		_:
			rotor.position = Vector3(-0.5, 1.75, -0.1)
			rotor.rotation.z = PI * 0.5
			var c := CylinderMesh.new()
			c.top_radius = 0.28
			c.bottom_radius = 0.28
			c.height = 0.06
			c.radial_segments = 8
			mi.mesh = c
	mi.material_override = _mats.metal
	rotor.add_child(mi)
	rec.node.add_child(rotor)
	rec.rotor = rotor


## "Sawmill (running): 3 logs in, 10 wood ready   [E] Load logs, take the wood"
func machine_prompt(key: String, has_input: int) -> String:
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty():
		return ""
	var m: Dictionary = MACHINES[rec.type]
	var Items = preload("res://scripts/items.gd")
	var state := "no power: cable it to a generator"
	if rec.powered:
		state = "running" if rec.input >= m.need and rec.output + m.make <= MACHINE_OUT_MAX else ("full" if rec.output + m.make > MACHINE_OUT_MAX else "waiting for %s" % Items.display_name(m.in).to_lower())
	var text := "%s (%s): %d %s in, %d %s ready" % [PIECES[rec.type].name, state, rec.input, Items.display_name(m.in).to_lower(), rec.output, Items.display_name(m.out).to_lower()]
	var acts: Array = []
	if has_input > 0 and rec.input < MACHINE_IN_MAX:
		acts.append("load %s" % Items.display_name(m.in).to_lower())
	if rec.output > 0:
		acts.append("take the %s" % Items.display_name(m.out).to_lower())
	if acts.is_empty():
		return text + "\n%d %s make %d %s every %d s" % [m.need, Items.display_name(m.in).to_lower(), m.make, Items.display_name(m.out).to_lower(), int(m.secs)]
	var act: String = ", ".join(acts)
	return text + "\n[E] " + act.left(1).to_upper() + act.substr(1)


## One step of a machine's work. Returns true while it is busy.
func run_machine(rec: Dictionary, dt: float) -> bool:
	var m: Dictionary = MACHINES[rec.type]
	var busy: bool = rec.powered and rec.input >= m.need and rec.output + m.make <= MACHINE_OUT_MAX
	if busy:
		rec.progress += dt
		if rec.progress >= m.secs:
			rec.progress -= m.secs
			rec.input -= m.need
			rec.output += m.make
	return busy


## Triangle pieces: a prism over half the square, cut from its north-east to
## its south-west corner (the right angle in the north-west): its six corners.
static func prism_points(type: String) -> PackedVector3Array:
	var h := FOUNDATION_H if type == "tri_foundation" else FLOOR_T
	var c := CELL * 0.5
	var top := [Vector3(-c, 0, -c), Vector3(c, 0, -c), Vector3(-c, 0, c)]
	var out := PackedVector3Array()
	for v in top:
		out.append(v)
	for v in top:
		out.append(v - Vector3(0, h, 0))
	return out


static func prism_mesh(type: String) -> ArrayMesh:
	var p := prism_points(type)
	var centre := Vector3.ZERO
	for v in p:
		centre += v / 6.0
	var faces: Array = [[p[0], p[1], p[2]], [p[3], p[5], p[4]]]
	for i in 3:
		var j := (i + 1) % 3
		faces.append([p[i], p[i + 3], p[j + 3]])
		faces.append([p[i], p[j + 3], p[j]])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var cc: Vector3 = f[2]
		var n := (cc - a).cross(b - a).normalized()
		if n.dot((a + b + cc) / 3.0 - centre) < 0.0:
			n = -n
			var t := b
			b = cc
			cc = t
		st.set_normal(n)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(cc)
	return st.commit()


func _add_prism(body: StaticBody3D, type: String) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = prism_mesh(type)
	mi.set_meta("mat", "wood_dark" if type == "tri_foundation" else "plank")
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = prism_points(type)
	col.shape = shape
	body.add_child(col)


## The part that turns: a swivel with a gun on it and a muzzle flash.
func _add_turret_head(rec: Dictionary) -> void:
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 3.4
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


## The glowing hearth of a furnace and its light, shown while it smelts.
func _add_glow(rec: Dictionary) -> void:
	var glow := Node3D.new()
	glow.name = "Glow"
	rec.node.add_child(glow)
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(Vector3(0.5, 0.35, 0.02))
	mi.position = Vector3(0, 0.43, 0.63)
	mi.material_override = _mats.ember
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position = Vector3(0, 0.6, 1.0)
	glow.add_child(light)
	glow.visible = false
	rec.glow = glow


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


## The trapdoor's hatch: a lid over the opening, hinged at its north edge.
func _add_hatch(rec: Dictionary, open: bool) -> void:
	var hinge := Node3D.new()
	hinge.position = Vector3(0, 0, -CELL * 0.5 + 0.05)
	rec.node.add_child(hinge)
	var lid := StaticBody3D.new()
	lid.set_meta("interact_id", "hatch:" + slot_key(rec.slot))
	lid.position = Vector3(0, -FLOOR_T * 0.5, HATCH * 0.5)
	hinge.add_child(lid)
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(Vector3(HATCH - 0.04, FLOOR_T * 0.8, HATCH / 3.0 - 0.03))
		mi.position.z = -HATCH * 0.5 + HATCH / 6.0 + i * HATCH / 3.0
		mi.set_meta("mat", "plank" if i % 2 == 0 else "wood")
		lid.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(HATCH - 0.04, FLOOR_T * 0.8, HATCH - 0.04)
	lid.add_child(col)
	rec.hinge = hinge
	_apply_tier(rec)
	set_gate(slot_key(rec.slot), open)


func set_gate(key: String, open: bool) -> void:
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty() or not rec.has("hinge"):
		return
	if rec.open != open:
		revision += 1
	rec.open = open
	rec.open_t = 0.0
	if rec.type == "trapdoor":
		rec.hinge.rotation.x = PI * 0.5 if open else 0.0
	else:
		rec.hinge.rotation.y = -PI * 0.5 if open else 0.0


## E on a gate: open it if closed, close it if open (not while it is locked).
func toggle_gate(key: String) -> void:
	if pieces.has(key) and not pieces[key].get("locked", false):
		set_gate(key, not pieces[key].open)


## R on a metal door: lock or unlock it (only when shut). A locked door takes
## half damage and can't be opened. Returns true if it changed.
func toggle_lock(key: String) -> bool:
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty() or rec.type != "metal_door" or rec.open:
		return false
	rec.locked = not rec.get("locked", false)
	revision += 1
	return true


## E on a switch: on or off.
func toggle_switch(key: String) -> void:
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty() or rec.type != "switch":
		return
	rec.open = not rec.open
	_set_lever(rec)


func _set_lever(rec: Dictionary) -> void:
	if rec.has("lever"):
		rec.lever.rotation.x = -0.6 if rec.open else 0.6


# --- Cables ---------------------------------------------------------------------

func cables_of(key: String) -> Array:
	return cables.filter(func(c): return key in c)


## Where a cable meets a piece.
func cable_anchor(key: String) -> Vector3:
	var rec: Dictionary = pieces[key]
	var h := {"floodlight": 2.6, "turret": 0.9, "electric_fence": 1.2, "switch": 1.1}.get(rec.type, 0.8) as float
	return rec.node.global_position + Vector3(0, h, 0)


## Cable items a cable between two pieces takes.
func cable_cost(a: String, b: String) -> int:
	return maxi(1, ceili(cable_anchor(a).distance_to(cable_anchor(b)) / CABLE_PER))


## Why two pieces can't be joined by a cable ("" if they can).
func cable_problem(a: String, b: String) -> String:
	if not pieces.has(a) or not pieces.has(b) or a == b:
		return "Pick two different pieces"
	if not pieces[a].type in WIRED or not pieces[b].type in WIRED:
		return "Cables join generators, switches, floodlights, electric fences and turrets"
	for c in cables:
		if a in c and b in c:
			return "They are already joined"
	if cable_anchor(a).distance_to(cable_anchor(b)) > CABLE_MAX:
		return "Too far for one cable (%d m at most): put a switch in between" % int(CABLE_MAX)
	return ""


## Joins two pieces with a cable (no cost check: see cable_cost). Returns true if laid.
func connect_cable(a: String, b: String) -> bool:
	if cable_problem(a, b) != "":
		return false
	cables.append([a, b])
	_rebuild_cables()
	return true


## Takes up every cable on a piece. Returns how many cable items come back.
func disconnect_all(key: String) -> int:
	var back := 0
	for c in cables_of(key):
		back += cable_cost(c[0], c[1])
	cables = cables.filter(func(c): return not key in c)
	_rebuild_cables()
	return back


## Older saves: cable every floodlight and fence to each generator in the old 18 m reach.
func auto_wire(reach: float) -> void:
	for g in keys_of(["generator"]):
		for k in keys_of(["floodlight", "electric_fence"]):
			if pieces[k].node.global_position.distance_to(pieces[g].node.global_position) <= reach:
				cables.append([g, k])
	_rebuild_cables()


## Every piece power reaches from these running generators: along cables, and
## on through switches only when they are on.
func power_network(running: Array) -> Dictionary:
	var reached := {}
	var todo: Array = running.duplicate()
	for k in running:
		reached[k] = true
	var links := {}
	for c in cables:
		for i in 2:
			if not links.has(c[i]):
				links[c[i]] = []
			links[c[i]].append(c[1 - i])
	while not todo.is_empty():
		var k: String = todo.pop_back()
		if pieces.has(k) and pieces[k].type == "switch" and not pieces[k].open:
			continue  # an open switch stops the power here
		for n in links.get(k, []):
			if not reached.has(n):
				reached[n] = true
				todo.append(n)
	return reached


## The cables as thin dark bars, sagging a little in the middle.
func _rebuild_cables() -> void:
	if _cable_root == null:
		return
	for c in _cable_root.get_children():
		c.queue_free()
	for c in cables:
		if not pieces.has(c[0]) or not pieces.has(c[1]):
			continue
		var a := cable_anchor(c[0])
		var b := cable_anchor(c[1])
		var mid := (a + b) * 0.5 - Vector3(0, minf(a.distance_to(b) * 0.06, 0.8), 0)
		for seg in [[a, mid], [mid, b]]:
			var p0: Vector3 = seg[0]
			var p1: Vector3 = seg[1]
			var mi := MeshInstance3D.new()
			mi.mesh = _box_mesh(Vector3(0.04, 0.04, maxf(p0.distance_to(p1), 0.01)))
			mi.material_override = _mats.cable
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_cable_root.add_child(mi)
			mi.global_position = (p0 + p1) * 0.5
			if p0.distance_to(p1) > 0.01:
				mi.look_at(p1, Vector3.UP if absf((p1 - p0).normalized().y) < 0.99 else Vector3.RIGHT)


## Prompt text for a gate, chest or workbench interact id ("gate:<key>"...), or "".
func prompt(id: String) -> String:
	var key := id.substr(id.find(":") + 1)
	if not pieces.has(key):
		return ""
	if id.begins_with("gate:"):
		var what := "door" if pieces[key].type == "metal_door" else "gate"
		if pieces[key].get("locked", false):
			return "Metal door, locked   [R] Unlock"
		var text := "[E] Close %s" % what if pieces[key].open else "[E] Open %s" % what
		return text + ("   [R] Lock" if pieces[key].type == "metal_door" and not pieces[key].open else "")
	if id.begins_with("hatch:"):
		return "[E] Close trapdoor" if pieces[key].open else "[E] Open trapdoor"
	if id.begins_with("chest:"):
		return "[E] Open storage chest"
	if id.begins_with("bench:"):
		return "[E] Use workbench"
	var rec: Dictionary = pieces[key]
	if id.begins_with("gen:"):
		var state := "running" if rec.running else ("idle, runs at night and for busy machines" if rec.fuel > 0.0 else "out of fuel")
		return "[E] Add a fuel can   Generator %d/%d cans, %s" % [ceili(rec.fuel), int(GEN_TANK), state]
	if id.begins_with("turret:"):
		return "[E] Load 9mm rounds   Auto-turret %d/%d rounds%s" % [rec.ammo, TURRET_AMMO, "" if rec.ammo > 0 else ", EMPTY"]
	if id.begins_with("switch:"):
		return "[E] Turn %s   Power switch: %s" % ["off" if rec.open else "on", "on" if rec.open else "off"]
	if id.begins_with("well:"):
		var next := int(ceil((1.0 - fmod(rec.water, 1.0)) * WELL_SECONDS))
		if rec.water >= WELL_MAX:
			return "[E] Take water   Well: %d bottles (full)" % int(WELL_MAX)
		if rec.water >= 1.0:
			return "[E] Take water   Well: %d bottle%s, the next in %d s" % [int(rec.water), "" if int(rec.water) == 1 else "s", next]
		return "Water well: filling, the first bottle in %d s" % next
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
	revision += 1
	for k in slot_keys(rec.type, rec.slot):
		occupied.erase(k)
	pieces.erase(key)
	support.erase(key)
	if not cables_of(key).is_empty():
		cables = cables.filter(func(c): return not key in c)
		_rebuild_cables()
	if _by_type.has(rec.type):
		_by_type[rec.type].erase(key)
	return rec.type


## True if the space a piece needs is free of props, other pieces and the player.
## The terrain is ignored (pieces sink into the sand a little).
func space_free(type: String, slot: Dictionary, y: float) -> bool:
	var b := piece_bounds(type)
	var shape := BoxShape3D.new()
	# A little smaller than the piece, so neighbours touching it don't count. Pieces a
	# whole square long lose a wall's thickness at each end, for walls meeting at corners.
	var shrink := Vector3(0.12, 0.12, 0.12)
	if b[0].x >= CELL - 0.01:
		shrink.x = WALL_T * 2.0 + 0.1
	if b[0].z >= CELL - 0.01:
		shrink.z = WALL_T * 2.0 + 0.1
	shape.size = (b[0] - shrink).max(Vector3(0.02, 0.02, 0.02))  # thin roofs stay positive
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
	return 1 if type in ["roof", "ramp", "tri_roof", "metal_door"] else 0


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


## What it costs to raise a piece one tier ({} at concrete): scrap metal and
## nails, then stone with clay as mortar, then cement.
func upgrade_cost(rec: Dictionary) -> Dictionary:
	if rec.tier >= TIER_NAMES.size() - 1 or PIECES[rec.type].get("fixed", false):
		return {}
	if rec.tier == 0:
		return {"scrap": _size(rec.type) + 1, "nails": 2}
	if rec.tier == 1:
		return {"stone": _size(rec.type) + 2, "clay": 1}
	return {"cement": _size(rec.type), "scrap": 1}


## One unit of the tier's material per started quarter of missing hit points.
func repair_cost(rec: Dictionary) -> Dictionary:
	var missing: float = 1.0 - rec.hp / max_hp(rec)
	if missing <= 0.001:
		return {}
	return {String(PIECES[rec.type].get("repair", TIER_ITEM[rec.tier])): int(ceil(missing * 4.0))}


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
	revision += 1
	_apply_tier(rec)
	_refresh_support()


func repair(key: String) -> void:
	var rec: Dictionary = pieces.get(key, {})
	if not rec.is_empty():
		rec.hp = max_hp(rec)
		revision += 1
		_update_cracks(rec)


## Every damaged piece gets back `share` of its hit points (v1.17: a livable
## base mends each morning). Returns how many pieces mended.
func mend_all(share: float) -> int:
	var n := 0
	for key in pieces:  # once a morning, every piece (a few hundred at most); no pieces added or removed
		var rec: Dictionary = pieces[key]
		var top := max_hp(rec)
		if rec.hp >= top:
			continue
		rec.hp = minf(rec.hp + top * share, top)
		_update_cracks(rec)
		n += 1
	if n > 0:
		revision += 1
	return n


## Hurts a piece. At 0 hit points it breaks and is gone. Returns true if it broke.
func damage(key: String, amount: float) -> bool:
	key = occupied.get(key, key)
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty():
		return false
	if rec.get("locked", false):
		amount *= 0.5  # a locked metal door is barred from inside
	var stage := crack_stage(rec)
	rec.hp = maxf(rec.hp - amount, 0.0)
	if crack_stage(rec) != stage:
		revision += 1  # a badly damaged wall is a cheaper way in
	if rec.hp <= 0.0:
		var type: String = rec.type
		_debris(rec)
		remove(key)
		piece_destroyed.emit(key, type)
		collapse_unsupported()
		return true
	_update_cracks(rec)
	return false


## Keys of all built pieces of these types.
func keys_of(types: Array) -> Array:
	var out: Array = []
	for t in types:
		if _by_type.has(t):
			out.append_array(_by_type[t].keys())
	return out


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
	if slot.kind == "post":
		var pb := piece_at(post_key(slot.cx, slot.cz, lv - 1))
		if not pb.is_empty():
			out.append(slot_key(pb.slot))
		for c in post_cells(slot):
			var f := piece_at(cell_key(c.x, c.y, lv))
			if not f.is_empty() and f.type in DECKS:
				out.append(slot_key(f.slot))
		return out
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
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var pl := piece_at(post_key(slot.cx + o.x, slot.cz + o.y, lv - 1))
			if not pl.is_empty():
				out.append(slot_key(pl.slot))
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


## What resting on sup costs a piece rec, in support points.
static func support_loss(rec: Dictionary, sup: Dictionary) -> float:
	var w: float = 1.0 if PIECES[rec.type].get("fixed", false) else TIER_WEIGHT[clampi(int(rec.tier), 0, TIER_WEIGHT.size() - 1)]
	if sup.slot.level < rec.slot.level:
		return LOSS_UP * w
	if rec.slot.kind == "cell":
		return LOSS_SIDE * w  # a floor hanging off the one next to it
	return LOSS_UP * 0.5 * w  # standing on a floor


## Support every piece gets, worked out from the ground up: key -> %. With
## tier_override {key: tier}, as if those pieces had other tiers.
func compute_support(tier_override := {}) -> Dictionary:
	var out := {}
	for key in pieces:
		if pieces[key].slot.level == 0:
			out[key] = 100.0
	var changed := true
	var passes := 0
	while changed and passes < 64:
		changed = false
		passes += 1
		for key in pieces:
			var rec: Dictionary = pieces[key]
			if rec.slot.level == 0:
				continue
			if tier_override.has(key):
				rec = rec.merged({"tier": tier_override[key]}, true)
			var best := -INF
			for k in _supporters(rec.slot):
				if out.has(k):
					best = maxf(best, out[k] - support_loss(rec, pieces[k]))
			if best > out.get(key, -INF) + 0.001:
				out[key] = best
				changed = true
	return out


## Support a new piece {type, slot, tier} would get where it stands (-INF if none).
func support_for(rec: Dictionary) -> float:
	if rec.slot.get("level", 0) == 0:
		return 100.0
	var best := -INF
	for k in _supporters(rec.slot):
		if support.has(k):
			best = maxf(best, support[k] - support_loss(rec, pieces[k]))
	return best


func _refresh_support() -> void:
	support = compute_support()
	for key in pieces:
		pieces[key].support = support.get(key, 0.0)


## Why upgrading a piece must wait ("" if it can go ahead): a heavier tier must
## not bring down what it holds up, or itself.
func upgrade_problem(key: String) -> String:
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty() or upgrade_cost(rec).is_empty():
		return ""
	var after := compute_support({key: rec.tier + 1})
	for k in pieces:
		if after.get(k, 0.0) < MIN_SUPPORT:
			return "Too heavy: a %s %s would bring %s down" % [TIER_NAMES[rec.tier + 1], PIECES[rec.type].name.replace("Wooden ", "").replace("Scrap ", "").to_lower(), "itself" if k == key else "what it holds up"]
	return ""


## Pieces without enough support (see MIN_SUPPORT) fall down, and then what
## they held up, with debris. Returns how many fell.
func collapse_unsupported() -> int:
	var fell := 0
	for round_i in 16:
		_refresh_support()
		var weak: Array = []
		for key in pieces:
			if support.get(key, 0.0) < MIN_SUPPORT:
				weak.append(key)
		if weak.is_empty():
			break
		for key in weak:
			if not pieces.has(key):
				continue
			var rec: Dictionary = pieces[key]
			_debris(rec)
			remove(key)
			piece_collapsed.emit(key, rec.type)
			fell += 1
	return fell


## True if a person standing at pos is on a ladder (can climb it).
func on_ladder(pos: Vector3) -> bool:
	for key in keys_of(["ladder"]):
		var local: Vector3 = pieces[key].node.global_transform.affine_inverse() * pos
		if absf(local.x) < 0.65 and local.z > -2.0 and local.z < 0.1 and local.y > -0.4 and local.y < LADDER_H + 0.2:
			return true
	return false


## A new foundation fills the sand under it up to its bottom (no gaps under it).
## A new well fills its footprint up to the ground around its shaft.
func level_under(key: String) -> void:
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty() or not rec.type in FOUNDATIONS + ["well"] or terrain == null or not terrain.has_method("raise_area"):
		return
	var x0: float = rec.slot.cx * CELL
	var z0: float = rec.slot.cz * CELL
	if rec.type == "well":
		terrain.raise_area(Rect2(x0, z0, CELL, CELL), rec.y, Vector2(x0 + CELL * 0.5, z0 + CELL * 0.5))
	else:
		terrain.raise_area(Rect2(x0, z0, CELL, CELL), rec.y - FOUNDATION_H)


## The ground changed (digging): pieces standing on the sand nearby are checked.
## Things like chests and traps settle onto the new ground; walls, foundations
## and the rest fall down if too much was dug out from under them, and whatever
## they held up comes down too. Returns how many pieces fell.
func settle(area: Rect2) -> int:
	var near := area.grow(CELL * 1.5)
	var fell := 0
	# Foundations first, then what stands on them or on the sand, then objects.
	for pass_i in 3:
		for key in pieces.keys():
			if not pieces.has(key):
				continue
			var rec: Dictionary = pieces[key]
			if rec.slot.level != 0:
				continue
			var c := slot_center(rec.slot, rec.type)
			if not near.has_point(Vector2(c.x, c.z)):
				continue
			var is_obj: bool = rec.slot.kind == "obj"
			if (pass_i == 0) != (rec.type in FOUNDATIONS) or (pass_i == 2) != is_obj:
				continue
			if is_obj:
				_reseat(rec)
			elif undermined(rec):
				_debris(rec)
				remove(key)
				piece_collapsed.emit(key, rec.type)
				fell += 1
	if fell > 0:
		fell += collapse_unsupported()
		# Objects that stood on a fallen foundation drop to the sand.
		for key in pieces.keys():
			if pieces.has(key) and pieces[key].slot.kind == "obj" and pieces[key].slot.level == 0:
				_reseat(pieces[key])
	return fell


## True if a ground-level piece has lost the sand under it (see UNDERMINE_GAP):
## under its middle, or under half of the points it stands on.
func undermined(rec: Dictionary) -> bool:
	var slot: Dictionary = rec.slot
	if not rec.type in FOUNDATIONS:
		if slot.kind == "cell" and not is_nan(foundation_top(slot.cx, slot.cz)):
			return false
		if slot.kind == "post":
			for c in post_cells(slot):
				if not is_nan(foundation_top(c.x, c.y)):
					return false
		if slot.kind == "edge":
			for c in edge_cells(slot):
				if not is_nan(foundation_top(c.x, c.y)):
					return false
	var bottom: float = rec.y - (FOUNDATION_H if rec.type in FOUNDATIONS else 0.0)
	# Foundations may stand on a slope already (up to MAX_SLOPE), so they take a bit more.
	var limit := UNDERMINE_GAP + (0.4 if rec.type in FOUNDATIONS else 0.0)
	var g := _ground_samples(rec.type, slot)
	var gaps := 0
	for h in g:
		if bottom - h > limit:
			gaps += 1
	# The middle sample is the last of each square (or of the edge).
	return gaps * 2 >= g.size() or bottom - g[g.size() - 1] > limit


## Moves an object on the sand (not on a foundation or floor) to the ground under it.
func _reseat(rec: Dictionary) -> void:
	var under := piece_at(cell_key(rec.slot.cx, rec.slot.cz, 0))
	if not under.is_empty() and under.type in FOUNDATIONS + ["floor", "trapdoor"]:
		return
	var y: float = _ground_level(rec.type, rec.slot).y
	if absf(y - rec.y) > 0.001:
		rec.y = y
		rec.node.position.y = y


var _debris_check := 0.0

func _physics_process(delta: float) -> void:
	_debris_check -= delta
	if _debris_check > 0.0 or terrain == null:
		return
	_debris_check = 0.5
	# Safety net: a chunk that somehow got under the sand is removed, not left falling.
	for c in get_tree().get_nodes_in_group("debris"):
		if not c.is_queued_for_deletion() and c.global_position.y < terrain.surface_height(c.global_position.x, c.global_position.z) - 1.0:
			c.queue_free()


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
	# Rigid chunks that tumble, bounce, settle and then shrink away. They sit on
	# their own layer (6), so nobody trips over them, and only hit the world.
	for i in 9:
		var chunk := RigidBody3D.new()
		chunk.collision_layer = DEBRIS_LAYER
		chunk.collision_mask = 1  # not each other: they start out overlapping
		chunk.add_collision_exception_with(rec.node)
		chunk.mass = 4.0
		chunk.continuous_cd = true  # thin chunks falling from upstairs mustn't pass through the sand
		var csize := Vector3(rng.randf_range(0.2, 0.7), rng.randf_range(0.12, 0.3), rng.randf_range(0.14, 0.3))
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(csize)
		mi.material_override = mat
		chunk.add_child(mi)
		var col := CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		col.shape.size = csize
		chunk.add_child(col)
		add_child(chunk)
		chunk.add_to_group("debris")
		var local: Vector3 = b[1] + Vector3(rng.randf_range(-0.5, 0.5) * size.x, rng.randf_range(-0.4, 0.4) * size.y, rng.randf_range(-0.5, 0.5) * size.z)
		var at: Vector3 = xf * local
		if terrain:
			# Never start inside the sand (foundations reach below it), or it drops through.
			at.y = maxf(at.y, terrain.surface_height(at.x, at.z) + 0.45)
		chunk.global_position = at
		chunk.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		chunk.linear_velocity = Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(0.5, 2.5), rng.randf_range(-2.0, 2.0))
		chunk.angular_velocity = Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		var tw := chunk.create_tween()
		tw.tween_interval(DEBRIS_SECONDS + rng.randf_range(0.0, 1.0))
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.6)
		tw.tween_callback(chunk.queue_free)
	# Too many at once (a big collapse): the oldest go first.
	var all := get_tree().get_nodes_in_group("debris")
	for j in maxi(all.size() - MAX_DEBRIS, 0):
		all[j].queue_free()
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


## One piece as plain data (for saves, and for carrying it to a new spot).
func piece_data(key: String) -> Dictionary:
	var p: Dictionary = pieces[key]
	var d := {"type": p.type, "kind": p.slot.kind, "cx": p.slot.cx, "cz": p.slot.cz, "dir": p.slot.dir, "level": p.slot.level, "y": p.y, "open": p.open, "tier": p.tier, "hp": p.hp}
	if int(p.slot.get("turn", 0)) != 0:
		d.turn = int(p.slot.turn)
	if p.has("storage"):
		d.items = p.storage.save_data()
	for k in ["fuel", "burn", "ammo", "water", "locked", "input", "output", "progress", "heat", "smelt", "load", "made"]:
		if p.has(k):
			d[k] = p[k]
	return d


## Builds a piece back from piece_data(), at its own slot or at another one.
## Returns its key ("" for an unknown type).
func restore_piece(p: Dictionary, slot := {}, y := NAN, old_tiers := false) -> String:
	if not PIECES.has(p.get("type", "")):
		return ""
	if slot.is_empty():
		slot = {"kind": str(p.kind), "cx": int(p.cx), "cz": int(p.cz), "dir": int(p.dir), "level": int(p.get("level", 0))}
		if int(p.get("turn", 0)) != 0 and p.type in FREE_TURN:
			slot.turn = posmod(int(p.turn), 6)
	if is_nan(y):
		y = float(p.y)
	var tier := int(p.get("tier", -1))
	if old_tiers and tier >= 2:
		tier += 1
	var key := place(p.type, slot, y, bool(p.get("open", false)), tier, float(p.get("hp", -1.0)))
	var rec: Dictionary = pieces[key]
	if rec.type == "sprinkler":
		rec.open = bool(p.get("open", true))
	if rec.has("storage") and p.has("items"):
		rec.storage.load_data(p.items)
	if rec.has("fuel"):
		rec.fuel = clampf(float(p.get("fuel", 0.0)), 0.0, GEN_TANK)
	if rec.has("ammo"):
		rec.ammo = clampi(int(p.get("ammo", 0)), 0, TURRET_AMMO)
	if rec.has("water"):
		rec.water = clampf(float(p.get("water", 0.0)), 0.0, WELL_MAX)
	if rec.has("burn"):
		rec.burn = clampf(float(p.get("burn", 0.0)), 0.0, FIRE_MAX)
	if MACHINES.has(rec.type):
		rec.input = clampi(int(p.get("input", 0)), 0, MACHINE_IN_MAX)
		rec.output = clampi(int(p.get("output", 0)), 0, MACHINE_OUT_MAX)
		rec.progress = float(p.get("progress", 0.0))
	if rec.type == "furnace":
		Furnace.restore(rec, p)
	if p.get("locked", false) and rec.type == "metal_door":
		rec.locked = true
	return key


## Why a piece can't be picked up and moved ("" if it can): foundations stay,
## and so does anything that holds another piece up.
func move_problem(key: String) -> String:
	var rec: Dictionary = pieces.get(key, {})
	if rec.is_empty():
		return "Nothing to move"
	if rec.type in FOUNDATIONS:
		return "Foundations can't be moved"
	if PIECES[rec.type].get("long", false) or rec.type == "well":
		return "This can't be moved"
	for k in pieces:
		if k != key and key in _supporters(pieces[k].slot):
			return "Something rests on it"
	if rec.slot.level == 0:
		# What stands on a foundation or floor square (walls on its edges, objects on it).
		if rec.slot.kind == "cell":
			for k in pieces:
				var o: Dictionary = pieces[k]
				if o.slot.level == 0 and o.slot.kind == "obj" and o.slot.cx == rec.slot.cx and o.slot.cz == rec.slot.cz:
					return "Something rests on it"
	return ""


func save_data() -> Array:
	var out: Array = []
	for key in pieces:
		out.append(piece_data(key))
	return out


func load_data(data: Array, old_tiers := false) -> void:
	_bulk = true
	for key in pieces.keys():
		remove(key, false)
	for p in data:
		restore_piece(p, {}, NAN, old_tiers)
	_bulk = false
	_refresh_support()


# --- Blueprints of ready-made buildings ----------------------------------------

## Lays out a blueprint: `todo` is prefabs.placed() (pieces in build order),
## y the height its foundations' tops come to. Returns its id.
func add_site(prefab: String, todo: Array, y: float) -> int:
	var id := _site_next
	_site_next += 1
	var list: Array = []
	for e in todo:
		list.append({"type": str(e.type), "slot": e.slot.duplicate()})
	sites[id] = {"prefab": prefab, "y": y, "todo": list, "node": null}
	_rebuild_site(id)
	return id


## Every slot key that a blueprint still has a piece planned for.
func site_keys() -> Dictionary:
	var out := {}
	for id in sites:
		for e in sites[id].todo:
			for k in slot_keys(e.type, e.slot):
				out[k] = id
	return out


func remove_site(id: int) -> void:
	var s: Dictionary = sites.get(id, {})
	if s.is_empty():
		return
	if s.node:
		s.node.queue_free()
	sites.erase(id)


## Where a blueprint piece would stand.
func site_piece_y(site: Dictionary, e: Dictionary) -> float:
	if e.type in FOUNDATIONS:
		return site.y
	var ev := evaluate(e.type, e.slot)
	return ev.y if ev.ok else site.y + int(e.slot.get("level", 0)) * WALL_H


## The next piece of a blueprint that can go up now: {"i", "type", "slot", "y"},
## or {"reason"} when none can. Pieces someone already built are dropped.
func site_next(id: int, person := Vector3.INF) -> Dictionary:
	var s: Dictionary = sites.get(id, {})
	if s.is_empty():
		return {"reason": "Nothing to build"}
	var todo: Array = s.todo
	for i in range(todo.size() - 1, -1, -1):
		var have := piece_at(slot_key(todo[i].slot))
		if not have.is_empty() and have.type == todo[i].type:
			todo.remove_at(i)
	var first_reason := ""
	for i in todo.size():
		var e: Dictionary = todo[i]
		var ev := evaluate(e.type, e.slot)
		var y: float = s.y if e.type in FOUNDATIONS else ev.y
		var why: String = ev.reason
		if ev.ok and not space_free(e.type, e.slot, y):
			why = "Something is in the way"
		elif ev.ok and person != Vector3.INF and blocks_person(e.type, e.slot, y, person):
			why = "Step out of the way of the %s" % PIECES[e.type].name.to_lower()
		elif ev.ok:
			return {"i": i, "type": e.type, "slot": e.slot, "y": y}
		if first_reason == "":
			first_reason = why
	return {"reason": first_reason if first_reason != "" else "Nothing to build"}


## Builds one piece of a blueprint (found with site_next) and takes it off the
## list; the blueprint goes when its last piece is up. Returns the piece key.
func build_site_piece(id: int, nxt: Dictionary) -> String:
	var s: Dictionary = sites.get(id, {})
	if s.is_empty() or not nxt.has("i"):
		return ""
	var key := place(nxt.type, nxt.slot, nxt.y)
	level_under(key)
	s.todo.remove_at(int(nxt.i))
	if s.todo.is_empty():
		remove_site(id)
	else:
		_rebuild_site(id)
	return key


## "[E] Build Cabin: next wooden wall (3 wood, 3 nails)   12 of 30 pieces left"
func site_prompt(id: int, cost_text: Callable, person := Vector3.INF) -> String:
	var s: Dictionary = sites.get(id, {})
	if s.is_empty():
		return ""
	var nxt := site_next(id, person)
	var name: String = Prefabs.display_name(s.prefab)
	if not nxt.has("i"):
		return "Blueprint: %s   (%s)" % [name, nxt.reason]
	return "[E] Build %s: next %s (%s)   %d piece%s left, hold E to keep going" % [name, PIECES[nxt.type].name.to_lower(),
		cost_text.call(PIECES[nxt.type].cost), s.todo.size(), "" if s.todo.size() == 1 else "s"]


## What a blueprint still needs, summed up.
func site_cost(id: int) -> Dictionary:
	var out := {}
	for e in sites.get(id, {}).get("todo", []):
		var c: Dictionary = PIECES[e.type].cost
		for item in c:
			out[item] = int(out.get(item, 0)) + int(c[item])
	return out


## Draws a blueprint: see-through blue pieces, each an interact area ("site:id").
func _rebuild_site(id: int) -> void:
	var s: Dictionary = sites[id]
	if s.node:
		s.node.queue_free()
	var root := Node3D.new()
	root.name = "Site%d" % id
	add_child(root)
	s.node = root
	for e in s.todo:
		var area := Area3D.new()
		area.collision_layer = SITE_LAYER
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("interact_id", "site:%d" % id)
		area.transform = piece_transform(e.type, e.slot, site_piece_y(s, e))
		root.add_child(area)
		add_ghost_meshes(area, e.type, Transform3D.IDENTITY, _mats.blueprint)
		var b := piece_bounds(e.type)
		var col := CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		col.shape.size = b[0]
		col.position = b[1]
		area.add_child(col)


## Adds see-through meshes of a piece under `parent`, at `xform` (build-mode
## ghosts and blueprints).
static func add_ghost_meshes(parent: Node3D, type: String, xform: Transform3D, mat: Material = null) -> void:
	if type in TRIS:
		var tri := MeshInstance3D.new()
		tri.mesh = prism_mesh(type)
		tri.transform = xform
		tri.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tri.material_override = mat
		parent.add_child(tri)
	for b in piece_boxes(type):
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = b[0] + Vector3(0.02, 0.02, 0.02)
		mi.mesh = mesh
		var t := Transform3D(Basis.IDENTITY, b[1])
		if b.size() > 3:
			t.basis = Basis(Vector3.RIGHT, b[3])
		if b.size() > 4:
			t.origin += Basis(Vector3.RIGHT, b[3]) * b[4]
		mi.transform = xform * t
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = mat
		parent.add_child(mi)


func sites_save_data() -> Array:
	var out: Array = []
	for id in sites:
		var s: Dictionary = sites[id]
		var todo: Array = []
		for e in s.todo:
			todo.append({"type": e.type, "kind": e.slot.kind, "cx": e.slot.cx, "cz": e.slot.cz, "dir": e.slot.dir, "level": e.slot.get("level", 0)})
		out.append({"prefab": s.prefab, "y": s.y, "todo": todo})
	return out


func sites_load_data(data: Array) -> void:
	for id in sites.keys():
		remove_site(id)
	_site_next = 1
	for d in data:
		var todo: Array = []
		for e in d.get("todo", []):
			if PIECES.has(str(e.get("type", ""))):
				todo.append({"type": str(e.type), "slot": {"kind": str(e.kind), "cx": int(e.cx), "cz": int(e.cz), "dir": int(e.dir), "level": int(e.get("level", 0))}})
		if not todo.is_empty():
			add_site(str(d.get("prefab", "")), todo, float(d.get("y", 0.0)))

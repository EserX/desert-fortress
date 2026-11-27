extends Node3D
## The main well by the flag and watering the desert (v1.13).
## The main well holds a store of water that is topped up every morning (deeper
## with the "Deepen the main well" upgrade). Carry it in a watering can and pour
## it on the sand; with the hand pump upgrade, water pipes carry it to sprinklers
## in the base that water the ground round them by day.
## The ground is a coarse map-wide grid of CELL m squares. Sand that has had
## SOIL_NEED litres turns to soil; soil that gets DAY_NEED litres in a day turns a
## little greener each morning (grass, then small plants), and wilts when dry.

const LowPoly = preload("res://scripts/lowpoly.gd")

const WELL_POS := Vector2(3.2, -2.8)   # next to the flag, between it and the crates
const WELL_R := 1.2
const STORE_BASE := 200.0     # litres the main well holds before upgrades
const CAN_MAX := 10.0         # litres a watering can holds
const POUR := 2.0             # litres one pour (left click) gives
const POUR_REACH := 4.5
const POUR_GAP := 0.35        # seconds between pours
const CELL := 4.0             # size of a ground square (matches the terrain's coarse grid)
const DAY_NEED := 4.0         # litres a square needs in a day to grow greener
const WET_MAX := 8.0          # a square can't soak up more than this in a day
const SOIL_NEED := 6.0        # litres in all that turn sand to soil
const GROW := 0.2             # greener each well-watered morning (5 mornings to full)
const WILT := 0.1             # browner each dry morning
const SAND_DAYS := 4          # dry mornings bare soil takes to go back to sand
const SPRAY_R := 5.0          # sprinklers water squares whose centre is this close
const SPRAY_LPS := 0.02       # litres a second a sprinkler gives each square
const SPRAY_TO := 6.0         # and it stops for a square that has had this much today
const PIPE_MAX := 24.0        # longest single pipe
const PIPE_PER := 2.0         # metres of pipe one water pipe item covers
const MAX_GRASS := 14         # grass tufts on a fully green square
const MAX_PLANTS := 3         # and small plants

## Emitted when the ground's soil or green changed (for the map and tests).
signal ground_changed
## Each morning before the squares' litres for the day are cleared (farming reads them).
signal morning_tally
## Something to tell the player: a banner, or pick-up lines.
signal message(text: String)
signal pickup(lines: Array)

var terrain  # Terrain
var building  # Building
var player  # Player (looking at the ground, the well and sprinklers)
var inventory  # Inventory (the can, water pipes)
## main.piece_under_crosshair: key of the built piece under the crosshair, or "".
var piece_at_crosshair := func() -> String: return ""
## Water pipe being laid: the end clicked first ("main" is the main well).
var pipe_from := ""
var store := STORE_BASE
var capacity := STORE_BASE
var pump := false
## Litres in your watering can (you only ever need one).
var can := 0.0
## Vector2i square -> {"wet": litres today, "total": litres ever, "green": 0..1, "dry": dry mornings}
var cells := {}
## Pipes: [id, id] pairs; "main" is the main well, anything else a sprinkler's piece key.
var pipes: Array = []
var well: StaticBody3D
var _water_surface: MeshInstance3D
var _pump_node: Node3D
var _soil: MeshInstance3D
var _soil_mat: StandardMaterial3D
var _grass: MultiMeshInstance3D
var _plants: MultiMeshInstance3D
var _pipe_root: Node3D
var _pipe_mat: StandardMaterial3D
var _dirty := true
var _redraw_wait := 0.0
var _spray_t := 0.0
var _last_pour := -100000


func _ready() -> void:
	_build_well()
	_soil_mat = StandardMaterial3D.new()
	_soil_mat.vertex_color_use_as_albedo = true
	_soil_mat.roughness = 1.0
	_soil = MeshInstance3D.new()
	_soil.name = "Soil"
	_soil.material_override = _soil_mat
	_soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_soil)
	_grass = _multimesh(_tuft_mesh())
	_grass.name = "Grass"
	_plants = _multimesh(LowPoly.flat(_bush_mesh()))
	_plants.name = "Plants"
	_pipe_root = Node3D.new()
	_pipe_root.name = "Pipes"
	add_child(_pipe_root)
	_pipe_mat = LowPoly.material(Color(0.25, 0.4, 0.5), 0.5)


func _process(delta: float) -> void:
	_redraw_wait -= delta
	if _dirty and _redraw_wait <= 0.0:
		redraw()


# --- The main well ---------------------------------------------------------------

func _build_well() -> void:
	var y: float = terrain.surface_height(WELL_POS.x, WELL_POS.y) if terrain else 0.0
	if terrain:
		y = terrain.ground_under(WELL_POS.x, WELL_POS.y, WELL_R)
	well = StaticBody3D.new()
	well.name = "MainWell"
	well.position = Vector3(WELL_POS.x, y, WELL_POS.y)
	well.set_meta("interact_id", "mainwell")
	add_child(well)
	var stone := LowPoly.material(Color(0.52, 0.47, 0.41))
	var stone_dark := LowPoly.material(Color(0.4, 0.36, 0.32))
	var wood := LowPoly.material(Color(0.42, 0.29, 0.17))
	var roof := LowPoly.material(Color(0.5, 0.34, 0.2))
	# A ring of stone blocks round the shaft.
	for i in 10:
		var a := i * TAU / 10.0
		var mi := _box(well, Vector3(0.7, 0.9, 0.38), Vector3(cos(a) * 1.0, 0.45, sin(a) * 1.0), stone if i % 2 == 0 else stone_dark)
		mi.rotation.y = -a + PI * 0.5
	_water_surface = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.85
	disc.bottom_radius = 0.85
	disc.height = 0.04
	disc.radial_segments = 10
	_water_surface.mesh = disc
	_water_surface.material_override = LowPoly.material(Color(0.16, 0.34, 0.42), 0.08)
	_water_surface.position.y = 0.6
	well.add_child(_water_surface)
	# Two posts, a little roof and a crank with a rope and bucket.
	for s in [-1.0, 1.0]:
		_box(well, Vector3(0.14, 2.3, 0.14), Vector3(s * 1.05, 1.15, 0), wood)
	for s in [-1.0, 1.0]:
		var r := _box(well, Vector3(2.6, 0.06, 0.95), Vector3(0, 2.55, s * 0.4), roof)
		r.rotation.x = s * 0.45
	_box(well, Vector3(2.3, 0.1, 0.1), Vector3(0, 1.85, 0), wood)
	_box(well, Vector3(0.06, 0.4, 0.06), Vector3(1.2, 1.7, 0.0), wood)  # crank handle
	_box(well, Vector3(0.025, 0.8, 0.025), Vector3(0, 1.4, 0), LowPoly.material(Color(0.3, 0.26, 0.2)))
	_box(well, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.95, 0), wood)
	# The hand pump (shop upgrade): a cast-iron pump on a block beside the ring.
	_pump_node = Node3D.new()
	_pump_node.position = Vector3(0, 0, 1.55)
	_pump_node.visible = false
	well.add_child(_pump_node)
	var iron := LowPoly.material(Color(0.2, 0.32, 0.28), 0.5)
	_box(_pump_node, Vector3(0.5, 0.4, 0.5), Vector3(0, 0.2, 0), stone_dark)
	_box(_pump_node, Vector3(0.18, 0.8, 0.18), Vector3(0, 0.8, 0), iron)
	_box(_pump_node, Vector3(0.08, 0.08, 0.35), Vector3(0, 0.95, 0.2), iron)  # spout
	var handle := _box(_pump_node, Vector3(0.05, 0.05, 0.7), Vector3(0, 1.25, -0.25), iron)
	handle.rotation.x = 0.35
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = WELL_R
	shape.height = 0.9
	col.shape = shape
	col.position.y = 0.45
	well.add_child(col)
	# A taller reach for E than the low stone ring, so you can look at the roof or crank too.
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.set_meta("interact_id", "mainwell")
	var ac := CollisionShape3D.new()
	var ash := CylinderShape3D.new()
	ash.radius = WELL_R + 0.1
	ash.height = 2.8
	ac.shape = ash
	ac.position.y = 1.4
	area.add_child(ac)
	well.add_child(area)
	for s in [-1.0, 1.0]:
		var pc := CollisionShape3D.new()
		var ps := BoxShape3D.new()
		ps.size = Vector3(0.16, 2.3, 0.16)
		pc.shape = ps
		pc.position = Vector3(s * 1.05, 1.15, 0)
		well.add_child(pc)
	_set_level()


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## The water you see in the well goes down as the store empties.
func _set_level() -> void:
	if _water_surface:
		_water_surface.position.y = lerpf(-0.6, 0.62, clampf(store / maxf(capacity, 1.0), 0.0, 1.0))
		_water_surface.visible = store > 0.5


func set_capacity(litres: float) -> void:
	capacity = litres
	store = minf(store, capacity)
	_set_level()


func set_pump(on: bool) -> void:
	pump = on
	if _pump_node:
		_pump_node.visible = on


## E at the main well: fills your watering can from the store. Returns litres taken.
func fill_can() -> float:
	var n := minf(CAN_MAX - can, store)
	if n <= 0.0:
		return 0.0
	can += n
	store -= n
	_set_level()
	return n


func well_prompt(has_can: bool) -> String:
	var text := "Main well: %d / %d litres (topped up every morning)" % [int(store), int(capacity)]
	if not has_can:
		return text + "\nYou need a watering can to carry water (workbench or shop)"
	if can >= CAN_MAX - 0.01:
		return text + "\nYour watering can is full (%d L)" % int(CAN_MAX)
	if store < 0.5:
		return text + "\nThe well is dry until morning"
	return text + "\n[E] Fill the watering can (%d / %d L)" % [int(can), int(CAN_MAX)]


## New day: the well fills up, and every square of ground counts what it got yesterday.
func on_morning(_day := 0) -> void:
	morning_tally.emit()
	store = capacity
	_set_level()
	# Once a day, over every watered square (a few hundred at most); .keys() as squares go back to sand.
	for c in cells.keys():
		var e: Dictionary = cells[c]
		var soil: bool = e.total >= SOIL_NEED
		if soil and e.wet >= DAY_NEED - 0.001:
			e.green = minf(e.green + GROW, 1.0)
			e.dry = 0
		else:
			e.dry += 1
			e.green = maxf(e.green - WILT, 0.0)
			if e.green <= 0.0 and e.dry >= SAND_DAYS:
				cells.erase(c)  # back to bare sand
				continue
		e.wet = 0.0
	_mark_dirty(0.0)
	ground_changed.emit()


# --- In your hands ---------------------------------------------------------------

func _has_can() -> bool:
	return inventory != null and inventory.count_of("watering_can") > 0


## E at the main well: fills the watering can if you carry one. Returns litres taken.
func use_well() -> float:
	if not _has_can():
		message.emit("You need a watering can to carry water: make one at the workbench or buy one")
		return 0.0
	var n := fill_can()
	if n > 0.0:
		pickup.emit(["Watering can: %d / %d L" % [int(round(can)), int(CAN_MAX)]])
	elif can < CAN_MAX:
		message.emit("The main well is dry until morning")
	return n


## Where the watering can pours: a point on the ground in reach, or null.
func pour_point() -> Variant:
	var hit: Dictionary = player.look_hit(POUR_REACH)
	if hit.is_empty() or hit.collider != terrain:
		return null
	return hit.position


## The pipe end under the crosshair: "main" (the main well), a sprinkler's key, or "".
func pipe_target() -> String:
	var hit: Dictionary = player.look_hit(4.5)
	if not hit.is_empty() and hit.collider == well:
		return "main"
	var key: String = piece_at_crosshair.call()
	if key != "" and building.pieces.get(key, {}).get("type", "") == "sprinkler":
		return key
	return ""


## The prompt for the watering can or water pipe in your hands.
func held_prompt(item: String) -> String:
	if item == "watering_can":
		var p = pour_point()
		if p == null:
			return "Watering can: %d / %d L" % [int(ceil(can)), int(CAN_MAX)]
		return ground_prompt(p)
	if item == "water_pipe":
		return pipe_prompt(pipe_target())
	return ""


## Mouse clicks with the can or pipe in hand. Returns true if used.
func handle_input(event: InputEvent, item: String) -> bool:
	if not (event is InputEventMouseButton and event.pressed) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	var why := ""
	if item == "watering_can":
		if event.button_index != MOUSE_BUTTON_LEFT:
			return false
		var p = pour_point()
		if p == null:
			return false
		why = try_pour(p)
	elif item == "water_pipe":
		if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
			return false
		var id := pipe_target()
		if id == "":
			return false
		why = pipe_click(id, event.button_index == MOUSE_BUTTON_RIGHT)
	else:
		return false
	if why != "":
		message.emit(why)
	return true


## What the water pipe does at this end (like the cable).
func pipe_prompt(id: String) -> String:
	if id == "":
		return "Water pipe: look at the main well or a sprinkler" if pipe_from != "" else ""
	var name := "Main well" if id == "main" else "Sprinkler"
	var n := pipes_of(id).size()
	var have: int = inventory.count_of("water_pipe")
	var take := ("   [RMB] Take up its %d pipe%s" % [n, "" if n == 1 else "s"]) if n > 0 else ""
	var need_pump := "" if pump else "\n(the pipes need the hand pump on the main well: shop, base upgrades)"
	if pipe_from == "" or not _valid_end(pipe_from):
		return "%s\n[LMB] Start a pipe here (%d pipe)%s%s" % [name, have, take, need_pump]
	if pipe_from == id:
		return "%s\n[LMB] Cancel this pipe" % name
	var why := pipe_problem(pipe_from, id)
	if why != "":
		return "%s\n%s" % [name, why]
	return "%s\n[LMB] Connect (%d pipe of your %d)%s%s" % [name, pipe_cost(pipe_from, id), have, take, need_pump]


## Left click an end to start a pipe, then another to connect it (paid in water
## pipe); right click takes up an end's pipes. Returns "" or why not.
func pipe_click(id: String, take_up_pipes := false) -> String:
	if id == "" or not _valid_end(id):
		return "Water pipes join the main well and sprinklers"
	if take_up_pipes:
		inventory.add("water_pipe", take_up(id))
		return ""
	if pipe_from == "" or not _valid_end(pipe_from) or pipe_from == id:
		pipe_from = "" if pipe_from == id else id
		return ""
	var why := pipe_problem(pipe_from, id)
	if why != "":
		return why
	var cost := pipe_cost(pipe_from, id)
	if inventory.count_of("water_pipe") < cost:
		return "Not enough water pipe: this needs %d" % cost
	inventory.remove("water_pipe", cost)
	connect_pipe(pipe_from, id)
	pipe_from = ""
	return ""


# --- Ground squares --------------------------------------------------------------

static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * CELL, (c.y + 0.5) * CELL)


func cell_info(c: Vector2i) -> Dictionary:
	return cells.get(c, {"wet": 0.0, "total": 0.0, "green": 0.0, "dry": 0})


func is_soil(c: Vector2i) -> bool:
	return cell_info(c).total >= SOIL_NEED


func green_of(c: Vector2i) -> float:
	return float(cell_info(c).green)


## Waters a square with up to `litres`. Returns how much it soaked up.
func water_cell(c: Vector2i, litres: float) -> float:
	if not cells.has(c):
		var p := cell_center(c)
		if p.length() > 225.0:  # beyond the edge of the map
			return 0.0
		cells[c] = {"wet": 0.0, "total": 0.0, "green": 0.0, "dry": 0}
	var e: Dictionary = cells[c]
	var n := clampf(litres, 0.0, WET_MAX - e.wet)
	if n <= 0.0:
		return 0.0
	var was_soil: bool = e.total >= SOIL_NEED
	e.wet += n
	e.total = minf(e.total + n, SOIL_NEED * 4.0)
	_mark_dirty(0.15)
	if not was_soil and e.total >= SOIL_NEED:
		ground_changed.emit()
	return n


## Life from plants (v1.14): `soil` litres towards turning the square to soil (not
## today's water) and `green` more green if it is soil. Keeps it from drying out.
func add_life(c: Vector2i, soil: float, green: float) -> void:
	if not cells.has(c):
		if soil <= 0.0 or cell_center(c).length() > 225.0:
			return
		cells[c] = {"wet": 0.0, "total": 0.0, "green": 0.0, "dry": 0}
	var e: Dictionary = cells[c]
	var was_soil: bool = e.total >= SOIL_NEED
	e.total = minf(e.total + soil, SOIL_NEED * 4.0)
	e.dry = 0
	if e.total >= SOIL_NEED:
		e.green = minf(e.green + green, 1.0)
	_mark_dirty(0.0)
	if not was_soil and e.total >= SOIL_NEED:
		ground_changed.emit()


## Left click with the watering can at a point on the ground. Returns "" or why not.
func pour(p: Vector3) -> String:
	if can <= 0.01:
		return "The watering can is empty: fill it at the main well by the flag"
	var c := cell_of(p.x, p.z)
	if cell_info(c).wet >= WET_MAX - 0.01:
		return "This ground is soaked for today"
	var used := water_cell(c, minf(POUR, can))
	can = maxf(can - used, 0.0)
	return ""


## Watering can in hand: pours if it's been long enough since the last pour.
func try_pour(p: Vector3) -> String:
	var now := Time.get_ticks_msec()
	if now - _last_pour < int(POUR_GAP * 1000.0):
		return ""
	_last_pour = now
	return pour(p)


## "Soil, watered 2 / 4 L today ... [LMB] Pour water (can 8 / 10 L)".
func ground_prompt(p: Vector3) -> String:
	var c := cell_of(p.x, p.z)
	var e := cell_info(c)
	var text: String
	if e.total >= SOIL_NEED:
		text = "Soil" if e.green < 0.05 else ("Grass, %d%% green" % int(round(e.green * 100.0)))
		text += (", watered today (%d L)" % int(e.wet)) if e.wet >= DAY_NEED - 0.001 else (", needs %d L more today" % int(ceil(DAY_NEED - e.wet)))
	elif e.total > 0.0:
		text = "Damp sand: %d / %d L more and it turns to soil" % [int(ceil(SOIL_NEED - e.total)), int(SOIL_NEED)]
	else:
		text = "Dry sand: %d L turns it to soil" % int(SOIL_NEED)
	if can <= 0.01:
		return text + "\nThe can is empty: fill it at the main well"
	if e.wet >= WET_MAX - 0.01:
		return text + "\nSoaked for today"
	return text + "\n[LMB] Pour water (can %d / %d L)" % [int(ceil(can)), int(CAN_MAX)]


## Squares counted as soil, and how green the land is on average over them.
func soil_count() -> int:
	var n := 0
	for c in cells:  # every watered square: only for prompts and tests
		if cells[c].total >= SOIL_NEED:
			n += 1
	return n


# --- Pipes and sprinklers ---------------------------------------------------------

func pipes_of(id: String) -> Array:
	return pipes.filter(func(p): return id in p)


func pipe_anchor(id: String) -> Vector3:
	if id == "main":
		return well.global_position + Vector3(0, 0.15, 1.6 if pump else 1.2)
	var rec: Dictionary = building.pieces.get(id, {})
	if rec.is_empty():
		return Vector3.ZERO
	return rec.node.global_position + Vector3(0, 0.1, 0)


func pipe_cost(a: String, b: String) -> int:
	return maxi(1, ceili(pipe_anchor(a).distance_to(pipe_anchor(b)) / PIPE_PER))


func _valid_end(id: String) -> bool:
	return id == "main" or building.pieces.get(id, {}).get("type", "") == "sprinkler"


## Why two ends can't be joined by a pipe ("" if they can).
func pipe_problem(a: String, b: String) -> String:
	if a == b or not _valid_end(a) or not _valid_end(b):
		return "Pipes join the main well and sprinklers"
	for p in pipes:
		if a in p and b in p:
			return "Already piped together"
	if pipe_anchor(a).distance_to(pipe_anchor(b)) > PIPE_MAX:
		return "Too far for one pipe (%d m at most): put a sprinkler in between" % int(PIPE_MAX)
	return ""


func connect_pipe(a: String, b: String) -> bool:
	if pipe_problem(a, b) != "":
		return false
	pipes.append([a, b])
	_rebuild_pipes()
	return true


## Takes up every pipe on an end. Returns how many pipe items come back.
func take_up(id: String) -> int:
	var back := 0
	for p in pipes_of(id):
		back += pipe_cost(p[0], p[1])
	pipes = pipes.filter(func(p): return not id in p)
	_rebuild_pipes()
	return back


## Drops pipes whose sprinkler is gone. Returns true if any went.
func prune_pipes() -> bool:
	var n := pipes.size()
	pipes = pipes.filter(func(p): return _valid_end(p[0]) and _valid_end(p[1]))
	if pipes.size() != n:
		_rebuild_pipes()
		return true
	return false


## Every sprinkler joined to the main well by pipes (through other sprinklers).
func fed_sprinklers() -> Dictionary:
	# A queue with a visited set over the pipes (a few dozen at most).
	var seen := {"main": true}
	var todo: Array = ["main"]
	while not todo.is_empty():
		var at: String = todo.pop_back()
		for p in pipes:
			if at in p:
				var other: String = p[1] if p[0] == at else p[0]
				if not seen.has(other) and _valid_end(other):
					seen[other] = true
					todo.append(other)
	seen.erase("main")
	return seen


## Squares a sprinkler at this point waters.
static func spray_cells(pos: Vector3) -> Array:
	var out: Array = []
	var c0 := cell_of(pos.x, pos.z)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var c := c0 + Vector2i(dx, dz)
			if cell_center(c).distance_to(Vector2(pos.x, pos.z)) <= SPRAY_R:
				out.append(c)
	return out


## Why a sprinkler isn't watering, or "" when it is (or would by day).
func sprinkler_state(key: String) -> String:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty():
		return "gone"
	if not rec.get("open", true):
		return "turned off"
	if not pump:
		return "no hand pump on the main well (shop: base upgrades)"
	if not fed_sprinklers().has(key):
		return "no water: lay a water pipe to it from the main well"
	if store < 0.05:
		return "the main well is dry until morning"
	return ""


func sprinkler_prompt(key: String) -> String:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty():
		return ""
	var why := sprinkler_state(key)
	var text := "Sprinkler: " + ("watering by day" if why == "" else why)
	return text + ("\n[E] Turn it off" if rec.get("open", true) else "\n[E] Turn it on")


func toggle_sprinkler(key: String) -> void:
	var rec: Dictionary = building.pieces.get(key, {})
	if not rec.is_empty():
		rec.open = not rec.get("open", true)


## Runs the sprinklers (by day only). Call every frame with the frame time.
func tick(delta: float, daytime: bool) -> void:
	_spray_t += delta
	if _spray_t < 1.0:
		return
	var dt := _spray_t
	_spray_t = 0.0
	prune_pipes()
	var fed := fed_sprinklers() if pump else {}
	# Once a second: every sprinkler (a handful) times the 4 to 9 squares round it.
	for key in building.keys_of(["sprinkler"]):
		var rec: Dictionary = building.pieces[key]
		var on: bool = daytime and rec.get("open", true) and fed.has(key) and store > 0.05
		var sprayed := false
		if on:
			for c in spray_cells(rec.node.global_position):
				var e := cell_info(c)
				if e.wet >= SPRAY_TO:
					continue
				var n := water_cell(c, minf(minf(SPRAY_LPS * dt, SPRAY_TO - e.wet), store))
				store -= n
				sprayed = sprayed or n > 0.0
		if rec.has("spray"):
			rec.spray.emitting = sprayed
	_set_level()


## Dug or filled ground: soil and grass on it follow the new surface.
func on_ground_changed(area: Rect2) -> void:
	var a := cell_of(area.position.x - 1.0, area.position.y - 1.0)
	var b := cell_of(area.end.x + 1.0, area.end.y + 1.0)
	for x in range(a.x, b.x + 1):
		for z in range(a.y, b.y + 1):
			if cells.has(Vector2i(x, z)):
				_mark_dirty(0.2)
				return


# --- Looks -----------------------------------------------------------------------

func _mark_dirty(wait: float) -> void:
	_dirty = true
	_redraw_wait = minf(_redraw_wait, wait) if _redraw_wait > 0.0 else wait


func _multimesh(mesh: Mesh) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Three thin blades leaning out from a point.
static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var a := i * TAU / 3.0
		var side := Vector3(cos(a), 0, sin(a)) * 0.05
		var tip := Vector3(cos(a + 1.0) * 0.12, 0.38, sin(a + 1.0) * 0.12)
		st.set_color(Color(1, 1, 1))
		st.add_vertex(-side)
		st.add_vertex(side)
		st.add_vertex(tip)
	st.generate_normals()
	return st.commit()


static func _bush_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 0.32
	m.height = 0.45
	m.radial_segments = 6
	m.rings = 3
	return m


## Rebuilds the soil patches and the grass on them.
func redraw() -> void:
	_dirty = false
	_redraw_wait = 0.5
	if terrain == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass: Array = []
	var plants: Array = []
	var n := 0
	# Every watered square, 32 triangles and up to 17 plants each; at most twice a
	# second, and only after something changed.
	for c in cells:
		var e: Dictionary = cells[c]
		var col := _cell_color(e)
		var x0: float = c.x * CELL
		var z0: float = c.y * CELL
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(c)
		for i in 4:
			for j in 4:
				var x := x0 + i
				var z := z0 + j
				var p00 := _ground(x, z)
				var p10 := _ground(x + 1, z)
				var p01 := _ground(x, z + 1)
				var p11 := _ground(x + 1, z + 1)
				var shade := 1.0 + rng.randf_range(-0.05, 0.05)
				var c1 := Color(col.r * shade, col.g * shade, col.b * shade)
				shade = 1.0 + rng.randf_range(-0.05, 0.05)
				var c2 := Color(col.r * shade, col.g * shade, col.b * shade)
				if posmod(int(x) + int(z), 2) == 0:
					_tri(st, p00, p11, p10, c1)
					_tri(st, p00, p01, p11, c2)
				else:
					_tri(st, p00, p01, p10, c1)
					_tri(st, p10, p01, p11, c2)
		n += 1
		var g: float = e.green
		for k in int(round(g * MAX_GRASS)):
			var px := x0 + rng.randf_range(0.2, CELL - 0.2)
			var pz := z0 + rng.randf_range(0.2, CELL - 0.2)
			var s := rng.randf_range(0.7, 1.3) * (0.6 + 0.4 * g)
			grass.append([Vector3(px, terrain.surface_height(px, pz), pz), rng.randf() * TAU, s,
				Color(0.32, 0.5, 0.18).lerp(Color(0.5, 0.55, 0.22), rng.randf())])
		var np := int(floor(maxf(g - 0.4, 0.0) / 0.6 * MAX_PLANTS + 0.001))
		for k in np:
			var px := x0 + rng.randf_range(0.5, CELL - 0.5)
			var pz := z0 + rng.randf_range(0.5, CELL - 0.5)
			plants.append([Vector3(px, terrain.surface_height(px, pz), pz), rng.randf() * TAU, rng.randf_range(0.7, 1.2),
				Color(0.26, 0.42, 0.16).lerp(Color(0.4, 0.5, 0.2), rng.randf())])
	if n > 0:
		_soil.mesh = st.commit()
	else:
		_soil.mesh = null
	_fill(_grass.multimesh, grass)
	_fill(_plants.multimesh, plants)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.surface_height(x, z) + 0.04, z)


## One flat triangle facing up (Godot's front face is clockwise, normal (c - a) x (b - a)).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (c - a).cross(b - a)
	if n.y < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	st.set_normal(n.normalized())
	st.set_color(col)
	for v in [a, b, c]:
		st.add_vertex(v)


## Damp sand, soil, then greener with green; darker while wet.
static func _cell_color(e: Dictionary) -> Color:
	var sand := Color(0.66, 0.46, 0.28)
	var soil := Color(0.4, 0.27, 0.16)
	var col := sand.lerp(soil, clampf(e.total / SOIL_NEED, 0.0, 1.0))
	col = col.lerp(Color(0.38, 0.52, 0.2), clampf(e.green, 0.0, 1.0) * 0.9)
	return col.darkened(clampf(e.wet / WET_MAX, 0.0, 1.0) * 0.3)


static func _fill(mm: MultiMesh, items: Array) -> void:
	mm.instance_count = items.size()
	for i in items.size():
		var it: Array = items[i]
		var b := Basis(Vector3.UP, it[1]).scaled(Vector3.ONE * float(it[2]))
		mm.set_instance_transform(i, Transform3D(b, it[0]))
		mm.set_instance_color(i, it[3])


## Pipes as thick blue-grey bars lying along the ground.
func _rebuild_pipes() -> void:
	if _pipe_root == null:
		return
	for c in _pipe_root.get_children():
		c.queue_free()
	for p in pipes:
		if not _valid_end(p[0]) or not _valid_end(p[1]):
			continue
		var a := pipe_anchor(p[0])
		var b := pipe_anchor(p[1])
		# Follow the ground in a few straight runs.
		var steps := maxi(1, ceili(a.distance_to(b) / 4.0))
		var prev := a
		for i in range(1, steps + 1):
			var t := float(i) / steps
			var q := a.lerp(b, t)
			if i < steps and terrain:
				q.y = terrain.surface_height(q.x, q.z) + 0.08
			var mi := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(0.09, 0.09, maxf(prev.distance_to(q), 0.01))
			mi.mesh = m
			mi.material_override = _pipe_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_pipe_root.add_child(mi)
			mi.global_position = (prev + q) * 0.5
			if prev.distance_to(q) > 0.01:
				mi.look_at(q, Vector3.UP if absf((q - prev).normalized().y) < 0.99 else Vector3.RIGHT)
			prev = q


# --- Saving ------------------------------------------------------------------------

func save_data() -> Dictionary:
	var list: Array = []
	for c in cells:
		var e: Dictionary = cells[c]
		list.append([c.x, c.y, snappedf(e.wet, 0.01), snappedf(e.total, 0.01), snappedf(e.green, 0.001), int(e.dry)])
	return {"store": store, "can": can, "cells": list, "pipes": pipes.duplicate(true)}


## A number from a save, or `fallback` if it isn't one (hand-edited or broken saves).
static func _num(v, fallback := 0.0) -> float:
	return float(v) if (v is float or v is int) else fallback


## Older saves (no "water"): a full well, an empty can and dry sand everywhere.
func load_data(data: Dictionary) -> void:
	store = clampf(_num(data.get("store", capacity), capacity), 0.0, capacity)
	can = clampf(_num(data.get("can", 0.0)), 0.0, CAN_MAX)
	cells = {}
	var list = data.get("cells", [])
	for e in (list if list is Array else []):
		if e is Array and e.size() >= 6:
			cells[Vector2i(int(_num(e[0])), int(_num(e[1])))] = {"wet": clampf(_num(e[2]), 0.0, WET_MAX),
				"total": clampf(_num(e[3]), 0.0, SOIL_NEED * 4.0), "green": clampf(_num(e[4]), 0.0, 1.0), "dry": int(_num(e[5]))}
	pipes = []
	var plist = data.get("pipes", [])
	for p in (plist if plist is Array else []):
		if p is Array and p.size() == 2 and _valid_end(str(p[0])) and _valid_end(str(p[1])):
			pipes.append([str(p[0]), str(p[1])])
	_rebuild_pipes()
	_set_level()
	_mark_dirty(0.0)
	ground_changed.emit()

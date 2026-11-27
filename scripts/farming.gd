extends Node3D
## Seeds and farming (v1.14).
## Seeds come by drone. Hold a packet and left click soil (watered sand, see
## water.gd) to dig a seed bed and plant it; beds sit on a SPOT m grid, four to a
## square of ground. Each morning a plant whose square got its litres the day
## before grows a day (faster near blooming flowers). At HEAT_HOUR the midday heat
## hurts plants whose square is still dry, and shade-loving ones out in the sun;
## a plant hurt twice without water in between dies. Ripe plants are harvested
## with E; some (flowers, fruit trees, dragon fruit) fruit again.

const LowPoly = preload("res://scripts/lowpoly.gd")
const Water = preload("res://scripts/water.gd")
const Items = preload("res://scripts/items.gd")

const SPOT := 2.0             # seed beds sit on a 2 m grid (four to a 4 m square)
const REACH := 4.5            # how far you can plant and harvest
const HEAT_HOUR := 13         # the midday heat check
const HEAT_HARM := 0.5        # health a dry (or sunburnt) plant loses at midday
const HEAL := 0.5             # health a watered plant gets back each morning
const FLOWER_R := 6.0         # blooming flowers help everything this close
const FLOWER_BOOST := 0.5     # extra days of growth a morning near flowers
const FLOWER_GREEN := 0.1     # and extra green on watered soil
const TREE_SHADE_R := 3.5     # a grown fruit tree shades plants this close
const TREE_SOIL := 1.0        # litres of "soil" a grown fruit tree adds round it each morning
const TREE_GREEN := 0.1       # and green on the soil round it
const KINDS := {"food": "food", "resource": "resource", "flower": "flower", "tree": "fruit tree", "exotic": "exotic"}

## Crop -> name, kind, days to ripe, litres a day its square needs, what it gives,
## "regrow" (days to fruit again; 0 = the plant is used up), "hardy" (never hurt by
## the heat), "tough" (hardy once it has fruited), "shade" (needs shade at midday),
## "max" (fussy: rots above this many litres a day), "h" (height grown, m).
const CROPS := {
	"millet": {"name": "Millet", "kind": "food", "days": 3, "need": 4.0, "yield": {"millet": 4}, "h": 1.0},
	"melon": {"name": "Melon", "kind": "food", "days": 4, "need": 6.0, "yield": {"melon": 2}, "h": 0.45},
	"cotton": {"name": "Cotton", "kind": "resource", "days": 4, "need": 4.0, "yield": {"cotton": 3}, "h": 0.9},
	"agave": {"name": "Agave", "kind": "resource", "days": 5, "need": 2.0, "yield": {"fibre": 4}, "hardy": true, "h": 0.8},
	"acacia": {"name": "Fast acacia", "kind": "resource", "days": 4, "need": 4.0, "yield": {"log": 3}, "h": 2.4},
	"marigold": {"name": "Desert marigold", "kind": "flower", "days": 2, "need": 4.0, "yield": {"flowers": 2}, "regrow": 2, "h": 0.5},
	"date_palm": {"name": "Date palm", "kind": "tree", "days": 6, "need": 4.0, "yield": {"dates": 4}, "regrow": 3, "tough": true, "h": 4.0},
	"saffron": {"name": "Saffron", "kind": "exotic", "days": 4, "need": 4.0, "max": 6.0, "shade": true, "yield": {"saffron": 1}, "h": 0.35},
	"dragon_fruit": {"name": "Dragon fruit", "kind": "exotic", "days": 5, "need": 6.0, "yield": {"dragon_fruit": 2}, "regrow": 3, "h": 1.4},
}

signal message(text: String)
signal pickup(lines: Array)
## Harvest that didn't fit in your bag, to drop at this point.
signal spilled(items: Dictionary, pos: Vector3)

var terrain  # Terrain
var water  # Water: the ground squares (soil, litres today) and greening
var player  # Player
var inventory  # Inventory (seeds, the harvest)
## Vector2i spot -> {"crop", "grow": days grown, "hp": 0..1, "dead": bool, "fruited": bool}
var plants := {}
var _beds: MultiMeshInstance3D
var _stalks: MultiMeshInstance3D
var _blobs: MultiMeshInstance3D
var _dirty := true


func _ready() -> void:
	var bed := BoxMesh.new()
	bed.size = Vector3(1.4, 0.12, 1.4)
	_beds = _multimesh(bed, "Beds")
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.6
	stalk.bottom_radius = 1.0
	stalk.height = 1.0
	stalk.radial_segments = 5
	stalk.rings = 1
	_stalks = _multimesh(LowPoly.flat(stalk), "Stalks")
	var blob := SphereMesh.new()
	blob.radius = 0.5
	blob.height = 1.0
	blob.radial_segments = 6
	blob.rings = 3
	_blobs = _multimesh(LowPoly.flat(blob), "Blobs")


func _process(_delta: float) -> void:
	if _dirty:
		redraw()


# --- Seeds and spots ----------------------------------------------------------------

static func seed_of(crop: String) -> String:
	return "seed_" + crop


## The crop a seed item grows, or "" if it isn't a seed.
static func crop_of_seed(item: String) -> String:
	var c := item.trim_prefix("seed_")
	return c if item.begins_with("seed_") and CROPS.has(c) else ""


static func spot_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / SPOT), floori(z / SPOT))


static func spot_center(s: Vector2i) -> Vector2:
	return Vector2((s.x + 0.5) * SPOT, (s.y + 0.5) * SPOT)


static func cell_of_spot(s: Vector2i) -> Vector2i:
	var p := spot_center(s)
	return Water.cell_of(p.x, p.y)


func is_ripe(e: Dictionary) -> bool:
	return not e.dead and e.grow >= float(CROPS[e.crop].days) - 0.001


## Flowers in bloom (and grown fruit trees) count from the first time they're ripe.
func is_grown(e: Dictionary) -> bool:
	return not e.dead and (e.fruited or is_ripe(e))


## Why a seed can't go in at this point on the ground ("" if it can).
func plant_problem(p: Vector3) -> String:
	var s := spot_of(p.x, p.z)
	if plants.has(s):
		return "There is already a plant here"
	if not water.is_soil(cell_of_spot(s)):
		return "Seeds need soil: water the sand first (%d L turns it to soil)" % int(Water.SOIL_NEED)
	if spot_center(s).distance_to(Water.WELL_POS) < Water.WELL_R + 1.6:
		return "Too close to the main well"
	return ""


## Plants a seed of `crop` at this point (takes one seed). Returns "" or why not.
func plant(p: Vector3, crop: String) -> String:
	if not CROPS.has(crop):
		return "That doesn't grow"
	if inventory.count_of(seed_of(crop)) <= 0:
		return "You have no %s seeds" % CROPS[crop].name.to_lower()
	var why := plant_problem(p)
	if why != "":
		return why
	inventory.remove(seed_of(crop), 1)
	plants[spot_of(p.x, p.z)] = {"crop": crop, "grow": 0.0, "hp": 1.0, "dead": false, "fruited": false}
	_dirty = true
	return ""


## Where the seeds in your hand would go: a point on the ground in reach, or null.
func ground_point() -> Variant:
	var hit: Dictionary = player.look_hit(REACH)
	if hit.is_empty() or hit.collider != terrain:
		return null
	return hit.position


## The plant under the crosshair (its spot), or null. Walks along the view ray in
## short steps and checks the plant standing on each spot it passes over.
func look_spot() -> Variant:
	if player == null or player.camera == null:
		return null
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var hit: Dictionary = player.look_hit(REACH)
	var far: float = REACH if hit.is_empty() else from.distance_to(hit.position) + 0.1
	var d := 0.3
	while d <= far:  # at most REACH / 0.2 steps, once a frame for the prompt
		var q := from + dir * d
		var s := spot_of(q.x, q.z)
		if plants.has(s):
			var c := spot_center(s)
			var g: float = terrain.surface_height(c.x, c.y) if terrain else 0.0
			var e: Dictionary = plants[s]
			var top := g + 0.25 + float(CROPS[e.crop].h) * _size(e)
			if Vector2(q.x, q.z).distance_to(c) < 0.75 and q.y < top:
				return s
		d += 0.2
	return null


## Growth from 0 to 1 (the plant's size follows it).
func _size(e: Dictionary) -> float:
	if e.dead:
		return 0.3
	return 0.25 + 0.75 * clampf(e.grow / float(CROPS[e.crop].days), 0.0, 1.0)


# --- Prompts and input ----------------------------------------------------------------

## "Millet (food): day 2 of 3, watered today ... [E] Harvest".
func plant_prompt(s: Vector2i) -> String:
	if not plants.has(s):
		return ""
	var e: Dictionary = plants[s]
	var cr: Dictionary = CROPS[e.crop]
	if e.dead:
		return "Dead %s: it dried out in the midday heat\n[E] Clear the bed" % cr.name.to_lower()
	var wet: float = water.cell_info(cell_of_spot(s)).wet
	var text := "%s (%s)" % [cr.name, KINDS[cr.kind]]
	var lines: Array = []
	if is_ripe(e):
		lines.append("ripe")
	elif e.fruited:
		lines.append("fruiting again in %d day%s" % [ceili(cr.days - e.grow), "" if ceili(cr.days - e.grow) == 1 else "s"])
	else:
		lines.append("day %d of %d" % [mini(int(e.grow) + 1, cr.days), cr.days])
	if cr.has("max") and wet > float(cr.max) + 0.001:
		lines.append("too wet today (%d L at most)" % int(cr.max))
	elif wet >= float(cr.need) - 0.001:
		lines.append("watered today")
	else:
		lines.append("needs %d L more water today" % int(ceil(float(cr.need) - wet)))
	if cr.get("shade", false) and not shaded(s):
		lines.append("needs shade at midday (a roof or a date palm)")
	if e.hp < 0.99:
		lines.append("wilting from the heat")
	text += ": " + ", ".join(lines)
	if is_ripe(e):
		var got: Array = []
		for item in cr.yield:
			got.append("%d %s" % [cr.yield[item], _item_name(item).to_lower()])
		text += "\n[E] Harvest (%s)" % ", ".join(got)
	return text


## The prompt with seeds in your hand: what is planted there, or where they'd go.
func seed_prompt(item: String) -> String:
	var crop := crop_of_seed(item)
	var p = ground_point()
	if crop == "" or p == null:
		return ""
	var s := spot_of(p.x, p.z)
	if plants.has(s):
		return plant_prompt(s)
	var why := plant_problem(p)
	if why != "":
		return why
	var cr: Dictionary = CROPS[crop]
	var text := "Soil\n[LMB] Plant %s (%s): ripe in %d days with %d L of water a day" % [cr.name.to_lower(), KINDS[cr.kind], cr.days, int(cr.need)]
	if cr.get("shade", false):
		text += ", in shade"
	if cr.has("max"):
		text += ", but no more than %d" % int(cr.max)
	return text


## Prompt for a plant under the crosshair, whatever is in your hands ("" if none).
func look_prompt() -> String:
	var s = look_spot()
	return "" if s == null else plant_prompt(s)


## Left click with seeds in hand. Returns true if used.
func handle_input(event: InputEvent, item: String) -> bool:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	var crop := crop_of_seed(item)
	var p = ground_point()
	if crop == "" or p == null:
		return false
	var why := plant(p, crop)
	if why != "":
		message.emit(why)
	else:
		pickup.emit(["Planted %s" % CROPS[crop].name.to_lower()])
	return true


## E on the plant under the crosshair. Returns true if there was one.
func use_look() -> bool:
	var s = look_spot()
	if s == null:
		return false
	harvest(s)
	return true


## Harvests a ripe plant (or clears a dead one). Returns the items it gave.
func harvest(s: Vector2i) -> Dictionary:
	if not plants.has(s):
		return {}
	var e: Dictionary = plants[s]
	var cr: Dictionary = CROPS[e.crop]
	if e.dead:
		plants.erase(s)
		_dirty = true
		pickup.emit(["Cleared the dead %s" % cr.name.to_lower()])
		return {}
	if not is_ripe(e):
		message.emit("%s isn't ripe yet" % cr.name)
		return {}
	var got: Dictionary = cr.yield.duplicate()
	var left: Dictionary = inventory.add_all(got)
	if not left.is_empty():
		var c := spot_center(s)
		spilled.emit(left, Vector3(c.x, terrain.surface_height(c.x, c.y) if terrain else 0.0, c.y))
	var lines: Array = []
	for item in got:
		lines.append("+%d %s" % [got[item], _item_name(item)])
	pickup.emit(lines)
	if int(cr.get("regrow", 0)) > 0:
		e.grow = float(cr.days - int(cr.regrow))
		e.fruited = true
	else:
		plants.erase(s)
	_dirty = true
	return got


static func _item_name(id: String) -> String:
	return Items.display_name(id)


# --- Days and the heat ---------------------------------------------------------------

## True if something shades this spot at midday: a roof or wall above it, or a
## grown fruit tree close by.
func shaded(s: Vector2i) -> bool:
	var c := spot_center(s)
	# Grown palms near this spot: looks at the 7x7 spots round it.
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var o: Vector2i = s + Vector2i(dx, dz)
			if o != s and plants.has(o) and plants[o].crop == "date_palm" and is_grown(plants[o]) \
					and spot_center(o).distance_to(c) <= TREE_SHADE_R:
				return true
	if not is_inside_tree() or terrain == null:
		return false
	var g: float = terrain.surface_height(c.x, c.y)
	var from := Vector3(c.x, g + 0.4, c.y)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 14, 0), 1, [player.get_rid()] if player else [])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Each hour: the midday heat check.
func on_hour(_day: int, hour: int) -> void:
	if hour == HEAT_HOUR:
		midday()


## The midday heat: plants on squares still dry today lose health, and so do
## shade lovers in the sun. Returns how many died.
func midday() -> int:
	var hurt := 0
	var died := 0
	# Once a day over every plant (a few dozen to a few hundred).
	for s in plants:
		var e: Dictionary = plants[s]
		if e.dead:
			continue
		var cr: Dictionary = CROPS[e.crop]
		var harm := 0.0
		var tough: bool = cr.get("hardy", false) or (cr.get("tough", false) and is_grown(e))
		if not tough and water.cell_info(cell_of_spot(s)).wet < float(cr.need) * 0.5:
			harm += HEAT_HARM
		if cr.get("shade", false) and not shaded(s):
			harm += HEAT_HARM
		if harm <= 0.0:
			continue
		e.hp -= harm
		if e.hp <= 0.001:
			e.dead = true
			died += 1
		else:
			hurt += 1
	if died > 0:
		message.emit("The midday heat killed %d plant%s: water them before noon" % [died, "" if died == 1 else "s"])
	elif hurt > 0:
		message.emit("%d plant%s wilting in the heat: water them" % [hurt, " is" if hurt == 1 else "s are"])
	if died + hurt > 0:
		_dirty = true
	return died


## New day (water.gd's morning_tally, before the squares' litres are cleared):
## watered plants grow a day, flowers help their neighbours, fruit trees push the
## green out round them.
func on_tally() -> void:
	var flowers: Array = []
	var trees: Array = []
	for s in plants:  # once a day, every plant
		var e: Dictionary = plants[s]
		if is_grown(e) and e.crop == "marigold":
			flowers.append(spot_center(s))
		if is_grown(e) and e.crop == "date_palm":
			trees.append(s)
	for s in plants:  # once a day, every plant times the blooming flowers (a handful)
		var e: Dictionary = plants[s]
		if e.dead:
			continue
		var cr: Dictionary = CROPS[e.crop]
		var wet: float = water.cell_info(cell_of_spot(s)).wet
		if cr.has("max") and wet > float(cr.max) + 0.001:
			e.hp -= HEAT_HARM  # fussy: rots when it's too wet
			if e.hp <= 0.001:
				e.dead = true
			continue
		if wet < float(cr.need) - 0.001:
			continue
		e.hp = minf(e.hp + HEAL, 1.0)
		if is_ripe(e):
			continue
		var boost := 0.0
		var c := spot_center(s)
		for f in flowers:
			if f.distance_to(c) <= FLOWER_R and f != c:
				boost = FLOWER_BOOST
				break
		e.grow = minf(e.grow + 1.0 + boost, float(cr.days))
	# Flowers green the watered soil round them; fruit trees spread soil and green.
	var greened := {}
	for f in flowers:
		var fc := Water.cell_of(f.x, f.y)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var c: Vector2i = fc + Vector2i(dx, dz)
				if not greened.has(c) and Water.cell_center(c).distance_to(f) <= FLOWER_R + 2.0 \
						and water.cell_info(c).wet >= Water.DAY_NEED - 0.001:
					greened[c] = true
					water.add_life(c, 0.0, FLOWER_GREEN)
	for s in trees:
		var tc := cell_of_spot(s)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				water.add_life(tc + Vector2i(dx, dz), TREE_SOIL, TREE_GREEN)
	_dirty = true


## Dug or filled ground uproots the plants on it.
func on_ground_changed(area: Rect2) -> void:
	var grown := area.grow(0.4)
	for s in plants.keys():  # .keys(): plants are taken out while looping
		if grown.has_point(spot_center(s)):
			plants.erase(s)
			_dirty = true


# --- Looks -----------------------------------------------------------------------

func _multimesh(mesh: Mesh, node_name: String) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mmi.material_override = mat
	add_child(mmi)
	return mmi


## A stalk from `base` along `up` (tilted), `h` long and `r` thick at the foot.
static func _stalk(out: Array, base: Vector3, h: float, r: float, col: Color, tilt := 0.0, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	b = b * Basis.from_scale(Vector3(r, h, r))
	out.append([Transform3D(b, base + b.y * 0.5), col])


static func _blob(out: Array, center: Vector3, size: Vector3, col: Color, yaw := 0.0, tilt := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt) * Basis.from_scale(size)
	out.append([Transform3D(b, center), col])


## Rebuilds the seed beds and plants (after something changed: planting, a harvest,
## a new day, the heat).
func redraw() -> void:
	_dirty = false
	var beds: Array = []
	var stalks: Array = []
	var blobs: Array = []
	# Every plant, up to about 12 instances each; only when something changed.
	for s in plants:
		var e: Dictionary = plants[s]
		var c := spot_center(s)
		var g: float = terrain.surface_height(c.x, c.y) if terrain else 0.0
		var o := Vector3(c.x, g + 0.08, c.y)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(s)
		var wet: float = water.cell_info(cell_of_spot(s)).wet if water else 0.0
		# The bed lies along the slope of the ground under it.
		var n := Vector3(0, 1, 0)
		if terrain:
			n = Vector3(terrain.surface_height(c.x - 0.6, c.y) - terrain.surface_height(c.x + 0.6, c.y), 1.2,
				terrain.surface_height(c.x, c.y - 0.6) - terrain.surface_height(c.x, c.y + 0.6)).normalized()
		var tilt := Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, rng.randf() * 0.2)
		beds.append([Transform3D(tilt, Vector3(c.x, g + 0.02, c.y)),
			Color(0.3, 0.2, 0.12).darkened(clampf(wet / Water.WET_MAX, 0.0, 1.0) * 0.35)])
		_plant_parts(e, o, rng, stalks, blobs)
	_fill(_beds.multimesh, beds)
	_fill(_stalks.multimesh, stalks)
	_fill(_blobs.multimesh, blobs)


## The low-poly look of one plant, by crop and size.
func _plant_parts(e: Dictionary, o: Vector3, rng: RandomNumberGenerator, stalks: Array, blobs: Array) -> void:
	var k := _size(e)
	var ripe := is_ripe(e)
	var green := Color(0.3, 0.5, 0.18).lerp(Color(0.55, 0.45, 0.2), 1.0 - clampf(e.hp, 0.0, 1.0))
	if e.dead:
		for i in 3:
			_stalk(stalks, o, 0.35, 0.025, Color(0.45, 0.35, 0.22), rng.randf_range(0.3, 0.9), rng.randf() * TAU)
		return
	match e.crop:
		"millet":
			var col := green.lerp(Color(0.78, 0.66, 0.3), 1.0 if ripe else 0.0)
			for i in 6:
				var tilt := rng.randf_range(0.0, 0.25)
				var yaw := rng.randf() * TAU
				var h := k * rng.randf_range(0.85, 1.05)
				var foot := o + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
				_stalk(stalks, foot, h, 0.032, col, tilt, yaw)
				if k > 0.6:
					var tip := foot + (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)) * Vector3(0, h, 0)
					_blob(blobs, tip, Vector3(0.09, 0.26, 0.09), col.darkened(0.15), yaw, tilt)
		"melon":
			_blob(blobs, o + Vector3(0, 0.1 * k, 0), Vector3(1.0, 0.3, 1.0) * k, green, rng.randf() * TAU)
			if ripe:
				for i in 2:
					var a := rng.randf() * TAU
					_blob(blobs, o + Vector3(cos(a) * 0.4, 0.15, sin(a) * 0.4), Vector3(0.38, 0.3, 0.3), Color(0.42, 0.6, 0.22), a)
		"cotton":
			_stalk(stalks, o, 0.6 * k, 0.03, Color(0.4, 0.35, 0.2))
			_blob(blobs, o + Vector3(0, 0.65 * k, 0), Vector3(0.6, 0.45, 0.6) * k, green)
			if ripe:
				for i in 5:
					var a := rng.randf() * TAU
					_blob(blobs, o + Vector3(cos(a) * 0.28, 0.75 + rng.randf() * 0.15, sin(a) * 0.28), Vector3.ONE * 0.13, Color(0.95, 0.94, 0.9))
		"agave":
			var col := Color(0.4, 0.55, 0.45)
			for i in 8:
				_stalk(stalks, o, 0.8 * k, 0.07, col, 0.25 + 0.55 * float(i % 2), i * TAU / 8.0)
			if ripe:
				_stalk(stalks, o, 1.4, 0.04, Color(0.5, 0.5, 0.25))
		"acacia":
			var h := 2.4 * k
			_stalk(stalks, o, h, 0.08 * k + 0.02, Color(0.4, 0.3, 0.2), 0.08, rng.randf() * TAU)
			_blob(blobs, o + Vector3(0, h, 0), Vector3(1.8, 0.35, 1.8) * k, Color(0.35, 0.45, 0.2), rng.randf() * TAU)
		"marigold":
			for i in 4:
				var foot := o + Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
				var h := 0.5 * k
				_stalk(stalks, foot, h, 0.02, green)
				if is_grown(e):  # in bloom
					_blob(blobs, foot + Vector3(0, h, 0), Vector3(0.18, 0.1, 0.18), Color(0.98, 0.62, 0.1).lerp(Color(1, 0.85, 0.15), rng.randf()))
				else:
					_blob(blobs, foot + Vector3(0, h * 0.7, 0), Vector3(0.12, 0.08, 0.12), green)
		"date_palm":
			var h := 4.0 * k
			var lean := rng.randf_range(0.0, 0.12)
			var yaw := rng.randf() * TAU
			_stalk(stalks, o, h, 0.16, Color(0.48, 0.36, 0.22), lean, yaw)
			var top := o + (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean)) * Vector3(0, h, 0)
			for i in 7:
				var a := i * TAU / 7.0
				var dir := Vector3(cos(a), 0, sin(a))
				_blob(blobs, top + dir * 0.7 * k + Vector3(0, -0.1, 0), Vector3(0.35, 0.08, 1.6) * k, Color(0.3, 0.5, 0.2), -a + PI * 0.5, 0.35)
			if ripe:
				for i in 4:
					var a := rng.randf() * TAU
					_blob(blobs, top + Vector3(cos(a) * 0.25, -0.35, sin(a) * 0.25), Vector3(0.22, 0.3, 0.22), Color(0.62, 0.34, 0.12))
		"saffron":
			for i in 6:
				_stalk(stalks, o + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)), 0.35 * k, 0.015, green, rng.randf_range(0.0, 0.4), rng.randf() * TAU)
			if ripe:
				for i in 3:
					_blob(blobs, o + Vector3(rng.randf_range(-0.2, 0.2), 0.3, rng.randf_range(-0.2, 0.2)), Vector3(0.12, 0.1, 0.12), Color(0.55, 0.3, 0.75))
		"dragon_fruit":
			for i in 3:
				var a := i * TAU / 3.0
				_stalk(stalks, o + Vector3(cos(a), 0, sin(a)) * 0.15, 1.4 * k, 0.1, Color(0.3, 0.55, 0.3), 0.25, a)
			if ripe:
				for i in 3:
					var a := i * TAU / 3.0 + 0.5
					_blob(blobs, o + Vector3(cos(a) * 0.35, 1.0, sin(a) * 0.35), Vector3(0.2, 0.24, 0.2), Color(0.9, 0.2, 0.45))


static func _fill(mm: MultiMesh, items: Array) -> void:
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])


# --- Saving ------------------------------------------------------------------------

func save_data() -> Dictionary:
	var list: Array = []
	for s in plants:
		var e: Dictionary = plants[s]
		list.append([s.x, s.y, e.crop, snappedf(e.grow, 0.01), snappedf(e.hp, 0.01), e.dead, e.fruited])
	return {"plants": list}


static func _num(v, fallback := 0.0) -> float:
	return float(v) if (v is float or v is int) else fallback


## Older saves (no "farming") have no plants. Broken entries are skipped.
func load_data(data: Dictionary) -> void:
	plants = {}
	var list = data.get("plants", [])
	for e in (list if list is Array else []):
		if not (e is Array and e.size() >= 7 and e[2] is String and CROPS.has(e[2])):
			continue
		var crop: String = e[2]
		plants[Vector2i(int(_num(e[0])), int(_num(e[1])))] = {"crop": crop,
			"grow": clampf(_num(e[3]), 0.0, float(CROPS[crop].days)), "hp": clampf(_num(e[4], 1.0), 0.0, 1.0),
			"dead": e[5] is bool and e[5], "fruited": e[6] is bool and e[6]}
	_dirty = true

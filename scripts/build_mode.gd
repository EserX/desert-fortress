extends Node3D
## Build mode (B): a see-through preview of the selected piece snaps to the
## grid where you look. Green means it can be built, red means it can't.
## Left click builds (costs materials), right click undoes a piece you built
## in the last minute (full refund; after that use the hammer), R turns the piece, the wheel or 1–9 picks a piece.
## Aiming higher up a wall or at an upper floor builds on the next level.
## Z / X turn the piece the other way or on (objects in 15° steps), and the
## preview swings round smoothly. T switches to ready-made buildings (prefabs):
## left click lays a free blueprint, E at the blueprint builds it.

const Building = preload("res://scripts/building.gd")
const Prefabs = preload("res://scripts/prefabs.gd")
const Items = preload("res://scripts/items.gd")
const Water = preload("res://scripts/water.gd")
const Weather = preload("res://scripts/weather.gd")
## Ground under a ready-made building may differ by at most this much.
const PREFAB_MAX_SPREAD := 1.4
## How fast the preview swings round to a new heading (per second).
const TURN_SPEED := 14.0

## Support the previewed piece would get (upper levels), or -INF.
var support_preview := -INF
## Left button held: where the line of pieces started ({} when not dragging).
var drag_start := {}
## A piece picked up with G to put down elsewhere: its piece_data(), or {}.
var carrying := {}
## Pays stamina for each piece built (set by the world; returns false when too tired).
var pay_stamina := Callable()
const LINE_MAX := 12
var building: Building
var inventory  # Inventory
var player  # Player
var shop  # Shop: which blueprint pieces are unlocked
var active := false
var type_index := 0
var dir := 0
## Extra 15° steps (0..5) past dir, for objects that turn freely.
var turn := 0
## T: ready-made buildings instead of single pieces.
var prefab_mode := false
var prefab_index := 0
## The material a ready-made building is laid in (G): 0 wood to 3 concrete.
var prefab_tier := 0
## The ready-made building under the crosshair: Prefabs.placed() and the height
## of its foundations.
var prefab_plan: Array = []
var prefab_y := 0.0
var _ghost_yaw := 0.0
var _ghost_prefab := ""
## What the preview shows right now.
var slot := {}
var base_y := 0.0
var can_build := false
var reason := ""
var looking_at_piece := ""

var _ghost: Node3D
var _ghost_type := ""
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
## Upstairs the preview shows how well it would be held up: green when solid,
## yellow, then orange close to the limit (red can't be built).
var _mid_mat: StandardMaterial3D
var _weak_mat: StandardMaterial3D
const SUPPORT_SOLID := 60.0
const SUPPORT_WEAK := 35.0
## Dashed circle on the sand showing a piece's reach while placing it
## (v2.8.5: not only turrets; see REACH_RINGS).
var range_ring: MultiMeshInstance3D
var _ring_at := Vector3.INF
var _ring_type := ""
var _ring_mat: StandardMaterial3D
## The pieces that show a reach circle: [radius in m, colour, what the HUD says].
const REACH_RINGS := {
	"turret": [Building.TURRET_RANGE, Color(1.0, 0.75, 0.25), "Shoots mutants up to %d m away (the circle)"],
	"sprinkler": [Water.SPRAY_R, Color(0.3, 0.65, 1.0), "Waters the ground up to %d m round it (the circle)"],
	"dew_collector": [Weather.DEW_R, Color(0.2, 0.85, 0.75), "Waters the ground up to %d m round it each morning (the circle)"],
	"weather_station": [Weather.STATION_R, Color(0.6, 0.8, 1.0), "Its showers cover up to %d m round it (the circle)"],
}
var ring_points := PackedVector3Array()  # where the dashes are (kept here, headless can't read a MultiMesh back)
const RING_DASHES := 90
## v2.8.7: while placing a piece with a reach, the circles of the ones already
## built that do the same job show too (fainter), so gaps and overlaps show.
## Sprinklers and dew collectors both water, so each shows the other's.
const RING_KIN := {
	"turret": ["turret"],
	"sprinkler": ["sprinkler", "dew_collector"],
	"dew_collector": ["sprinkler", "dew_collector"],
	"weather_station": ["weather_station"],
}
const OTHER_DASHES := 48  # per built circle (fewer than the preview's)
const OTHER_MAX := 24  # the nearest this many built pieces get a circle
const OTHER_RANGE := 70.0  # m from the preview
var other_rings: MultiMeshInstance3D
var other_centres: Array = []  # [centre, type, first dash, colour] of each circle drawn (headless can't read a MultiMesh back)
var _others_key := ""  # what the circles were drawn for; redraw when it changes
## v2.8.8: how many ground squares a sprinkler or dew collector placed at the
## preview would water that no built one already does: Vector2i(new, already).
var square_counts := Vector2i(-1, -1)
var _squares_key := ""  # what square_counts was worked out for


func _ready() -> void:
	_ok_mat = _ghost_mat(Color(0.3, 1.0, 0.35, 0.38))
	_bad_mat = _ghost_mat(Color(1.0, 0.25, 0.2, 0.38))
	_mid_mat = _ghost_mat(Color(0.95, 0.9, 0.25, 0.38))
	_weak_mat = _ghost_mat(Color(1.0, 0.55, 0.15, 0.38))
	_ghost = Node3D.new()
	_ghost.visible = false
	add_child(_ghost)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var dash := BoxMesh.new()
	dash.size = Vector3(0.12, 0.06, 0.8)
	mm.mesh = dash
	mm.instance_count = RING_DASHES
	range_ring = MultiMeshInstance3D.new()
	range_ring.multimesh = mm
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(1.0, 0.75, 0.25)
	range_ring.material_override = _ring_mat
	range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_ring.visible = false
	add_child(range_ring)
	var omm := MultiMesh.new()
	omm.transform_format = MultiMesh.TRANSFORM_3D
	omm.use_colors = true
	var odash := BoxMesh.new()
	odash.size = Vector3(0.08, 0.04, 0.8)
	omm.mesh = odash
	omm.instance_count = OTHER_DASHES * OTHER_MAX
	omm.visible_instance_count = 0
	other_rings = MultiMeshInstance3D.new()
	other_rings.multimesh = omm
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.vertex_color_use_as_albedo = true
	other_rings.material_override = om
	other_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	other_rings.visible = false
	add_child(other_rings)


func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	return m


func current_type() -> String:
	if not carrying.is_empty():
		return carrying.type
	return Building.ORDER[type_index]


func toggle() -> void:
	if active:
		cancel_carry()
		drag_start = {}
	active = not active
	_ghost.visible = false
	range_ring.visible = false
	hide_others()


func select(i: int) -> void:
	if prefab_mode:
		if i >= 0 and i < Prefabs.ORDER.size():
			prefab_index = i
	elif i >= 0 and i < Building.ORDER.size():
		type_index = i


func cycle(step: int) -> void:
	if prefab_mode:
		prefab_index = posmod(prefab_index + step, Prefabs.ORDER.size())
	else:
		type_index = posmod(type_index + step, Building.ORDER.size())


## T: single pieces or ready-made buildings.
func toggle_prefabs() -> void:
	cancel_carry()
	drag_start = {}
	prefab_mode = not prefab_mode
	_ghost_type = ""
	_ghost_prefab = ""


func current_prefab() -> String:
	return Prefabs.ORDER[prefab_index]


## G with ready-made buildings: wood, scrap metal, stone, concrete, wood...
func cycle_prefab_tier() -> void:
	prefab_tier = (prefab_tier + 1) % Building.TIER_NAMES.size()


## R: a quarter turn clockwise.
func rotate_piece() -> void:
	dir = (dir + 1) % 4


## Z (-1) / X (+1): objects that turn freely go 15° at a time, everything
## else a quarter turn either way.
func fine_turn(step: int) -> void:
	if not prefab_mode and current_type() in Building.FREE_TURN:
		var t := posmod(dir * 6 + turn + step, 24)
		dir = t / 6
		turn = t % 6
	else:
		dir = posmod(dir + step, 4)
		turn = 0


## Heading of the piece in degrees (0 = as built facing north), for the HUD.
func heading() -> int:
	var t := turn if not prefab_mode and current_type() in Building.FREE_TURN else 0
	return posmod(dir * 90 + t * 15, 360)


func _process(d: float) -> void:
	if not active:
		return
	update_preview(d)


## Works out the slot under the crosshair and whether the piece fits there.
## delta: how far the preview swings to its new heading (1 = all the way).
func update_preview(delta := 1.0) -> void:
	if prefab_mode:
		_update_prefab_preview(delta)
		return
	var type := current_type()
	if _ghost_type != type:
		_rebuild_ghost(type)
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * Building.REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	looking_at_piece = ""
	if hit.is_empty():
		_ghost.visible = false
		range_ring.visible = false
		hide_others()
		can_build = false
		reason = "Look at the ground nearby"
		slot = {}
		return
	if hit.collider.has_meta("piece_key"):
		looking_at_piece = hit.collider.get_meta("piece_key")
	# Nudge the point back towards the camera so aiming at a wall face picks this side.
	var p: Vector3 = hit.position + hit.normal * 0.05
	slot = Building.slot_for(type, p, dir)
	if type in Building.FREE_TURN and turn != 0:
		slot.turn = turn
	slot.level = building.level_for(type, slot, p.y)
	var ev := building.evaluate(type, slot)
	support_preview = float(ev.get("support", -INF))
	base_y = ev.y
	reason = ev.reason
	can_build = ev.ok
	if can_build and (not building.space_free(type, slot, base_y) or building.blocks_person(type, slot, base_y, player.global_position)):
		can_build = false
		reason = "Something is in the way"
	if can_build and carrying.is_empty() and shop and not shop.is_unlocked(type, Building.PIECES):
		can_build = false
		reason = "Locked: order its blueprint by drone from the shop terminal"
	if can_build and carrying.is_empty() and not has_materials(type):
		can_build = false
		reason = "Not enough materials"
	_set_ghost(Building.piece_transform(type, slot, base_y), delta)
	_update_ring(type)


## Moves the preview there at once, but swings its heading round smoothly.
func _set_ghost(t: Transform3D, delta: float) -> void:
	var yaw := t.basis.get_euler().y
	_ghost_yaw = yaw if delta >= 1.0 or not _ghost.visible else lerp_angle(_ghost_yaw, yaw, clampf(delta * TURN_SPEED, 0.0, 1.0))
	_ghost.transform = Transform3D(Basis(Vector3.UP, _ghost_yaw), t.origin)
	_ghost.visible = true
	var m := ghost_material()
	for mi in _ghost.get_children():
		mi.material_override = m


## The preview's colour: red if it can't be built, else by support upstairs.
func ghost_material() -> StandardMaterial3D:
	if not can_build:
		return _bad_mat
	if support_preview == -INF or support_preview >= SUPPORT_SOLID:
		return _ok_mat
	return _mid_mat if support_preview >= SUPPORT_WEAK else _weak_mat


## The ready-made building under the crosshair, turned with R / Z / X: its
## foundations must all fit on fairly even ground, and no piece may be taken.
func _update_prefab_preview(delta: float) -> void:
	var id := current_prefab()
	range_ring.visible = false
	hide_others()
	if _ghost_prefab != id + str(dir):
		_rebuild_prefab_ghost(id)
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * Building.REACH * 1.6, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	looking_at_piece = ""
	support_preview = -INF
	if hit.is_empty():
		_ghost.visible = false
		can_build = false
		reason = "Look at the ground nearby"
		slot = {}
		prefab_plan = []
		return
	var c: Dictionary = Building.slot_for("foundation", hit.position, 0)
	# The square you aim at is the middle of the building.
	var mid := prefab_middle(id, dir)
	c.cx -= mid.x
	c.cz -= mid.y
	slot = {"kind": "cell", "cx": c.cx, "cz": c.cz, "dir": dir, "level": 0}
	var ev := evaluate_prefab(id, c.cx, c.cz, dir)
	prefab_plan = ev.plan
	prefab_y = ev.y
	can_build = ev.ok
	reason = ev.reason
	base_y = ev.y
	_ghost.transform = Transform3D(Basis.IDENTITY, Vector3(c.cx * Building.CELL, ev.y, c.cz * Building.CELL))
	_ghost.visible = true
	for mi in _ghost.get_children():
		mi.material_override = _ok_mat if can_build else _bad_mat


## The middle square of a ready-made building turned `turns` × 90°, counted
## from its first square.
static func prefab_middle(id: String, turns: int) -> Vector2i:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for e in Prefabs.placed(id, 0, 0, turns, Building.PIECES):
		if e.type in Building.FOUNDATIONS:
			lo = Vector2i(mini(lo.x, e.slot.cx), mini(lo.y, e.slot.cz))
			hi = Vector2i(maxi(hi.x, e.slot.cx), maxi(hi.y, e.slot.cz))
	return Vector2i(floori((lo.x + hi.x) / 2.0), floori((lo.y + hi.y) / 2.0))


## Can ready-made building `id` go with its first square at (cx, cz), turned
## `turns` × 90°? {"ok", "reason", "y": foundation tops, "plan"}.
func evaluate_prefab(id: String, cx: int, cz: int, turns: int) -> Dictionary:
	var plan: Array = Prefabs.placed(id, cx, cz, turns, Building.PIECES)
	var y := -INF
	var lo := INF
	var planned: Dictionary = building.site_keys()
	for e in plan:
		for k in Building.slot_keys(e.type, e.slot):
			if planned.has(k):
				return {"ok": false, "reason": "Another blueprint is here", "y": maxf(y, 0.0), "plan": plan}
			if building.occupied.has(k):
				return {"ok": false, "reason": "Something is already built here", "y": maxf(y, 0.0), "plan": plan}
		if not building.in_zone(e.type, e.slot):
			return {"ok": false, "reason": "Outside the base zone (stay within %d m of the flag)" % int(building.zone_radius), "y": maxf(y, 0.0), "plan": plan}
		if e.type in Building.FOUNDATIONS:
			var fe: Dictionary = building.evaluate(e.type, e.slot)
			if not fe.ok:
				return {"ok": false, "reason": fe.reason, "y": fe.y, "plan": plan}
			y = maxf(y, fe.y)
			var cc := Building.slot_center(e.slot)
			lo = minf(lo, building.terrain.surface_height(cc.x, cc.z))
	if y == -INF:
		return {"ok": false, "reason": "No foundations", "y": 0.0, "plan": plan}
	if y - lo > PREFAB_MAX_SPREAD:
		return {"ok": false, "reason": "The ground is too uneven for this building", "y": y, "plan": plan}
	for e in plan:
		if e.type in Building.FOUNDATIONS and not building.space_free(e.type, e.slot, y):
			return {"ok": false, "reason": "Something is in the way", "y": y, "plan": plan}
	return {"ok": true, "reason": "", "y": y, "plan": plan}


## Lays the blueprint of the previewed ready-made building (free). Returns
## its site id, or 0.
func place_prefab() -> int:
	if not active or not prefab_mode or not can_build or prefab_plan.is_empty():
		return 0
	return building.add_site(current_prefab(), prefab_plan, prefab_y, prefab_tier)


func _rebuild_prefab_ghost(id: String) -> void:
	_ghost_prefab = id + str(dir)
	_ghost_type = ""
	for c in _ghost.get_children():
		c.queue_free()
	for e in Prefabs.placed(id, 0, 0, dir, Building.PIECES):
		var y: float = int(e.slot.level) * Building.WALL_H
		Building.add_ghost_meshes(_ghost, e.type, Building.piece_transform(e.type, e.slot, y))


## The reach circle's radius for a piece type, or 0 when it has none.
static func ring_radius(type: String) -> float:
	return float(REACH_RINGS[type][0]) if REACH_RINGS.has(type) else 0.0


## Lays the dashes of the reach circle on the sand around the previewed piece.
## Runs every frame in build mode, but only redraws (RING_DASHES dashes) when
## the preview moved or the piece changed.
func _update_ring(type: String) -> void:
	_draw_ring(type, _ghost.global_position, _ghost.visible)
	_draw_others(type, _ghost.global_position, _ghost.visible)
	_count_squares(type, _ghost.global_position, _ghost.visible)


## v2.8.7: the fainter circles of the built pieces that do the same job as the
## one being placed (RING_KIN), the OTHER_MAX nearest within OTHER_RANGE.
## Runs every frame in build mode; the loop over all pieces (a few hundred at
## most) only runs when the piece type, the base (building.revision) or the
## preview's 8 m square changes.
func _draw_others(type: String, c: Vector3, show: bool) -> void:
	if not show or not RING_KIN.has(type):
		hide_others()
		return
	var key := "%s|%d|%d|%d|%s" % [type, building.revision, floori(c.x / 8.0), floori(c.z / 8.0), carrying.get("key", "")]
	other_rings.visible = true
	if key == _others_key:
		return
	_others_key = key
	var kin: Array = RING_KIN[type]
	var found: Array = []  # [distance, centre, type]
	for k in building.pieces.keys():
		var rec: Dictionary = building.pieces[k]
		if not kin.has(rec.type) or not is_instance_valid(rec.node):
			continue
		var pc: Vector3 = (rec.node as Node3D).global_position
		var d := Vector2(pc.x - c.x, pc.z - c.z).length()
		if d <= OTHER_RANGE + ring_radius(rec.type):
			found.append([d, pc, rec.type])
	found.sort_custom(func(a, b): return a[0] < b[0])
	found.resize(mini(found.size(), OTHER_MAX))
	other_centres.clear()
	var mm := other_rings.multimesh
	var n := 0
	for f in found:
		var pc: Vector3 = f[1]
		var r := ring_radius(f[2])
		var col: Color = (REACH_RINGS[f[2]][1] as Color).lerp(Color(0.85, 0.85, 0.85), 0.35)
		var dash_len := clampf(TAU * r / OTHER_DASHES * 0.45, 0.1, 1.2)
		var sc := Basis.from_scale(Vector3(1, 1, dash_len / 0.8))
		for i in OTHER_DASHES:
			var a := i * TAU / OTHER_DASHES
			var p := pc + Vector3(cos(a) * r, 0, sin(a) * r)
			p.y = maxf(building.terrain.surface_height(p.x, p.z), pc.y) + 0.05
			if i == 0:
				other_centres.append([pc, f[2], p, col])
			mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, -a) * sc, p))
			mm.set_instance_color(n, col)
			n += 1
	mm.visible_instance_count = n
	other_rings.visible = n > 0


## The ground squares a sprinkler or dew collector at pos waters (the same
## helpers the sprinklers and the morning dew use), or [] for other pieces.
static func watered_cells(type: String, pos: Vector3) -> Array:
	match type:
		"sprinkler":
			return Water.spray_cells(pos)
		"dew_collector":
			return Weather.cells_within(Vector2(pos.x, pos.z), Weather.DEW_R)
	return []


## v2.8.8: counts the squares a sprinkler or dew collector at pos would water:
## Vector2i(new, already watered by a built sprinkler or dew collector).
## Loops over all pieces (a few hundred at most) and the 9 to 21 squares of
## each nearby waterer; called only when the preview moves, the piece type
## or the base changes (see _count_squares).
func count_squares(type: String, pos: Vector3) -> Vector2i:
	var mine := watered_cells(type, pos)
	if mine.is_empty():
		return Vector2i(-1, -1)
	var reach := ring_radius(type) + Weather.DEW_R + Water.CELL * 2.0
	var taken := {}
	for k in building.pieces.keys():
		var rec: Dictionary = building.pieces[k]
		if not (rec.type == "sprinkler" or rec.type == "dew_collector") or not is_instance_valid(rec.node):
			continue
		var pc: Vector3 = (rec.node as Node3D).global_position
		if Vector2(pc.x - pos.x, pc.z - pos.z).length() > reach:
			continue
		for c in watered_cells(rec.type, pc):
			taken[c] = true
	var old := 0
	for c in mine:
		if taken.has(c):
			old += 1
	return Vector2i(mine.size() - old, old)


func _count_squares(type: String, c: Vector3, show: bool) -> void:
	if not show or watered_cells(type, c).is_empty():
		square_counts = Vector2i(-1, -1)
		_squares_key = ""
		return
	var key := "%s|%d|%.2f|%.2f" % [type, building.revision, c.x, c.z]
	if key == _squares_key:
		return
	_squares_key = key
	square_counts = count_squares(type, c)


## The build line's count of squares ("Waters 7 squares: 5 new, 2 already watered"), or "".
func squares_text() -> String:
	if square_counts.x < 0:
		return ""
	var total := square_counts.x + square_counts.y
	if square_counts.y == 0:
		return "Waters %d squares, all new" % total
	if square_counts.x == 0:
		return "Waters %d squares, all already watered by another" % total
	return "Waters %d squares: %d new, %d already watered by another" % [total, square_counts.x, square_counts.y]


## Hides the built pieces' circles (and forgets them, so they redraw next time).
func hide_others() -> void:
	other_rings.visible = false
	other_centres.clear()
	_others_key = ""


## v2.8.6: outside build mode, the hammer pointed at a built sprinkler, dew
## collector, weather station or turret shows its reach circle round it.
## key: the piece under the crosshair, or "" to hide. Called every frame by
## main while the hammer is held; redraws only when the piece changes.
func show_reach_of(key: String) -> void:
	if active:
		return  # build mode draws its own circle
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty() or not REACH_RINGS.has(rec.type) or not is_instance_valid(rec.node):
		range_ring.visible = false
		return
	_draw_ring(rec.type, (rec.node as Node3D).global_position, true)


## The reach text for a piece type ("Waters the ground up to 5 m round it (the circle)"), or "".
static func reach_text(type: String) -> String:
	return String(REACH_RINGS[type][2]) % int(ring_radius(type)) if REACH_RINGS.has(type) else ""


func _draw_ring(type: String, c: Vector3, show: bool) -> void:
	range_ring.visible = REACH_RINGS.has(type) and show
	if not range_ring.visible:
		return
	if type == _ring_type and c.distance_to(_ring_at) < 0.01:
		return
	_ring_at = c
	_ring_type = type
	var r := ring_radius(type)
	_ring_mat.albedo_color = REACH_RINGS[type][1]
	# Shorter dashes on small circles so they stay dashes, not a solid ring.
	var dash_len := clampf(TAU * r / RING_DASHES * 0.55, 0.12, 1.0)
	var sc := Basis.from_scale(Vector3(1, 1, dash_len / 0.8))
	ring_points.resize(RING_DASHES)
	for i in RING_DASHES:
		var a := i * TAU / RING_DASHES
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = maxf(building.terrain.surface_height(p.x, p.z), c.y) + 0.06
		ring_points[i] = p
		range_ring.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -a) * sc, p))


func _rebuild_ghost(type: String) -> void:
	_ghost_type = type
	_ghost_prefab = ""
	for c in _ghost.get_children():
		c.queue_free()
	Building.add_ghost_meshes(_ghost, type, Transform3D.IDENTITY)


func has_materials(type: String) -> bool:
	var cost: Dictionary = Building.PIECES[type].cost
	for item in cost:
		if inventory.count_of(item) < cost[item]:
			return false
	return true


## Builds the previewed piece. Returns true on success.
func try_place() -> bool:
	if not active or slot.is_empty() or not can_build:
		return false
	if not carrying.is_empty():
		building.restore_piece(carrying, slot, base_y)
		carrying = {}
		return true
	var type := current_type()
	var cost: Dictionary = Building.PIECES[type].cost
	for item in cost:
		inventory.remove(item, cost[item])
	var key: String = building.place(type, slot, base_y)
	building.level_under(key)
	return true


## Left button down: a line of pieces may start here.
func begin_drag() -> void:
	drag_start = slot.duplicate() if active and not slot.is_empty() else {}


## Left button up: builds the line from where it was pressed to here (one piece
## if the mouse didn't move). Returns how many pieces were built.
func end_drag() -> int:
	var start := drag_start
	drag_start = {}
	if not active or slot.is_empty():
		return 0
	if start.is_empty() or not carrying.is_empty() or start.get("level", 0) != slot.get("level", 0):
		if can_build and (not pay_stamina.is_valid() or pay_stamina.call()):
			return 1 if try_place() else 0
		return 0
	return place_line(line_slots(current_type(), start, slot))


## Slots in a straight line from a to b: squares along the longer way, edges
## along their own direction, corners like squares. At most LINE_MAX.
static func line_slots(type: String, a: Dictionary, b: Dictionary) -> Array:
	if a.is_empty():
		return []
	var info: Dictionary = Building.PIECES[type]
	if b.is_empty() or info.slot == "obj" or info.get("long", false) or a.kind != b.kind:
		return [a.duplicate()]
	var vary_x: bool
	if a.kind == "edge":
		if b.dir != a.dir:
			return [a.duplicate()]
		vary_x = a.dir == 0
	else:
		vary_x = absi(b.cx - a.cx) >= absi(b.cz - a.cz)
	var n0: int = a.cx if vary_x else a.cz
	var n1: int = b.cx if vary_x else b.cz
	var step := 1 if n1 >= n0 else -1
	var out: Array = []
	for i in mini(absi(n1 - n0), LINE_MAX - 1) + 1:
		var s: Dictionary = a.duplicate()
		if vary_x:
			s.cx = n0 + i * step
		else:
			s.cz = n0 + i * step
		out.append(s)
	return out


## Builds the current piece in each slot that takes it, paying for each, until
## the materials (or your breath) run out. Returns how many were built.
func place_line(slots: Array) -> int:
	var type := current_type()
	var cost: Dictionary = Building.PIECES[type].cost
	var n := 0
	for s in slots:
		var ev: Dictionary = building.evaluate(type, s)
		if not ev.ok or not building.space_free(type, s, ev.y) or building.blocks_person(type, s, ev.y, player.global_position):
			continue
		if shop and not shop.is_unlocked(type, Building.PIECES):
			break
		if not has_materials(type):
			break
		if pay_stamina.is_valid() and not pay_stamina.call():
			break
		for item in cost:
			inventory.remove(item, cost[item])
		building.level_under(building.place(type, s, ev.y))
		n += 1
	return n


## G: picks up the piece under the crosshair to put it down elsewhere (its
## contents, fuel, damage and so on go with it). Returns "" or why not.
func pick_up(key: String) -> String:
	if not carrying.is_empty():
		return "You are already carrying a piece"
	var why := building.move_problem(key)
	if why != "":
		return why
	key = building.occupied.get(key, key)
	carrying = building.piece_data(key)
	carrying.home = key
	building.remove(key, false)
	dir = int(carrying.dir)
	turn = int(carrying.get("turn", 0))
	return ""


## Puts a carried piece back where it came from.
func cancel_carry() -> void:
	if carrying.is_empty():
		return
	var c := carrying
	carrying = {}
	building.restore_piece(c)


## The piece under the crosshair, traps and ladders included (for G).
func piece_under_crosshair() -> String:
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * Building.REACH, 1 | Building.TRAP_LAYER, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return building.piece_key_of(hit.collider) if not hit.is_empty() else ""


## Undoes a freshly built piece under the crosshair with a full refund.
## Returns its type, "" if nothing was there, or "old" if it is too late to undo.
func try_remove() -> String:
	if not active or looking_at_piece == "":
		return ""
	var rec: Dictionary = building.piece_at(looking_at_piece)
	if rec.is_empty():
		return ""
	if not building.can_undo(rec):
		return "old"
	var type := building.remove(looking_at_piece)
	building.collapse_unsupported()  # whatever it held up comes down too
	if type != "":
		var left: Dictionary = inventory.add_all(Building.PIECES[type].cost)
		if not left.is_empty():
			# Pockets full: nothing is lost, it goes into a bag.
			get_parent().loot.spawn_drop(left, player.global_position)
	looking_at_piece = ""
	return type


## Keys while building, for the HUD.
func keys_text() -> String:
	if prefab_mode:
		return "[LMB] lay blueprint  [R/Z/X] turn  [Wheel] building  [T] blueprint menu  [G] material  [E at a blueprint] build it  [RMB on it] scrap it"
	return "[LMB] build (drag: a line)  [R] turn 90°  [Z/X] turn %s  [Wheel/1-9] piece  [T] ready-made buildings  [G] move  [RMB] undo" % ("15°" if current_type() in Building.FREE_TURN else "90°")


## One line for the HUD.
func status_text() -> String:
	if prefab_mode:
		var id := current_prefab()
		var cost: Dictionary = Building.prefab_cost(id, prefab_tier)
		var parts: Array = []
		for item in cost:
			parts.append("%d %s" % [cost[item], Items.display_name(item).to_lower()])
		var pl := "BUILDING: %s in %s   (%d pieces: %s)   facing %d°" % [Prefabs.display_name(id), Building.TIER_NAMES[prefab_tier],
			Prefabs.entries(id).size(), ", ".join(parts), dir * 90]
		pl += "\n" + (reason if not can_build and reason != "" else "Left click lays the blueprint for free, then E at it builds it piece by piece")
		return pl + "\n" + keys_text()
	var type := current_type()
	var info: Dictionary = Building.PIECES[type]
	var parts: Array = []
	for item in info.cost:
		parts.append("%d %s (%d)" % [info.cost[item], Items.display_name(item).to_lower(), inventory.count_of(item)])
	var line := "BUILD: %s   %s   facing %d°" % [info.name, ", ".join(parts), heading()]
	if not carrying.is_empty():
		line = "MOVING: %s   left click puts it down, G puts it back" % info.name
	elif not drag_start.is_empty():
		line += "\nLine: %d pieces (let go to build)" % line_slots(current_type(), drag_start, slot).size()
	if not can_build and reason != "":
		line += "\n" + reason
	elif slot.get("level", 0) > 0 and support_preview > -INF:
		line += "\nSupport here: %d%%" % int(support_preview)
	if REACH_RINGS.has(type) and carrying.is_empty() and not slot.is_empty():
		line += "\n" + reach_text(type)
		var sq := squares_text()
		if sq != "":
			line += "\n" + sq
	return line + "\n" + keys_text()

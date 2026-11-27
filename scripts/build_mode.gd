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
## Dashed circle on the sand showing a turret's reach while placing one.
var range_ring: MultiMeshInstance3D
var _ring_at := Vector3.INF
var ring_points := PackedVector3Array()  # where the dashes are (kept here, headless can't read a MultiMesh back)
const RING_DASHES := 90


func _ready() -> void:
	_ok_mat = _ghost_mat(Color(0.3, 1.0, 0.35, 0.38))
	_bad_mat = _ghost_mat(Color(1.0, 0.25, 0.2, 0.38))
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
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.0, 0.75, 0.25)
	range_ring.material_override = rm
	range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_ring.visible = false
	add_child(range_ring)


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
	for mi in _ghost.get_children():
		mi.material_override = _ok_mat if can_build else _bad_mat


## The ready-made building under the crosshair, turned with R / Z / X: its
## foundations must all fit on fairly even ground, and no piece may be taken.
func _update_prefab_preview(delta: float) -> void:
	var id := current_prefab()
	range_ring.visible = false
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
	return building.add_site(current_prefab(), prefab_plan, prefab_y)


func _rebuild_prefab_ghost(id: String) -> void:
	_ghost_prefab = id + str(dir)
	_ghost_type = ""
	for c in _ghost.get_children():
		c.queue_free()
	for e in Prefabs.placed(id, 0, 0, dir, Building.PIECES):
		var y: float = int(e.slot.level) * Building.WALL_H
		Building.add_ghost_meshes(_ghost, e.type, Building.piece_transform(e.type, e.slot, y))


## Lays the dashes of the range circle on the sand around the previewed turret.
func _update_ring(type: String) -> void:
	range_ring.visible = type == "turret"
	if not range_ring.visible:
		return
	var c := _ghost.global_position
	if c.distance_to(_ring_at) < 0.01:
		return
	_ring_at = c
	var r: float = Building.TURRET_RANGE
	ring_points.resize(RING_DASHES)
	for i in RING_DASHES:
		var a := i * TAU / RING_DASHES
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = maxf(building.terrain.surface_height(p.x, p.z), c.y) + 0.06
		ring_points[i] = p
		range_ring.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -a), p))


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
		return "[LMB] lay blueprint  [R/Z/X] turn  [Wheel] building  [T] single pieces  [E at a blueprint] build it  [RMB on it] scrap it"
	return "[LMB] build (drag: a line)  [R] turn 90°  [Z/X] turn %s  [Wheel/1-9] piece  [T] ready-made buildings  [G] move  [RMB] undo" % ("15°" if current_type() in Building.FREE_TURN else "90°")


## One line for the HUD.
func status_text() -> String:
	if prefab_mode:
		var id := current_prefab()
		var cost: Dictionary = Prefabs.total_cost(id, Building.PIECES)
		var parts: Array = []
		for item in cost:
			parts.append("%d %s" % [cost[item], Items.display_name(item).to_lower()])
		var pl := "BUILDING: %s   (%d pieces: %s)   facing %d°" % [Prefabs.display_name(id), Prefabs.entries(id).size(), ", ".join(parts), dir * 90]
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
	return line + "\n" + keys_text()

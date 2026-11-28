extends SceneTree
## Headless smoke tests. Run with:
##   godot --headless --path . -s tests/run_tests.gd --fixed-fps 60
## Exits with code 0 when everything passes, 1 otherwise.

var main: Node
var frame := 0
var failures: Array[String] = []
var start_pos: Vector3
var events: Array[String] = []
var title: Node
var game: Node


## Collects every error Godot reports while the tests run (script errors
## included), so a script that fails to compile or crashes fails the run even
## when the checks after it still pass.
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		errors.append("[%d] %s (%s:%d in %s)" % [error_type, rationale if rationale != "" else code, file, line, function])
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var catcher := ErrorCatcher.new()


func _initialize() -> void:
	OS.add_logger(catcher)
	print("== Desert Fortress tests ==")
	game = root.get_node("Game")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		failures.append(msg)


## Looting: aim at a crate, search it, loot is saved and restored.
func _test_loot() -> void:
	var loot = main.loot
	var kinds := {}
	for c in main.props.containers:
		kinds[c.kind] = true
	check(kinds.has("glovebox") and kinds.has("trunk") and kinds.has("crate"), "wrecks and ruins have containers (%d)" % loot.containers.size())
	# Stand in front of a crate and look at it.
	var crate: Dictionary = main.props.containers.filter(func(c): return c.kind == "crate")[0]
	var target: Vector3 = crate.lid.global_position
	var player = main.player
	var away := Vector3(1.6, 0, 0)
	player.position = target + away - Vector3(0, player.EYE_HEIGHT, 0)
	player.rotation.y = atan2(away.x, away.z)
	player.head.rotation.x = 0.0
	player.head.position.y = player.EYE_HEIGHT
	var seen: String = player.interact_target()
	check(seen == crate.id, "crosshair finds the crate (%s)" % seen)
	check(loot.prompt(crate.id).begins_with("[E] Search"), "prompt: " + loot.prompt(crate.id))
	var inv = main.inventory
	main.interact(crate.id)
	check(inv.weight() > 0.0, "searching puts loot in the inventory (%.1f kg)" % inv.weight())
	check(loot.open(crate.id).is_empty(), "a searched crate is empty")
	check(loot.prompt(crate.id).ends_with("(empty)"), "prompt shows empty")
	var data: Dictionary = main.collect_save_data()
	var before: Array = inv.slots.duplicate(true)
	loot.containers[crate.id].opened = false
	inv.load_data({})
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(loot.is_opened(crate.id), "opened containers are saved")
	check(inv.slots == before, "inventory is saved")
	_test_inventory()
	# Same seed and id always roll the same loot.
	var Items = load("res://scripts/items.gd")
	var r1 := RandomNumberGenerator.new()
	r1.seed = 9
	var r2 := RandomNumberGenerator.new()
	r2.seed = 9
	check(Items.roll("trunk", r1) == Items.roll("trunk", r2), "loot rolls are repeatable")


## Stacking, weight limit, moving, dropping and picking up bags, old saves.
func _test_inventory() -> void:
	var Inventory = load("res://scripts/inventory.gd")
	var inv = Inventory.new()
	check(inv.add("nails", 70) == 0 and inv.slots[0].count == 50 and inv.slots[1].count == 20, "stacks split at the stack size")
	inv.add("nails", 10)
	check(inv.slots[1].count == 30, "new items top up existing stacks")
	inv.add("wood", 3)
	inv.move(2, 0)
	check(inv.slots[0].item == "wood" and inv.slots[2].item == "nails", "moving onto another item swaps")
	inv.move(1, 2)
	check(inv.slots[2].count == 50 and inv.slots[1].count == 30, "moving onto the same item merges up to a full stack")
	check(inv.remove("nails", 85) == 80 and inv.count_of("nails") == 0, "remove takes what there is")
	check(not inv.overloaded(), "light load is fine")
	inv.add("scrap", 40)
	check(inv.overloaded(), "60 kg of scrap is too heavy")
	var full = Inventory.new()
	for i in Inventory.SIZE:
		full.add("water", 10)
	check(full.add("water", 3) == 3, "a full inventory reports what didn't fit")
	# Overloaded player can't sprint.
	var player = main.player
	var real = main.inventory
	real.add("scrap", 40)
	check(player.overloaded, "player knows they are overloaded")
	real.remove("scrap", 40)
	check(not player.overloaded, "dropping weight allows sprint again")
	# Drop a stack and pick the bag back up.
	real.load_data({})
	real.add("cloth", 4)
	main.drop_slot(0)
	check(real.count_of("cloth") == 0 and main.loot.drops.size() == 1, "dropping a stack leaves a bag")
	var bag_id: String = main.loot.drops.keys()[0]
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	main.interact(bag_id)
	check(real.count_of("cloth") == 4 and main.loot.drops.is_empty(), "picking the bag up empties it")
	main.apply_save_data(data)
	check(main.loot.drops.size() == 1 and real.count_of("cloth") == 0, "dropped bags are saved")
	main.interact(main.loot.drops.keys()[0])
	# A v0.4 save (plain item counts) still loads.
	data.erase("inventory")
	data.loot["inventory"] = {"wood": 7}
	main.apply_save_data(data)
	check(real.count_of("wood") == 7, "v0.4 saves keep their items")
	real.load_data({})
	main.loot.load_data({})
	_test_survival()


## Hunger, thirst, heat, shade, eating, damage, death and respawn.
func _test_survival() -> void:
	var Survival = load("res://scripts/survival.gd")
	var a = Survival.new()
	var b = Survival.new()
	a.tick(60.0, 13.0, false, false)
	b.tick(60.0, 13.0, false, true)
	check(a.water < b.water and a.hot and not b.hot, "midday sun drains water faster than shade (%.1f vs %.1f)" % [a.water, b.water])
	var c = Survival.new()
	c.tick(60.0, 9.0, true, false)
	check(c.food < b.food, "sprinting makes you hungrier")
	a.water = 0.0
	a.tick(10.0, 9.0, false, false)
	check(a.health < Survival.MAX, "no water hurts")
	a.consume("water")
	check(a.water >= 40.0, "drinking restores water")
	a.fall(20.0)
	check(a.health < 20.0, "a long fall hurts a lot (%.0f)" % a.health)
	a.free(); b.free(); c.free()
	# Eat from the hotbar.
	var inv = main.inventory
	inv.load_data({})
	inv.add("canned_food", 2)
	inv.selected = 0
	main.survival.food = 30.0
	main.use_selected()
	check(main.survival.food > 60.0 and inv.count_of("canned_food") == 1, "eating from the hotbar uses one can")
	inv.add("scrap", 1)
	inv.selected = 1
	main.use_selected()
	check(inv.count_of("scrap") == 1, "scrap can't be eaten")
	# Shade: under a wreck at noon vs open sand.
	main.day_night.restore(1, 13.0)
	main.player.position = Vector3(0, main.terrain.surface_height(0, 20), 20)
	check(not main._check_shade(), "open sand at noon is in the sun")
	# Die and respawn with items.
	main.survival.damage(500.0)
	check(main.survival.dead and main.death_screen.is_open() and paused, "dying shows the death screen")
	main.respawn()
	check(not paused and main.survival.health == Survival.MAX, "respawn restores health")
	check(main.player.position.distance_to(main.player.spawn_point) < 0.1, "respawn at the base")
	check(inv.count_of("scrap") == 1, "items kept after death")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	main.survival.water = 10.0
	saved.survival.water = 42.0
	main.apply_save_data(saved)
	check(absf(main.survival.water - 42.0) < 0.01, "needs are saved")
	inv.load_data({})
	_test_map_and_refill()


## Discovery, morning refill, supply crates and the map screen.
func _test_map_and_refill() -> void:
	var loot = main.loot
	var place: Dictionary = main.places[0]
	main.player.position = place.pos + Vector3(5, 1, 0)
	main._discover_nearby()
	check(main.discovered.has(place.key), "walking near a wreck discovers it")
	check(main.place_has_loot(place), "an unsearched wreck has loot")
	for id in loot.containers.keys():
		if id.begins_with(place.key + "_"):
			main.interact(id)
	check(not main.place_has_loot(place), "searched wreck is empty")
	var searched := 0
	for id in loot.containers:
		if loot.containers[id].opened:
			searched += 1
	check(loot.refill(2, 99) == searched and main.place_has_loot(place), "refill restocks searched spots")
	var first_id: String = place.key + "_trunk"
	loot.open(first_id)
	loot.refill(3, 99)
	check(not loot.open(first_id).is_empty(), "a refilled container can be searched again")
	# Supply crate: spawn, search, save, removed next morning.
	loot.spawn_supply("supply_test", Vector3(10, main.terrain.surface_height(10, 30), 30))
	check(loot.containers.has("supply_test") and loot.prompt("supply_test") == "[E] Search supply crate", "supply crate spawned")
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	main.interact("supply_test")
	check(main.inventory.count_of("nails") >= 8, "supply crates have better loot")
	main.discovered = {}
	main.apply_save_data(data)
	check(loot.supplies.has("supply_test") and not loot.is_opened("supply_test"), "supply crates are saved")
	check(main.discovered.has(place.key), "discovered places are saved")
	loot.open("supply_test")
	loot.remove_empty_supplies()
	check(not loot.supplies.has("supply_test") and not loot.containers.has("supply_test"), "empty supply crates go away in the morning")
	main._on_morning(5)
	main.map_ui.toggle()
	check(main.map_ui.is_open(), "map opens")
	main.inventory.load_data({})
	_test_building()


## Build mode: preview, cost, foundation and wall, overlap, refund, saving.
func _test_building() -> void:
	var bm = main.build_mode
	var b = main.building
	var inv = main.inventory
	var player = main.player
	var terrain = main.terrain
	player.position = Vector3(7, terrain.surface_height(7, 15), 15)
	player.rotation.y = 0.0
	player.head.rotation.x = -0.6
	player.head.position.y = player.EYE_HEIGHT
	inv.load_data({})
	bm.toggle()
	check(bm.active, "B turns build mode on")
	bm.select(0)
	bm.update_preview()
	check(bm.slot.get("kind", "") == "cell" and bm.slot.cz == 6, "preview snaps to the grid cell in front (%s)" % str(bm.slot))
	check(not bm.can_build and bm.reason == "Not enough materials", "no materials, no building")
	inv.add_all({"wood": 20, "nails": 20})
	bm.update_preview()
	check(bm.can_build, "foundation can be built on flat sand (%s)" % bm.reason)
	check(bm.try_place() and inv.count_of("wood") == 16 and inv.count_of("nails") == 16, "building a foundation costs 4 wood and 4 nails")
	var fkey: String = b.slot_key(bm.slot)
	bm.update_preview()
	check(not bm.can_build, "can't build twice in one spot")
	# Wall on the foundation edge.
	bm.select(1)
	bm.update_preview()
	check(bm.slot.kind == "edge", "walls snap to cell edges")
	var wall_slot := {"kind": "edge", "cx": 3, "cz": 6, "dir": 0}
	var ev: Dictionary = b.evaluate("wall", wall_slot)
	check(absf(ev.y - b.pieces[fkey].y) < 0.001, "a wall stands on the foundation")
	b.place("wall", wall_slot, ev.y)
	bm.rotate_piece()
	check(bm.dir == 1, "R turns the wall")
	# The player's own cell is blocked by the player.
	var mine := {"kind": "cell", "cx": 3, "cz": 7, "dir": 0}
	check(b.blocks_person("foundation", mine, b.evaluate("foundation", mine).y, player.position), "can't build on top of yourself")
	check(not b.blocks_person("foundation", {"kind": "cell", "cx": 3, "cz": 5, "dir": 0}, 0.0, player.position), "a cell further away is fine")
	# Save, wipe, load.
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	b.load_data([])
	check(b.pieces.is_empty(), "pieces cleared")
	main.apply_save_data(data)
	check(b.pieces.size() == 2 and b.pieces.has(fkey), "buildings are saved and loaded")
	# Take down the foundation: full refund.
	bm.looking_at_piece = fkey
	check(bm.try_remove() == "foundation" and inv.count_of("wood") == 20, "taking a piece down refunds it")
	_test_more_pieces()
	_test_tiers()
	_test_base()
	_test_melee()
	_test_mutants()
	b.load_data([])
	bm.toggle()
	inv.load_data({})


## v0.9 pieces: doorway gate, window, upper levels and support, stairs.
func _test_more_pieces() -> void:
	var b = main.building
	b.load_data([])
	var f := {"kind": "cell", "cx": 3, "cz": 4, "dir": 0, "level": 0}
	var fy: float = b.evaluate("foundation", f).y
	b.place("foundation", f, fy)
	var edges: Array = b.cell_edges(3, 4, 0)
	var floor_slot := {"kind": "cell", "cx": 3, "cz": 4, "dir": 0, "level": 1}
	check(not b.evaluate("floor", floor_slot).ok, "a floor upstairs needs support")
	b.place("doorway", edges[0], b.evaluate("doorway", edges[0]).y)
	b.place("window", edges[1], b.evaluate("window", edges[1]).y)
	b.place("wall", edges[2], b.evaluate("wall", edges[2]).y)
	var ev: Dictionary = b.evaluate("floor", floor_slot)
	check(ev.ok and absf(ev.y - (fy + b.WALL_H)) < 0.001, "walls hold up a floor one level up")
	b.place("floor", floor_slot, ev.y)
	var up: Dictionary = edges[2].duplicate()
	up.level = 1
	check(b.evaluate("wall", up).ok, "walls stack on walls")
	var roof_next := {"kind": "cell", "cx": 4, "cz": 4, "dir": 0, "level": 1}
	check(b.evaluate("roof", roof_next).ok, "a roof can hang off a floor next to it")
	check(b.level_for("wall", up, fy + 2.3) == 1, "aiming at the floor above picks level 1")
	check(b.pieces[b.slot_key(edges[1])].node.get_children().filter(func(n): return n is CollisionShape3D).size() == 4, "a window wall has a hole in it")
	# Gate.
	var gate_id: String = "gate:" + b.slot_key(edges[0])
	check(main._prompt_for(gate_id) == "[E] Open gate", "gate prompt")
	main.interact(gate_id)
	check(b.pieces[b.slot_key(edges[0])].open, "E opens the gate")
	var data: Array = JSON.parse_string(JSON.stringify(b.save_data()))
	b.load_data(data)
	check(b.pieces[b.slot_key(edges[0])].open and b.pieces.size() == 5, "gate state and upper floors are saved")
	main.interact(gate_id)
	check(not b.pieces[b.slot_key(edges[0])].open, "E closes it again")
	# Stairs take two squares; removing frees both.
	var st := {"kind": "cell", "cx": 6, "cz": 4, "dir": 0, "level": 0}
	var sk: String = b.place("stairs", st, b.evaluate("stairs", st).y)
	check(b.occupied.has(b.cell_key(6, 3, 0)), "stairs take up the square they climb into")
	check(not b.evaluate("floor", {"kind": "cell", "cx": 6, "cz": 3, "dir": 0, "level": 0}).ok, "can't build on top of the stairs")
	b.remove(b.cell_key(6, 3, 0))
	check(not b.occupied.has(b.cell_key(6, 4, 0)) and not b.pieces.has(sk), "taking down stairs frees both squares")
	b.load_data([])


## v0.10: tiers, hit points, cracks, hammer repair/upgrade/demolish, undo.
func _test_tiers() -> void:
	var b = main.building
	var inv = main.inventory
	var was_building: bool = main.build_mode.active
	main.build_mode.active = false
	b.load_data([])
	inv.load_data({})
	var slot := {"kind": "edge", "cx": 3, "cz": 4, "dir": 0, "level": 0}
	var key: String = b.place("wall", slot, b.evaluate("wall", slot).y)
	var rec: Dictionary = b.pieces[key]
	check(rec.tier == 0 and rec.hp == 250.0, "new walls are wood with 250 hp")
	check(b.base_tier("roof") == 1, "roofs start as scrap metal")
	b.damage(key, 100.0)
	check(b.crack_stage(rec) == 1 and rec.cracks.get_child(0).visible, "damage shows cracks")
	check(b.repair_cost(rec) == {"wood": 2}, "repair costs wood by missing hp %s" % str(b.repair_cost(rec)))
	inv.add("hammer", 1)
	inv.selected = 0
	check(main.holding_hammer(), "holding the hammer")
	main.hammer_use(key)
	check(rec.hp == 150.0, "no wood, no repair")
	inv.add_all({"wood": 5, "scrap": 20, "nails": 10, "cement": 10, "stone": 6, "clay": 2})
	main.hammer_use(key)
	check(rec.hp == 250.0 and inv.count_of("wood") == 3, "hammer repairs for 2 wood")
	main.hammer_use(key)
	check(rec.tier == 1 and rec.hp == 600.0 and inv.count_of("scrap") == 16, "hammer upgrades wood to scrap metal (4 scrap)")
	main.hammer_use(key)
	check(rec.tier == 2 and rec.hp == 1000.0 and inv.count_of("stone") == 1 and inv.count_of("clay") == 1, "then scrap metal to stone (5 stone, 1 clay)")
	check(b.describe(rec) == "Stone wall", "a stone wall: " + b.describe(rec))
	main.hammer_use(key)
	check(rec.tier == 3 and rec.hp == 1500.0 and inv.count_of("cement") == 7, "and stone to concrete (3 cement)")
	check(b.upgrade_cost(rec).is_empty(), "concrete is the top tier")
	check(main.hammer_prompt(key).contains("Fully upgraded"), "prompt: " + main.hammer_prompt(key).replace("\n", " | "))
	# Saved with tier and hit points.
	b.damage(key, 400.0)
	var data: Array = JSON.parse_string(JSON.stringify(b.save_data()))
	b.load_data(data)
	rec = b.pieces[key]
	check(rec.tier == 3 and rec.hp == 1100.0, "tier and hit points are saved")
	# Saves from before the stone tier: their concrete (tier 2) stays concrete.
	var old: Array = data.duplicate(true)
	old[0].tier = 2
	b.load_data(old, true)
	check(b.pieces[key].tier == 3, "an older save's concrete wall is still concrete")
	var full: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	check(int(full.get("tiers", 0)) == 4, "saves say how many tiers there are")
	full.erase("tiers")
	full.buildings[0].tier = 1
	main.apply_save_data(full)
	check(b.pieces[key].tier == 1, "older saves keep scrap metal as scrap metal")
	full.buildings[0].tier = 2
	main.apply_save_data(full)
	check(b.pieces[key].tier == 3, "and concrete as concrete")
	rec = b.pieces[key]
	# Too late to undo in build mode; the hammer demolishes for half back.
	rec.built_at -= 61000
	main.build_mode.active = true
	main.build_mode.looking_at_piece = key
	check(main.build_mode.try_remove() == "old", "build-mode undo only right after building")
	main.build_mode.active = false
	var refund: Dictionary = b.refund(rec)
	check(refund == {"wood": 1, "nails": 2, "scrap": 2, "cement": 1, "stone": 2}, "demolish refunds half %s" % str(refund))
	check(not main.hammer_demolish(key) and b.pieces.has(key), "first right click only arms demolish")
	check(main.hammer_demolish(key) and not b.pieces.has(key), "second right click demolishes")
	# Breaking a piece.
	var k2: String = b.place("wall", slot, 0.0)
	var broke := []
	b.piece_destroyed.connect(func(k, t): broke.append(t), CONNECT_ONE_SHOT)
	check(b.damage(k2, 999.0) and broke == ["wall"] and not b.pieces.has(k2), "a piece at 0 hp breaks")
	inv.load_data({})
	b.load_data([])
	main.build_mode.active = was_building


## Ramp: walk up it for real.
var ramp_top := 0.0
var chase_walker: Node
var march_walker: Node
var break_wall := ""
var spit_seen := false
var turret_key := ""
var turret_near: Node
var turret_far: Node
var ramp_base := 0.0
## v0.11: base zone, storage chest, workbench crafting, bandages, spike barricade.
func _test_base() -> void:
	var b = main.building
	var inv = main.inventory
	var ui = main.inventory_ui
	var player = main.player
	var far := {"kind": "cell", "cx": 20, "cz": 0, "dir": 0, "level": 0}
	var ev_far: Dictionary = b.evaluate("foundation", far)
	check(not ev_far.ok and ev_far.reason.begins_with("Outside the base zone"), "can't build outside the base zone (%s)" % ev_far.reason)
	check(b.in_zone("wall", {"kind": "edge", "cx": 3, "cz": 3, "dir": 0, "level": 0}), "near the flag is inside the zone")
	check(main.base_zone.get_child_count() == 3, "zone stakes, rags and edge line exist")
	main.base_zone.set_highlight(true)
	check(main.base_zone.highlighted(), "zone edge lights up in build mode")
	main.base_zone.set_highlight(false)

	# A chest on a foundation.
	var f := {"kind": "cell", "cx": -5, "cz": -5, "dir": 0, "level": 0}
	var fy: float = b.evaluate("foundation", f).y
	b.place("foundation", f, fy)
	var cs := {"kind": "obj", "cx": -5, "cz": -5, "dir": 1, "level": 0}
	var cev: Dictionary = b.evaluate("chest", cs)
	check(cev.ok and is_equal_approx(cev.y, fy), "a chest stands on a foundation (%s)" % cev.reason)
	var ck: String = b.place("chest", cs, cev.y)
	check(not b.evaluate("chest", cs).ok, "one object per square")
	check(b.prompt("chest:" + ck).contains("storage chest"), "chest prompt")
	check(b.upgrade_cost(b.pieces[ck]).is_empty() and b.describe(b.pieces[ck]) == "Storage chest", "chests have no tiers")
	player.position = Vector3(-9, main.terrain.surface_height(-9, -7.5) + 0.7, -7.5)
	main.interact("chest:" + ck)
	check(ui.is_open() and ui.chest == b.storage_of(ck), "E opens the chest screen")
	inv.load_data({})
	inv.add("wood", 10)
	ui.click(0)
	ui.click(3, true)
	check(ui.chest.slots[3].get("item", "") == "wood" and inv.count_of("wood") == 0, "move a stack into the chest")
	inv.add("nails", 5)
	inv.transfer(0, ui.chest)
	check(ui.chest.count_of("nails") == 5 and ui.chest.count_of("wood") == 10, "right-click moves a whole stack across")
	ui.chest.transfer(3, inv)
	check(inv.count_of("wood") == 10 and ui.chest.count_of("wood") == 0, "and back to the pockets")
	ui.chest.add("wood", 7)
	player.position += Vector3(10, 0, 0)
	main._check_station_reach()
	check(not ui.is_open(), "walking away closes the chest")
	var saved: Array = b.save_data()
	b.load_data(saved)
	check(b.storage_of(ck) != null and b.storage_of(ck).count_of("wood") == 7 and b.storage_of(ck).count_of("nails") == 5, "chest contents are saved")
	var drops_before: int = main.loot.drops.size()
	b.remove(ck)
	check(main.loot.drops.size() == drops_before + 1, "a chest taken down spills its contents into a bag")

	# Workbench crafting.
	var ws := {"kind": "obj", "cx": -4, "cz": -5, "dir": 0, "level": 0}
	var wev: Dictionary = b.evaluate("workbench", ws)
	check(wev.ok, "a workbench can stand on the sand (%s)" % wev.reason)
	var wk: String = b.place("workbench", ws, wev.y)
	player.position = Vector3(-7, main.terrain.surface_height(-7, -7.5) + 0.7, -7.5)
	main.interact("bench:" + wk)
	check(ui.is_open() and ui.bench_key == wk, "E opens the workbench")
	inv.load_data({})
	inv.add("cloth", 4)
	ui.craft("spike_barricade")
	check(inv.count_of("spike_barricade") == 0, "no crafting without materials")
	ui.craft("bandage")
	check(inv.count_of("bandage") == 1 and inv.count_of("cloth") == 2, "2 cloth make a bandage")
	inv.add_all({"scrap": 2, "wood": 6, "nails": 4})
	ui.craft("hammer")
	ui.craft("spike_barricade")
	check(inv.count_of("hammer") == 1 and inv.count_of("spike_barricade") == 1 and inv.count_of("wood") == 0, "craft a hammer and a spike barricade")
	ui.close()
	main.survival.health = 50.0
	for i in inv.HOTBAR:
		if inv.slots[i].get("item", "") == "bandage":
			inv.selected = i
	main.use_selected()
	check(is_equal_approx(main.survival.health, 80.0) and inv.count_of("bandage") == 0, "a bandage heals 30")

	# Spike barricade piece: costs the crafted item, comes back whole.
	var ss := {"kind": "obj", "cx": -6, "cz": -5, "dir": 1, "level": 0}
	var sk: String = b.place("spikes", ss, b.evaluate("spikes", ss).y)
	check(b.refund(b.pieces[sk]) == {"spike_barricade": 1}, "demolishing spikes gives the barricade back")
	check(main.hammer_prompt(wk).begins_with("Workbench"), "hammer prompt on a workbench: " + main.hammer_prompt(wk).replace("\n", " | "))
	b.remove(sk)
	b.remove(wk)
	b.remove(b.cell_key(-5, -5, 0))


## v0.12: hands, pipe and machete swings, stamina cost, training dummy.
func _test_melee() -> void:
	var m = main.melee
	var d = main.dummy
	var inv = main.inventory
	var player = main.player
	player.position = Vector3(-3, main.terrain.surface_height(-3, 5.6), 5.6)
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	player.head.position.y = player.EYE_HEIGHT
	inv.load_data({})
	inv.add_all({"pipe": 1, "machete": 1})
	m.set_item("pipe")
	check(m.visible and m.item == "pipe", "hands show the rusty pipe")
	player.stamina = 100.0
	check(m.try_swing() and is_equal_approx(player.stamina, 88.0), "a pipe swing costs 12 stamina")
	check(not m.try_swing(), "no new swing until the last one is done")
	var r: Dictionary = m.strike()
	check(r.kind == "target" and d.hits == 1 and is_equal_approx(d.total_damage, 25.0), "the pipe hits the dummy for 25 (%s)" % r.kind)
	check(d._wobble_vel.length() > 0.5, "the dummy wobbles when hit")
	check(d.get_children().any(func(c): return c is Label3D and c.text == "25"), "the damage floats up over the dummy")
	m.set_item("machete")
	player.stamina = 5.0
	check(not m.try_swing(), "too out of breath to swing")
	player.stamina = 100.0
	check(m.try_swing() and is_equal_approx(player.stamina, 91.0), "a machete swing costs 9 stamina")
	m.strike()
	check(is_equal_approx(d.total_damage, 65.0), "the machete hits for 40")
	player.rotation.y = PI
	check(m.strike().kind == "", "swinging at thin air hits nothing")
	m.set_item("water")
	check(not m.visible, "hands hide with a water bottle")
	m.set_item("hammer")
	check(m.visible and not m.try_swing(), "the hammer is held but not swung as a weapon")
	m.set_item("")
	inv.load_data({})
	inv.add("cloth", 1)
	inv.add("scrap", 3)
	inv.add("wood", 1)
	check(main.Items.craft("machete", inv) != null and inv.count_of("machete") == 1, "the workbench makes a machete")
	inv.load_data({})
	main.apply_save_data(main.collect_save_data())
	check(inv.count_of("pipe") == 1, "older saves get a rusty pipe")


## v0.13: the Walker. Sight, hearing, hits, death, saving, spawning.
func _test_mutants() -> void:
	var ms = main.mutants
	var player = main.player
	check(ms.alive().size() == ms.WANDERERS, "a new game has %d walkers roaming (%d)" % [ms.WANDERERS, ms.alive().size()])
	check(ms.alive().all(func(m): return Vector2(m.position.x, m.position.z).length() >= ms.MIN_BASE_DIST - 0.1), "walkers start far from the base")
	var data: Dictionary = main.collect_save_data()
	ms.clear()
	var py: float = main.terrain.surface_height(8, -8)
	player.position = Vector3(8, py, -8)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	var w = ms.spawn("walker", Vector3(8, 0, -20))
	w.rotation.y = PI  # facing the player (+Z)
	check(w.notices_target(false), "a walker 12 m away sees you in daylight")
	w.rotation.y = 0.0
	check(not w.notices_target(false), "it doesn't see you behind its back")
	w.position = Vector3(8, py, -14)
	check(w.notices_target(false), "but it hears you when you are close")
	player.crouching = true
	check(not w.notices_target(false), "crouching keeps you quiet")
	player.crouching = false
	w.position = Vector3(8, py, -34)
	w.rotation.y = PI
	check(not w.notices_target(false), "26 m away it doesn't notice you")
	check(w.notices_target(false) == false and not w.notices_target(true), "at night it sees less far")
	# Saving.
	ms.clear()
	var a = ms.spawn("walker", Vector3(100, 0, 40), 60.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	ms.clear()
	main.apply_save_data(saved)
	var back: Array = ms.alive()
	check(back.size() == 1 and back[0].position.distance_to(a.position) < 0.2 and is_equal_approx(back[0].health, 60.0), "walkers are saved with position and health")
	saved.erase("mutants")
	main.apply_save_data(saved)
	check(ms.alive().size() == 1, "older saves keep the walkers already there")
	ms.clear()
	check(ms.top_up(2) == ms.WANDERERS and ms.alive().size() == ms.WANDERERS, "each morning the walkers are topped up")
	# Death by walker.
	main.survival.health = 5.0
	main._on_player_hit(12.0, player.global_position + Vector3(0, 0, -2))
	check(main.survival.dead and main.death_screen.is_open(), "a walker can kill you")
	check(main.death_screen._cause.text.contains("walker"), "the death screen says what got you: " + main.death_screen._cause.text)
	main.respawn()
	main.apply_save_data(data)
	ms.clear()


## Melee on the walker that just chased you down.
func _test_walker_hits() -> void:
	var ms = main.mutants
	var player = main.player
	var w = chase_walker
	var py: float = player.position.y
	w.health = 100.0
	player.rotation.y = 0.0
	player.head.rotation.x = -0.1
	# Hits from the pipe.
	main.melee.set_item("pipe")
	player.rotation.y = 0.0  # looking at -Z, at the walker
	var r: Dictionary = main.melee.strike()
	check(r.kind == "target" and r.node == w and is_equal_approx(w.health, 75.0), "the pipe hits a walker for 25 (%s, %.0f)" % [r.kind, w.health])
	check(w.state == w.State.CHASE, "a hit makes it chase you")
	var kills: int = ms.kills
	w.take_hit(80.0, w.global_position, Vector3(0, 0, -1))
	check(w.is_dead() and w.collision_layer == 0 and ms.kills == kills + 1, "at 0 health it dies and stops blocking")
	check(not ms.alive().has(w), "dead walkers don't count as alive")
	w.take_hit(25.0, w.global_position, Vector3(0, 0, -1))
	check(ms.kills == kills + 1, "hitting a corpse does nothing")
	main.melee.set_item("")


## v0.14: siren, wave size, spawning at the edge, clearing, dawn, summary, saving.
func _test_waves() -> void:
	var wv = main.waves
	var ms = main.mutants
	var Waves = load("res://scripts/waves.gd")
	check(Waves.wave_size(1) == 4 and Waves.wave_size(5) == 12 and Waves.wave_size(40) == Waves.MAX_SIZE, "waves grow by 2 each night up to %d" % Waves.MAX_SIZE)
	var got_siren := [false]
	wv.siren.connect(func(): got_siren[0] = true, CONNECT_ONE_SHOT)
	wv.on_dusk(1)
	check(got_siren[0], "the siren sounds at dusk")
	ms.clear()
	main.day_night.restore(main.day_night.day, 21.0)
	var n0: int = wv.wave
	wv.start_wave()
	check(wv.active and wv.wave == n0 + 1 and wv.remaining() == Waves.wave_size(wv.wave), "night starts wave %d with %d mutants" % [wv.wave, wv.remaining()])
	var size: int = wv.remaining()
	for i in 40:
		wv._process(1.0)
	check(wv.to_spawn == 0 and wv.hunters().size() == size, "the whole wave arrives in groups (%d)" % wv.hunters().size())
	check(wv.hunters().all(func(m): return Vector2(m.position.x, m.position.z).length() > 195.0), "they come in from the edge of the map")
	main.hud._process(0.0)
	check(main.hud.clock.text.contains("Wave %d: %d left" % [wv.wave, size]), "the HUD shows the wave counter: " + main.hud.clock.text.replace("\n", " | "))
	# Save in the middle of the night.
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	var ended := []
	wv.wave_ended.connect(func(s): ended.append(s))
	main._on_player_hit(5.0, main.player.global_position)
	for m in wv.hunters():
		m.take_hit(500.0, m.global_position, Vector3.FORWARD)
	wv._process(0.1)
	check(not wv.active and ended.size() == 1 and ended[0].cleared and ended[0].kills == size, "killing them all ends the wave (%s)" % str(ended))
	check(int(ended[0].damage) == 5, "the summary counts damage taken")
	check(main.hud.summary.visible and Waves.summary_lines(ended[0])[0] == "Wave %d cleared!" % wv.wave, "the summary card shows")
	main.apply_save_data(data)
	check(wv.active and wv.hunters().size() == size and wv.wave == n0 + 1, "a wave in progress is saved and loaded")
	wv.on_dawn(3)
	check(not wv.active and wv.hunters().is_empty() and not ended[1].cleared, "dawn ends the wave and the rest crumble")
	check(Waves.summary_lines(ended[1])[0].begins_with("Dawn"), "dawn summary: " + Waves.summary_lines(ended[1])[0])
	check(ms.alive().size() == 0, "crumbled mutants don't count as alive")
	data.erase("waves")
	main.day_night.restore(6, 10.0)
	main.apply_save_data(data)
	main.day_night.restore(6, 10.0)
	check(not wv.active, "older saves load without a wave running")
	main.survival.health = 100.0
	ms.clear()
	march_walker = ms.spawn("walker", Vector3(0, 0, 40))
	march_walker.make_hunter(Vector3.ZERO)
	main.player.position = Vector3(60, main.terrain.surface_height(60, -60), -60)


## v0.15: collapsing upper floors, finding pieces from colliders, spikes biting back.
func _test_breaking() -> void:
	var b = main.building
	var ms = main.mutants
	b.load_data([])
	var w := {"kind": "edge", "cx": 5, "cz": -3, "dir": 0, "level": 0}
	var wk: String = b.place("wall", w, b.evaluate("wall", w).y)
	var f := {"kind": "cell", "cx": 5, "cz": -3, "dir": 0, "level": 1}
	var fev: Dictionary = b.evaluate("floor", f)
	var fk: String = b.place("floor", f, fev.y)
	var f2 := {"kind": "cell", "cx": 6, "cz": -3, "dir": 0, "level": 1}
	var f2k: String = b.place("floor", f2, b.evaluate("floor", f2).y)
	check(fev.ok and b.pieces.has(f2k), "a floor held up by one wall, with an overhang")
	var collapsed := []
	b.piece_collapsed.connect(func(k, _t): collapsed.append(k))
	b.damage(wk, 9999.0)
	check(not b.pieces.has(fk) and not b.pieces.has(f2k) and collapsed.size() == 2, "when the wall breaks the floors above collapse (%d)" % collapsed.size())
	var d := {"kind": "edge", "cx": 5, "cz": -5, "dir": 0, "level": 0}
	var dk: String = b.place("doorway", d, b.evaluate("doorway", d).y)
	var gate_body: Node = b.pieces[dk].hinge.get_child(0)
	check(b.piece_key_of(gate_body) == dk, "a gate counts as part of its doorway")
	var ss := {"kind": "obj", "cx": 7, "cz": -6, "dir": 0, "level": 0}
	var sk: String = b.place("spikes", ss, b.evaluate("spikes", ss).y)
	var m = ms.spawn("walker", Vector3(15, 0, -11))
	m.break_key = sk
	m.state = m.State.BREAK
	for i in 20:
		m._break(0.05)
	check(b.pieces[sk].hp < b.max_hp(b.pieces[sk]) and is_equal_approx(m.health, 100.0 - m.SPIKE_DAMAGE), "clawing at spikes hurts the mutant (%.0f)" % m.health)
	b.remove(sk)
	m._break(0.05)
	check(m.state != m.State.BREAK, "when the piece is gone it moves on")
	# Nobody home: a wave mutant at the base goes for the nearest building.
	var lone := {"kind": "edge", "cx": 1, "cz": 1, "dir": 0, "level": 0}
	var lk: String = b.place("wall", lone, b.evaluate("wall", lone).y)
	var h = ms.spawn("walker", Vector3(6, 0, 4))
	h.make_hunter(Vector3.ZERO)
	check(h._wreck_target(0.1) and h._wreck_key == lk, "a wave mutant at an empty base heads for the nearest wall")
	b.remove(lk)
	ms.clear()
	b.load_data([])


## v0.16: runner, brute and spitter stats, wave mixes, acid arcs, saving types.
func _test_types() -> void:
	var ms = main.mutants
	var T: Dictionary = ms.Mutant.TYPES
	check(T.has("runner") and T.has("brute") and T.has("spitter"), "four mutant types")
	check(T.runner.run > main.player.WALK_SPEED and T.runner.run < main.player.SPRINT_SPEED, "runners outrun your walk but not your sprint")
	check(T.runner.health < T.walker.health and T.brute.health >= 4.0 * T.walker.health, "runners are weak, brutes are tanky")
	check(T.brute.wall_damage >= 4.0 * T.walker.wall_damage and T.brute.run < T.walker.run, "brutes are slow and wreck walls")
	var Waves = load("res://scripts/waves.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var m1: Array = Waves.wave_mix(1, rng)
	check(m1.size() == 4 and m1.all(func(t): return t == "walker"), "night 1 is all walkers")
	check(Waves.wave_mix(2, rng).has("runner"), "runners join on night 2")
	check(Waves.wave_mix(3, rng).has("spitter"), "spitters join on night 3")
	var m4: Array = Waves.wave_mix(4, rng)
	check(m4.has("brute") and m4.size() == Waves.wave_size(4), "brutes join on night 4: " + Waves.mix_text(m4))
	var late: Array = Waves.wave_mix(12, rng)
	check(late.filter(func(t): return t != "walker").size() > late.size() / 3, "later waves are mostly the nasty ones: " + Waves.mix_text(late))
	check(Waves.mix_text(["walker", "walker", "brute"]) == "2 walkers, 1 brute", "wave banner text")
	# The lob lands where it aims.
	var from := Vector3(0, 3, 0)
	var to := Vector3(11, 2, -6)
	var v: Vector3 = ms.Mutant.launch_velocity(from, to, 15.0)
	var p := from
	var best := 99.0
	for i in 240:
		v.y -= 9.8 / 120.0
		p += v / 120.0
		best = minf(best, p.distance_to(to))
	check(best < 0.3, "acid arcs land on target (misses by %.2f m)" % best)
	# Brutes barely flinch.
	ms.clear()
	var b = ms.spawn("brute", Vector3(60, 0, 60))
	var w = ms.spawn("walker", Vector3(64, 0, 60))
	b.take_hit(25.0, b.global_position, Vector3.FORWARD)
	w.take_hit(25.0, w.global_position, Vector3.FORWARD)
	check(b.knock.length() < w.knock.length() * 0.5 and b.stagger_t < w.stagger_t * 0.5, "brutes barely flinch when hit")
	check(b.get_child_count() > 2 and b._shape.shape.radius > w._shape.shape.radius, "brutes are bigger")
	ms.spawn("spitter", Vector3(70, 0, 60))
	ms.spawn("runner", Vector3(74, 0, 60))
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	ms.clear()
	main.apply_save_data(data)
	var kinds: Array = ms.alive().map(func(m): return m.type)
	kinds.sort()
	check(kinds == ["brute", "runner", "spitter", "walker"], "mutant types are saved: " + str(kinds))
	# Wave queue saved.
	main.day_night.restore(main.day_night.day, 21.0)
	main.waves.start_wave()
	var q: Array = main.waves.queue.duplicate()
	data = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	main.waves.end_wave(true)
	main.apply_save_data(data)
	check(main.waves.queue == q and main.waves.active, "the wave's lineup is saved")
	main.waves.end_wave(true)
	main.day_night.restore(main.day_night.day, 10.0)
	main.survival.health = 5.0
	main._on_player_hit(30.0, main.player.global_position, "brute")
	check(main.death_screen._cause.text == "A brute got you.", "death screen names the brute: " + main.death_screen._cause.text)
	main.respawn()
	ms.clear()


## v0.17: the pistol. Crafting, reloading, firing, rate, kick, aiming, noise, saving.
func _test_pistol() -> void:
	var g = main.guns
	var inv = main.inventory
	var player = main.player
	var d = main.dummy
	inv.load_data({})
	inv.add_all({"scrap": 10, "wood": 2, "nails": 6})
	check(main.Items.craft("pistol", inv) != null and inv.count_of("pistol") == 1, "the workbench makes a pistol")
	inv.add_all({"scrap": 2, "nails": 3})
	main.Items.craft("ammo_9mm", inv)
	check(inv.count_of("ammo_9mm") == 8, "and 8 rounds of 9mm")
	inv.selected = inv.slots.find(inv.slots.filter(func(x): return x.get("item", "") == "pistol")[0])
	main._process(0.0)
	check(g.item == "pistol" and g.visible and not main.melee.visible, "holding the pistol shows it in both hands")
	g.mag = {}
	g._cooldown = 0.0
	check(not g.try_fire().fired and g.reload_t < 0.0, "a gun can't fire while it is still coming up")
	g._process(g.RAISE_TIME + 0.01)
	var r: Dictionary = g.try_fire()
	check(not r.fired and g.reload_t >= 0.0, "an empty pistol clicks and starts reloading")
	for i in 16:
		g._process(0.1)
	check(g.loaded("pistol") == 8 and inv.count_of("ammo_9mm") == 0, "reloading takes rounds from your pockets (%d loaded)" % g.loaded("pistol"))
	check(not g.start_reload(), "no reload without spare ammo")
	inv.add("ammo_9mm", 30)
	check(g.start_reload(), "reload with ammo")
	for i in 16:
		g._process(0.1)
	check(g.loaded("pistol") == 12 and inv.count_of("ammo_9mm") == 26, "a full magazine holds 12")
	main.hud._process(0.0)
	check(main.hud.ammo_label.text.begins_with("Pistol  12 / 26"), "the HUD shows the ammo: " + main.hud.ammo_label.text.replace("\n", " | "))
	# Aim at the dummy from 10 m.
	player.position = Vector3(-3, main.terrain.surface_height(-3, 14), 14)
	player.rotation.y = 0.0
	player.head.rotation.x = -0.03
	player.head.position.y = player.EYE_HEIGHT
	g.set_ads(true)
	for i in 5:
		g._process(0.1)
	check(g.ads_amount > 0.99 and player.camera.fov < root.get_node("Settings").fov * 0.8, "aiming down the sights zooms in (fov %.0f)" % player.camera.fov)
	var before: float = d.total_damage
	var pitch: float = player.head.rotation.x
	var shots := 0
	for i in 3:
		r = g.try_fire()
		g._cooldown = 0.0
		player.head.rotation.x = -0.03
		player.rotation.y = 0.0
		shots += 1 if r.kind == "target" else 0
	check(shots == 3 and is_equal_approx(d.total_damage - before, 34.0 * 3), "aimed shots hit the dummy at 10 m for 34 each (%d hits, %.0f)" % [shots, d.total_damage - before])
	check(g.loaded("pistol") == 9, "each shot uses a round")
	g.try_fire()
	check(player.head.rotation.x > -0.03 + 0.02, "each shot kicks the view up")
	check(not g.try_fire().fired, "one shot at a time (rate limit)")
	g._process(0.25)
	g.set_ads(false)
	# A shot brings a wandering walker running.
	var ms = main.mutants
	ms.clear()
	var w = ms.spawn("walker", player.position + Vector3(25, 0, 10))
	w.rotation.y = atan2(-1, 0)  # looking away
	check(w.state == w.State.WANDER, "the walker is minding its own business")
	g.try_fire()
	check(w.state == w.State.CHASE, "a gunshot 27 m away brings it running")
	ms.clear()
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	g.mag = {}
	main.apply_save_data(data)
	check(g.loaded("pistol") == 7, "rounds in the magazine are saved (%d)" % g.loaded("pistol"))
	inv.load_data({})
	main._process(0.0)
	check(g.item == "" and not g.visible, "putting the pistol away hides it")
	for i in 5:
		g._process(0.1)
	check(is_equal_approx(player.camera.fov, root.get_node("Settings").fov), "the view zooms back out")


## v0.18: shotgun pellets, rifle scope, headshots, switching, new ammo.
func _test_long_guns() -> void:
	var g = main.guns
	var inv = main.inventory
	var player = main.player
	var d = main.dummy
	var Items = main.Items
	inv.load_data({})
	inv.add_all({"scrap": 40, "wood": 10, "nails": 30, "cloth": 4})
	for id in ["shotgun", "shells", "rifle", "ammo_762"]:
		Items.craft(id, inv)
	check(inv.count_of("shotgun") == 1 and inv.count_of("rifle") == 1 and inv.count_of("shells") == 6 and inv.count_of("ammo_762") == 5, "the workbench makes a shotgun, a rifle and their ammo")
	main.inventory_ui.open_bench("x")
	check(main.inventory_ui._recipe_buttons.size() == Items.RECIPES.size(), "all %d recipes are on the workbench" % Items.RECIPES.size())
	main.inventory_ui.close()
	# Headshot with the rifle on a walker 14 m away.
	var w = chase_walker
	g.set_item("rifle")
	check(g.raise_t > 0.0 and not g.try_fire().fired, "switching weapons takes a moment")
	g._process(g.RAISE_TIME + 0.01)
	g.mag["rifle"] = 5
	g.set_ads(true)
	for i in 5:
		g._process(0.1)
	main.hud._update_ammo()
	check(main.hud.scope.visible and not g._models.rifle.visible, "the rifle scope fills the view when aiming")
	check(player.camera.fov < root.get_node("Settings").fov * 0.4, "and zooms in a lot (fov %.0f)" % player.camera.fov)
	var head: Vector3 = w.global_position + Vector3(0, 1.68, 0)
	var eye: Vector3 = player.camera.global_position
	var to := head - eye
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.rotation.y = atan2(-to.x, -to.z)
	var r: Dictionary = g.try_fire()
	check(r.kind == "head" and w.is_dead(), "a rifle headshot kills a walker outright (%s, %.0f damage)" % [r.kind, r.get("damage", 0.0)])
	check(is_equal_approx(r.get("damage", 0.0), g.GUNS.rifle.damage * g.HEADSHOT), "headshots do double damage")
	g.set_ads(false)
	main.mutants.clear()
	# Shotgun on the dummy: close up most pellets hit, far away few do.
	g._rng.seed = 42
	g.set_item("shotgun")
	g._process(g.RAISE_TIME + 0.01)
	var totals: Array = []
	for dist in [4.0, 26.0]:
		player.position = Vector3(-3, main.terrain.surface_height(-3, 4 + dist), 4 + dist)
		var aim: Vector3 = d.global_position + Vector3(0, 1.3, 0) - (player.position + Vector3(0, player.EYE_HEIGHT, 0))
		player.rotation.y = 0.0
		player.head.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
		var sum := 0.0
		for i in 4:
			g.mag["shotgun"] = 6
			g._cooldown = 0.0
			var hits_before: int = d.hits
			var before: float = d.total_damage
			g.try_fire()
			sum += d.total_damage - before
			if i == 0 and dist < 5.0:
				check(d.hits == hits_before + 1, "pellets on one target add up to a single hit")
		totals.append(sum)
	check(totals[0] > 13.0 * 4 * 2 and totals[0] > totals[1] * 2.0, "the shotgun is deadly close up and weak far away (%.0f vs %.0f)" % [totals[0], totals[1]])
	check(g.loaded("shotgun") == 5, "each blast uses one shell")
	g.set_item("")


## v0.19: spike strip, barbed wire and landmine.
func _test_traps() -> void:
	var b = main.building
	var ms = main.mutants
	var tr = main.traps
	var player = main.player
	b.load_data([])
	ms.clear()
	var keys := {}
	var cx := 3
	for t in ["spike_strip", "barbed_wire", "landmine"]:
		var slot := {"kind": "obj", "cx": cx, "cz": -8, "dir": 0, "level": 0}
		var ev: Dictionary = b.evaluate(t, slot)
		check(ev.ok, "a %s can be built on the sand (%s)" % [t, ev.reason])
		keys[t] = b.place(t, slot, ev.y)
		cx += 3
	check(b.pieces[keys.spike_strip].node.collision_layer == b.TRAP_LAYER, "traps don't block you or the mutants")
	# Spike strip.
	var strip: Vector3 = b.pieces[keys.spike_strip].node.global_position
	var w = ms.spawn("walker", strip)
	w.global_position = strip
	tr.tick(0.1)
	check(is_equal_approx(w.health, 100.0 - tr.STRIP_DAMAGE) and w.slow_mult < 1.0, "a spike strip bites a mutant walking over it (%.0f)" % w.health)
	check(b.pieces[keys.spike_strip].hp < b.max_hp(b.pieces[keys.spike_strip]), "and wears down")
	tr.tick(0.1)
	check(is_equal_approx(w.health, 100.0 - tr.STRIP_DAMAGE), "but not every tick")
	# Barbed wire.
	w.global_position = b.pieces[keys.barbed_wire].node.global_position
	w.slow_mult = 1.0
	var hp: float = w.health
	for i in 10:
		tr.tick(0.1)
	check(w.slow_mult <= tr.WIRE_SLOW + 0.01 and hp - w.health > 3.0, "barbed wire slows a mutant and cuts it (%.1f damage)" % (hp - w.health))
	var py: float = main.terrain.surface_height(-20, 20)
	player.position = Vector3(-20, py, 20)
	# Landmine: a walker on it, another 3.5 m away, a brute close by.
	var mine: Vector3 = b.pieces[keys.landmine].node.global_position
	w.global_position = mine
	w.health = 100.0
	var w2 = ms.spawn("walker", mine)
	w2.global_position = mine + Vector3(3.5, 0, 0)
	var br = ms.spawn("brute", mine)
	br.global_position = mine + Vector3(0, 0, 1.5)
	var booms := []
	tr.exploded.connect(func(p): booms.append(p), CONNECT_ONE_SHOT)
	tr.tick(0.1)
	check(booms.is_empty() and b.pieces.has(keys.landmine), "a mine beeps and waits a moment")
	tr._physics_process(0.3)
	check(booms.size() == 1 and not b.pieces.has(keys.landmine), "then it goes off and is gone")
	check(w.is_dead(), "the walker on it is blown apart")
	check(not w2.is_dead() and w2.health < 100.0, "one 3.5 m away is hurt (%.0f left)" % w2.health)
	check(not br.is_dead() and br.health < br.stats.health, "a brute survives a mine (%.0f left)" % br.health)
	check(main.survival.health >= 100.0, "you were far enough away")
	# A mine next to you hurts.
	var slot := {"kind": "obj", "cx": -10, "cz": 9, "dir": 0, "level": 0}
	var mk: String = b.place("landmine", slot, b.evaluate("landmine", slot).y)
	player.position = b.pieces[mk].node.global_position + Vector3(2, 0, 0)
	main.survival.health = 100.0
	tr.detonate(mk)
	check(main.survival.health < 100.0 and main.survival.cause.contains("landmine"), "standing next to a mine when it blows hurts (%.0f)" % main.survival.health)
	# Wearing out.
	ms.clear()
	var w3 = ms.spawn("brute", strip)
	w3.global_position = strip
	for i in 30:
		tr._bites.clear()
		tr.tick(0.1)
	check(not b.pieces.has(keys.spike_strip), "a spike strip wears out after enough bites")
	ms.clear()
	b.load_data([])
	main.survival.health = 100.0


## v0.20: generator fuel, power range, floodlights, electric fence, fire pit.
func _test_power() -> void:
	var b = main.building
	var ms = main.mutants
	var pw = main.power
	var tr = main.traps
	var inv = main.inventory
	b.load_data([])
	ms.clear()
	inv.load_data({})
	var place := func(t: String, slot: Dictionary) -> String:
		var ev: Dictionary = b.evaluate(t, slot)
		check(ev.ok, "a %s can be built (%s)" % [t, ev.reason])
		return b.place(t, slot, ev.y)
	var gk: String = place.call("generator", {"kind": "obj", "cx": 2, "cz": 2, "dir": 0, "level": 0})
	var near: String = place.call("floodlight", {"kind": "obj", "cx": 5, "cz": 2, "dir": 0, "level": 0})
	var far: String = place.call("floodlight", {"kind": "obj", "cx": -9, "cz": -4, "dir": 0, "level": 0})
	var fk: String = place.call("electric_fence", {"kind": "edge", "cx": 3, "cz": 5, "dir": 0, "level": 0})
	var pk: String = place.call("fire_pit", {"kind": "obj", "cx": -3, "cz": 6, "dir": 0, "level": 0})
	check(not pw.add_fuel(gk, inv), "no fuel cans, no fuel")
	inv.add("fuel", 12)
	for i in 12:
		pw.add_fuel(gk, inv)
	check(is_equal_approx(b.pieces[gk].fuel, b.GEN_TANK) and inv.count_of("fuel") == 2, "the tank takes %d cans" % int(b.GEN_TANK))
	check(main._prompt_for("gen:" + gk).contains("10/10 cans"), "generator prompt: " + main._prompt_for("gen:" + gk))
	main.day_night.restore(main.day_night.day, 12.0)
	pw.tick(0.25)
	check(not b.pieces[gk].running and not b.pieces[near].powered, "by day the generator stays off")
	# Power goes by cable (v1.8).
	check(b.connect_cable(gk, near) and b.connect_cable(gk, fk), "cables from the generator to a floodlight and the fence")
	main.day_night.restore(main.day_night.day, 22.0)
	pw.tick(0.25)
	check(b.pieces[gk].running and b.pieces[near].powered and b.pieces[near].light.visible, "at night it runs and a floodlight cabled to it lights up")
	check(not b.pieces[far].powered, "a floodlight %d m away without a cable stays dark" % int(b.pieces[far].node.global_position.distance_to(b.pieces[gk].node.global_position)))
	check(b.pieces[fk].powered, "the electric fence is live")
	var before: float = b.pieces[gk].fuel
	pw.tick(pw.FUEL_SECONDS)
	check(is_equal_approx(before - b.pieces[gk].fuel, 1.0), "a can lasts %d seconds" % int(pw.FUEL_SECONDS))
	# Shock a walker against the fence.
	var fpos: Vector3 = b.pieces[fk].node.global_position
	var w = ms.spawn("walker", fpos)
	w.global_position = fpos + Vector3(0, 0, -0.5)
	tr.tick(0.1)
	check(is_equal_approx(w.health, 100.0 - tr.SHOCK_DAMAGE), "a live fence shocks a mutant touching it (%.0f)" % w.health)
	# Run dry.
	b.pieces[gk].fuel = 0.01
	pw.tick(1.0)
	check(not b.pieces[gk].running and not b.pieces[near].powered and not b.pieces[fk].powered, "out of fuel, the power goes off")
	tr._bites.clear()
	var hp: float = w.health
	tr.tick(0.1)
	check(is_equal_approx(w.health, hp), "a dead fence doesn't shock")
	# Fire pit.
	check(main._prompt_for("fire:" + pk) == "[E] Light the fire (1 wood)", "fire pit prompt")
	inv.add("wood", 2)
	main.interact("fire:" + pk)
	check(b.pieces[pk].burn > 0.0 and b.pieces[pk].flame.visible and inv.count_of("wood") == 1, "a piece of wood lights the fire")
	w.global_position = b.pieces[pk].node.global_position
	hp = w.health
	for i in 10:
		tr.tick(0.1)
	check(w.health < hp - 10.0, "mutants walking through the fire get burned (%.0f)" % (hp - w.health))
	b.pieces[gk].fuel = 3.5
	var data: Array = b.save_data()
	b.load_data(data)
	check(is_equal_approx(b.pieces[gk].fuel, 3.5) and b.pieces[pk].burn > 50.0, "fuel and fire are saved")
	pw.tick(61.0)
	check(not b.pieces[pk].flame.visible, "the fire burns out")
	main.day_night.restore(main.day_night.day, 10.0)
	ms.clear()
	b.load_data([])


## v0.21: a turret with a range circle while placing, loading and a real fight.
func _start_turret() -> void:
	var b = main.building
	var bm = main.build_mode
	var inv = main.inventory
	b.load_data([])
	main.mutants.clear()
	inv.load_data({})
	inv.add_all({"scrap": 18, "nails": 10, "wood": 2, "ammo_9mm": 30})
	var player = main.player
	player.position = Vector3(-3, main.terrain.surface_height(-3, -10), -10)
	player.rotation.y = PI
	player.head.rotation.x = -0.5
	bm.active = true
	bm.select(b.ORDER.find("turret"))
	bm.update_preview()
	check(bm.range_ring.visible, "placing a turret shows its range circle")
	var t0: Vector3 = bm.ring_points[0]
	var c: Vector3 = bm._ghost.global_position
	check(absf(Vector2(t0.x - c.x, t0.z - c.z).length() - b.TURRET_RANGE) < 0.1, "the circle is %d m round the turret" % int(b.TURRET_RANGE))
	bm.toggle()
	check(not bm.range_ring.visible, "and hides when you stop building")
	var slot := {"kind": "obj", "cx": -2, "cz": -8, "dir": 0, "level": 0}
	turret_key = b.place("turret", slot, b.evaluate("turret", slot).y)
	check(main._prompt_for("turret:" + turret_key).contains("0/%d rounds, EMPTY" % b.TURRET_AMMO), "turret prompt: " + main._prompt_for("turret:" + turret_key))
	main.interact("turret:" + turret_key)
	check(b.pieces[turret_key].ammo == 30 and inv.count_of("ammo_9mm") == 0, "E loads your 9mm rounds into it")
	var data: Array = b.save_data()
	b.load_data(data)
	turret_key = b.slot_key(slot)
	check(b.pieces[turret_key].ammo == 30, "its rounds are saved")
	var tp: Vector3 = b.pieces[turret_key].node.global_position
	turret_near = main.mutants.spawn("walker", tp + Vector3(4, 0, -11))
	turret_near.set_physics_process(false)
	turret_far = main.mutants.spawn("walker", tp + Vector3(-10, 0, 28))
	turret_far.set_physics_process(false)
	player.position = Vector3(20, main.terrain.surface_height(20, 20), 20)


## v0.22: cash per wave and the shop terminal.
func _test_shop() -> void:
	var sh = main.shop
	var ui = main.shop_ui
	var inv = main.inventory
	var Waves = load("res://scripts/waves.gd")
	sh.cash = sh.START_CASH
	check(main._prompt_for("shop") == "[E] Use the shop terminal   ($%d)" % sh.START_CASH, "the terminal by the flag: " + main._prompt_for("shop"))
	main.interact("shop")
	check(ui.is_open() and ui._cash.text == "Cash: $%d" % sh.START_CASH, "E opens the shop with your cash")
	var water: int = sh.CATALOG.map(func(e): return e.name).find("3 water bottles")
	var rifle: int = sh.CATALOG.map(func(e): return e.name).find("Hunting rifle")
	check(ui._buttons[rifle].disabled and not ui._buttons[water].disabled, "things you can't afford are greyed out")
	inv.load_data({})
	ui.buy(water)
	check(inv.count_of("water") == 3 and sh.cash == sh.START_CASH - 15, "buying 3 water bottles for $15")
	check(sh.buy(rifle, inv) == null and inv.count_of("rifle") == 0, "no rifle without $380")
	ui.close()
	check(not ui.is_open(), "the shop closes")
	# Cash for a night.
	var c: Dictionary = Waves.cash_for({"wave": 3, "bounty": 50, "pieces": 10, "lost": 2, "cleared": false})
	check(c.cash == 50 + 55 + 48 and c.cash_base == 48, "a night pays kills + survival + base condition ($%d)" % c.cash)
	check(Waves.cash_for({"wave": 3, "bounty": 50, "pieces": 10, "lost": 2, "cleared": true}).cash == int(round(153 * 1.25)), "clearing the whole wave pays a quarter more")
	check(Waves.cash_for({"wave": 1, "bounty": 0, "pieces": 0, "lost": 0, "cleared": false}).cash == 35, "even with no base, surviving pays")
	# A real (short) wave.
	var wv = main.waves
	main.mutants.clear()
	main.day_night.restore(main.day_night.day, 21.0)
	wv.start_wave()
	for i in 40:
		wv._process(1.0)
	var size: int = wv.hunters().size()
	var bounty := 0
	for m in wv.hunters():
		bounty += wv.BOUNTY[m.type]
		m.take_hit(9999.0, m.global_position, Vector3.FORWARD)
	var before: int = sh.cash
	var ended := []
	wv.wave_ended.connect(func(s): ended.append(s), CONNECT_ONE_SHOT)
	wv._process(0.1)
	check(ended.size() == 1 and ended[0].cash_kills == bounty and sh.cash == before + ended[0].cash, "clearing wave %d (%d mutants) pays $%d" % [wv.wave, size, ended[0].get("cash", 0)])
	check(Waves.summary_lines(ended[0])[-1] == "Cash earned: $%d" % ended[0].cash, "the summary shows the cash")
	main.hud._process(0.0)
	check(main.hud.clock.text.begins_with("$%d" % sh.cash), "the HUD shows your cash: " + main.hud.clock.text.split("\n")[0])
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	var cash: int = sh.cash
	sh.cash = 0
	main.apply_save_data(data)
	check(sh.cash == cash, "cash is saved")
	data.erase("shop")
	main.apply_save_data(data)
	check(sh.cash == sh.START_CASH + 40 * wv.wave, "older saves get pay for the nights already survived")
	main.day_night.restore(main.day_night.day, 10.0)
	inv.load_data({})


## v0.23: landing pad, drone orders and flights, blueprints unlocking builds.
func _test_drone() -> void:
	var sh = main.shop
	var dr = main.drone
	var b = main.building
	var bm = main.build_mode
	var ui = main.shop_ui
	b.load_data([])
	main.loot.load_data({})
	sh.unlocked = {}
	sh.cash = 1000
	dr.load_data({})
	check(not sh.is_unlocked("turret", b.PIECES) and sh.is_unlocked("wall", b.PIECES), "turrets need a blueprint, walls don't")
	var player = main.player
	player.position = Vector3(-3, main.terrain.surface_height(-3, -10), -10)
	player.rotation.y = PI
	player.head.rotation.x = -0.5
	main.inventory.load_data({})
	main.inventory.add_all({"scrap": 40, "nails": 20, "wood": 6})
	bm.active = true
	bm.select(b.ORDER.find("turret"))
	bm.update_preview()
	check(not bm.can_build and bm.reason.begins_with("Locked"), "a locked piece can't be built: " + bm.reason)
	bm.toggle()
	var bp: int = sh.DRONE.map(func(e): return e.name).find("Blueprint: Auto-turret")
	var wood: int = sh.DRONE.map(func(e): return e.name).find("40 wood")
	check(not sh.can_order(bp), "no drone orders without a landing pad")
	var slot := {"kind": "obj", "cx": 6, "cz": 6, "dir": 0, "level": 0}
	var ev: Dictionary = b.evaluate("landing_pad", slot)
	check(ev.ok, "a landing pad can be built (%s)" % ev.reason)
	b.place("landing_pad", slot, ev.y)
	ui.open()
	ui.show_page(true)
	check(not ui.drone_buttons[bp].disabled and ui._drone_note.text.begins_with("Orders are flown"), "with a pad the drone page opens up")
	ui.order(bp)
	check(sh.cash == 850 and sh.blueprint_owned("bp_turret") and not sh.can_order(bp), "ordering a blueprint ($150), only once")
	ui.order(wood)
	ui.close()
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	# Fly it for real (in big steps).
	var got := []
	dr.delivered.connect(func(items, pos): got.append(items.duplicate()), CONNECT_ONE_SHOT)
	var t := 0.0
	dr._process(0.1)
	check(dr.phase == "in", "the drone takes off with both orders")
	while dr.phase != "idle" and t < 60.0:
		dr._process(0.1)
		t += 0.1
	check(got.size() == 1 and got[0].has("wood"), "it arrives and lowers a parcel (%.0f s)" % t)
	check(sh.unlocked.has("turret"), "the blueprint is learned on delivery")
	check(main.loot.drops.size() == 1 and main.loot.drops.values()[0].items.get("wood", 0) == 40, "the wood is in a bag on the pad")
	check(sh.is_unlocked("turret", b.PIECES), "now turrets can be built")
	# A parcel still in the air is saved.
	main.loot.load_data({})
	main.apply_save_data(data)
	check(dr.orders.size() == 2 and not sh.unlocked.has("turret"), "orders not yet delivered are saved")
	dr.finish_now()
	check(sh.unlocked.has("turret") and main.loot.drops.size() == 1, "and delivered after loading")
	data.erase("shop")
	main.apply_save_data(data)
	check(sh.unlocked.has("sandbags") and sh.unlocked.has("electric_fence"), "older saves keep every build")
	var sb := {"kind": "edge", "cx": 4, "cz": 6, "dir": 0, "level": 0}
	var sk: String = b.place("sandbags", sb, b.evaluate("sandbags", sb).y)
	check(b.max_hp(b.pieces[sk]) == 900.0, "a sandbag wall has 900 hit points")
	b.load_data([])
	main.loot.load_data({})
	dr.load_data({})
	main.inventory.load_data({})


## Feedback (v1.14): the workbench and chest screens fit a 1280x720 window,
## and the recipes (or chest slots) scroll when there isn't room for them all.
func _test_screen_fit() -> void:
	var ui = main.inventory_ui
	var Items = main.Items
	ui.close()
	ui.window_height_override = 720.0
	ui.open_bench("x")
	check(ui.panel_height() <= 720.0, "the workbench screen fits a 720 px window (%d px)" % ui.panel_height())
	check(not ui.list_fits() and ui._help.text.contains("scrolls the recipes"), "the recipes scroll there, and the help line says so")
	var inside := 0
	for id in ui._recipe_buttons:
		if ui._recipe_scroll.is_ancestor_of(ui._recipe_buttons[id]):
			inside += 1
	check(inside == Items.RECIPES.size(), "every recipe is in the scroll list (%d)" % inside)
	ui.close()
	ui.window_height_override = 1200.0
	ui.open_bench("x")
	check(ui.list_fits() and not ui._help.text.contains("scrolls"), "a tall window shows every recipe without scrolling")
	ui.close()
	ui.window_height_override = 720.0
	var Inventory = load("res://scripts/inventory.gd")
	var big = Inventory.new(ui.MAX_CHEST)
	big.add_all({"ammo_9mm": 90, "shells": 20, "cement": 4})  # wrapped three-line labels
	ui.open_chest("x", big)
	check(ui.panel_height() <= 720.0, "the biggest chest screen fits a 720 px window too (%d px)" % ui.panel_height())
	ui.close()
	ui.open()
	check(ui.panel_height() <= 720.0, "the plain inventory fits as well")
	ui.close()
	ui.window_height_override = 0.0


## v0.24: base upgrades (zone, storage, workbench tiers, radio) and medkits.
func _test_upgrades() -> void:
	var sh = main.shop
	var b = main.building
	var ui = main.inventory_ui
	var inv = main.inventory
	var Items = main.Items
	main.apply_save_data(JSON.parse_string(JSON.stringify(main.collect_save_data())))
	for id in sh.upgrades:
		sh.upgrades[id] = 0
	main.apply_upgrades()
	sh.cash = 3000
	b.load_data([])
	inv.load_data({})
	inv.add_all({"scrap": 30, "wood": 10, "nails": 20, "cloth": 4})
	ui.open_bench("x")
	check(ui._recipe_buttons.shotgun.disabled and ui._recipe_buttons.shotgun.text.contains("tier 2"), "a new workbench can't make a shotgun yet")
	ui.craft("shotgun")
	check(inv.count_of("shotgun") == 0, "no shotgun from a tier 1 bench")
	ui.close()
	check(sh.buy_upgrade("bench") and ui.bench_tier == 2 and sh.cash == 2800, "workbench tier 2 for $200")
	ui.open_bench("x")
	ui.craft("shotgun")
	check(inv.count_of("shotgun") == 1, "now it makes a shotgun")
	check(ui._recipe_buttons.rifle.disabled, "the rifle needs tier 3")
	ui.close()
	# Zone.
	var far := {"kind": "cell", "cx": 14, "cz": 0, "dir": 0, "level": 0}
	check(not b.in_zone("foundation", far), "29 m out is outside the starting zone")
	sh.buy_upgrade("zone")
	check(b.zone_radius == 34.0 and b.in_zone("foundation", far) and main.base_zone.radius == 34.0, "a bigger zone: 34 m")
	check(main.base_zone.get_child_count() == 3, "the stakes moved out")
	sh.buy_upgrade("zone")
	check(b.zone_radius == 42.0 and sh.next_level("zone").is_empty() and not sh.can_upgrade("zone"), "42 m is the biggest")
	# Storage.
	var cs := {"kind": "obj", "cx": -5, "cz": 5, "dir": 0, "level": 0}
	var ck: String = b.place("chest", cs, b.evaluate("chest", cs).y)
	check(b.storage_of(ck).slots.size() == 20, "chests start with 20 slots")
	sh.buy_upgrade("storage")
	check(b.storage_of(ck).slots.size() == 30, "a storage upgrade grows every chest to 30")
	b.storage_of(ck).slots[27] = {"item": "wood", "count": 5}
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	main.apply_save_data(data)
	check(b.storage_of(ck).count_of("wood") == 5 and sh.upgrades.storage == 1 and b.zone_radius == 42.0, "upgrades and big chests are saved")
	main.interact("chest:" + ck)
	check(ui._chest_buttons[29].visible and not ui._chest_buttons[30].visible, "the chest screen shows 30 slots")
	ui.close()
	# Radio.
	var wv = main.waves
	sh.buy_upgrade("radio")
	check(sh._radio.visible, "a radio sits on the terminal")
	main.hud.banner.text = ""
	wv.on_dusk(1)
	var preview: Array = wv.preview_next()
	check(main.hud.banner.text.begins_with("Radio: wave %d tonight" % (wv.wave + 1)), "at dusk the radio says what is coming: " + main.hud.banner.text)
	main.day_night.restore(main.day_night.day, 21.0)
	wv.start_wave()
	check(wv.queue == preview, "and it is right")
	wv.end_wave(true)
	main.mutants.clear()
	main.day_night.restore(main.day_night.day, 10.0)
	# Medkit.
	inv.load_data({})
	inv.add("medkit", 1)
	main.survival.health = 20.0
	inv.selected = 0
	main.use_selected()
	check(is_equal_approx(main.survival.health, 90.0), "a medkit heals 70")
	data.shop.erase("upgrades")
	main.apply_save_data(data)
	check(ui.bench_tier == 3, "older saves keep every recipe (tier 3 bench)")
	b.load_data([])
	inv.load_data({})


## v1.0: difficulty levels and first-time hints.
func _test_difficulty_and_hints() -> void:
	var Waves = load("res://scripts/waves.gd")
	var rng := RandomNumberGenerator.new()
	check(game.difficulty == "normal" and game.diff("waves") == 1.0, "the default difficulty is normal")
	check(Waves.wave_mix(5, rng, game.DIFFICULTIES.hard.waves).size() == 17 and Waves.wave_mix(5, rng, game.DIFFICULTIES.easy.waves).size() == 8, "hard waves are bigger, easy ones smaller (night 5: 17 / 12 / 8)")
	game.difficulty = "easy"
	main.survival.health = 100.0
	main._on_player_hit(10.0, main.player.global_position)
	check(is_equal_approx(main.survival.health, 94.0), "on easy a 10 damage claw does 6")
	check(game.save_game("test") and game.read_slot("test").get("difficulty", "") == "easy", "the difficulty is saved with the game")
	game.delete_slot("test")
	game.difficulty = "normal"
	main.survival.health = 100.0
	var s = root.get_node("Settings")
	var was: bool = s.hints
	s.hints = true
	s.hints_seen = []
	main.hud._hint_queue.clear()
	main.hud._hint_time = 0.0
	check(main.hints.show_hint("gun") and main.hud.hint_box.visible and main.hud._hint_label.text.contains("reload"), "a first-time hint shows: " + main.hud._hint_label.text)
	check(not main.hints.show_hint("gun"), "only the first time")
	main.hud._hint_time = 0.0
	main.hints.show_hint("build")
	main.hints.show_hint("hammer")
	check(main.hud._hint_queue.size() == 1, "hints wait their turn (%s)" % str(main.hud._hint_queue))
	s.hints = false
	check(not main.hints.show_hint("mutant"), "no hints when they are turned off")
	s.hints = was
	s.hints_seen = []
	s.save_settings()
	# The temporary test box.
	if main.TEST_BOX:
		main.shop.cash = 0
		main.interact("testbox")
		check(main.inventory_ui.is_open() and main.test_storage.count_of("rifle") == 1 and main.test_storage.count_of("wood") == 20, "the test box holds a stack of every item")
		check(main.shop.cash == main.TEST_CASH, "and tops the cash up to $%d" % main.TEST_CASH)
		main.test_storage.transfer(0, main.inventory)
		main._check_station_reach()
		check(main.inventory_ui.is_open(), "it doesn't close by itself")
		main.inventory_ui.close()
		main.inventory.load_data({})
	# Controls page in the pause menu.
	main.pause_menu.open()
	main.pause_menu.show_page("controls")
	check(main.pause_menu._col.get_child(1) is GridContainer and main.pause_menu._col.get_child(1).get_child_count() == main.pause_menu.CONTROLS.size() * 2, "the pause menu lists the controls")
	main.pause_menu.resume()
	# Graphics quality.
	var q: int = s.quality
	s.set_value("quality", 0)
	check(not main.sun.shadow_enabled and main.player.camera.far < 500.0 and main.get_viewport().scaling_3d_scale < 1.0, "low quality: no sun shadows, shorter view, lower render scale")
	s.set_value("quality", 2)
	check(main.sun.shadow_enabled and main.player.camera.far == 900.0 and main.get_viewport().msaa_3d == Viewport.MSAA_2X, "high quality: shadows, full view, anti-aliasing")
	s.set_value("quality", q)


func _start_spitter() -> void:
	var player = main.player
	var py: float = main.terrain.surface_height(8, -8)
	player.position = Vector3(8, py, -8)
	player.velocity = Vector3.ZERO
	main.survival.health = 100.0
	chase_walker = main.mutants.spawn("spitter", Vector3(8, 0, -21))
	chase_walker.make_hunter(Vector3.ZERO)
	chase_walker.rotation.y = PI


## A wave mutant smells you behind a wall and breaks through it. You are shut
## in a 2 x 2 m box (since v1.10 they walk round a lone wall); the wall facing
## it is the weak one, so that is the way in.
func _start_break_in() -> void:
	var b = main.building
	var player = main.player
	var slot := {"kind": "edge", "cx": 0, "cz": -2, "dir": 0, "level": 0}
	break_wall = b.place("wall", slot, b.evaluate("wall", slot).y, false, 0, 60.0)
	for e in b.cell_edges(0, -2, 0):
		if b.slot_key(e) != break_wall:
			b.place("wall", e, b.evaluate("wall", e).y)
	player.position = Vector3(1, main.terrain.surface_height(1, -3.45), -3.45)
	player.velocity = Vector3.ZERO
	main.survival.health = 100.0
	chase_walker = main.mutants.spawn("walker", Vector3(1, 0, -12))
	chase_walker.make_hunter(Vector3.ZERO)
	chase_walker.rotation.y = PI


## Real chase over many frames: it walks up to the player and claws.
func _start_chase() -> void:
	var ms = main.mutants
	var player = main.player
	main.day_night.restore(main.day_night.day, 10.0)
	var py: float = main.terrain.surface_height(8, -8)
	player.position = Vector3(8, py, -8)
	player.velocity = Vector3.ZERO
	main.survival.health = 100.0
	chase_walker = ms.spawn("walker", Vector3(8, 0, -20))
	chase_walker.rotation.y = PI


func _start_ramp_walk() -> void:
	var b = main.building
	var player = main.player
	var slot := {"kind": "cell", "cx": 3, "cz": 4, "dir": 0, "level": 0}
	var ev: Dictionary = b.evaluate("ramp", slot)
	check(ev.ok, "ramp fits on the sand (%s)" % ev.reason)
	b.place("ramp", slot, ev.y)
	ramp_base = ev.y
	ramp_top = -INF
	player.position = Vector3(7, main.terrain.surface_height(7, 11.5) + 0.05, 11.5)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	Input.action_press("move_forward")


var pit_center := Vector3.ZERO


## v1.1: deformable ground and the shovel (the parts that need no physics steps).
func _test_digging() -> void:
	var t = main.terrain
	var b = main.building
	var inv = main.inventory
	var Items = load("res://scripts/items.gd")
	var Shop = load("res://scripts/shop.gd")
	check(Items.ITEMS.has("shovel") and Items.ITEMS.has("sand"), "shovel and sand are items")
	check(Items.RECIPES.has("shovel") and Items.recipe_tier("shovel") == 1, "the workbench makes a shovel")
	check(Shop.CATALOG.map(func(e): return e.name).has("Shovel"), "the shop sells a shovel")
	main.open_test_box()
	check(main.test_storage.count_of("shovel") == 1 and main.test_storage.count_of("sand") == 20, "the test box has a shovel and sand")
	main.inventory_ui.close()
	check(t.has_node("Ground_0_0") and t.has_node("Ground_5_5"), "the base area is a grid of ground chunks")
	# The fine grid sampler matches its own vertices and the old ground.
	check(absf(t.surface_height(12.0, -12.0) - t.vertex_height(60, 36)) < 0.001, "height at a grid point is the vertex height")
	check(absf(t.surface_height(12.5, -12.5) - t.BASE_HEIGHT) < 0.01, "the base clearing is still flat (%.3f)" % t.surface_height(12.5, -12.5))
	check(t.dig_blocked(100.0, 0.0) != "" and t.dig_blocked(12.5, -12.5) == "", "you can only dig near the base")
	check(t.dig_blocked(main.shop.position.x, main.shop.position.z) != "", "not under the shop terminal")
	check(t.dig_blocked(0.2, 0.2) != "", "not under the flag")
	inv.load_data({})
	inv.add("shovel", 1)
	inv.selected = 0
	check(main.holding_shovel(), "holding the shovel")
	var p := Vector3(12.5, 0, -12.5)
	var h0: float = t.surface_height(p.x, p.z)
	check(main.dig_at(p) == "" and inv.count_of("sand") == 1, "a dig gives a bag of sand")
	check(absf(t.surface_height(p.x, p.z) - (h0 - t.DIG_STEP)) < 0.001, "and lowers the cell %.2f m" % t.DIG_STEP)
	for i in 3:
		main.dig_at(p)
	check(absf(t.cell_depth(t.dig_cell(p.x, p.z)) - 1.0) < 0.001 and inv.count_of("sand") == 4, "four digs make a 1 m hole and 4 sand")
	check(main.dig_at(p, true) == "" and inv.count_of("sand") == 3, "filling uses a bag of sand")
	check(absf(t.surface_height(p.x, p.z) - (h0 - 0.75)) < 0.001, "and raises the cell back up")
	inv.remove("sand", 3)
	check(main.dig_at(p, true) != "", "no filling without sand")
	# Bedrock (solid stone above it needs the pickaxe).
	for i in 30:
		main.dig_at(p, false, "pickaxe")
	var sand_at_bottom: int = inv.count_of("sand")
	check(t.at_bedrock(p.x, p.z) and absf(t.cell_depth(t.dig_cell(p.x, p.z)) - t.BEDROCK) < 0.001, "bedrock stops the shovel %.0f m down" % t.BEDROCK)
	check(main.dig_at(p, false, "pickaxe").begins_with("Bedrock") and inv.count_of("sand") == sand_at_bottom, "no sand from bedrock")
	# A row of single digs makes a level trench.
	t.load_data({})
	for x in [8.5, 9.5, 10.5]:
		main.dig_at(Vector3(x, 0, -4.5))
	var c: Array = t.cell_corners(t.dig_cell(9.5, -4.5))
	check(absf(c.max() - c.min()) < 0.001 and absf(c[0] - (h0 - t.DIG_STEP)) < 0.001, "a row of digs makes a level trench")
	# Piling sand stops at the limit.
	inv.add("sand", 20)
	var piled := 0
	for i in 12:
		if main.dig_at(Vector3(10.5, 0, -8.5), true) == "":
			piled += 1
	check(piled == int(t.MAX_RAISE / t.DIG_STEP), "sand piles up to %.0f m (%d fills)" % [t.MAX_RAISE, piled])
	# Prompt when looking at the ground.
	var player = main.player
	player.position = Vector3(20.5, t.surface_height(20.5, -10.0), -10.0)
	player.rotation.y = 0.0
	player.head.rotation.x = -0.9
	player.head.position.y = player.EYE_HEIGHT
	var prompt: String = main.shovel_prompt()
	check(prompt.begins_with("Sand") and "[LMB] Dig" in prompt, "shovel prompt: " + prompt.replace("\n", " / "))
	main._update_dig_marker()
	check(main._dig_marker.visible, "a marker shows the cell the shovel will dig")
	check(main.hints.HINTS.has("shovel"), "there is a first-time hint for the shovel")
	# Saved as height deltas.
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	check(data.has("terrain") and data.terrain.deltas.size() > 0, "dug ground goes in the save (%d numbers)" % data.terrain.deltas.size())
	var before: float = t.surface_height(9.5, -4.5)
	t.load_data({})
	check(absf(t.surface_height(9.5, -4.5) - h0) < 0.001, "cleared")
	main.apply_save_data(data)
	check(absf(t.surface_height(9.5, -4.5) - before) < 0.002, "dug ground is loaded")
	data.erase("terrain")
	main.apply_save_data(data)
	check(absf(t.surface_height(9.5, -4.5) - h0) < 0.001, "older saves load flat ground")
	# Undermining: a wall on the sand falls when the ground next to it is dug out.
	b.load_data([])
	var wall_slot := {"kind": "edge", "cx": 8, "cz": -4, "dir": 0}  # x 16..18 along z = -8
	b.place("wall", wall_slot, b.evaluate("wall", wall_slot).y)
	var wkey: String = b.slot_key(wall_slot)
	var chest_slot := {"kind": "obj", "cx": 10, "cz": -4, "dir": 0}  # x 20..22, z -8..-6
	b.place("chest", chest_slot, b.evaluate("chest", chest_slot).y)
	var ckey: String = b.slot_key(chest_slot)
	var far_slot := {"kind": "edge", "cx": 8, "cz": -10, "dir": 0}
	b.place("wall", far_slot, b.evaluate("wall", far_slot).y)
	main.dig_at(Vector3(16.5, 0, -8.5))
	check(b.pieces.has(wkey), "one dig next to a wall is fine")
	for i in 3:
		main.dig_at(Vector3(16.5, 0, -8.5))
		main.dig_at(Vector3(17.5, 0, -8.5))
	check(not b.pieces.has(wkey), "a wall falls when the sand under it is dug out")
	check(b.pieces.has(b.slot_key(far_slot)), "a wall further away stands")
	var cy: float = b.pieces[ckey].y
	main.dig_at(Vector3(20.5, 0, -7.5))
	check(b.pieces[ckey].y < cy - 0.1, "a chest on the sand settles into the hole (%.2f -> %.2f)" % [cy, b.pieces[ckey].y])
	# A foundation with a wall and a floor on top: dig it out and all of it comes down.
	b.load_data([])
	var f_slot := {"kind": "cell", "cx": 9, "cz": 3, "dir": 0}  # x 18..20, z 6..8
	b.place("foundation", f_slot, b.evaluate("foundation", f_slot).y)
	var fw_slot := {"kind": "edge", "cx": 9, "cz": 3, "dir": 0}
	b.place("wall", fw_slot, b.evaluate("wall", fw_slot).y)
	var up_slot := {"kind": "cell", "cx": 9, "cz": 3, "dir": 0, "level": 1}
	b.place("floor", up_slot, b.evaluate("floor", up_slot).y)
	check(b.pieces.size() == 3, "foundation, wall and floor built")
	for i in 4:
		for cell in [Vector3(18.5, 0, 6.5), Vector3(19.5, 0, 6.5), Vector3(18.5, 0, 7.5), Vector3(19.5, 0, 7.5)]:
			main.dig_at(cell)
	check(b.pieces.size() == 3, "a foundation takes 1 m of digging under it")
	for i in 4:
		for cell in [Vector3(18.5, 0, 6.5), Vector3(19.5, 0, 6.5), Vector3(18.5, 0, 7.5), Vector3(19.5, 0, 7.5)]:
			main.dig_at(cell)
	check(b.pieces.is_empty(), "dug out further, it falls with everything on it (%d left)" % b.pieces.size())
	# A bag dropped in a hole settles to the bottom.
	t.load_data({})
	var bag: String = main.loot.spawn_drop({"wood": 1}, Vector3(26.5, t.surface_height(26.5, 4.5), 4.5))
	main.dig_at(Vector3(26.5, 0, 4.5))
	check(absf(main.loot.drops[bag].node.position.y - t.surface_height(26.5, 4.5)) < 0.001, "a dropped bag settles into the hole")
	main.loot.set_drop_items(bag, {})
	# Physics next: a 2 m wide, 1 m deep pit for the player to fall into.
	pit_center = Vector3(14.0, 0, 10.0)
	for i in 4:
		for o in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			main.dig_at(Vector3(pit_center.x + o.x, 0, pit_center.z + o.y))
	player.position = Vector3(pit_center.x, h0 + 0.2, pit_center.z)
	player.velocity = Vector3.ZERO
	player.head.rotation.x = 0.0


## v1.1, after some physics frames: the new ground collides where it is drawn.
func _check_digging() -> void:
	var t = main.terrain
	var player = main.player
	var bottom: float = t.surface_height(pit_center.x, pit_center.z)
	check(absf(bottom - (t.BASE_HEIGHT - 1.0)) < 0.01, "the pit is 1 m deep (%.2f)" % bottom)
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(pit_center.x + 0.3, 50, pit_center.z - 0.2), Vector3(pit_center.x + 0.3, -50, pit_center.z - 0.2), 1, [player.get_rid()])
	var hit := space.intersect_ray(q)
	check(not hit.is_empty() and hit.collider == t and absf(hit.position.y - t.surface_height(pit_center.x + 0.3, pit_center.z - 0.2)) < 0.01, "collision follows the dug ground")
	check(player.is_on_floor() and absf(player.position.y - bottom) < 0.1, "you fall into the pit and stand on its floor (y %.2f)" % player.position.y)
	main.inventory.add("sand", 1)
	main.dig_at(Vector3(pit_center.x - 0.5, 0, pit_center.z - 0.5), true)
	main.dig_at(Vector3(pit_center.x + 0.5, 0, pit_center.z - 0.5), true)
	check(player.position.y >= t.surface_height(player.position.x, player.position.z) - 0.001, "filling under you lifts you out of the sand")
	t.load_data({})
	main.building.load_data([])
	main.inventory.load_data({})
	main.player.position = main.player.spawn_point


var pit_walker: Node
var deep_walker: Node
var nav_walker: Node
var nav_inside := Vector3.ZERO


## A ring of walls round squares cx0..cx0+2, cz0..cz0+2 (6 x 6 m), with a
## doorway in the middle of the south side. Returns {"door", "east" (middle of
## the east side), "walls": [keys]}.
func _nav_box(cx0: int, cz0: int, door_open: bool, foundations := false) -> Dictionary:
	var b = main.building
	var out := {"walls": []}
	if foundations:
		for dz in 3:
			for dx in 3:
				var f := {"kind": "cell", "cx": cx0 + dx, "cz": cz0 + dz, "dir": 0, "level": 0}
				b.place("foundation", f, b.evaluate("foundation", f).y)
	for k in 3:
		var sides := [
			{"kind": "edge", "cx": cx0 + k, "cz": cz0, "dir": 0, "level": 0},
			{"kind": "edge", "cx": cx0 + k, "cz": cz0 + 3, "dir": 0, "level": 0},
			{"kind": "edge", "cx": cx0, "cz": cz0 + k, "dir": 1, "level": 0},
			{"kind": "edge", "cx": cx0 + 3, "cz": cz0 + k, "dir": 1, "level": 0},
		]
		for i in 4:
			var e: Dictionary = sides[i]
			var door: bool = i == 1 and k == 1
			var key: String = b.place("doorway" if door else "wall", e, b.evaluate("wall", e).y, door and door_open)
			if door:
				out.door = key
			else:
				out.walls.append(key)
			if i == 3 and k == 1:
				out.east = key
	return out


## v1.10: the nav grid and its flow fields (worked out on the spot, no physics).
func _test_nav() -> void:
	var b = main.building
	var t = main.terrain
	var nav = main.nav
	main.mutants.clear()
	b.load_data([])
	t.load_data({})
	check(nav != null and nav.get_parent() == main, "the game has a nav grid")
	# A 6 x 6 m walled yard at x -12..-6, z 4..10, the gate in the south side open.
	var box := _nav_box(-6, 2, true)
	var inside := Vector3(-9, 0, 6)
	var f = nav.compute_now("player", inside)
	check(nav.n >= 2 * int(b.zone_radius) and f.ready, "the grid covers the build zone (%d x %d m)" % [nav.n, nav.n])
	var north := Vector3(-9, 0, -4)
	var path: Array = nav.trace(f, north)
	var crossed: Array = nav.pieces_on(path)
	check(path.size() > 14 and crossed == ["gate"], "from outside, the path goes round to the open gate (%d cells, %s)" % [path.size(), str(crossed)])
	var straight: float = north.distance_to(inside)
	check(f.dist[nav.cell_of(north.x, north.z).y * nav.n + nav.cell_of(north.x, north.z).x] > straight + 6.0, "the way round is longer than straight through, but cheaper than a wall")
	var d: Vector3 = nav.direction("player", Vector3(-9, 0, 1))
	check(d != Vector3.ZERO and absf(d.x) > 0.5, "a mutant facing the north wall is sent sideways round it (%s)" % str(d))
	var s0: Vector3 = nav.cell_point(nav.cell_of(-9, 12))
	var at_gate: Vector3 = nav.direction("player", s0)
	check(at_gate.z < -0.7, "just outside the gate it heads in through it (%s)" % str(at_gate))
	# Close the gate: now the way in is the weakest piece.
	var rev: int = b.revision
	b.set_gate(box.door, false)
	check(b.revision > rev and nav.map_stale(), "closing a gate marks the paths out of date")
	b.damage(box.east, 210.0)
	f = nav.compute_now("player", inside)
	var from_n: Array = nav.pieces_on(nav.trace(f, north))
	var from_e: Array = nav.pieces_on(nav.trace(f, Vector3(4, 0, 2)))
	var from_s: Array = nav.pieces_on(nav.trace(f, Vector3(-9, 0, 18)))
	check(from_n == [box.east], "with the gate shut, it goes for the damaged wall (%s)" % str(from_n))
	check(from_e == [box.east] and from_s == [box.east], "and so does everyone, from every side (%s, %s)" % [str(from_e), str(from_s)])
	b.repair(box.east)
	f = nav.compute_now("player", inside)
	from_n = nav.pieces_on(nav.trace(f, north))
	check(from_n.size() == 1 and from_n[0] != box.east, "repaired, it picks another wall (%s)" % str(from_n))
	var lk: String = b.slot_key({"kind": "edge", "cx": -5, "cz": 2, "dir": 0, "level": 0})
	b.upgrade(lk)
	b.upgrade(lk)
	f = nav.compute_now("player", inside)
	check(not lk in nav.pieces_on(nav.trace(f, north)), "but never the stone wall right in front")
	# Brutes don't use it.
	var brute = main.mutants.spawn("brute", north)
	brute.set_physics_process(false)
	check(brute._nav_want("player", Vector3.FORWARD) == Vector3.FORWARD and brute.nav_field == "", "Brutes go straight through")
	var w = main.mutants.spawn("walker", north)
	w.set_physics_process(false)
	var wd: Vector3 = w._nav_want("player", Vector3.FORWARD)
	check(w.nav_field == "player" and wd != Vector3.FORWARD, "Walkers follow the path (%s)" % str(wd))
	main.mutants.clear()
	b.load_data([])
	# Traps cost something; open sand nothing.
	var ws := {"kind": "obj", "cx": 8, "cz": -8, "dir": 0, "level": 0}
	b.place("barbed_wire", ws, b.evaluate("barbed_wire", ws).y)
	nav.rebuild_map()
	var wc: Vector2i = nav.cell_of(16.5, -15.5)
	var oc: Vector2i = nav.cell_of(20.5, -15.5)
	check(nav.cell_cost[wc.y * nav.n + wc.x] > 3.0 and nav.cell_cost[oc.y * nav.n + oc.x] == 0.0, "barbed wire makes a square dearer to cross")
	b.load_data([])
	# A deep trench from x -24 to -6 at z -6: the path goes round its end.
	for k in 10:
		_dig_pit(-23.0 + k * 2.0, -6.0, 9)
	var goal := Vector3(-14, 0, 2)
	f = nav.compute_now("base", goal)
	var south := Vector3(-14, 0, -14)
	path = nav.trace(f, south)
	var lowest := INF
	for c in path:
		lowest = minf(lowest, nav.cell_point(c).y)
	check(path.size() > 18 and lowest > t.BASE_HEIGHT - 1.0, "a 2.25 m trench is walked round, not through (%d cells, lowest %.2f)" % [path.size(), lowest])
	var pc: Vector2i = nav.cell_of(-14.5, -6.5)
	check(is_inf(f.dist[pc.y * nav.n + pc.x]), "and there is no way out of it")
	t.load_data({})
	nav.rebuild_map()
	check(not nav.map_stale(), "the map is up to date after a rebuild")


## v1.10, real physics: a walker goes round a walled yard on foundations, in
## through the open gate (stepping up onto the foundation), without touching a wall.
func _start_nav_walk() -> void:
	var b = main.building
	main.mutants.clear()
	b.load_data([])
	main.terrain.load_data({})
	main.day_night.restore(main.day_night.day, 11.0)
	var box := _nav_box(5, 5, true, true)  # x 10..16, z 10..16, gate at x 13, z 16
	var top: float = b.foundation_top(6, 6)
	nav_inside = Vector3(13, top, 11.6)
	main.player.position = nav_inside
	main.player.velocity = Vector3.ZERO
	main.survival.health = 100.0
	main.survival.dead = false
	nav_walker = main.mutants.spawn("walker", Vector3(13, 0, 3))
	nav_walker.make_hunter(Vector3.ZERO)
	nav_walker.rotation.y = PI


func _check_nav_walk() -> void:
	var b = main.building
	var p: Vector3 = nav_walker.global_position
	var hurt: Array = b.pieces.values().filter(func(r): return r.hp < b.max_hp(r))
	print("    nav walker at ", p, "  player health ", main.survival.health)
	var in_yard: bool = p.x > 10.0 and p.x < 16.0 and p.z > 10.0 and p.z < 16.0
	check(in_yard and p.y > b.foundation_top(6, 6) - 0.2, "a walker goes round the walls and in through the open gate, onto the foundations")
	check(hurt.is_empty() and b.pieces.size() == 21, "without tearing at a wall (%d damaged)" % hurt.size())
	check(main.survival.health < 100.0, "and gets to you (health %.0f)" % main.survival.health)
	main.mutants.clear()
	b.load_data([])
	main.survival.health = 100.0
	main.player.position = main.player.spawn_point


## Digs a 2 x 2 m pit centred on (x, z), `times` digs deep.
func _dig_pit(x: float, z: float, times: int) -> void:
	for i in times:
		for o in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			main.dig_at(Vector3(x + o.x, 0, z + o.y))


## v1.2: trenches and pits. A walker in a 1.5 m pit and one in a 2.25 m pit.
func _start_pits() -> void:
	main.inventory.load_data({})
	main.mutants.clear()
	main.terrain.load_data({})
	main.building.load_data([])
	main.player.position = Vector3(-30, main.terrain.surface_height(-30, 30), 30)
	_dig_pit(14.0, -14.0, 6)
	_dig_pit(-14.0, -14.0, 9)
	check(absf(main.terrain.cell_depth(main.terrain.dig_cell(-14.5, -14.5)) - 2.25) < 0.01, "a 2.25 m pit dug")
	pit_walker = main.mutants.spawn("walker", Vector3(14.0, 0, -14.0))
	pit_walker.make_hunter(Vector3(14.0, 0, -26.0))
	deep_walker = main.mutants.spawn("walker", Vector3(-14.0, 0, -14.0))
	deep_walker.make_hunter(Vector3(-14.0, 0, -26.0))


func _check_pits() -> void:
	var t = main.terrain
	var d1: float = Vector2(pit_walker.global_position.x - 14.0, pit_walker.global_position.z + 14.0).length()
	print("    pit walker at ", pit_walker.global_position, "  deep walker at ", deep_walker.global_position)
	check(d1 > 2.5 and pit_walker.global_position.y > t.BASE_HEIGHT - 0.3, "a walker climbs out of a 1.5 m pit (%.1f m from it)" % d1)
	var d2: float = Vector2(deep_walker.global_position.x + 14.0, deep_walker.global_position.z + 14.0).length()
	check(d2 < 1.6 and deep_walker.global_position.y < t.BASE_HEIGHT - 1.5, "but a 2.25 m pit holds one (y %.2f)" % deep_walker.global_position.y)
	main.mutants.clear()


## v1.2: spiked pit, ladder, sandbags and foundations levelling the sand (no physics needed).
func _test_trench_pieces() -> void:
	var b = main.building
	var t = main.terrain
	main.inventory.load_data({})
	check(b.PIECES.sandbags.cost.has("sand") and b.PIECES.sandbags.cost.has("cloth"), "sandbags are made of sand and cloth")
	# Spiked pit: only in a hole.
	var ps := {"kind": "obj", "cx": 5, "cz": -8, "dir": 0}  # x 10..12, z -16..-14
	var ev: Dictionary = b.evaluate("spiked_pit", ps)
	check(not ev.ok and ev.reason.begins_with("Dig a pit"), "a spiked pit needs a hole: " + ev.reason)
	_dig_pit(11.0, -15.0, 4)
	ev = b.evaluate("spiked_pit", ps)
	check(ev.ok and absf(ev.y - (t.BASE_HEIGHT - 1.0)) < 0.01, "and fits in a 1 m pit (%s)" % ev.reason)
	var pk: String = b.place("spiked_pit", ps, ev.y)
	var m = main.mutants.spawn("walker", Vector3(11.0, 0, -15.0))
	m.set_physics_process(false)
	main.traps.tick(0.1)
	check(m.health < 100.0 and m.slow_mult < 1.0, "the stakes hurt and slow a mutant in the pit (%.0f)" % m.health)
	var hp: float = m.health
	main.traps.tick(0.1)
	check(is_equal_approx(m.health, hp), "once a second, not every tick")
	check(b.pieces[pk].hp < b.max_hp(b.pieces[pk]), "the stakes wear out")
	main.mutants.clear()
	# Ladder: stands in a pit, you climb it from in front.
	var ls := {"kind": "obj", "cx": 6, "cz": -8, "dir": 0}  # next to the spiked pit, on the slope
	_dig_pit(13.0, -15.0, 4)
	ev = b.evaluate("ladder", ls)
	check(ev.ok, "a ladder can stand in a pit (%s)" % ev.reason)
	b.place("ladder", ls, ev.y)
	check(b.on_ladder(Vector3(13.0, ev.y, -15.3)) and not b.on_ladder(Vector3(13.0, ev.y, -13.0)) and not b.on_ladder(Vector3(14.0, ev.y, -15.3)), "you are on the ladder only right in front of it")
	check(b.on_ladder(Vector3(13.0, ev.y + 2.0, -15.6)), "and on the way up")
	# Foundations fill the sand under them.
	t.load_data({})
	b.load_data([])
	for i in 2:
		main.dig_at(Vector3(16.5, 0, 16.5))
	var fs := {"kind": "cell", "cx": 8, "cz": 8, "dir": 0}  # x 16..18, z 16..18
	ev = b.evaluate("foundation", fs)
	var fk: String = b.place("foundation", fs, ev.y)
	b.level_under(fk)
	var bottom: float = ev.y - b.FOUNDATION_H
	check(t.surface_height(16.0, 16.0) > bottom - 0.001 and t.surface_height(17.0, 17.0) > bottom - 0.001, "a foundation fills the hole under it up to its bottom (%.2f)" % t.surface_height(16.5, 16.5))
	check(absf(t.surface_height(15.0, 16.0) - t.BASE_HEIGHT) < 0.01, "and nothing outside it")
	var bm_src: String = FileAccess.get_file_as_string("res://scripts/build_mode.gd")
	check("level_under" in bm_src, "building a foundation levels the sand")
	b.load_data([])
	t.load_data({})


var ladder_top := 0.0


## v1.2 physics: climbing a ladder out of a 2.25 m pit.
func _start_ladder() -> void:
	var b = main.building
	_dig_pit(-7.0, 11.0, 9)
	var ls := {"kind": "obj", "cx": -4, "cz": 5, "dir": 0}  # x -8..-6, z 10..12
	var ev: Dictionary = b.evaluate("ladder", ls)
	b.place("ladder", ls, ev.y)
	ladder_top = main.terrain.surface_height(-7.0, 8.5)
	var p = main.player
	p.position = Vector3(-7.0, ev.y + 0.05, 11.2)
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0  # facing north, the ladder
	Input.action_press("move_forward")


func _check_ladder() -> void:
	Input.action_release("move_forward")
	var p = main.player
	check(p.position.y > ladder_top - 0.2 and p.position.z < 10.0, "you climb a ladder out of a 2.25 m pit (y %.2f, z %.2f)" % [p.position.y, p.position.z])
	main.building.load_data([])
	main.terrain.load_data({})
	p.position = p.spawn_point


## v1.3: layers under the sand, the pickaxe and rocks, buried caches and the metal detector.
func _test_mining() -> void:
	var t = main.terrain
	var inv = main.inventory
	var Items = load("res://scripts/items.gd")
	t.load_data({})
	main.building.load_data([])
	inv.load_data({})
	check(Items.RECIPES.has("pickaxe") and Items.RECIPES.has("metal_detector"), "the workbench makes a pickaxe and a metal detector")
	main.open_test_box()
	check(main.test_storage.count_of("pickaxe") == 1 and main.test_storage.count_of("metal_detector") == 1 and main.test_storage.count_of("stone") == 20, "the test box has them, and stone and clay")
	main.inventory_ui.close()
	# Sand, then clay, then stone that only the pickaxe gets through.
	var p := Vector3(-10.5, 0, -6.5)
	check(t.next_layer(p.x, p.z) == "sand", "digging starts in sand")
	for i in 6:
		main.dig_at(p)
	check(t.next_layer(p.x, p.z) == "clay" and inv.count_of("sand") == 6, "below 1.5 m comes clay")
	for i in 5:
		main.dig_at(p)
	check(inv.count_of("clay") == 5 and t.next_layer(p.x, p.z) == "stone", "below 2.75 m, solid stone")
	check(main.dig_at(p).begins_with("Solid stone") and inv.count_of("stone") == 0, "the shovel can't dig stone")
	check(main.dig_at(p, false, "pickaxe") == "" and inv.count_of("stone") == 1, "the pickaxe can, and gives stone")
	inv.add("shovel", 1)
	for i in inv.slots.size():
		if not inv.slots[i].is_empty() and inv.slots[i].item == "shovel" and i < 9:
			inv.selected = i
	var player = main.player
	player.position = Vector3(-10.5, t.surface_height(-10.5, -4.0), -4.0)
	player.rotation.y = 0.0
	player.head.rotation.x = -1.2
	player.head.position.y = player.EYE_HEIGHT
	var prompt: String = main.ground_prompt(p, "shovel")
	check("pickaxe" in prompt and prompt.begins_with("Stone"), "the shovel prompt says stone needs a pickaxe: " + prompt.replace("\n", " / "))
	# Rocks.
	var props = main.props
	check(props.rocks.size() > 100, "rocks can be broken (%d)" % props.rocks.size())
	var id := 0
	var rock: Node3D = props.rocks[id].node
	var r: float = rock.get_child(1).shape.radius
	var cam_y: float = player.EYE_HEIGHT
	var away := Vector3(1, 0, 0)
	player.position = rock.global_position + away * (r + 1.3)
	player.position.y = t.surface_height(player.position.x, player.position.z)
	player.rotation.y = atan2(away.x, away.z)
	var dy: float = rock.global_position.y - (player.position.y + cam_y)
	player.head.rotation.x = atan2(dy, r + 1.3)
	inv.load_data({})
	inv.add("pickaxe", 1)
	inv.selected = 0
	check(main.dig_tool() == "pickaxe" and main.rock_under_crosshair() == id, "the pickaxe finds the rock under the crosshair (%d)" % main.rock_under_crosshair())
	check(main.shovel_prompt().begins_with("Rock"), "rock prompt: " + main.shovel_prompt().replace("\n", " / "))
	var hits: int = props.rocks[id].hits
	main.mine_rock(id)
	check(inv.count_of("stone") == 1 and main.rock_hits_left(id) == hits - 1 or hits == 1, "a hit gives a stone")
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	for i in hits:
		main.mine_rock(id)
	check(inv.count_of("stone") == hits and main.broken_rocks.has(id) and not rock.visible and rock.collision_layer == 0, "the rock breaks after %d hits, a stone each" % hits)
	check(main.mine_rock(id) == 0, "a broken rock gives nothing")
	var data2: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	main.apply_save_data(data)
	check(rock.visible and (hits == 1 or main.rock_hits_left(id) == hits - 1), "loading brings back the rock as it was, hits included")
	main.apply_save_data(data2)
	check(not rock.visible and main.broken_rocks.has(id), "broken rocks are saved")
	data2.erase("mining")
	main.apply_save_data(data2)
	check(rock.visible, "older saves have every rock")
	# Caches and the metal detector.
	var c = main.caches
	t.load_data({})
	check(c.caches.size() >= 6, "caches are buried near the base (%d)" % c.caches.size())
	var cache: Dictionary = {}
	for e in c.caches:
		if not e.found:
			cache = e
			break
	inv.load_data({})
	inv.add("metal_detector", 1)
	inv.selected = 0
	player.position = Vector3(cache.x, t.surface_height(cache.x, cache.z), cache.z)
	var close_text: String = main.detector_text()
	check(main.holding("metal_detector") and close_text.contains("steady tone"), "right over a cache: " + close_text)
	player.position = Vector3(cache.x + 300.0, 0, cache.z)
	check(main.detector_text().contains("no signal"), "far away: no signal")
	var hidden: int = c.hidden_count()
	var bags: int = main.loot.drops.size()
	for i in 3:
		main.dig_at(Vector3(cache.x, 0, cache.z))
	check(not cache.found, "not found until 1 m down")
	main.dig_at(Vector3(cache.x, 0, cache.z))
	check(cache.found and c.hidden_count() == hidden - 1 and main.loot.drops.size() == bags + 1, "dug 1 m down, the cache comes up in a bag")
	data = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	cache.found = false
	main.apply_save_data(data)
	check(c.hidden_count() == hidden - 1, "found caches are saved")
	data.erase("caches")
	main.apply_save_data(data)
	check(c.caches.size() == 6 and c.hidden_count() == 6, "older saves get a fresh set of caches")
	for id2 in main.loot.drops.keys():
		main.loot.set_drop_items(id2, {})
	t.load_data({})
	inv.load_data({})


## v1.4: the water well over a 3.5 m shaft, stamina for hard work.
func _test_well() -> void:
	var t = main.terrain
	var b = main.building
	var inv = main.inventory
	t.load_data({})
	b.load_data([])
	inv.load_data({})
	var ws := {"kind": "obj", "cx": -6, "cz": -3, "dir": 0}  # x -12..-10, z -6..-4, centre (-11, -5)
	var ev: Dictionary = b.evaluate("well", ws)
	check(not ev.ok and ev.reason.begins_with("Dig a pit at least 3.5 m"), "a well needs a deep shaft: " + ev.reason)
	for i in 14:
		main.dig_at(Vector3(-10.5, 0, -4.5), false, "pickaxe")
	check(t.depth_at(-11.0, -5.0) >= 3.5 - 0.001, "a 1 m shaft 3.5 m deep, into the stone")
	# Looking steeply down into the shaft reaches its bottom.
	var player = main.player
	player.position = Vector3(-10.5, t.surface_height(-10.5, -3.6), -3.6)
	player.rotation.y = 0.0
	player.head.rotation.x = -1.35
	player.head.position.y = player.EYE_HEIGHT
	var dp = main.dig_point()
	check(dp != null and dp.y < t.BASE_HEIGHT - 3.0, "looking down a shaft, the shovel reaches the bottom (%s)" % str(dp))
	player.head.rotation.x = 0.0
	ev = b.evaluate("well", ws)
	check(ev.ok and absf(ev.y - t.BASE_HEIGHT) < 0.01, "then a well stands over it at ground level (%s %.2f)" % [ev.reason, ev.y])
	var wk: String = b.place("well", ws, ev.y)
	b.level_under(wk)
	check(t.depth_at(-11.0, -5.0) >= 3.5 - 0.001 and t.depth_at(-10.0, -4.0) < 0.01, "its footprint is filled in round the shaft")
	check(b.prompt("well:" + wk).begins_with("Water well: filling"), "well prompt: " + b.prompt("well:" + wk))
	main.power.tick(b.WELL_SECONDS)
	check(b.prompt("well:" + wk).begins_with("[E] Take water"), "a bottle every %.0f s: %s" % [b.WELL_SECONDS, b.prompt("well:" + wk)])
	check(main.take_water(wk) == 1 and inv.count_of("water") == 1, "E takes the water")
	check(main.take_water(wk) == 0, "then it fills again")
	main.power.tick(b.WELL_SECONDS * 20.0)
	check(is_equal_approx(b.pieces[wk].water, b.WELL_MAX), "it holds up to %d bottles" % int(b.WELL_MAX))
	main.dig_at(Vector3(-9.5, 0, -4.5))
	check(absf(b.pieces[wk].y - ev.y) < 0.001, "digging next to it doesn't drop it into its shaft")
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	b.pieces[wk].water = 0.0
	main.apply_save_data(data)
	check(is_equal_approx(b.pieces[wk].water, b.WELL_MAX), "the water in a well is saved")
	# Stamina.
	player.stamina = 5.0
	check(not main.use_stamina(main.STAMINA_DIG) and is_equal_approx(player.stamina, 5.0), "too tired to dig with 5 stamina")
	player.stamina = 50.0
	check(main.use_stamina(main.STAMINA_DIG) and is_equal_approx(player.stamina, 50.0 - main.STAMINA_DIG), "a dig costs %.0f stamina" % main.STAMINA_DIG)
	player.stamina = player.STAMINA_MAX
	b.load_data([])
	t.load_data({})
	inv.load_data({})


## v1.5: structural support: overhangs, heavier tiers, collapse with rigid debris.
func _test_stability() -> void:
	var b = main.building
	main.terrain.load_data({})
	b.load_data([])
	for e in b.cell_edges(6, -6, 0):
		b.place("wall", e, b.evaluate("wall", e).y)
	var keys := []
	for i in 4:
		var s := {"kind": "cell", "cx": 6 + i, "cz": -6, "dir": 0, "level": 1}
		var ev: Dictionary = b.evaluate("floor", s)
		check(ev.ok, "floor %d out can be built (%s)" % [i, ev.reason])
		keys.append(b.place("floor", s, ev.y))
	var sup: Array = keys.map(func(k): return b.support[k])
	check(is_equal_approx(sup[0], 90.0) and is_equal_approx(sup[1], 90.0) and is_equal_approx(sup[2], 65.0) and is_equal_approx(sup[3], 40.0), "support: 90%% on walls, then 65%% and 40%% further out (%s)" % str(sup))
	var far := {"kind": "cell", "cx": 10, "cz": -6, "dir": 0, "level": 1}
	var ev5: Dictionary = b.evaluate("floor", far)
	check(not ev5.ok and ev5.reason.begins_with("Too far from support (15%)"), "the next floor out is too far: " + ev5.reason)
	var up := {"kind": "edge", "cx": 6, "cz": -6, "dir": 0, "level": 1}
	check(is_equal_approx(b.evaluate("wall", up).support, 90.0), "a wall on a wall: 90%")
	check(main.hammer_prompt(keys[2]).contains("support 65%"), "the hammer shows support: " + main.hammer_prompt(keys[2]).replace("\n", " | "))
	# Heavier tiers need more support.
	for i in 2:
		b.upgrade(keys[1])
		b.upgrade(keys[2])
	b.upgrade(keys[3])
	keys = keys.slice(1)
	sup = keys.map(func(k): return b.support[k])
	check(is_equal_approx(sup[0], 86.0) and is_equal_approx(sup[1], 51.0) and is_equal_approx(sup[2], 22.25), "stone floors weigh more: 86%%, 51%%, 22%% (%s)" % str(sup))
	var problem: String = b.upgrade_problem(keys[2])
	check(problem.begins_with("Too heavy"), "a stone floor that far out would fall: " + problem)
	var inv = main.inventory
	inv.load_data({})
	inv.add_all({"hammer": 1, "stone": 20, "clay": 5})
	inv.selected = 0
	main.hammer_use(keys[2])
	check(b.pieces[keys[2]].tier == 1 and inv.count_of("stone") == 20, "so the hammer won't upgrade it, and takes nothing")
	check(b.upgrade_problem(keys[0]) == "", "the stone floor on the walls can go up to concrete")
	# Take a wall down: the floors still stand on the other three... until they don't.
	var walls: Array = b.keys_of(["wall"])
	var collapsed := []
	b.piece_collapsed.connect(func(k, _t): collapsed.append(k))
	for k in walls:
		b.damage(k, 99999.0)
	check(b.pieces.is_empty() and collapsed.size() == 4, "with the walls gone, all four floors come down (%d)" % collapsed.size())
	var chunks: Array = main.get_tree().get_nodes_in_group("debris")
	check(chunks.size() > 0 and chunks[0] is RigidBody3D, "collapses throw rigid debris (%d chunks)" % chunks.size())
	check(chunks.size() <= b.MAX_DEBRIS, "but never more than %d at once" % b.MAX_DEBRIS)
	inv.load_data({})


## A few seconds later: the debris has landed on the ground and lies still.
func _check_debris() -> void:
	var chunks: Array = main.get_tree().get_nodes_in_group("debris").filter(func(c): return not c.is_queued_for_deletion())
	var worst := 0.0
	var fastest := 0.0
	for c in chunks:
		worst = maxf(worst, main.terrain.surface_height(c.global_position.x, c.global_position.z) - c.global_position.y)
		fastest = maxf(fastest, c.linear_velocity.length())
	check(chunks.size() > 0 and worst < 0.3 and fastest < 1.5, "debris settles on the sand (%d chunks, deepest %.2f m under, fastest %.2f m/s)" % [chunks.size(), worst, fastest])


## True if a point (in a piece's local space) is inside one of its colliders.
func _inside_collider(type: String, p: Vector3) -> bool:
	var b = main.building
	for c in b.piece_colliders(type):
		var half: Vector3 = c[0] * 0.5
		var d: Vector3 = (p - c[1]).abs()
		if d.x <= half.x and d.y <= half.y and d.z <= half.z:
			return true
	return false


## v1.6: more pieces.
func _test_more_pieces_2() -> void:
	var b = main.building
	main.terrain.load_data({})
	b.load_data([])
	for t in ["half_wall", "low_wall", "slit_wall", "pillar", "trapdoor", "tri_foundation", "tri_roof", "metal_door"]:
		check(b.PIECES.has(t) and t in b.ORDER, "%s is in the build list" % t)
	# Half and low walls: you can shoot over them, they hold nothing up.
	var hs := {"kind": "edge", "cx": -8, "cz": 7, "dir": 0, "level": 0}
	var hk: String = b.place("half_wall", hs, b.evaluate("half_wall", hs).y)
	check(_inside_collider("half_wall", Vector3(0, 1.0, 0)) and not _inside_collider("half_wall", Vector3(0, 1.3, 0)), "a half wall is %.1f m high, below your eyes (%.2f)" % [b.HALF_H, main.player.EYE_HEIGHT])
	check(not _inside_collider("low_wall", Vector3(0, 0.8, 0)) and _inside_collider("low_wall", Vector3(0, 0.5, 0)), "a low wall is %.1f m high" % b.LOW_H)
	check(not b.evaluate("floor", {"kind": "cell", "cx": -8, "cz": 7, "dir": 0, "level": 1}).ok, "a half wall can't hold a floor up")
	check(b.describe(b.pieces[hk]) == "Wood half wall" and not b.upgrade_cost(b.pieces[hk]).is_empty(), "half walls have tiers: " + b.describe(b.pieces[hk]))
	# Gun slit: a gap at eye height to shoot through, otherwise a full wall.
	var sy: float = b.SLIT_Y + b.SLIT_H * 0.5
	check(not _inside_collider("slit_wall", Vector3(0, sy, 0)) and _inside_collider("slit_wall", Vector3(0.8, sy, 0)) and _inside_collider("slit_wall", Vector3(0, 1.0, 0)) and _inside_collider("slit_wall", Vector3(0, 2.0, 0)), "a gun slit wall has a slot at %.2f m" % sy)
	b.load_data([])
	# Pillars stand on grid corners and hold up floors.
	var ps: Dictionary = b.slot_for("pillar", Vector3(-11.8, 0, 16.3), 0)
	check(ps.kind == "post" and ps.cx == -6 and ps.cz == 8, "a pillar snaps to the nearest grid corner (%s)" % str(ps))
	var pk: Array = []
	for o in [Vector2i(0, 0), Vector2i(1, 0)]:
		var s := {"kind": "post", "cx": -6 + o.x, "cz": 8 + o.y, "dir": 0, "level": 0}
		var ev: Dictionary = b.evaluate("pillar", s)
		check(ev.ok, "a pillar on the sand (%s)" % ev.reason)
		pk.append(b.place("pillar", s, ev.y))
	var fs := {"kind": "cell", "cx": -6, "cz": 8, "dir": 0, "level": 1}  # its north-west corner is pillar 0
	var fev: Dictionary = b.evaluate("floor", fs)
	check(fev.ok and is_equal_approx(fev.support, 90.0) and absf(fev.y - (b.pieces[pk[0]].y + b.WALL_H)) < 0.001, "pillars hold a floor up (%s, %s)" % [fev.reason, str(fev.get("support"))])
	var fk: String = b.place("floor", fs, fev.y)
	var up := {"kind": "post", "cx": -6, "cz": 8, "dir": 0, "level": 1}
	check(b.evaluate("pillar", up).ok, "pillars stack")
	var save: Array = JSON.parse_string(JSON.stringify(b.save_data()))
	b.load_data(save)
	check(b.pieces.has(pk[0]) and b.pieces.has(fk), "pillars are saved")
	b.damage(pk[0], 99999.0)
	check(b.pieces.has(fk), "one pillar is enough")
	b.damage(pk[1], 99999.0)
	check(not b.pieces.has(fk), "with both gone the floor falls")
	b.load_data([])
	# Trapdoor: a floor with a hatch that opens.
	for e in b.cell_edges(-6, 8, 0):
		b.place("wall", e, b.evaluate("wall", e).y)
	var ts := {"kind": "cell", "cx": -6, "cz": 8, "dir": 0, "level": 1}
	var tev: Dictionary = b.evaluate("trapdoor", ts)
	check(tev.ok, "a trapdoor goes upstairs like a floor (%s)" % tev.reason)
	var tk: String = b.place("trapdoor", ts, tev.y)
	check(b.evaluate("floor", {"kind": "cell", "cx": -5, "cz": 8, "dir": 0, "level": 1}).ok, "it holds up a floor next to it")
	check(not _inside_collider("trapdoor", Vector3(0, -0.07, -0.45)) and _inside_collider("trapdoor", Vector3(0, -0.07, 0.6)), "its frame has a hole for the hatch")
	var hid: String = "hatch:" + tk
	check(main._prompt_for(hid) == "[E] Open trapdoor", "trapdoor prompt")
	main.interact(hid)
	check(b.pieces[tk].open and absf(b.pieces[tk].hinge.rotation.x) > 1.0, "E opens the hatch")
	save = JSON.parse_string(JSON.stringify(b.save_data()))
	b.load_data(save)
	check(b.pieces[tk].open, "an open trapdoor is saved open")
	b.load_data([])
	# Triangle foundation and roof.
	var tf := {"kind": "cell", "cx": -8, "cz": 8, "dir": 1}
	var tfev: Dictionary = b.evaluate("tri_foundation", tf)
	check(tfev.ok and absf(tfev.y - (main.terrain.BASE_HEIGHT + 0.12)) < 0.01, "a triangle foundation sits like a foundation (%s)" % tfev.reason)
	var tfk: String = b.place("tri_foundation", tf, tfev.y)
	var shape = b.pieces[tfk].node.get_children().filter(func(n): return n is CollisionShape3D)[0].shape
	check(shape is ConvexPolygonShape3D and shape.points.size() == 6, "it has a triangular collider")
	var we := {"kind": "edge", "cx": -8, "cz": 8, "dir": 0}
	check(absf(b.evaluate("wall", we).y - tfev.y) < 0.001, "walls stand on it")
	var wk: String = b.place("wall", we, b.evaluate("wall", we).y)
	var tr := {"kind": "cell", "cx": -8, "cz": 8, "dir": 1, "level": 1}
	check(b.evaluate("tri_roof", tr).ok, "a triangle roof goes on top")
	main.build_mode._rebuild_ghost("tri_roof")
	check(main.build_mode._ghost.get_child_count() >= 1, "build mode shows the triangle")
	b.load_data([])
	# Metal door.
	var ds := {"kind": "edge", "cx": -6, "cz": 8, "dir": 0}
	var dk: String = b.place("metal_door", ds, b.evaluate("metal_door", ds).y)
	var drec: Dictionary = b.pieces[dk]
	check(drec.hp == 1400.0 and b.describe(drec) == "Metal door" and b.upgrade_cost(drec).is_empty(), "a metal door: 1400 hp, no tiers")
	check(main._prompt_for("gate:" + dk).begins_with("[E] Open door"), "door prompt: " + main._prompt_for("gate:" + dk))
	main.interact("gate:" + dk)
	check(drec.open, "E opens it")
	check(b.evaluate("floor", {"kind": "cell", "cx": -6, "cz": 8, "dir": 0, "level": 1}).ok, "it holds up a floor like a wall")
	b.load_data([])


## v1.7: lines of pieces, area repair and upgrade, moving pieces.
func _test_fast_building() -> void:
	var b = main.building
	var bm = main.build_mode
	var inv = main.inventory
	var player = main.player
	main.terrain.load_data({})
	b.load_data([])
	inv.load_data({})
	player.position = Vector3(-14, main.terrain.surface_height(-14, 12), 12)
	player.stamina = player.STAMINA_MAX
	# Line geometry.
	var a := {"kind": "edge", "cx": -8, "cz": 2, "dir": 0, "level": 0}
	var e := {"kind": "edge", "cx": -4, "cz": 2, "dir": 0, "level": 0}
	var line: Array = bm.line_slots("wall", a, e)
	check(line.size() == 5 and line[4].cx == -4 and line[2].cz == 2, "a dragged wall line covers every edge between (5)")
	var c1 := {"kind": "cell", "cx": -8, "cz": 0, "dir": 0, "level": 0}
	var c2 := {"kind": "cell", "cx": -6, "cz": -5, "dir": 0, "level": 0}
	line = bm.line_slots("foundation", c1, c2)
	check(line.size() == 6 and line.all(func(s): return s.cx == -8), "squares go along the longer way (%d)" % line.size())
	check(bm.line_slots("wall", a, {"kind": "edge", "cx": 40, "cz": 2, "dir": 0, "level": 0}).size() == bm.LINE_MAX, "at most %d in a line" % bm.LINE_MAX)
	check(bm.line_slots("chest", c1, c2).size() == 1, "objects don't make lines")
	# Building a line: paid piece by piece, stops when the materials run out.
	bm.toggle()
	bm.select(Building_index("wall"))
	inv.add_all({"wood": 9, "nails": 9})
	bm.drag_start = a
	bm.slot = e
	var built: int = bm.end_drag()
	check(built == 3 and inv.count_of("wood") == 0, "a line of 5 walls with wood for 3 builds 3 (%d)" % built)
	check(b.pieces.has(b.slot_key(a)) and b.pieces.has(b.slot_key({"kind": "edge", "cx": -6, "cz": 2, "dir": 0, "level": 0})), "starting at the first one")
	# Area repair, paid from a chest within reach.
	var walls: Array = b.keys_of(["wall"])
	for k in walls:
		b.damage(k, 120.0)
	var cs := {"kind": "obj", "cx": -7, "cz": 5, "dir": 0, "level": 0}
	var ck: String = b.place("chest", cs, b.evaluate("chest", cs).y)
	b.storage_of(ck).add("wood", 20)
	player.position = Vector3(-13, main.terrain.surface_height(-13, 9), 9)
	check(main.has_near({"wood": 20}) and not main.has_near({"wood": 21}), "chests within reach count as yours for the hammer")
	bm.toggle()
	var fixed: int = main.area_repair(player.global_position)
	check(fixed == 3 and walls.all(func(k): return b.pieces[k].hp == b.max_hp(b.pieces[k])), "R with the hammer repairs all 3 walls (%d)" % fixed)
	check(b.storage_of(ck).count_of("wood") == 14, "paid with wood from the chest (%d left)" % b.storage_of(ck).count_of("wood"))
	# Area upgrade.
	inv.add_all({"scrap": 8, "nails": 4})
	var up: int = main.area_upgrade(walls[0])
	check(up == 2 and inv.count_of("scrap") == 0, "G upgrades every wood wall near it while the scrap lasts (%d)" % up)
	check(main.area_upgrade(walls[0]) == 0, "and nothing without materials")
	# Moving a piece: a chest keeps what is in it, and it costs nothing.
	b.storage_of(ck).add("nails", 7)
	bm.toggle()
	inv.load_data({})
	check(bm.pick_up(ck) == "" and not b.pieces.has(ck) and bm.current_type() == "chest", "G picks up the chest")
	check(bm.status_text().begins_with("MOVING"), "build mode says so")
	var to := {"kind": "obj", "cx": -9, "cz": 5, "dir": 0, "level": 0}
	bm.slot = to
	bm.base_y = b.evaluate("chest", to).y
	bm.can_build = true
	check(bm.try_place() and bm.carrying.is_empty(), "left click puts it down")
	var nk: String = b.slot_key(to)
	check(b.pieces.has(nk) and b.storage_of(nk).count_of("nails") == 7 and b.storage_of(nk).count_of("wood") == 14, "with everything still in it, for free")
	# A wall holding up a floor stays; a carried piece goes back when you stop.
	var f1 := {"kind": "cell", "cx": -8, "cz": 2, "dir": 0, "level": 1}
	b.place("floor", f1, b.evaluate("floor", f1).y)
	check(bm.pick_up(b.slot_key(a)) == "Something rests on it", "a wall holding up a floor can't be moved")
	check(bm.pick_up(nk) == "", "picked up the chest again")
	bm.toggle()
	check(b.pieces.has(nk) and b.storage_of(nk).count_of("nails") == 7, "leaving build mode puts it back")
	b.load_data([])
	inv.load_data({})
	player.stamina = player.STAMINA_MAX


## v2.4: ready-made buildings laid in a chosen material (G in build mode).
func _test_blueprint_tiers() -> void:
	var b = main.building
	var bm = main.build_mode
	var inv = main.inventory
	var player = main.player
	var Prefabs = load("res://scripts/prefabs.gd")
	main.terrain.load_data({})
	b.load_data([])
	b.sites_load_data([])
	inv.load_data({})
	player.position = Vector3(-14, main.terrain.surface_height(-14, 12), 12)
	var W: Dictionary = b.PIECES.wall.cost
	check(b.cost_at_tier("wall", 0) == W, "a wooden wall costs what it always did")
	var stone: Dictionary = b.cost_at_tier("wall", 2)
	var by_hand: Dictionary = W.duplicate()
	for t in 2:
		var up: Dictionary = b.upgrade_cost({"type": "wall", "tier": t})
		for item in up:
			by_hand[item] = int(by_hand.get(item, 0)) + up[item]
	check(stone == by_hand, "a stone wall costs the wood one plus both hammer upgrades (%s)" % str(stone))
	check(b.tier_for("ladder", 3) == 0 and b.cost_at_tier("ladder", 3) == b.PIECES.ladder.cost, "ladders and other fixed pieces keep their own material")
	check(b.tier_for("roof", 0) == 1 and b.tier_for("roof", 2) == 2, "roofs are never below scrap metal")
	check(b.prefab_cost("cabin", 0) == Prefabs.total_cost("cabin", b.PIECES), "a wooden blueprint costs the same as before")
	check(b.prefab_cost("cabin", 3).has("cement") and not b.prefab_cost("cabin", 1).has("cement"), "a concrete one needs cement, a scrap one doesn't")
	# Picking the material in build mode.
	bm.toggle()
	if not bm.prefab_mode:
		bm.toggle_prefabs()
	bm.select(Prefabs.ORDER.find("shelter"))
	check(bm.prefab_tier == 0 and bm.status_text().contains("Shelter (1×1) in wood"), "blueprints start out in wood")
	bm.cycle_prefab_tier()
	bm.cycle_prefab_tier()
	check(bm.prefab_tier == 2 and bm.status_text().contains("in stone") and bm.status_text().contains(" stone"), "G twice picks stone, and the HUD shows the stone cost")
	check(bm.keys_text().contains("[G] material"), "the key help lists G")
	var ev: Dictionary = bm.evaluate_prefab("shelter", -5, -5, 0)
	check(ev.ok, "a shelter fits (%s)" % ev.reason)
	bm.can_build = true
	bm.prefab_plan = ev.plan
	bm.prefab_y = ev.y
	var sid: int = bm.place_prefab()
	check(sid > 0 and b.site_tier(sid) == 2, "the blueprint is laid in stone")
	check(b.site_cost(sid) == b.prefab_cost("shelter", 2), "it needs the stone price (%s)" % str(b.site_cost(sid)))
	var pr: String = b.site_prompt(sid, main._cost_text)
	check(pr.contains("Shelter (1×1) in stone") and pr.contains("next stone foundation"), "the prompt names the material: " + pr)
	var need: Dictionary = b.site_cost(sid)
	var short: Dictionary = b.cost_at_tier("foundation", 2)
	inv.add_all(b.PIECES.foundation.cost)
	check(main.build_site_step(sid) == "", "the wood alone isn't enough for a stone foundation")
	inv.load_data({})
	inv.add_all(need)
	var n := 0
	for i in 40:
		player.stamina = player.STAMINA_MAX
		if not b.sites.has(sid) or main.build_site_step(sid) == "":
			break
		n += 1
	check(not b.sites.has(sid) and n == Prefabs.entries("shelter").size(), "the stone shelter goes up in full (%d pieces)" % n)
	var all_stone := true
	for k in b.pieces:
		var r: Dictionary = b.pieces[k]
		if not b.PIECES[r.type].get("fixed", false) and (r.tier != 2 or r.hp < b.max_hp(r)):
			all_stone = false
	check(all_stone, "every piece stands in stone at full strength")
	check(inv.weight() < 0.01, "and it used up exactly the stone price (%.1f kg left)" % inv.weight())
	check(short.has("stone"), "a stone foundation costs stone")
	# Saving keeps the material; older saves and broken values load as wood.
	b.load_data([])
	var pev: Dictionary = bm.evaluate_prefab("cabin", -11, 0, 0)
	check(pev.ok, "a cabin fits (%s)" % pev.reason)
	var s3: int = b.add_site("cabin", pev.plan, pev.y, 3)
	var data: Dictionary = main.collect_save_data()
	b.sites_load_data([])
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(b.sites.size() == 1 and b.site_tier(b.sites.keys()[0]) == 3, "a concrete blueprint stays concrete through a save")
	var old: Array = b.sites_save_data()
	old[0].erase("tier")
	b.sites_load_data(old)
	check(b.site_tier(b.sites.keys()[0]) == 0, "a blueprint from an older save is wood")
	old[0]["tier"] = "lots"
	b.sites_load_data(old)
	check(b.site_tier(b.sites.keys()[0]) == 0, "a broken tier falls back to wood")
	old[0]["tier"] = 9
	b.sites_load_data(old)
	check(b.site_tier(b.sites.keys()[0]) == 3, "a tier past concrete is clamped")
	bm.cycle_prefab_tier()
	bm.cycle_prefab_tier()
	check(bm.prefab_tier == 0, "G goes round back to wood")
	bm.toggle_prefabs()
	bm.toggle()
	b.sites_load_data([])
	b.load_data([])
	inv.load_data({})
	player.stamina = player.STAMINA_MAX


## v1.9: free turning, ready-made buildings (blueprints) and the horde button.
func _test_building_v19() -> void:
	var b = main.building
	var bm = main.build_mode
	var inv = main.inventory
	var player = main.player
	var Prefabs = load("res://scripts/prefabs.gd")
	main.terrain.load_data({})
	b.load_data([])
	inv.load_data({})
	player.position = Vector3(-14, main.terrain.surface_height(-14, 12), 12)
	# Turning a grid slot four times brings it back; walls stay round their squares.
	var ok_turns := true
	for e in Prefabs.entries("long_cabin") + Prefabs.entries("watchtower"):
		var sl: Dictionary = {"kind": e.kind, "cx": e.cx, "cz": e.cz, "dir": e.dir, "level": e.level}
		var t: Dictionary = sl
		for i in 4:
			t = Prefabs.turn_slot(t)
		if t.cx != sl.cx or t.cz != sl.cz or posmod(int(t.dir), 4) != posmod(int(sl.dir), 4):
			ok_turns = false
	check(ok_turns, "a blueprint slot turned four times comes back to where it was")
	var all_round := true
	for turns in 4:
		var plan: Array = Prefabs.placed("cabin", 3, -2, turns, b.PIECES)
		var cells := {}
		for e in plan:
			if e.type == "foundation":
				cells[Vector2i(e.slot.cx, e.slot.cz)] = true
		for e in plan:
			if e.slot.kind == "edge" and e.slot.level == 0:
				if not b.edge_cells(e.slot).any(func(c): return cells.has(c)):
					all_round = false
			if e.slot.kind == "cell" and not cells.has(Vector2i(e.slot.cx, e.slot.cz)):
				all_round = false
		if cells.size() != 4:
			all_round = false
	check(all_round, "a turned cabin keeps its walls and roof on its own squares (all 4 ways)")
	# Laying a blueprint is free; E builds it piece by piece.
	bm.toggle()
	bm.toggle_prefabs()
	check(bm.prefab_mode and bm.status_text().begins_with("BUILDING: Shelter"), "T switches build mode to ready-made buildings")
	bm.select(Prefabs.ORDER.find("cabin"))
	var ev: Dictionary = bm.evaluate_prefab("cabin", 4, -7, 1)
	check(ev.ok, "a cabin fits on open sand in the base (%s)" % ev.reason)
	bm.dir = 1
	bm.can_build = true
	bm.prefab_plan = ev.plan
	bm.prefab_y = ev.y
	var sid: int = bm.place_prefab()
	check(sid > 0 and b.sites.has(sid) and b.pieces.is_empty(), "left click lays its blueprint and builds nothing yet")
	check(inv.weight() < 0.01, "laying a blueprint costs nothing")
	check(not bm.evaluate_prefab("cabin", 4, -7, 1).ok, "a second one can't go on top of it")
	check(b.sites[sid].node.get_child_count() == Prefabs.entries("cabin").size(), "every piece shows as a blue blueprint (%d)" % b.sites[sid].node.get_child_count())
	var cost: Dictionary = b.site_cost(sid)
	check(cost == Prefabs.total_cost("cabin", b.PIECES), "the blueprint needs %s" % str(cost))
	check(main.build_site_step(sid) == "", "without materials nothing goes up")
	check(b.site_prompt(sid, main._cost_text).contains("next wooden foundation"), "the prompt names the next piece: " + b.site_prompt(sid, main._cost_text))
	inv.add_all({"wood": 4, "nails": 4})
	player.stamina = player.STAMINA_MAX
	var k1: String = main.build_site_step(sid)
	check(k1 != "" and b.pieces.has(k1) and b.pieces[k1].type == "foundation" and inv.count_of("wood") == 0, "E builds the first foundation and pays for it")
	check(b.sites[sid].todo.size() == Prefabs.entries("cabin").size() - 1, "and it comes off the blueprint")
	# The rest: wood and nails in a chest in reach, scrap for the roof in pockets.
	var need: Dictionary = b.site_cost(sid)
	var cs := {"kind": "obj", "cx": -7, "cz": 5, "dir": 0, "level": 0}
	var ck: String = b.place("chest", cs, b.evaluate("chest", cs).y)
	b.storage_of(ck).add_all({"wood": need.get("wood", 0), "nails": need.get("nails", 0)})
	player.position = Vector3(-13, main.terrain.surface_height(-13, 9), 9)
	inv.add("scrap", need.get("scrap", 0))
	var built := 1
	for i in 60:
		player.stamina = player.STAMINA_MAX
		if not b.sites.has(sid) or main.build_site_step(sid) == "":
			break
		built += 1
	check(not b.sites.has(sid) and built == Prefabs.entries("cabin").size(), "holding E builds the whole cabin (%d of %d pieces)" % [built, Prefabs.entries("cabin").size()])
	check(b.storage_of(ck).count_of("wood") == 0 and inv.count_of("scrap") == 0, "paid from the chest and your pockets")
	var roofs: Array = b.keys_of(["roof"])
	check(roofs.size() == 4 and roofs.all(func(k): return b.support.get(k, 0.0) >= b.MIN_SUPPORT), "its roof stands on the walls (%d squares)" % roofs.size())
	check(b.keys_of(["doorway"]).size() == 1 and b.keys_of(["window"]).size() == 1, "with a door and a window")
	# Every ready-made building can be built in full.
	var spots := {"shelter": Vector2i(-2, -10), "watchtower": Vector2i(1, 4), "gatehouse": Vector2i(-9, -4), "long_cabin": Vector2i(3, 2)}
	for id in spots:
		var at: Vector2i = spots[id]
		var pev: Dictionary = bm.evaluate_prefab(id, at.x, at.y, 0)
		if not pev.ok:
			check(false, "%s fits (%s)" % [id, pev.reason])
			continue
		var site: int = b.add_site(id, pev.plan, pev.y)
		inv.load_data({})
		inv.add_all(b.site_cost(site))
		var n := 0
		for i in 80:
			player.stamina = player.STAMINA_MAX
			if not b.sites.has(site) or main.build_site_step(site) == "":
				break
			n += 1
		check(not b.sites.has(site), "the %s goes up in full (%d of %d)" % [id, n, Prefabs.entries(id).size()])
	# Blueprints are saved.
	var pev2: Dictionary = bm.evaluate_prefab("shelter", -6, 8, 2)
	var s2: int = b.add_site("shelter", pev2.plan, pev2.y)
	inv.load_data({})
	inv.add_all({"wood": 4, "nails": 4})
	main.build_site_step(s2)
	var data: Dictionary = main.collect_save_data()
	b.sites_load_data([])
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(b.sites.size() == 1 and b.sites.values()[0].todo.size() == Prefabs.entries("shelter").size() - 1, "a half-built blueprint is saved and loaded")
	bm.toggle_prefabs()
	# Walls meeting at a corner both fit (the room check left room for the corner).
	var wa := {"kind": "edge", "cx": -10, "cz": 10, "dir": 1, "level": 0}
	b.place("wall", wa, b.evaluate("wall", wa).y)
	var wb := {"kind": "edge", "cx": -11, "cz": 10, "dir": 0, "level": 0}
	check(b.space_free("wall", wb, b.evaluate("wall", wb).y), "a wall fits against the end of another at a corner")
	b.remove(b.slot_key(wa), false)
	# Free turning: objects in 15° steps, walls a quarter at a time.
	bm.select(Building_index("chest"))
	bm.dir = 0
	bm.turn = 0
	bm.fine_turn(1)
	check(bm.dir == 0 and bm.turn == 1 and bm.heading() == 15, "X turns a chest 15°")
	bm.fine_turn(-1)
	bm.fine_turn(-1)
	check(bm.dir == 3 and bm.turn == 5 and bm.heading() == 345, "Z turns it back past north (%d°)" % bm.heading())
	var ts := {"kind": "obj", "cx": -9, "cz": 9, "dir": 1, "level": 0, "turn": 2}
	var tk: String = b.place("chest", ts, b.evaluate("chest", ts).y)
	var yaw: float = b.pieces[tk].node.rotation.y
	check(absf(angle_difference(yaw, -PI / 2 - PI / 6)) < 0.01, "a chest turned 90° + 30° stands that way (%.2f)" % yaw)
	data = main.collect_save_data()
	b.load_data([])
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(b.pieces.has(tk) and absf(angle_difference(b.pieces[tk].node.rotation.y, yaw)) < 0.01, "and stays turned after loading")
	bm.select(Building_index("wall"))
	bm.dir = 0
	bm.fine_turn(1)
	check(bm.dir == 1 and bm.turn == 0, "walls turn a quarter with X")
	check(bm.status_text().contains("[T] ready-made"), "build mode lists its keys")
	bm.toggle()
	# The horde button.
	var w = main.waves
	main.day_night.restore(main.day_night.day, 10.0)
	main.mutants.clear()
	check(main.horde_stand != null and main.horde_prompt().begins_with("[E] Press the red button"), "the horde stand by the spawn point: " + main.horde_prompt())
	var cash0: int = main.shop.cash
	check(main.press_horde_button() and w.active and w.called and w.to_spawn > 0, "pressing it calls a horde by day (%d mutants)" % w.to_spawn)
	check(not main.press_horde_button(), "it can't be pressed again while the horde is out")
	w._spawn_group()
	var stand: Vector3 = main.horde_stand.global_position
	var near: Array = main.mutants.alive().filter(func(m): return m.hunter and Vector2(m.position.x - stand.x, m.position.z - stand.z).length() < w.CALL_RADIUS + 8.0)
	check(not near.is_empty() and near.size() == w.hunters().size(), "they come from about %d m away (%d so far)" % [int(w.CALL_RADIUS), near.size()])
	data = main.collect_save_data()
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(w.active and w.called, "a horde out by day is saved and loaded")
	var c: Dictionary = w.cash_for({"called": true, "bounty": 30, "wave": 5, "pieces": 10, "cleared": false})
	check(c.cash == 30 and c.cash_night == 0, "a horde pays only the bounty (%d)" % c.cash)
	check(w.summary_lines({"called": true, "cleared": true})[0] == "Horde wiped out!", "and has its own summary")
	w.end_wave(false)
	main.mutants.clear()
	check(main.shop.cash >= cash0, "the horde ends")
	b.load_data([])
	b.sites_load_data([])
	inv.load_data({})
	player.stamina = player.STAMINA_MAX


## v1.11: trees and the axe, loose stones, machines, log stakes.
func _test_resources() -> void:
	var b = main.building
	var inv = main.inventory
	var props = main.props
	var player = main.player
	var Items = load("res://scripts/items.gd")
	b.load_data([])
	inv.load_data({})
	main.mutants.clear()
	# Trees and stones in the world.
	check(props.trees.size() >= 80, "trees grow in groves and alone (%d)" % props.trees.size())
	var nearest := INF
	for t in props.trees:
		nearest = minf(nearest, Vector2(t.node.position.x, t.node.position.z).length())
	check(nearest > 42.0, "none inside the biggest build zone (nearest %.0f m)" % nearest)
	var close: int = props.pebbles.filter(func(pb): return Vector2(pb.pos.x, pb.pos.z).length() < 41.0).size()
	check(props.pebbles.size() >= 150 and close >= 20, "loose stones lie about, %d near the base" % close)
	# Aiming at a tree with the axe.
	var tid := 0
	var tn: Node3D = props.trees[tid].node
	var tp: Vector3 = tn.global_position
	player.position = Vector3(tp.x + 1.6, main.terrain.surface_height(tp.x + 1.6, tp.z), tp.z)
	player.rotation.y = PI * 0.5  # facing -x, the tree
	player.head.rotation.x = 0.0
	inv.add("axe", 1)
	inv.selected = 0
	check(main.tree_under_crosshair() == tid, "the axe finds the tree in front of you (%d)" % main.tree_under_crosshair())
	check(main.axe_prompt().contains("[LMB] Chop"), "prompt: " + main.axe_prompt().replace("\n", " / "))
	# Chopping it down.
	var hits: int = props.trees[tid].hits
	var logs := 0
	for i in hits - 1:
		logs += main.chop_tree(tid)
	check(logs == 0 and main.tree_hits_left(tid) == 1, "each blow brings it closer (%d hits)" % hits)
	var data: Dictionary = main.collect_save_data()
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(main.tree_hits_left(tid) == 1, "a half-chopped tree is saved")
	logs = main.chop_tree(tid)
	check(logs == props.trees[tid].logs and inv.count_of("log") == logs and main.felled_trees.has(tid), "the last blow fells it: %d logs" % logs)
	check(main.tree_under_crosshair() == -1, "a felled tree can't be chopped again")
	data = main.collect_save_data()
	main.felled_trees = {}
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(main.felled_trees.has(tid) and not props.trees[tid].node.visible, "felled trees stay felled after loading")
	var day: int = main.day_night.day
	main._regrow(day + 2)
	check(main.felled_trees.has(tid), "not grown back after 2 days")
	main._regrow(day + 3)
	check(not main.felled_trees.has(tid) and props.trees[tid].node.visible and props.trees[tid].node.collision_layer == 1, "grown back after 3")
	# Logs: split by hand at the workbench, or 5 wood each at a sawmill.
	check(Items.RECIPES.has("axe") and Items.RECIPES.wood.cost == {"log": 1} and Items.RECIPES.wood.count == 2, "the workbench makes axes and splits logs into 2 wood")
	# Loose stones.
	var pid := 0
	var stone0: int = inv.count_of("stone")
	check(main._prompt_for("pebble:0") == "[E] Pick up stone", "loose stones say E picks them up")
	check(main.pick_pebble(pid) and inv.count_of("stone") == stone0 + 1, "E picks a stone up")
	check(not main.pick_pebble(pid), "and it is gone")
	data = main.collect_save_data()
	main.taken_pebbles = {}
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(main.taken_pebbles.has(pid), "picked stones stay picked after loading")
	main._regrow(day + 2)
	check(not main.taken_pebbles.has(pid) and props.pebbles[pid].area.collision_layer != 0, "and turn up again two days later")
	# Machines come by drone.
	var kits := {}
	for e in main.shop.DRONE:
		for it in e.items:
			if it.begins_with("kit_"):
				kits[it] = e.price
	check(kits.has("kit_sawmill") and kits.has("kit_crusher") and kits.has("kit_press"), "the drone flies in a sawmill, a rock crusher and a nail press (%s)" % str(kits))
	# A sawmill next to a fuelled generator, by day.
	main.day_night.restore(day, 10.0)
	var gs := {"kind": "obj", "cx": -9, "cz": 9, "dir": 0, "level": 0}
	var gk: String = b.place("generator", gs, b.evaluate("generator", gs).y)
	b.pieces[gk].fuel = 2.0
	var ss := {"kind": "obj", "cx": -8, "cz": 9, "dir": 0, "level": 0}
	var sk: String = b.place("sawmill", ss, b.evaluate("sawmill", ss).y)
	main.power.tick(0.25)
	check(not b.pieces[gk].running, "by day an idle generator stays off")
	inv.load_data({})
	inv.add("log", 4)
	check(main._prompt_for("machine:" + sk).contains("[E] Load log"), "the sawmill prompt: " + main._prompt_for("machine:" + sk).replace("\n", " / "))
	var r: Array = main.use_machine(sk)
	check(r[0] == 4 and b.pieces[sk].input == 4 and inv.count_of("log") == 0, "E loads the logs into it")
	main.power.tick(0.25)
	check(b.pieces[gk].running and b.pieces[sk].powered, "the generator starts up for it, by day")
	for i in 24:
		main.power.tick(0.25)
	check(b.pieces[sk].output == 5 and b.pieces[sk].input == 3, "a log becomes 5 wood in 6 s (%d)" % b.pieces[sk].output)
	data = main.collect_save_data()
	b.load_data([])
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(b.pieces.has(sk) and b.pieces[sk].output == 5 and b.pieces[sk].input == 3, "what is in a machine is saved")
	r = main.use_machine(sk)
	check(r[1] == 5 and inv.count_of("wood") == 5, "E takes the wood")
	# A crusher out of reach of power does nothing.
	var cs := {"kind": "obj", "cx": -14, "cz": 9, "dir": 0, "level": 0}
	var ck: String = b.place("crusher", cs, b.evaluate("crusher", cs).y)
	inv.add("stone", 6)
	main.use_machine(ck)
	for i in 70:
		main.power.tick(0.25)
	check(b.pieces[ck].output == 0 and main._prompt_for("machine:" + ck).contains("no power"), "a crusher without power waits")
	b.connect_cable(gk, ck)
	b.pieces[gk].fuel = 2.0
	for i in 70:
		main.power.tick(0.25)
	check(b.pieces[ck].output == 1 and b.pieces[ck].input == 3, "cabled up it grinds 3 stone into a cement bag in 15 s")
	# Demolishing gives the machine back in its crate.
	inv.load_data({})
	main.hammer_demolish(ck)
	main.hammer_demolish(ck)
	check(inv.count_of("kit_crusher") == 1, "demolished, the crusher goes back in its crate")
	# Log stakes.
	var ls := {"kind": "obj", "cx": -12, "cz": 12, "dir": 0, "level": 0}
	var lk: String = b.place("log_stakes", ls, b.evaluate("log_stakes", ls).y)
	check(b.PIECES.log_stakes.cost.has("log"), "log stakes are made of logs")
	var w = main.mutants.spawn("walker", b.pieces[lk].node.global_position)
	w.set_physics_process(false)
	main.traps.tick(0.1)
	check(w.health < 100.0, "log stakes bite a mutant on them (%.0f)" % w.health)
	main.mutants.clear()
	b.load_data([])
	inv.load_data({})
	main.day_night.restore(day, 10.0)
	# Build mode colours a weakly held piece.
	var bm = main.build_mode
	bm.can_build = true
	bm.support_preview = 90.0
	var solid = bm.ghost_material()
	bm.support_preview = 40.0
	var mid = bm.ghost_material()
	bm.support_preview = 22.0
	var weak = bm.ghost_material()
	check(solid != mid and mid != weak and weak != bm._bad_mat, "the preview goes green, yellow, orange as support drops")
	bm.support_preview = -INF
	bm.can_build = false


func Building_index(t: String) -> int:
	return main.building.ORDER.find(t)


## v1.8: cables and switches, powered turrets, gates closing at night, the lock.
func _test_wiring() -> void:
	var b = main.building
	var pw = main.power
	var inv = main.inventory
	var player = main.player
	main.terrain.load_data({})
	b.load_data([])
	inv.load_data({})
	var put := func(t: String, slot: Dictionary) -> String:
		return b.place(t, slot, b.evaluate(t, slot).y)
	var gk: String = put.call("generator", {"kind": "obj", "cx": -9, "cz": 2, "dir": 0})
	var sk: String = put.call("switch", {"kind": "obj", "cx": -9, "cz": 5, "dir": 0})
	var lk: String = put.call("floodlight", {"kind": "obj", "cx": -9, "cz": 8, "dir": 0})
	var plug: String = put.call("floodlight", {"kind": "obj", "cx": -8, "cz": 2, "dir": 0})
	var tk: String = put.call("turret", {"kind": "obj", "cx": -5, "cz": 5, "dir": 0})
	var ck: String = put.call("chest", {"kind": "obj", "cx": -7, "cz": 5, "dir": 0})
	b.pieces[gk].fuel = 5.0
	main.day_night.restore(main.day_night.day, 22.0)
	pw.tick(0.25)
	check(b.pieces[plug].powered, "a floodlight right next to a generator is plugged in")
	check(not b.pieces[lk].powered, "one further away needs a cable")
	# Laying cable by hand.
	inv.add("cable", 40)
	inv.selected = 0
	check(main.holding("cable"), "holding the cable")
	check(main.cable_click(ck) != "", "chests can't be cabled")
	check(main.cable_click(gk) == "" and main.cable_from == gk, "click the generator to start a cable")
	var cost: int = b.cable_cost(gk, sk)
	check(main.cable_click(sk) == "" and b.cables.size() == 1 and inv.count_of("cable") == 40 - cost, "then the switch to connect it (%d cable)" % cost)
	main.cable_click(sk)
	main.cable_click(lk)
	main.cable_click(sk)
	main.cable_click(tk)
	check(b.cables.size() == 3, "switch to floodlight and switch to turret (%d cables)" % b.cables.size())
	check(main.cable_prompt(lk).begins_with("Floodlight"), "cable prompt: " + main.cable_prompt(lk).replace("\n", " / "))
	pw.tick(0.25)
	check(not b.pieces[lk].powered and not b.pieces[tk].powered, "with the switch off, no power gets past it")
	check(main._prompt_for("switch:" + sk).begins_with("[E] Turn on"), "switch prompt: " + main._prompt_for("switch:" + sk))
	main.interact("switch:" + sk)
	check(b.pieces[sk].open and b.pieces[lk].powered and b.pieces[lk].light.visible and b.pieces[tk].powered, "switched on, the floodlight lights and the turret has power")
	var far := {"kind": "obj", "cx": -9, "cz": 22, "dir": 0}
	var fk2: String = put.call("floodlight", far)
	check(b.cable_problem(lk, fk2).begins_with("Too far"), "a cable can only be so long: " + b.cable_problem(lk, fk2))
	# Saved, and older saves get cables in the old reach.
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	check(data.cables.size() == 3, "cables are saved")
	main.apply_save_data(data)
	check(b.cables.size() == 3 and b.pieces[sk].open, "and loaded, switch still on")
	data.erase("cables")
	main.apply_save_data(data)
	check(b.cables.size() == 2 and b.cables.all(func(c): return gk in c), "older saves: the generator is cabled to both lights within 18 m (%d)" % b.cables.size())
	# Taking cables up gives the cable back.
	var had: int = inv.count_of("cable")
	check(main.cable_click(gk, true) == "" and b.cables_of(gk).is_empty() and inv.count_of("cable") > had, "right click takes up a piece's cables and gives them back")
	b.load_data([])
	# Gates close by themselves at night; the metal door locks.
	var gate := {"kind": "edge", "cx": -9, "cz": 4, "dir": 0}
	var dk: String = put.call("doorway", gate)
	b.set_gate(dk, true)
	player.position = Vector3(-30, main.terrain.surface_height(-30, 30), 30)
	main.day_night.restore(main.day_night.day, 12.0)
	pw.tick(b.AUTO_CLOSE + 1.0)
	check(b.pieces[dk].open, "by day an open gate stays open")
	main.day_night.restore(main.day_night.day, 22.0)
	player.global_position = b.pieces[dk].node.global_position
	pw.tick(1.0)
	check(b.pieces[dk].open, "at night it waits while you stand in it")
	player.position = Vector3(-30, main.terrain.surface_height(-30, 30), 30)
	pw.tick(1.0)
	check(not b.pieces[dk].open, "and closes by itself once you have gone")
	var md := {"kind": "edge", "cx": -7, "cz": 4, "dir": 0}
	var mk: String = put.call("metal_door", md)
	check(main.lock_door("gate:" + mk) and b.pieces[mk].locked, "R locks a shut metal door")
	main.interact("gate:" + mk)
	check(not b.pieces[mk].open and main._prompt_for("gate:" + mk).contains("locked"), "a locked door won't open")
	b.damage(mk, 200.0)
	check(is_equal_approx(b.pieces[mk].hp, 1300.0), "and takes half damage (%.0f)" % b.pieces[mk].hp)
	var bsave: Array = JSON.parse_string(JSON.stringify(b.save_data()))
	b.load_data(bsave)
	check(b.pieces[mk].get("locked", false), "the lock is saved")
	main.lock_door("gate:" + mk)
	main.interact("gate:" + mk)
	check(not b.pieces[mk].locked and b.pieces[mk].open, "unlocked, it opens")
	check(not main.lock_door("gate:" + mk) or b.pieces[mk].get("locked", false) == false, "an open door can't be locked")
	b.load_data([])
	inv.load_data({})
	main.day_night.restore(main.day_night.day, 12.0)


## v2.0 physics pass: knockback, stagger, blasts, falls, debris, shoves.
var phys := {}


## Weapon tuning and the instant effects of hits and shoves.
func _test_physics() -> void:
	var ms = main.mutants
	var W: Dictionary = main.melee.WEAPONS
	var G: Dictionary = main.guns.GUNS
	ms.clear()
	check(W.pipe.knock > W.axe.knock and W.axe.knock > W.machete.knock and W.pipe.stagger > W.machete.stagger, "the pipe shoves and staggers most, the machete least")
	check(G.shotgun.knock * G.shotgun.pellets > G.rifle.knock and G.rifle.knock > G.pistol.knock, "a full shotgun blast shoves more than a rifle round, a pistol least")
	var a = ms.spawn("walker", Vector3(70, 0, 70))
	var c = ms.spawn("walker", Vector3(74, 0, 70))
	a.take_hit(W.pipe.damage, a.global_position, Vector3.RIGHT, W.pipe.knock, W.pipe.stagger)
	c.take_hit(W.machete.damage, c.global_position, Vector3.RIGHT, W.machete.knock, W.machete.stagger)
	check(a.knock.x > c.knock.x * 2.0 and a.stagger_t > c.stagger_t, "a pipe hit knocks a walker back further and longer than a machete (%.1f / %.1f m/s)" % [a.knock.x, c.knock.x])
	c.state = c.State.ATTACK
	c._attack_t = 0.2
	c.take_hit(1.0, c.global_position, Vector3.RIGHT, 2.0, 0.4)
	check(c.state == c.State.CHASE and c._attack_t < 0.0, "a stagger cuts its swing short")
	var t: float = c.stagger_t
	c.take_hit(1.0, c.global_position, Vector3.RIGHT, 0.8, 0.0)
	check(is_equal_approx(c.stagger_t, t), "turret-style hits with no stagger don't stunlock it")
	var r = ms.spawn("runner", Vector3(78, 0, 70))
	r.take_hit(1.0, r.global_position, Vector3.RIGHT, 9.0, 9.0)
	check(r.stagger_t <= r.STAGGER_MAX + 0.001, "a stagger never lasts longer than %.1f s" % r.STAGGER_MAX)
	var br = ms.spawn("brute", Vector3(82, 0, 70))
	br.blast(br.global_position - Vector3(2, 0, 0), 11.0, 6.5, 1.2)
	a.blast(a.global_position - Vector3(2, 0, 0), 11.0, 6.5, 1.2)
	check(a.velocity.y > 5.0 and br.velocity.y < 2.0 and br.knock.x < a.knock.x * 0.4, "a blast throws a walker up and away, a brute barely moves")
	ms.clear()
	# A Brute's fist shoves you, a walker's claw a little, acid not at all.
	var p = main.player
	p.knock = Vector3.ZERO
	main.survival.health = 100.0
	main._on_player_hit(5.0, p.global_position + Vector3(-1, 0, 0), "spitter")
	check(p.knock == Vector3.ZERO, "acid doesn't shove you")
	main._on_player_hit(5.0, p.global_position + Vector3(-1, 0, 0), "walker")
	var wk: float = p.knock.x
	p.knock = Vector3.ZERO
	main._on_player_hit(5.0, p.global_position + Vector3(-1, 0, 0), "brute")
	check(wk > 0.5 and p.knock.x > wk * 3.0, "a brute's fist shoves you much harder than a walker's claw (%.1f / %.1f m/s)" % [p.knock.x, wk])
	p.knock = Vector3.ZERO
	p.velocity = Vector3.ZERO
	main.survival.health = 100.0


## Sets up the moving tests: walkers to hit, one dropped off a roof-high
## ledge, one from a step, a mine with walkers and debris round it, and you.
func _start_physics() -> void:
	var b = main.building
	var ms = main.mutants
	ms.clear()
	b.load_data([])
	main.terrain.load_data({})
	main.day_night.restore(main.day_night.day, 11.0)
	var slot := {"kind": "obj", "cx": -6, "cz": -10, "dir": 0, "level": 0}
	phys.mine_key = b.place("landmine", slot, b.evaluate("landmine", slot).y)
	var mine: Vector3 = b.pieces[phys.mine_key].node.global_position
	phys.mine = mine
	var pp := mine + Vector3(45, 0, 45)
	main.player.position = Vector3(pp.x, main.terrain.surface_height(pp.x, pp.z), pp.z)
	main.player.velocity = Vector3.ZERO
	main.player.knock = Vector3.ZERO
	phys.pipe = ms.spawn("walker", mine + Vector3(0, 0, 14))
	phys.machete = ms.spawn("walker", mine + Vector3(4, 0, 14))
	phys.near = ms.spawn("walker", mine + Vector3(3, 0, 0))     # 3 m from the mine
	phys.on = ms.spawn("walker", mine)                          # on it
	for k in ["high", "low"]:
		var at: Vector3 = mine + (Vector3(-10, 0, 14) if k == "high" else Vector3(-14, 0, 14))
		var w = ms.spawn("walker", at)
		w.global_position.y += 6.5 if k == "high" else 1.5
		phys[k] = w
	# A loose chunk of debris lying 2 m from the mine.
	var chunk := RigidBody3D.new()
	chunk.collision_layer = b.DEBRIS_LAYER
	chunk.collision_mask = 1
	chunk.mass = 4.0
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(0.4, 0.2, 0.3)
	chunk.add_child(col)
	main.add_child(chunk)
	chunk.add_to_group("debris")
	chunk.global_position = mine + Vector3(-2, 0.4, 0)
	phys.chunk = chunk
	main.survival.health = 100.0


func _kick_physics() -> void:
	var W: Dictionary = main.melee.WEAPONS
	for k in ["pipe", "machete"]:
		var w = phys[k]
		phys[k + "_from"] = w.global_position
		w.take_hit(W[k].damage, w.global_position + Vector3(0, 1, 0), Vector3.LEFT, W[k].knock, W[k].stagger)
	phys.near_from = phys.near.global_position
	phys.on_from = phys.on.global_position
	phys.chunk_from = phys.chunk.global_position
	phys.near_top = phys.near.global_position.y
	main.traps.detonate(phys.mine_key)
	var p = main.player
	phys.player_from = p.global_position
	main._on_player_hit(10.0, p.global_position + Vector3(-1, 0, 0), "brute")


func _check_knockback() -> void:
	var pipe: float = phys.pipe_from.x - phys.pipe.global_position.x
	var machete: float = phys.machete_from.x - phys.machete.global_position.x
	check(pipe > 0.5 and pipe > machete * 2.0, "a pipe hit knocks a walker back %.2f m, a machete %.2f m" % [pipe, machete])
	var near: Vector3 = phys.near.global_position - phys.near_from
	check(near.x > 1.0 and phys.near_top > phys.near_from.y + 0.1, "the mine throws a walker 3 m away up and back (%.1f m)" % near.x)


func _check_physics() -> void:
	var hi = phys.high
	var lo = phys.low
	check(hi.last_fall_damage > 50.0 and hi.health < 100.0 and not hi.is_dead(), "a walker falling 6.5 m off a roof gets hurt (%.0f damage)" % hi.last_fall_damage)
	check(is_equal_approx(lo.health, 100.0), "a 1.5 m drop doesn't hurt")
	var thrown: float = phys.on.global_position.distance_to(phys.on_from)
	check(phys.on.is_dead() and thrown > 0.5, "the walker on the mine is blown apart and its body thrown (%.1f m)" % thrown)
	var cm: float = phys.chunk.global_position.distance_to(phys.chunk_from)
	check(cm > 1.0, "the blast scatters loose debris (%.1f m)" % cm)
	var pm: float = main.player.global_position.x - phys.player_from.x
	check(pm > 1.0, "a brute's fist knocks you back (%.1f m)" % pm)
	check(main.player.knock.length() < 0.5, "and the shove fades out")
	phys.chunk.queue_free()
	main.mutants.clear()
	main.building.load_data([])
	main.survival.health = 100.0
	main.player.position = main.player.spawn_point


func _process(_delta: float) -> bool:
	frame += 1
	var player = main.player
	var terrain = main.terrain
	if frame > 2010 and frame < 2250 and not main.mutants.spits().is_empty():
		spit_seen = true
	if frame > 3920 and frame < 3990 and phys.has("near"):
		phys.near_top = maxf(phys.near_top, phys.near.global_position.y)
	if frame > 720 and frame < 811:
		ramp_top = maxf(ramp_top, player.position.y - ramp_base)
	match frame:
		2:
			check(main.has_method("collect_save_data") and player != null, "game scripts compiled and the world was built")
			if player == null:
				quit(1)
				return true
			check(terrain.get_child_count() >= 2, "terrain has mesh and collision")
			var mesh: Mesh = terrain.get_node("TerrainMesh").mesh
			var arrays := mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var down := 0
			for n in normals:
				if n.y < 0.0:
					down += 1
			check(down == 0, "all terrain normals face up (%d down)" % down)
			check(main.props.get_child_count() > 300, "props spawned (%d)" % main.props.get_child_count())
			check(main.props.wreck_positions.size() > 0, "wrecks placed")
		120:
			var ground: float = terrain.height_at(player.position.x, player.position.z)
			check(player.is_on_floor(), "player standing on the ground after spawn")
			check(absf(player.position.y - ground) < 1.0, "player at ground height (y=%.2f ground=%.2f)" % [player.position.y, ground])
			player.rotation.y = PI  # face away from the flag pole
			start_pos = player.position
			# The exact height sampler must match the collision surface.
			var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
			var worst := 0.0
			var hits := 0
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in 200:
				var x := rng.randf_range(-200, 200)
				var z := rng.randf_range(-200, 200)
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, 200, z), Vector3(x, -50, z))
				q.collision_mask = 1
				q.exclude = [main.player.get_rid()]
				var hit := space.intersect_ray(q)
				if hit and hit.collider == terrain:
					hits += 1
					worst = maxf(worst, absf(hit.position.y - terrain.surface_height(x, z)))
			check(hits > 150 and worst < 0.05, "surface_height matches terrain collision (%d hits, worst %.3f m)" % [hits, worst])
			Input.action_press("move_forward")
		300:
			Input.action_release("move_forward")
			var moved := Vector2(player.position.x - start_pos.x, player.position.z - start_pos.z).length()
			check(moved > 8.0, "player walked forward (%.1f m)" % moved)
			check(player.position.y > -1.0, "player did not fall through the world")
			# Teleport to the edge and push outward: must stay inside the ring.
			player.position = Vector3(0, terrain.height_at(0, -224) + 1.0, -224)
			player.velocity = Vector3.ZERO
			Input.action_press("move_forward")
			Input.action_press("sprint")
		480:
			Input.action_release("move_forward")
			Input.action_release("sprint")
			var r := Vector2(player.position.x, player.position.z).length()
			check(r <= terrain.PLAY_RADIUS + 0.5, "player kept inside play area (r=%.1f)" % r)
			check(player.stamina < player.STAMINA_MAX, "sprinting uses stamina")
			# Crouch.
			player.position = Vector3(0, terrain.surface_height(0, 12) + 0.5, 12)
			player.velocity = Vector3.ZERO
			Input.action_press("crouch")
		540:
			check(player.crouching and player.head.position.y < 1.2, "crouch lowers the view")
			Input.action_release("crouch")
		570:
			check(not player.crouching, "stands up again after crouch")
			# Day/night: fast-forward and count the events.
			main.day_night.dusk_started.connect(func(_d): events.append("dusk"))
			main.day_night.night_started.connect(func(_d): events.append("night"))
			main.day_night.day_started.connect(func(_d): events.append("day"))
			main.day_night.time_scale = 400.0
		700:
			main.day_night.time_scale = 1.0
			check(events == ["dusk", "night", "day"], "day/night cycle fires dusk, night, day (%s)" % str(events))
			check(main.day_night.day == 2, "day counter advanced to 2")
			# Pause menu.
			main.pause_menu.open()
			check(paused, "pause menu pauses the game")
			main.pause_menu.resume()
			check(not paused, "resume unpauses")
			# Save -> change state -> load restores it.
			player.position = Vector3(30, terrain.surface_height(30, -40) + 0.01, -40)
			player.rotation.y = 1.25
			main.day_night.restore(4, 21.5)
			check(game.save_game("test"), "save_game writes a slot")
			var data: Dictionary = game.read_slot("test")
			check(not data.is_empty() and int(data.world.day) == 4, "saved slot reads back (day 4)")
			check(game.describe_slot("test").contains("Day 4 21:30"), "slot description: " + game.describe_slot("test"))
			player.position = Vector3(0, 50, 0)
			player.rotation.y = 0.0
			main.day_night.restore(1, 8.0)
			main.apply_save_data(data)
			check(player.position.distance_to(Vector3(30, terrain.surface_height(30, -40), -40)) < 0.1, "load restores player position")
			check(absf(player.rotation.y - 1.25) < 0.001, "load restores facing")
			check(main.day_night.day == 4 and absf(main.day_night.hour - 21.5) < 0.01, "load restores day and time")
			check(main.day_night.is_night(), "restored time is night")
			game.delete_slot("test")
			check(game.read_slot("test").is_empty(), "slot deleted")
			_test_loot()
			check(game.read_slot("does_not_exist").is_empty(), "missing slot reads as empty")
			# Title screen builds without errors.
			title = load("res://scenes/title.tscn").instantiate()
			root.add_child(title)
		705:
			main.map_ui.toggle()
			check(not main.map_ui.is_open(), "map closes")
		710:
			check(title.world.menu_mode and title.world.player == null, "title screen shows the world without a player")
			check(title._col.get_child_count() >= 5, "title menu has its buttons")
			title.queue_free()
		720:
			_start_ramp_walk()
		811:
			Input.action_release("move_forward")
			check(ramp_top > 1.8, "the player can walk up a ramp (climbed %.2f m)" % ramp_top)
			main.building.load_data([])
			_start_chase()
		900:
			var d: float = chase_walker.global_position.distance_to(main.player.global_position)
			check(chase_walker.state != chase_walker.State.WANDER and d < 8.0, "the walker spots you and chases (%.1f m away)" % d)
		1100:
			check(main.survival.health < 100.0, "the walker reaches you and claws (health %.0f)" % main.survival.health)
			_test_walker_hits()
			main.mutants.clear()
			main.survival.health = 100.0
			_test_waves()
		1220:
			var d := Vector2(march_walker.position.x, march_walker.position.z).length()
			check(d < 38.0, "a wave mutant marches on the base (%.1f m from the flag, started at 40)" % d)
			main.mutants.clear()
			_test_breaking()
			_start_break_in()
		1500:
			var b = main.building
			check(chase_walker.state == chase_walker.State.BREAK and chase_walker.break_key == break_wall, "a mutant blocked by a wall claws at it (state %d)" % chase_walker.state)
			check(b.pieces.has(break_wall) and b.pieces[break_wall].hp < 60.0, "the wall takes damage (%.0f hp)" % b.pieces.get(break_wall, {}).get("hp", 0.0))
			check(main.survival.health >= 100.0, "it can't claw you through the wall (health %.0f)" % main.survival.health)
		1800:
			check(not main.building.pieces.has(break_wall), "the wall breaks")
			check(main.building.get_children().any(func(c): return c is CPUParticles3D), "a broken wall leaves dust and debris")
		2000:
			check(main.survival.health < 100.0, "then the mutant gets through to you (health %.0f)" % main.survival.health)
			main.mutants.clear()
			main.building.load_data([])
			main.survival.health = 100.0
			_test_types()
			_start_spitter()
		2250:
			check(spit_seen, "the spitter lobs acid from a distance")
			check(main.survival.health < 100.0, "the acid burns you (health %.0f)" % main.survival.health)
			var d: float = chase_walker.global_position.distance_to(main.player.global_position)
			check(d > 5.0, "the spitter keeps its distance (%.1f m)" % d)
			main.mutants.clear()
			main.survival.health = 100.0
			var py: float = main.terrain.surface_height(8, -8)
			main.player.position = Vector3(8, py, -8)
			chase_walker = main.mutants.spawn("runner", Vector3(8, 0, -28))
			chase_walker.make_hunter(Vector3.ZERO)
			chase_walker.rotation.y = PI
		2350:
			var d: float = chase_walker.global_position.distance_to(main.player.global_position)
			check(d < 13.0, "a runner closes 20 m in under 2 seconds (%.1f m left)" % d)
			main.mutants.clear()
			main.survival.health = 100.0
			_test_pistol()
			var p = main.player
			p.position = Vector3(30, main.terrain.surface_height(30, -30), -30)
			p.rotation.y = 0.0
			chase_walker = main.mutants.spawn("walker", Vector3(30, 0, -44))
			chase_walker.rotation.y = 0.0  # looking away
			chase_walker.set_physics_process(false)
		2362:
			_test_long_guns()
			_test_traps()
			_test_power()
			_test_shop()
			_test_drone()
			_test_upgrades()
			_test_screen_fit()
			_test_difficulty_and_hints()
		2370:
			_start_turret()
		2490:
			var b = main.building
			var rec: Dictionary = b.pieces[turret_key]
			check(turret_near.health < 100.0, "the turret shoots a walker 12 m away (%.0f left)" % turret_near.health)
			check(rec.ammo < 30, "using rounds from its ammo box (%d left)" % rec.ammo)
			check(is_equal_approx(turret_far.health, 100.0), "but leaves one 30 m away alone")
			main.mutants.clear()
			rec.ammo = 0
			turret_near = main.mutants.spawn("walker", rec.node.global_position + Vector3(0, 0, -8))
			turret_near.set_physics_process(false)
		2560:
			check(is_equal_approx(turret_near.health, 100.0), "an empty turret doesn't shoot")
			main.mutants.clear()
			main.building.load_data([])
		2570:
			_test_digging()
		2640:
			_check_digging()
		2650:
			_start_pits()
		3130:
			_check_pits()
		3135:
			_test_trench_pieces()
			_test_mining()
			_test_well()
			_test_stability()
			_test_more_pieces_2()
			_test_fast_building()
			_test_wiring()
			_test_building_v19()
			_test_blueprint_tiers()
			_test_resources()
			_test_water()
			_test_farming()
			_test_market()
			_start_ladder()
		3300:
			_check_debris()
			_check_ladder()
			_test_nav()
			_start_nav_walk()
		3900:
			_check_nav_walk()
			_test_physics()
			_start_physics()
		3920:
			_kick_physics()
		3950:
			_check_knockback()
		4010:
			_check_physics()
			_test_life()
			_start_life()
		4070:
			_check_life()
			_test_livable()
			_test_oases()
			_test_goals()
		4080:
			_test_throwables()
			_start_throws()
		4270:
			_check_throws()
			_test_survival_depth()
			_test_crafting_chain()
			_test_events()
			_start_shelter()
		4280:
			_check_shelter()
		4290:
			for e in catcher.errors:
				print("  ERROR ", e)
			check(catcher.errors.is_empty(), "Godot reported no errors while the tests ran (%d)" % catcher.errors.size())
			if failures.is_empty():
				print("== ALL TESTS PASSED ==")
				quit(0)
			else:
				print("== %d TEST(S) FAILED ==" % failures.size())
				quit(1)
	return false


## v1.13: the main well, the watering can, soil turning green, pipes and sprinklers.
func _test_water() -> void:
	var w = main.water
	var b = main.building
	var inv = main.inventory
	var sh = main.shop
	var player = main.player
	var W = load("res://scripts/water.gd")
	b.load_data([])
	inv.load_data({})
	main.mutants.clear()
	for id in sh.upgrades:
		sh.upgrades[id] = 0
	main.apply_upgrades()
	w.load_data({})
	check(w.well.position.distance_to(Vector3(0, w.well.position.y, 0)) < 5.0, "the main well stands by the flag (%s)" % str(w.well.position))
	check(is_equal_approx(w.store, W.STORE_BASE) and w.cells.is_empty(), "it starts full (%d L) and the sand is dry" % int(w.store))
	# Look at it.
	player.position = Vector3(w.well.position.x, w.well.position.y, w.well.position.z + 2.6)
	player.rotation.y = 0.0
	player.head.rotation.x = -0.5
	player.head.position.y = player.EYE_HEIGHT
	check(player.interact_target() == "mainwell", "the crosshair finds the main well (%s)" % player.interact_target())
	check(main._prompt_for("mainwell").contains("You need a watering can"), "without a can: " + main._prompt_for("mainwell").replace("\n", " / "))
	check(w.use_well() == 0.0, "and E gives nothing")
	inv.add("watering_can", 1)
	check(main._prompt_for("mainwell").contains("[E] Fill the watering can"), "with a can: " + main._prompt_for("mainwell").replace("\n", " / "))
	main.interact("mainwell")
	check(is_equal_approx(w.can, W.CAN_MAX) and is_equal_approx(w.store, W.STORE_BASE - W.CAN_MAX), "E fills the can (%.0f L) from the well (%.0f L left)" % [w.can, w.store])
	check(main._prompt_for("mainwell").contains("is full"), "a full can says so")
	# Pour on the sand.
	var p := Vector3(14.5, 0, 14.5)
	var c: Vector2i = W.cell_of(p.x, p.z)
	check(w.ground_prompt(p).begins_with("Dry sand"), "dry sand: " + w.ground_prompt(p).replace("\n", " / "))
	check(w.pour(p) == "" and is_equal_approx(w.can, W.CAN_MAX - W.POUR), "a pour uses %.0f L of the can" % W.POUR)
	check(not w.is_soil(c) and w.ground_prompt(p).begins_with("Damp sand"), "damp sand isn't soil yet: " + w.ground_prompt(p).replace("\n", " / "))
	w.pour(p)
	w.pour(p)
	check(w.is_soil(c) and w.soil_count() == 1, "%.0f L turns the square to soil" % W.SOIL_NEED)
	w.pour(p)
	check(w.pour(p) == "This ground is soaked for today" and is_equal_approx(w.cell_info(c).wet, W.WET_MAX), "a square soaks up %.0f L a day at most" % W.WET_MAX)
	check(is_equal_approx(w.can, 2.0), "the can has 2 L left")
	# Another square only gets a little.
	var p2 := Vector3(22.5, 0, 14.5)
	var c2: Vector2i = W.cell_of(p2.x, p2.z)
	w.pour(p2)
	check(w.pour(p2).begins_with("The watering can is empty"), "an empty can says where to fill it")
	w.redraw()
	check(w._soil.mesh != null and w._grass.multimesh.instance_count == 0, "soil shows on the ground, no grass yet")
	main.day_night.day_started.emit(main.day_night.day)
	check(is_equal_approx(w.green_of(c), W.GROW) and is_equal_approx(w.cell_info(c).wet, 0.0), "next morning the watered soil is greener (%.2f) and dry again" % w.green_of(c))
	check(w.green_of(c2) == 0.0 and not w.is_soil(c2), "the damp sand next to it didn't green")
	check(is_equal_approx(w.store, W.STORE_BASE), "and the main well is full again")
	w.redraw()
	check(w._grass.multimesh.instance_count > 0, "grass comes up (%d tufts)" % w._grass.multimesh.instance_count)
	for i in 6:
		w.water_cell(c, W.DAY_NEED)
		w.on_morning()
	check(is_equal_approx(w.green_of(c), 1.0), "five well-watered mornings make it fully green")
	w.redraw()
	check(w._plants.multimesh.instance_count > 0, "with small plants (%d)" % w._plants.multimesh.instance_count)
	w.on_morning()
	check(is_equal_approx(w.green_of(c), 1.0 - W.WILT), "a dry morning wilts it a little (%.2f)" % w.green_of(c))
	# Saved.
	w.can = 4.0
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	w.load_data({})
	check(w.cells.is_empty() and w.can == 0.0, "an old save has dry sand and an empty can")
	w.load_data({"store": "lots", "can": null, "cells": [[1, 2, "x", 9.0, 0.5, 0], "junk", [3]], "pipes": 7})
	check(is_equal_approx(w.store, W.STORE_BASE) and w.can == 0.0 and w.cells.size() == 1 and w.pipes.is_empty(), "a broken save loads with sensible defaults")
	main.apply_save_data(data)
	check(is_equal_approx(w.green_of(c), 1.0 - W.WILT) and w.is_soil(c) and is_equal_approx(w.can, 4.0), "soil, green and the can are saved")
	# Bare soil left dry goes back to sand.
	w.cells = {}
	w.water_cell(c2, W.SOIL_NEED)
	w.cells[c2].wet = 0.0
	for i in W.SAND_DAYS:
		w.on_morning()
	check(not w.cells.has(c2), "bare soil dry for %d mornings is sand again" % W.SAND_DAYS)
	# Sprinklers and pipes.
	w.cells = {}
	sh.cash = 2000
	var ss := {"kind": "obj", "cx": 4, "cz": 4, "dir": 0}  # centre (9, 9)
	var ev: Dictionary = b.evaluate("sprinkler", ss)
	check(ev.ok, "a sprinkler can be built in the base (%s)" % ev.reason)
	var sk: String = b.place("sprinkler", ss, ev.y)
	check(w.sprinkler_prompt(sk).contains("no hand pump"), "it needs the hand pump: " + w.sprinkler_prompt(sk).replace("\n", " / "))
	check(sh.buy_upgrade("pump") and w.pump and w._pump_node.visible, "the hand pump upgrade puts a pump on the well")
	check(w.sprinkler_prompt(sk).contains("lay a water pipe"), "then it needs a pipe: " + w.sprinkler_prompt(sk).replace("\n", " / "))
	inv.add("water_pipe", 3)
	var cost: int = w.pipe_cost("main", sk)
	check(w.pipe_click("main") == "" and w.pipe_from == "main", "click the well to start a pipe")
	check(w.pipe_click(sk).begins_with("Not enough water pipe"), "a %d-pipe run needs the pipes" % cost)
	inv.add("water_pipe", 20)
	w.pipe_click(sk)
	check(w.pipes.size() == 1 and inv.count_of("water_pipe") == 23 - cost and w.fed_sprinklers().has(sk), "then a sprinkler is piped to it (%d pipes)" % cost)
	check(w.sprinkler_prompt(sk).begins_with("Sprinkler: watering"), "and waters: " + w.sprinkler_prompt(sk).replace("\n", " / "))
	var near: Array = W.spray_cells(b.pieces[sk].node.global_position)
	check(near.size() >= 4, "it covers %d squares" % near.size())
	w.tick(0.5, true)
	w.tick(0.6, false)
	check(w.cells.is_empty(), "not at night")
	var before: float = w.store
	w.tick(50.0, true)
	var wet: float = w.cell_info(near[0]).wet
	check(is_equal_approx(wet, 1.0) and is_equal_approx(before - w.store, near.size() * 1.0), "by day it waters every square round it (%.2f L each, %.1f L from the well)" % [wet, before - w.store])
	check(b.pieces[sk].spray.emitting, "throwing droplets")
	w.tick(1000.0, true)
	check(is_equal_approx(w.cell_info(near[0]).wet, W.SPRAY_TO), "up to %.0f L a square a day" % W.SPRAY_TO)
	before = w.store
	w.tick(10.0, true)
	check(is_equal_approx(before, w.store) and not b.pieces[sk].spray.emitting, "then it stops using water")
	main.interact("sprinkler:" + sk)
	check(w.sprinkler_prompt(sk).contains("turned off"), "E turns it off")
	# A second sprinkler chained on from the first, too far for one pipe from the well.
	var ss2 := {"kind": "obj", "cx": 12, "cz": 4, "dir": 0}  # centre (25, 9), 24.2 m from the well
	var sk2: String = b.place("sprinkler", ss2, ev.y)
	check(w.pipe_problem("main", sk2).begins_with("Too far"), "a pipe is %d m at most" % int(W.PIPE_MAX))
	check(w.connect_pipe(sk, sk2) and w.fed_sprinklers().has(sk2), "sprinklers pass water on to the next")
	data = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	w.pipes = []
	main.apply_save_data(data)
	check(w.pipes.size() == 2 and not b.pieces[sk].open and b.pieces[sk2].open, "pipes and the valve are saved")
	b.remove(sk)
	w.prune_pipes()
	check(w.pipes.is_empty(), "taking a sprinkler down takes its pipes")
	check(sh.buy_upgrade("well") and is_equal_approx(w.capacity, 350.0), "deepening the main well holds more (%.0f L)" % w.capacity)
	w.on_morning()
	check(is_equal_approx(w.store, 350.0), "and fills it each morning")
	# Clean up.
	for id in sh.upgrades:
		sh.upgrades[id] = 0
	main.apply_upgrades()
	b.load_data([])
	w.load_data({})
	inv.load_data({})


## v1.14: seeds, seed beds, growing over days with water, the midday heat, harvests.
func _test_farming() -> void:
	var f = main.farming
	var w = main.water
	var inv = main.inventory
	var player = main.player
	var F = load("res://scripts/farming.gd")
	var W = load("res://scripts/water.gd")
	var Items = load("res://scripts/items.gd")
	var Shop = load("res://scripts/shop.gd")
	main.building.load_data([])
	main.mutants.clear()
	inv.load_data({})
	w.load_data({})
	f.load_data({})
	# Seeds by drone, for every crop.
	var seeds := {}
	for e in Shop.DRONE:
		for item in e.items:
			if F.crop_of_seed(item) != "":
				seeds[F.crop_of_seed(item)] = true
	check(seeds.size() == F.CROPS.size(), "the drone sells seeds for all %d crops" % seeds.size())
	var kinds := {}
	for c in F.CROPS:
		kinds[F.CROPS[c].kind] = true
		for item in F.CROPS[c].yield:
			if not Items.ITEMS.has(item) or not Items.ITEMS.has(F.seed_of(c)):
				check(false, "%s's seed and harvest (%s) are real items" % [c, item])
	check(kinds.size() == 5, "crops of every kind: food, resource, flower, fruit tree, exotic")
	# Planting needs soil.
	var p := Vector3(14.5, 0, 14.5)
	p.y = main.terrain.surface_height(p.x, p.z)
	var s: Vector2i = F.spot_of(p.x, p.z)
	var c: Vector2i = F.cell_of_spot(s)
	check(f.plant(p, "millet").begins_with("You have no"), "no seeds, no planting")
	inv.add("seed_millet", 3)
	check(f.plant(p, "millet").begins_with("Seeds need soil"), "seeds don't go in sand: " + f.plant(p, "millet"))
	w.water_cell(c, W.SOIL_NEED)
	check(f.plant(p, "millet") == "" and f.plants.has(s) and inv.count_of("seed_millet") == 2, "on soil a seed bed is dug and planted (one seed used)")
	check(f.plant(p, "millet") == "There is already a plant here", "one plant to a bed")
	check(f.plant_problem(Vector3(W.WELL_POS.x, 0, W.WELL_POS.y)) != "", "not in the main well")
	w.cells[c].wet = 0.0
	check(f.plant_prompt(s).contains("day 1 of 3") and f.plant_prompt(s).contains("needs 4 L"), "its prompt: " + f.plant_prompt(s).replace("\n", " / "))
	# Growing a day per watered morning.
	w.on_morning()
	check(f.plants[s].grow == 0.0, "a dry day: no growth")
	w.water_cell(c, 4.0)
	check(f.plant_prompt(s).contains("watered today"), "watered: " + f.plant_prompt(s).replace("\n", " / "))
	w.on_morning()
	check(is_equal_approx(f.plants[s].grow, 1.0), "a watered day: one day grown")
	for i in 2:
		w.water_cell(c, 4.0)
		w.on_morning()
	check(f.is_ripe(f.plants[s]) and f.plant_prompt(s).contains("[E] Harvest (4 millet)"), "ripe after 3 days: " + f.plant_prompt(s).replace("\n", " / "))
	f.redraw()
	check(f._beds.multimesh.instance_count == 1 and f._stalks.multimesh.instance_count >= 6, "a bed and stalks are drawn")
	# Harvest by looking at it and pressing E.
	var cc: Vector2 = F.spot_center(s)
	var g: float = main.terrain.surface_height(cc.x, cc.y)
	player.position = Vector3(cc.x, g, cc.y + 2.4)
	player.rotation.y = 0.0
	player.head.rotation.x = -0.55
	player.head.position.y = player.EYE_HEIGHT
	check(f.look_spot() == s, "the crosshair finds the plant (%s)" % str(f.look_spot()))
	main.interact("")
	check(inv.count_of("millet") == 4 and not f.plants.has(s), "E harvests 4 millet and the bed is free again")
	var food0: float = main.survival.food
	main.survival.food = 50.0
	main.survival.consume("millet")
	check(main.survival.food > 50.0, "millet is food")
	main.survival.food = food0
	# The midday heat.
	f.plant(p, "millet")
	w.cells[c].wet = 0.0
	main.day_night.hour_changed.emit(main.day_night.day, F.HEAT_HOUR)
	check(is_equal_approx(f.plants[s].hp, 1.0 - F.HEAT_HARM) and f.plant_prompt(s).contains("wilting"), "a dry plant wilts in the midday heat")
	f.midday()
	check(f.plants[s].dead and f.plant_prompt(s).begins_with("Dead millet"), "a second dry midday kills it: " + f.plant_prompt(s).replace("\n", " / "))
	f.harvest(s)
	check(not f.plants.has(s), "E clears a dead plant")
	f.plant(p, "millet")
	w.water_cell(c, 4.0)
	f.midday()
	check(is_equal_approx(f.plants[s].hp, 1.0), "watered before noon: no harm")
	f.plants.erase(s)
	# Agave is hardy; saffron needs shade and hates too much water.
	var s2: Vector2i = s + Vector2i(-1, 0)  # the other bed on the same square
	var p2 := Vector3(F.spot_center(s2).x, 0, F.spot_center(s2).y)
	inv.add("seed_agave", 1)
	inv.add("seed_saffron", 1)
	w.cells[c].wet = 0.0
	f.plant(p, "agave")
	f.plant(p2, "saffron")
	f.midday()
	check(is_equal_approx(f.plants[s].hp, 1.0), "agave doesn't mind the heat")
	check(f.plants[s2].dead, "saffron, dry and in the sun, is hurt twice over and dies")
	f.plants[s2].dead = false
	f.plants[s2].hp = 1.0
	w.water_cell(c, 4.0)
	check(f.plant_prompt(s2).contains("needs shade"), "saffron wants shade: " + f.plant_prompt(s2).replace("\n", " / "))
	f.midday()
	check(is_equal_approx(f.plants[s2].hp, 1.0 - F.HEAT_HARM), "watered but in the sun it is still hurt")
	w.water_cell(c, 3.0)
	f.plants[s2].hp = 1.0
	w.on_morning()
	check(f.plants[s2].grow == 0.0 and f.plants[s2].hp < 1.0, "saffron rots with more than 6 L a day")
	f.plants.erase(s)
	f.plants.erase(s2)
	# Flowers make crops near them grow faster and come back after picking.
	inv.add("seed_marigold", 1)
	inv.add("seed_millet", 1)
	f.plant(p, "marigold")
	f.plant(p2, "millet")
	for i in 2:
		w.water_cell(c, 4.0)
		w.on_morning()
	check(f.is_ripe(f.plants[s]) and is_equal_approx(f.plants[s2].grow, 2.0), "marigolds bloom in 2 days")
	w.cells[c].green = 0.2
	var green0: float = w.green_of(c)
	w.water_cell(c, 4.0)
	w.on_morning()
	check(is_equal_approx(f.plants[s2].grow, 3.0) or f.is_ripe(f.plants[s2]), "the millet next to them grows faster (%.1f)" % f.plants[s2].grow)
	check(w.green_of(c) > green0 + W.GROW + 0.05, "and the soil round blooming flowers greens faster (%.2f to %.2f)" % [green0, w.green_of(c)])
	var got: Dictionary = f.harvest(s)
	check(got.get("flowers", 0) == 2 and f.plants.has(s) and f.plants[s].fruited and not f.is_ripe(f.plants[s]), "picked marigolds grow back")
	f.plants.erase(s)
	f.plants.erase(s2)
	# A grown date palm shades saffron and spreads soil round it.
	inv.add("seed_date_palm", 1)
	f.plant(p, "date_palm")
	f.plants[s].grow = float(F.CROPS.date_palm.days)
	inv.add("seed_saffron", 1)
	f.plant(p2, "saffron")
	check(f.shaded(s2), "a grown date palm shades the saffron beside it")
	var far: Vector2i = c + Vector2i(1, 1)
	check(not w.is_soil(far), "the sand beyond is dry")
	for i in int(W.SOIL_NEED / F.TREE_SOIL):
		w.on_morning()
	check(w.is_soil(far), "after %d mornings the palm has turned the sand round it to soil" % int(W.SOIL_NEED / F.TREE_SOIL))
	check(f.harvest(s).get("dates", 0) == 4 and f.plants[s].fruited, "it gives dates and keeps fruiting")
	for i in 3:
		f.midday()
	check(not f.plants[s].dead, "a grown palm survives dry middays")
	# Saved.
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	var n: int = f.plants.size()
	f.load_data({})
	check(f.plants.is_empty(), "an old save has no plants")
	f.load_data({"plants": [[1, 2, "millet", "x", null, 0, 0], [1, 2, "triffid", 1, 1, false, false], "junk", 5]})
	check(f.plants.size() == 1 and f.plants[Vector2i(1, 2)].grow == 0.0 and f.plants[Vector2i(1, 2)].hp == 1.0, "a broken save loads with sensible defaults")
	main.apply_save_data(data)
	check(f.plants.size() == n and f.plants[s].crop == "date_palm" and f.plants[s].fruited, "plants, growth and fruiting are saved")
	# Digging uproots.
	f.on_ground_changed(Rect2(cc.x - 0.5, cc.y - 0.5, 1.0, 1.0))
	check(not f.plants.has(s) and f.plants.has(s2), "digging a bed up uproots its plant only")
	# Crafting and the test boxes.
	inv.load_data({})
	inv.add("cotton", 3)
	Items.craft("cloth", inv)
	check(inv.count_of("cloth") == 2, "3 cotton spin into 2 cloth")
	main.open_test_box(1)
	check(main.test_storage.count_of("seed_dragon_fruit") > 0, "the second test box holds the newer items (seeds)")
	main.inventory_ui.close()
	f.load_data({})
	w.load_data({})
	inv.load_data({})


## v1.15: the market at the shop terminal: daily prices, gluts, selling and buying food.
func _test_market() -> void:
	var m = main.market
	var shop = main.shop
	var inv = main.inventory
	var ui = main.shop_ui
	var Market = load("res://scripts/market.gd")
	var Items = load("res://scripts/items.gd")
	var F = load("res://scripts/farming.gd")
	inv.load_data({})
	m.load_data({}, 3)
	# Every harvest has a buyer, and exotic crops are worth the most.
	var missing: Array = []
	for c in F.CROPS:
		for item in F.CROPS[c].yield:
			if not Market.GOODS.has(item):
				missing.append(item)
	check(missing.is_empty(), "the market buys every harvest %s" % [missing])
	for item in Market.GOODS:
		if not Items.ITEMS.has(item):
			check(false, "market good %s is a real item" % item)
	var top := 0
	for item in Market.GOODS:
		if item != "saffron" and item != "dragon_fruit":
			top = maxi(top, Market.GOODS[item].base)
	check(Market.GOODS.saffron.base > Market.GOODS.dragon_fruit.base and Market.GOODS.dragon_fruit.base > top, "exotic crops are worth the most")
	check(Market.GOODS.rope.base * 1 > Market.GOODS.fibre.base * 3, "rope sells for more than the fibre it is made of")
	# Daily prices: repeatable for a seed and day, different on other days.
	var p3: int = m.price("saffron")
	var m2 = Market.new()
	m2.world_seed = m.world_seed
	m2.day = 3
	check(m2.price("saffron") == p3, "the same world and day give the same price ($%d)" % p3)
	var seen := {}
	for d in range(1, 11):
		m2.day = d
		seen[m2.price("saffron")] = true
		var f: float = m2.daily_factor("millet")
		if f < 0.7 or f > 1.3:
			check(false, "daily millet price stays within its swing (%.2f)" % f)
	check(seen.size() >= 4, "saffron's price changes from day to day (%d prices in 10 days)" % seen.size())
	# Selling: cash in, items out, the price drops with each one sold.
	shop.cash = 0
	inv.add("millet", 30)
	var first: int = m.price("millet")
	var all_value: int = m.sale_value("millet", 30)
	check(all_value < first * 30, "selling a lot gets less than the first price for each ($%d for 30)" % all_value)
	var got: int = m.sell("millet", 10, inv, shop)
	check(got > 0 and shop.cash == got and inv.count_of("millet") == 20, "selling 10 millet pays $%d and takes them" % got)
	check(m.price("millet") < first, "the millet price drops after selling ($%d to $%d)" % [first, m.price("millet")])
	check(m.sell("millet", 99, inv, shop) > 0 and inv.count_of("millet") == 0, "you can only sell what you have")
	check(m.sell("millet", 1, inv, shop) == 0, "nothing left, nothing sold")
	check(m.sell("scrap", 1, inv, shop) == 0 and m.price("scrap") == 0, "the market doesn't buy scrap")
	var low: int = m.price("millet")
	m.on_morning(4)
	m.day = 3  # same day's prices, to see only the glut wear off
	check(m.price("millet") > low, "the glut wears off overnight ($%d to $%d)" % [low, m.price("millet")])
	for i in 10:
		m.on_morning(4 + i)
	check(not m.glut.has("millet"), "after a few days it is gone")
	# Saved, and broken saves load.
	m.day = 3
	m.glut = {"melon": 12.0}
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	m.glut = {}
	main.apply_save_data(data)
	check(is_equal_approx(float(m.glut.get("melon", 0.0)), 12.0), "the glut is saved")
	check(m.day == main.day_night.day, "loading sets today's prices from the saved day")
	m.load_data({"glut": {"melon": "lots", "triffid": 3, "dates": -4, "rope": 2}}, 2)
	check(m.glut.size() == 1 and m.glut.has("rope"), "a broken market save loads what it can")
	m.load_data({"glut": "junk"}, 2)
	check(m.glut.is_empty(), "a junk market save loads empty")
	# Buying food.
	inv.load_data({})
	shop.cash = 0
	check(not m.buy("melon", inv, shop), "no cash, no melon")
	shop.cash = 100
	var bp: int = m.buy_price("melon")
	check(bp >= Market.GOODS.melon.base, "food costs more to buy than it sells for ($%d)" % bp)
	check(m.buy("melon", inv, shop) and inv.count_of("melon") == 1 and shop.cash == 100 - bp, "buying a melon takes $%d" % bp)
	check(not m.buy("saffron", inv, shop), "the market doesn't sell saffron")
	# The shop screen's market page.
	inv.load_data({})
	inv.add("dates", 8)
	shop.cash = 0
	ui.open()
	ui.show_page(3)
	var row: Dictionary = ui.market_rows["dates"]
	check(ui._market_page.visible and not ui._counter.visible, "the market tab shows the market page")
	check(row.name.text.contains("8") and not row.all.disabled and ui.market_rows["saffron"].all.disabled, "rows show what you have: " + row.name.text)
	var expect: int = m.sale_value("dates", 8)
	check(row.all.text.contains("$%d" % expect), "sell all shows the total: " + row.all.text)
	row.all.pressed.emit()
	check(inv.count_of("dates") == 0 and shop.cash == expect, "the sell all button sells them ($%d)" % shop.cash)
	check(ui.market_buy_buttons.size() == Market.FOR_SALE.size(), "the market sells %d foods" % ui.market_buy_buttons.size())
	ui.close()
	inv.load_data({})
	m.load_data({}, main.day_night.day)


## v1.16: animals drawn by green land and water, hunting, cooking, and mutants
## drawn to the main well and the fields.
func _test_life() -> void:
	var an = main.animals
	var rd = main.raids
	var w = main.water
	var f = main.farming
	var inv = main.inventory
	var player = main.player
	var A = load("res://scripts/animals.gd")
	var Animal = load("res://scripts/animal.gd")
	var R = load("res://scripts/raids.gd")
	var W = load("res://scripts/water.gd")
	var F = load("res://scripts/farming.gd")
	var Waves = load("res://scripts/waves.gd")
	var Items = load("res://scripts/items.gd")
	main.building.load_data([])
	main.mutants.clear()
	an.clear()
	inv.load_data({})
	w.load_data({})
	f.load_data({})
	main.day_night.restore(main.day_night.day, 10.0)
	player.position = Vector3(0, main.terrain.surface_height(0, 60) + 0.1, 60)
	# How many animals the land draws.
	check(A.wanted(0.0).values().all(func(n): return n == 0), "dead sand draws no animals")
	var wd: Dictionary = A.wanted(12.0)
	check(wd.gazelle == 3 and wd.jackal == 1 and wd.bird == 6, "12 green draws 3 gazelles, a jackal and 6 birds (%s)" % str(wd))
	var big: Dictionary = A.wanted(500.0)
	check(big.gazelle + big.jackal == A.MAX_GROUND and big.bird == A.MAX_BIRDS, "and no more than %d grazers and %d birds" % [A.MAX_GROUND, A.MAX_BIRDS])
	check(an.try_spawn(10.0) == "" and an.alive().is_empty(), "no green, no animals")
	# Green some land by the base.
	for x in range(2, 6):
		for z in range(2, 5):
			var c := Vector2i(x, z)
			w.water_cell(c, W.SOIL_NEED)
			w.cells[c].green = 1.0
	check(is_equal_approx(w.green_total(), 12.0) and an.life_score() >= 12.0, "12 green squares give a life score of %.1f" % an.life_score())
	check(an.try_spawn(20.0) == "", "no animals come in at night")
	an.day = 4
	an.spawned_today = 0
	check(an.try_spawn(10.0) == "gazelle" and an.count_of("gazelle") == 1, "by day a gazelle comes in")
	var g = an.alive()[0]
	var first: Vector3 = g.position
	var first_goal: Vector3 = g.goal
	check(Vector2(g.position.x, g.position.z).length() > A.SPAWN_MIN - 5.0, "from out in the desert (%.0f m)" % Vector2(g.position.x, g.position.z).length())
	var well: Vector3 = R.well_goal()
	var on_green: bool = w.cells.keys().any(func(c): return W.cell_center(c).distance_to(Vector2(g.goal.x, g.goal.z)) < 4.5)
	check(on_green or Vector2(g.goal.x - well.x, g.goal.z - well.z).length() < 6.0, "heading for the green land or the main well")
	an.clear()
	an.spawned_today = 0
	an.try_spawn(10.0)
	check(an.alive()[0].position.is_equal_approx(first) and an.alive()[0].goal.is_equal_approx(first_goal), "the same world and day bring the same animal")
	var kinds := []
	for i in 12:
		var k: String = an.try_spawn(10.0)
		if k != "":
			kinds.append(k)
	var want: Dictionary = A.wanted(an.life_score())
	check(an.count_of("gazelle") == want.gazelle and an.count_of("jackal") == want.jackal and an.count_of("bird") == want.bird and want.bird % A.FLOCK == 0,
		"then the rest come in (%s), birds in flocks of %d" % [", ".join(kinds), A.FLOCK])
	check(an.try_spawn(10.0) == "", "until the land is full")
	# Shy gazelles, bold jackals.
	an.clear()
	var ga = an.spawn("gazelle", Vector3(30, 0, 60), Vector3(30, 0, 40))
	ga.set_physics_process(false)
	player.position = Vector3(30, ga.position.y, 50)
	player.crouching = true
	ga._decide()
	check(ga.state != Animal.State.FLEE, "crouching, you can creep 10 m from a gazelle")
	player.crouching = false
	ga._decide()
	check(ga.state == Animal.State.FLEE, "standing up, it bolts")
	var ja = an.spawn("jackal", Vector3(34, 0, 50), Vector3(30, 0, 40))
	ja.set_physics_process(false)
	ja._decide()
	check(ja.state == Animal.State.ATTACK, "a jackal comes for you when you're close")
	main.survival.health = 100.0
	ja.global_position = player.global_position + Vector3(1.0, 0, 0)
	ja._physics_process(0.05)
	check(main.survival.health < 100.0, "and bites (health %d)" % int(main.survival.health))
	ja.take_hit(25.0, ja.global_position, Vector3.FORWARD)
	ja._decide()
	check(ja.state == Animal.State.FLEE, "hurt badly, it runs off")
	var bird = an.spawn("bird", Vector3(36, 0, 70), Vector3(30, 0, 40))
	bird.set_physics_process(false)
	check(an.alert(Vector3(36, 0, 72), 30.0) >= 1 and bird.state == Animal.State.FLEE, "a gunshot scares the birds off")
	# Hunting: a body to butcher.
	ga.take_hit(200.0, ga.global_position, Vector3.FORWARD)
	check(ga.is_dead() and ga.collision_layer == Animal.DEAD_LAYER, "a shot gazelle falls over")
	check(an.prompt("animal:" + ga.name) == "[E] Butcher the gazelle (3 raw meat)", "its prompt: " + an.prompt("animal:" + ga.name))
	check(main._prompt_for("animal:" + ga.name).begins_with("[E] Butcher"), "the crosshair prompt shows it")
	main.interact("animal:" + ga.name)
	check(inv.count_of("raw_meat") == 3 and an.find(ga.name) == null, "butchering gives 3 raw meat and the body is gone")
	check(not main.survival.can_consume("raw_meat") and main.survival.can_consume("cooked_meat"), "raw meat must be cooked before you can eat it")
	check(Items.ITEMS.has("raw_meat") and main.test_items().has("cooked_meat"), "meat is in the test boxes")
	# Cooking at a fire pit.
	var b = main.building
	var ev: Dictionary = b.evaluate("fire_pit", {"kind": "obj", "cx": -3, "cz": 6, "dir": 0, "level": 0})
	var pk: String = b.place("fire_pit", {"kind": "obj", "cx": -3, "cz": 6, "dir": 0, "level": 0}, ev.y)
	var rec: Dictionary = b.pieces[pk]
	check(main._prompt_for("fire:" + pk).contains("Light the fire to cook"), "a cold fire can't cook: " + main._prompt_for("fire:" + pk).replace("\n", " / "))
	inv.add("wood", 1)
	main.interact("fire:" + pk)
	check(rec.burn > 0.0 and inv.count_of("raw_meat") == 3, "E with wood lights it (the meat waits)")
	var burn: float = rec.burn
	check(main._prompt_for("fire:" + pk).contains("[E] Cook 3 raw meat"), "then: " + main._prompt_for("fire:" + pk).replace("\n", " / "))
	main.interact("fire:" + pk)
	check(inv.count_of("raw_meat") == 0 and inv.count_of("cooked_meat") == 3, "E cooks the meat")
	check(is_equal_approx(rec.burn, burn - 3 * load("res://scripts/camp.gd").COOK_EACH), "cooking burns the fire down")
	main.survival.food = 20.0
	main.survival.consume("cooked_meat")
	check(main.survival.food > 55.0, "cooked meat is a good meal (food %d)" % int(main.survival.food))
	# Dusk and night.
	var gz = an.spawn("gazelle", Vector3(20, 0, 20), Vector3(10, 0, 10))
	var dead = an.spawn("gazelle", Vector3(22, 0, 20), Vector3(10, 0, 10))
	dead.take_hit(500.0, dead.global_position, Vector3.FORWARD)
	an.on_dusk()
	check(gz.state == Animal.State.LEAVE, "at dusk the animals head back out")
	# Saving.
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	var n_all: int = an.all().size()
	an.clear()
	main.apply_save_data(data)
	main.day_night.restore(main.day_night.day, 10.0)
	check(an.all().size() == n_all and an.all().filter(func(a): return a.is_dead()).size() == 1, "animals and bodies are saved (%d)" % an.all().size())
	check(an.alive().any(func(a): return a.state == Animal.State.LEAVE), "and still leaving")
	an.load_data({"list": [{"type": "unicorn", "pos": [0, 0, 0], "goal": [0, 0]}, {"type": "gazelle", "pos": "x"}, 7,
		{"type": "jackal", "pos": [1, 0, 1], "goal": [0, 0], "hp": "lots"}], "spawned": "many"}, main.day_night.day)
	check(an.all().size() == 1 and is_equal_approx(an.all()[0].health, 40.0), "broken animal entries are skipped or fixed")
	data.erase("animals")
	main.apply_save_data(data)
	main.day_night.restore(main.day_night.day, 10.0)
	check(an.all().is_empty(), "older saves load with no animals")
	an.on_dusk()
	an.spawn("gazelle", Vector3(20, 0, 20), Vector3(10, 0, 10))
	an.on_night()
	check(an.alive().is_empty(), "by nightfall they're gone")
	an.clear()
	# --- The night side: the lure, the well, the fields and pipes ---
	check(R.lure_for(0.0, 0.0) == 0 and R.lure_for(80.0, 8.5) == 4 and R.lure_for(5000.0, 0.0) == R.LURE_MAX,
		"water drawn and green land draw extra mutants (80 L + 8.5 green = 4, at most %d)" % R.LURE_MAX)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	check(Waves.wave_mix(1, rng, 1.0, 3).size() == Waves.wave_size(1) + 3, "the lure adds to the wave")
	w.store = w.capacity - 80.0
	check(rd.lure() == 2 + 3, "today: 80 L drawn and 12 green squares draw 5 (%d)" % rd.lure())
	var wv = main.waves
	wv.on_dusk(main.day_night.day)
	check(wv.lure == 5 and wv.preview_next().size() == Waves.wave_size(wv.wave + 1) + 5, "the siren works out tonight's lure")
	main.hud.banner.text = ""
	main.shop.upgrades.radio = 1
	wv.siren.emit()
	check(main.hud.banner.text.contains("draw 5 of them"), "the radio says so: " + main.hud.banner.text)
	main.shop.upgrades.radio = 0
	# Plants for the raiders.
	inv.add("seed_millet", 10)
	var spots: Array = []
	for x in [9.0, 11.0, 13.0]:
		var p := Vector3(x, 0, 9.0)
		p.y = main.terrain.surface_height(p.x, p.z)
		check(f.plant(p, "millet") == "", "millet planted at %.0f, 9" % x)
		spots.append(F.spot_of(p.x, p.z))
	main.mutants.clear()
	main.day_night.restore(main.day_night.day, 21.0)
	wv.start_wave()
	check(wv.remaining() == Waves.wave_size(wv.wave) + 5, "the night wave is %d bigger (%d)" % [5, wv.remaining()])
	check(wv.stats.lure == 5, "and the wave remembers why")
	for i in 30:
		wv._process(1.0)
	var homes := {}
	for m in wv.hunters():
		var to_well: bool = Vector2(m.home.x - well.x, m.home.z - well.z).length() < 0.1
		var to_field: bool = spots.any(func(s): return F.spot_center(s).distance_to(Vector2(m.home.x, m.home.z)) < 0.1)
		homes["well" if to_well else ("field" if to_field else "other")] = true
		if not m.base_goal.is_equal_approx(well):
			homes.bad_base = true
	check(homes.has("well") and homes.has("field") and not homes.has("other") and not homes.has("bad_base"),
		"night waves march on the main well, and some groups go for the fields (%s)" % str(homes.keys()))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	var raider = wv.hunters()[0]
	# Wrecking: a wave mutant at the base picks the nearest plant.
	raider.global_position = Vector3(10.0, main.terrain.surface_height(10, 12), 12.0)
	raider.home = raider.global_position
	raider._wreck_t = 0.0
	check(raider._wreck_target(0.1) and raider._wreck_key == raider.RAID_KEY, "a wave mutant goes for the nearest plant")
	var c0: Vector2 = F.spot_center(spots[0])
	check(Vector2(raider._wander_to.x, raider._wander_to.z).distance_to(F.spot_center(spots[0])) < 0.1 \
			or Vector2(raider._wander_to.x, raider._wander_to.z).distance_to(F.spot_center(spots[1])) < 0.1, "the closest one")
	# Trampling.
	for m in wv.hunters():
		if m != raider:
			m.global_position = Vector3(-60, 0, -60)
	raider.global_position = Vector3(c0.x, raider.global_position.y, c0.y)
	rd.trampled = 0
	rd.tick(0.5)
	check(not f.plants[spots[0]].dead, "a moment on a plant doesn't kill it")
	rd.tick(0.5)
	check(f.plants[spots[0]].dead and rd.trampled == 1 and int(wv.stats.trampled) == 1, "standing on it tramples it dead")
	check(not f.plants[spots[1]].dead, "the plant next to it is fine")
	# Pipes.
	main.shop.cash = 2000
	main.shop.buy_upgrade("pump")
	var ss := {"kind": "obj", "cx": -4, "cz": 4, "dir": 0}
	var sev: Dictionary = b.evaluate("sprinkler", ss)
	var sk: String = b.place("sprinkler", ss, sev.y)
	check(w.connect_pipe("main", sk), "a pipe from the well to a sprinkler")
	var mid: Vector3 = (w.pipe_anchor("main") + w.pipe_anchor(sk)) * 0.5
	raider.global_position = Vector3(mid.x, raider.global_position.y, mid.z)
	check(rd.raid_point(raider.global_position).distance_to(Vector3(mid.x, 0, mid.z)) < 0.2, "pipes are raid targets too")
	rd.tick(1.0)
	check(w.pipes.size() == 1, "a moment on a pipe doesn't break it")
	rd.tick(1.0)
	check(w.pipes.is_empty() and rd.pipes_broken == 1 and int(wv.stats.pipes) == 1, "a mutant on a pipe tears it up")
	wv.stats.size = 1
	check("Plants trampled: 1" in Waves.summary_lines(wv.stats) and "Water pipes torn up: 1" in Waves.summary_lines(wv.stats), "the summary counts them")
	# Nothing left to wreck: on to the well.
	for s in f.plants.keys():
		f.plants[s].dead = true
	raider.home = Vector3(40, 0, 40)
	raider.global_position = Vector3(40, raider.global_position.y, 40)
	raider._wreck_t = 0.0
	check(not raider._wreck_target(0.1) and raider.home.is_equal_approx(well), "a field wrecked, they move on to the main well")
	# Saving a wave with its lure and raiders.
	main.apply_save_data(saved)
	check(wv.active and wv.lure == 5 and wv.hunters().all(func(m): return m.base_goal.is_equal_approx(well)), "the lure and where they're headed are saved")
	var old: Dictionary = saved.duplicate(true)
	old.waves.erase("lure")
	for e in old.mutants.list:
		e.erase("base")
	main.apply_save_data(old)
	check(wv.lure == 0 and wv.hunters().all(func(m): return m.base_goal.is_equal_approx(m.home)), "older saves load with no lure")
	wv.end_wave(false)
	main.mutants.clear()
	f.load_data({})
	w.load_data({})
	b.load_data([])
	main.day_night.restore(main.day_night.day, 10.0)


var life := {}

## Animals moving in real frames, and the weapons hitting them.
func _start_life() -> void:
	var an = main.animals
	var player = main.player
	an.clear()
	main.day_night.restore(main.day_night.day, 10.0)
	player.position = Vector3(-60, main.terrain.surface_height(-60, 60) + 0.1, 60)
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	life.walker = an.spawn("gazelle", Vector3(40, 0, 60), Vector3(40, 0, 20))
	life.walker_d = life.walker.position.distance_to(Vector3(40, life.walker.position.y, 20))
	life.bird = an.spawn("bird", Vector3(50, 0, 60), Vector3(50, 0, 0))
	# A gazelle right in front of you (held still), for the gun.
	var eye: Vector3 = player.camera.global_position
	life.target = an.spawn("gazelle", Vector3(eye.x, 0, eye.z - 6.0), Vector3(eye.x, 0, eye.z - 6.0))
	life.target.set_physics_process(false)
	life.target.position.y = eye.y - 1.0


func _check_life() -> void:
	var player = main.player
	var w = life.walker
	var d: float = w.position.distance_to(Vector3(40, w.position.y, 20))
	check(d < life.walker_d - 1.5, "a gazelle walks in towards the green (%.1f m nearer)" % (life.walker_d - d))
	var g: float = main.terrain.surface_height(life.bird.position.x, life.bird.position.z)
	check(life.bird.position.y > g + 2.0, "birds fly in (%.1f m up)" % (life.bird.position.y - g))
	var t = life.target
	var hp: float = t.health
	var gun = main.guns
	main.inventory.add("rifle", 1)
	gun.set_item("rifle")
	gun.mag.rifle = 5
	gun.raise_t = 0.0
	gun._cooldown = 0.0
	gun.ads_amount = 1.0
	var res: Dictionary = gun.try_fire()
	check(res.get("node") == t and t.health < hp, "a rifle shot hits the gazelle (%s)" % str(res.get("kind", "")))
	gun.set_item("")
	main.animals.clear()


## v1.17: the green % of the map, the livable score of the base, milestones and
## their comforts, green land and palms spreading, saving.
func _test_livable() -> void:
	var lv = main.livable
	var w = main.water
	var f = main.farming
	var b = main.building
	var sv = main.survival
	var player = main.player
	var L = load("res://scripts/livable.gd")
	var W = load("res://scripts/water.gd")
	var F = load("res://scripts/farming.gd")
	var Prefabs = load("res://scripts/prefabs.gd")
	var banners: Array = []
	lv.message.connect(func(t): banners.append(t))
	b.load_data([])
	w.load_data({})
	f.load_data({})
	main.shop.upgrades.well = 0
	main.shop.upgrades.pump = 0
	main.shop.upgrades.zone = 0
	main.apply_upgrades()
	lv.load_data({})
	check(L.land_squares() > 9000 and L.land_squares() < 11000, "the map has %d ground squares" % L.land_squares())
	check(lv.green_percent() == 0.0 and lv.hud_text().begins_with("Green 0.00%"), "dead desert: 0%% green (%s)" % lv.hud_text())
	check(lv.score == 6 and lv.parts.water == 6 and lv.parts.shade == 0 and lv.parts.shelter == 0, "a bare base is only the main well: livable %d (%s)" % [lv.score, str(lv.parts)])
	check(lv.level() == 0 and lv.reached == 0, "no milestone yet")
	# Green land near the base and far out.
	for x in range(0, 5):
		for z in range(3, 5):
			var c := Vector2i(x, z)
			w.water_cell(c, W.SOIL_NEED)
			w.cells[c].green = 1.0
	var far := Vector2i(30, 30)
	w.water_cell(far, W.SOIL_NEED)
	w.cells[far].green = 1.0
	lv.refresh()
	check(absf(lv.green_percent() - 11.0 / L.land_squares() * 100.0) < 0.0001, "green %% counts the whole map (%s)" % lv.percent_text())
	check(lv.parts.plants == 20, "10 green squares in the build zone give full plant points, the far one doesn't count (%d)" % lv.parts.plants)
	main.hud._process(0.0)
	check(main.hud.clock.text.contains(lv.hud_text()), "the HUD shows it: " + lv.hud_text())
	# Food plants, a fire pit, palms for shade.
	var spots := [Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7)]
	for s in spots:
		f.plants[s] = {"crop": "melon", "grow": 1.0, "hp": 1.0, "dead": false, "fruited": false}
	f.plants[Vector2i(6, 7)] = {"crop": "date_palm", "grow": 6.0, "hp": 1.0, "dead": false, "fruited": true}
	f.plants[Vector2i(7, 7)] = {"crop": "millet", "grow": 1.0, "hp": 1.0, "dead": true, "fruited": false}
	var fs := {"kind": "obj", "cx": -3, "cz": 6, "dir": 0, "level": 0}
	b.place("fire_pit", fs, b.evaluate("fire_pit", fs).y)
	lv.refresh()
	check(lv.parts.food == 16, "4 melons, a date palm and a fire pit: food %d (dead plants don't count)" % lv.parts.food)
	check(lv.parts.shade == 4, "a grown date palm gives shade (%d)" % lv.parts.shade)
	check(lv.score == 46 and lv.level() == 1 and lv.reached == 1, "livable %d reaches the first milestone" % lv.score)
	check(banners.size() == 1 and banners[0].contains("Settled"), "and it is announced: " + (banners[0] if banners.size() > 0 else "nothing"))
	lv.refresh()
	check(banners.size() == 1, "only once")
	# Comforts: faster healing at the base.
	player.position = Vector3(0, main.terrain.surface_height(0, 8), 8)
	lv._apply_comforts()
	check(sv.regen_mult == L.HEAL_MULT and not sv.heat_shelter, "settled: you heal twice as fast at the base, but still feel the heat")
	sv.stop_bleeding()  # v2.1: claws and bites earlier in the run left a wound
	sv.health = 50.0
	sv.food = 100.0
	sv.water = 100.0
	sv.tick(4.0, 9.0, false, false)
	check(absf(sv.health - (50.0 + sv.REGEN * 2.0 * 4.0)) < 0.01, "healing %.1f in 4 s" % (sv.health - 50.0))
	player.position = Vector3(0, main.terrain.surface_height(0, 60), 60)
	lv._apply_comforts()
	check(sv.regen_mult == 1.0, "away from the base, normal healing")
	# A cabin, its roof and walls: shelter and shade.
	var at := Vector2i(-8, -8)
	for e in Prefabs.entries("cabin"):
		var slot: Dictionary = {"kind": e.kind, "cx": e.cx + at.x, "cz": e.cz + at.y, "dir": e.dir, "level": e.level}
		var ev: Dictionary = b.evaluate(e.type, slot)
		if ev.ok:
			b.place(e.type, slot, ev.y)
	var cs := {"kind": "obj", "cx": -2, "cz": -9, "dir": 0, "level": 0}
	b.place("chest", cs, b.evaluate("chest", cs).y)
	lv.refresh()
	check(b.keys_of(["roof"]).size() == 4 and lv.parts.shade == 12, "the cabin's 4 roofs add shade (%d)" % lv.parts.shade)
	check(lv.parts.shelter >= 14, "its walls, roof and a chest give shelter (%d)" % lv.parts.shelter)
	check(lv.level() == 2 and banners.size() == 2 and banners[1].contains("Cool camp"), "livable %d: Cool camp" % lv.score)
	player.position = Vector3(0, main.terrain.surface_height(0, 8), 8)
	lv._apply_comforts()
	sv.tick(1.0, 13.0, false, false)
	check(sv.heat_shelter and not sv.hot, "at the base you rest through the midday heat")
	player.position = Vector3(0, main.terrain.surface_height(0, 60), 60)
	lv._apply_comforts()
	sv.tick(1.0, 13.0, false, false)
	check(sv.hot, "out in the desert the heat still gets you")
	# Water upgrades.
	main.shop.upgrades.well = 3
	main.shop.upgrades.pump = 1
	main.apply_upgrades()
	lv.refresh()
	check(lv.parts.water == 18, "a deep well and a pump: water %d" % lv.parts.water)
	check(lv.level() == 3 and banners[-1].contains("Homestead"), "livable %d: Homestead" % lv.score)
	# Homestead: buildings mend each morning.
	var wk: String = b.keys_of(["wall"])[0]
	var top: float = b.max_hp(b.pieces[wk])
	b.pieces[wk].hp = top * 0.5
	lv.on_morning(0)
	check(absf(b.pieces[wk].hp - top * 0.6) < 0.5, "a damaged wall mends 10%% in the morning (%d / %d)" % [int(b.pieces[wk].hp), int(top)])
	check(lv.summary_lines().any(func(l): return l.begins_with("[x] 75")), "the map lists the milestones reached")
	# Saving.
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	check(int(data.livable.reached) == 3, "the milestones reached are saved")
	var n := banners.size()
	main.apply_save_data(data)
	check(lv.reached == 3 and lv.score > 75 and banners.size() == n, "and load back without announcing them again (%d)" % lv.score)
	data.erase("livable")
	main.apply_save_data(data)
	check(lv.reached == 3 and banners.size() == n, "an older save takes the milestones it has as already reached")
	lv.load_data({"reached": "lots"})
	check(lv.reached == 3, "a broken save falls back to the score")
	# Greening spreads round a fully green square.
	b.load_data([])
	w.load_data({})
	f.load_data({})
	main.shop.upgrades.well = 0
	main.shop.upgrades.pump = 0
	main.apply_upgrades()
	var core := Vector2i(10, 10)
	w.water_cell(core, W.SOIL_NEED)
	w.cells[core].green = 1.0
	for i in 3:
		w.water_cell(core, W.DAY_NEED)
		w.on_morning()
	var ring := [core + Vector2i(1, 0), core + Vector2i(-1, 0), core + Vector2i(0, 1), core + Vector2i(0, -1)]
	check(ring.all(func(c): return w.is_soil(c)), "a watered, fully green square turns the sand next to it to soil in 3 mornings")
	check(not w.is_soil(core + Vector2i(1, 1)) and not w.is_soil(core + Vector2i(2, 0)), "only the squares right next to it")
	for i in 6:
		w.water_cell(core, W.DAY_NEED)
		w.on_morning()
	check(ring.all(func(c): return w.is_soil(c) and w.green_of(c) < 0.01), "it stays soil while the green holds, but needs your water to go green")
	for i in 6:
		w.on_morning()
	check(w.green_of(core) < 0.999 and not ring.any(func(c): return w.cells.has(c)), "left dry, the green fades and the soil round it goes back to sand")
	# Palms drop saplings on watered soil.
	w.load_data({})
	f.load_data({})
	for x in range(4, 8):
		for z in range(4, 8):
			w.water_cell(Vector2i(x, z), W.SOIL_NEED)
	var palm: Vector2i = F.spot_of(4.0 * 5 + 2.0, 4.0 * 5 + 2.0)
	f.plants[palm] = {"crop": "date_palm", "grow": 6.0, "hp": 1.0, "dead": false, "fruited": true}
	var first_day := -1
	var first: Array = []
	for d in range(1, 40):
		f.plants = {palm: {"crop": "date_palm", "grow": 6.0, "hp": 1.0, "dead": false, "fruited": true}}
		for x in range(4, 8):
			for z in range(4, 8):
				w.cells[Vector2i(x, z)].wet = W.DAY_NEED
		var got: Array = lv.sprout_palms(d)
		if not got.is_empty():
			first_day = d
			first = got
			break
	check(first_day > 0 and first.size() == 1, "a grown palm drops a sapling now and then (day %d)" % first_day)
	if first_day > 0:
		var sp: Vector2i = first[0]
		check(f.plants.has(sp) and f.plants[sp].crop == "date_palm" and f.plants[sp].grow == 0.0, "a young date palm comes up")
		check(absi(sp.x - palm.x) <= L.SPROUT_REACH and absi(sp.y - palm.y) <= L.SPROUT_REACH, "next to its parent")
		f.plants = {palm: {"crop": "date_palm", "grow": 6.0, "hp": 1.0, "dead": false, "fruited": true}}
		check(lv.sprout_palms(first_day) == first, "the same world and day drop it in the same spot")
		f.plants = {palm: {"crop": "date_palm", "grow": 6.0, "hp": 1.0, "dead": false, "fruited": true}}
		for c in w.cells:
			w.cells[c].wet = 0.0
		check(lv.sprout_palms(first_day).is_empty(), "but only on watered soil")
	check(not f.sprout(F.spot_of(W.WELL_POS.x, W.WELL_POS.y), "date_palm") and not f.sprout(Vector2i(60, 60), "date_palm"), "never on the main well or on sand")
	lv.message.disconnect(lv.message.get_connections().back().callable)
	w.load_data({})
	f.load_data({})
	lv.refresh(false)


## v1.18: hidden oases with springs, reeds, clay and a stash, guards and nests, claimed as outposts.
func _test_oases() -> void:
	var oa = main.oases
	var w = main.water
	var b = main.building
	var inv = main.inventory
	var sv = main.survival
	var mu = main.mutants
	var O = load("res://scripts/oases.gd")
	var W = load("res://scripts/water.gd")
	var B = load("res://scripts/building.gd")
	var banners: Array = []
	oa.message.connect(func(t): banners.append(t))
	b.load_data([])
	mu.clear()
	inv.load_data({})
	w.load_data({})
	main.farming.load_data({})
	oa.load_data({})
	var n: int = oa.count()
	check(n >= 3 and n <= 5, "%d oases in this world" % n)
	var far_ok := true
	var apart_ok := true
	for i in n:
		var p: Vector3 = oa.list[i].pos
		far_ok = far_ok and Vector2(p.x, p.z).length() >= O.MIN_R - 0.01 and Vector2(p.x, p.z).length() <= O.MAX_R + 0.01
		for j in range(i + 1, n):
			apart_ok = apart_ok and Vector2(p.x, p.z).distance_to(Vector2(oa.list[j].pos.x, oa.list[j].pos.z)) >= O.SPACING
	check(far_ok and apart_ok, "out in the desert (%d to %d m from the base) and far apart" % [int(O.MIN_R), int(O.MAX_R)])
	var again: Array = O.find_spots(main.world_seed, main.terrain, oa._avoid)
	check(again.size() == n and again.all(func(q): return oa.list.any(func(o): return o.pos.distance_to(q) < 0.01)), "the same world has the same oases")
	var other: Array = O.find_spots(main.world_seed + 99, main.terrain, oa._avoid)
	check(not other.is_empty() and not (other.size() == n and other.all(func(q): return oa.list.any(func(o): return o.pos.distance_to(q) < 0.01))), "another world has others")
	check(not oa.list[0].has_nest and oa.list.any(func(o): return o.has_nest), "the nearest has no nest, but at least one has (%s)" % str(oa.list.map(func(o): return o.has_nest)))
	var clear_ok := true
	for o in oa.list:
		for v in oa._avoid:
			if Vector2(v.x, v.z).distance_to(Vector2(o.pos.x, o.pos.z)) < O.CLEAR_R:
				clear_ok = false
	check(clear_ok, "no rock, tree or wreck in the ponds")
	var wild: int = 0
	var nest_i: int = -1
	for i in n:
		if oa.list[i].has_nest:
			nest_i = i if nest_i < 0 else nest_i
	var wp: Vector3 = oa.list[wild].pos
	var wc: Vector2i = W.cell_of(wp.x, wp.z)
	check(w.is_soil(wc) and w.green_of(wc) > 0.5, "a wild spring keeps the land round it green (%.2f)" % w.green_of(wc))
	var np: Vector3 = oa.list[nest_i].pos
	check(not w.cells.has(W.cell_of(np.x, np.z)), "a nest's oasis is dead sand")
	check(oa.wild_green() > 1.0 and main.raids.lure() == 0, "wild oasis green doesn't draw the waves (wild %.1f, lure %d)" % [oa.wild_green(), main.raids.lure()])
	# Finding it.
	main.player.global_position = wp + Vector3(0, 1, O.FIND_R - 5.0)
	mu.clear()
	oa.list[wild].guards = 0  # guards are tested below
	oa.tick(0.5)
	check(oa.list[wild].found and banners.size() > 0 and banners.back().contains("found an oasis"), "walking up finds it: " + (banners.back() if banners.size() > 0 else ""))
	# The spring.
	sv.water = 30.0
	check(oa.prompt("oasis:spring:%d" % wild).contains("[E] Drink"), "spring: " + oa.prompt("oasis:spring:%d" % wild).replace("\n", " / "))
	inv.add("watering_can", 1)
	w.can = 0.0
	check(oa.prompt("oasis:spring:%d" % wild).contains("fill the watering can"), "with a can it fills that too")
	main.interact("oasis:spring:%d" % wild)
	check(is_equal_approx(sv.water, sv.MAX) and is_equal_approx(w.can, W.CAN_MAX), "E: drunk your fill (%.0f) and the can is full (%.0f L)" % [sv.water, w.can])
	check(oa.prompt("oasis:spring:%d" % wild).contains("had your fill"), "then: had your fill")
	# Reeds and clay.
	var got := 0
	for k in 6:
		got += oa.take(wild, "reeds")
	check(got == O.REEDS_DAY and inv.count_of("reeds") == O.REEDS_DAY, "cut %d reeds a day" % got)
	check(oa.prompt("oasis:reeds:%d" % wild).contains("Cut for today"), "then: " + oa.prompt("oasis:reeds:%d" % wild).replace("\n", " / "))
	main.interact("oasis:clay:%d" % wild)
	check(inv.count_of("clay") == O.TAKE and oa.prompt("oasis:clay:%d" % wild).contains("%d left" % (O.CLAY_DAY - O.TAKE)), "E digs %d clay" % O.TAKE)
	var Items = load("res://scripts/items.gd")
	check(Items.can_craft("fibre", inv), "reeds strip into fibre at the workbench")
	oa.on_tally()
	check(oa.list[wild].reeds == 0 and oa.list[wild].clay == 0, "they come back by morning")
	# The stash.
	check(oa.prompt("oasis:stash:%d" % wild).contains("Search it"), "an old stash")
	main.interact("oasis:stash:%d" % wild)
	check(inv.count_of("seed_saffron") >= 2 and inv.count_of("seed_dragon_fruit") >= 1, "it holds rare seeds (%d saffron, %d dragon fruit)" % [inv.count_of("seed_saffron"), inv.count_of("seed_dragon_fruit")])
	check(oa.search_stash(wild).is_empty() and oa.prompt("oasis:stash:%d" % wild) == "" and not oa._nodes[wild].stash.visible, "once")
	# Guards.
	oa.list[wild].guards = O.GUARDS
	main.player.global_position = wp + Vector3(0, 1, O.WAKE_R - 5.0)
	mu.top_up(1)
	var wanderers: int = mu.alive().filter(func(m): return m.guard_of < 0).size()
	oa.tick(0.5)
	var gs: Array = oa.guards_of(wild)
	check(gs.size() == O.GUARD_CAP and oa.list[wild].guards == O.GUARDS - O.GUARD_CAP, "coming close wakes %d guards" % gs.size())
	check(gs.all(func(m): return Vector2(m.position.x - wp.x, m.position.z - wp.z).length() < 8.0 and Vector2(m.home.x, m.home.z).distance_to(Vector2(wp.x, wp.z)) < 0.01), "they guard the pond")
	check(mu.top_up(2) == 0 and mu.alive().filter(func(m): return m.guard_of < 0).size() == wanderers, "guards don't count as the desert's wanderers")
	check(oa.prompt("oasis:post:%d" % wild).contains("Kill the guards first (3 left)"), "claim post: " + oa.prompt("oasis:post:%d" % wild).replace("\n", " / "))
	check(not oa.claim(wild), "can't claim it while they're about")
	var saved_guard: Dictionary = gs[0].save_data()
	for m in gs:
		m.take_hit(1000.0, m.global_position, Vector3.FORWARD)
	check(oa.guards_of(wild).is_empty(), "guards killed")
	check(oa.prompt("oasis:post:%d" % wild).contains("You need 6 wood, 2 cloth"), "then it needs materials: " + oa.prompt("oasis:post:%d" % wild).replace("\n", " / "))
	inv.add("wood", 6)
	inv.add("cloth", 2)
	check(oa.prompt("oasis:post:%d" % wild).contains("[E] Claim it"), "with them: [E] Claim it")
	var wg_before: float = oa.wild_green()
	main.interact("oasis:post:%d" % wild)
	check(oa.list[wild].claimed and inv.count_of("wood") == 0 and inv.count_of("cloth") == 0, "claimed (paid)")
	check(b.outposts.size() == 1 and oa._nodes[wild].zone != null and oa._nodes[wild].flag.visible, "it gets a build zone, a ring of stakes and a flag")
	var post: Vector3 = oa.list[wild].post_pos
	var fslot: Dictionary = B.slot_for("foundation", post + Vector3(4, 0, 0), 0)
	var ev: Dictionary = b.evaluate("foundation", fslot)
	check(b.in_zone("foundation", fslot) and ev.ok, "a foundation can go down at the outpost (%s)" % ev.reason)
	var far_slot: Dictionary = B.slot_for("foundation", post + Vector3(O.OUTPOST_R + 6.0, 0, 0), 0)
	check(not b.in_zone("foundation", far_slot), "but not past its zone")
	var fkey: String = b.place("foundation", fslot, ev.y)
	check(b.pieces.has(fkey), "built a foundation at the outpost")
	main.livable.refresh(false)
	var shelter_before: int = int(main.livable.parts.shelter)
	var wslot: Dictionary = B.slot_for("wall", post + Vector3(4, 0, 0), 0)
	var wev: Dictionary = b.evaluate("wall", wslot)
	var wkey: String = b.place("wall", wslot, wev.y) if wev.ok else ""
	main.livable.refresh(false)
	check(wkey != "" and int(main.livable.parts.shelter) == shelter_before, "a wall at the outpost doesn't count for the base's livable score (%s, shelter %d -> %d)" % [wev.reason, shelter_before, int(main.livable.parts.shelter)])
	main._process(0.0)
	check(oa._nodes[wild].zone.highlighted() == false, "the ring lights only in build mode")
	oa.set_highlight(true)
	check(oa._nodes[wild].zone.highlighted(), "and lights in build mode")
	oa.set_highlight(false)
	check(oa.wild_green() < wg_before - 1.0, "a claimed oasis' green is yours: it counts for the lure (wild green %.1f, was %.1f)" % [oa.wild_green(), wg_before])
	# A claimed spring waters further.
	var edge: Vector2i = W.cell_of(wp.x + O.SPRING_R + 2.0, wp.z)
	w.clear_cell(edge)
	oa.on_tally()
	check(w.is_soil(edge) and w.cell_info(edge).wet >= W.DAY_NEED - 0.01, "a claimed spring waters the land further out (%.1f L)" % w.cell_info(edge).wet)
	# The nest.
	var no: Dictionary = oa.list[nest_i]
	var nc: Vector2i = W.cell_of(no.nest_pos.x, no.nest_pos.z)
	w.add_life(nc, W.SOIL_NEED, 0.5)
	oa.on_tally()
	check(not w.cells.has(nc), "a living nest kills the land round it every morning")
	check(oa._nodes[nest_i].stumps.visible and not oa._nodes[nest_i].palms.visible, "its palms are dead stumps")
	check(oa.prompt("oasis:post:%d" % nest_i).contains("Burn out the mutant nest first"), "claim post: burn the nest first")
	inv.remove("fuel", inv.count_of("fuel"))
	check(oa.prompt("oasis:nest:%d" % nest_i).contains("You need a fuel can"), "nest without fuel: " + oa.prompt("oasis:nest:%d" % nest_i).replace("\n", " / "))
	check(not oa.burn_nest(nest_i), "can't burn it without fuel")
	var g0: int = no.guards
	no.guards = 1
	oa.tick(O.NEST_BREED)
	check(no.guards == 2, "a nest breeds more guards (%d)" % no.guards)
	no.guards = g0
	inv.add("fuel", 1)
	check(oa.prompt("oasis:nest:%d" % nest_i).contains("[E] Burn it"), "with a fuel can: [E] Burn it")
	main.interact("oasis:nest:%d" % nest_i)
	check(no.nest == "burning" and inv.count_of("fuel") == 0 and oa._nodes[nest_i].flames.visible, "it burns (one fuel can)")
	var sd: Dictionary = oa.save_data()
	check(sd.list[nest_i].nest == "gone", "saved while burning, it counts as burned")
	oa._process(O.BURN_TIME + 0.1)
	check(no.nest == "gone" and not oa._nodes[nest_i].nest.visible and oa._nodes[nest_i].palms.visible, "it burns out and the palms come back")
	oa.on_tally()
	var npc: Vector2i = W.cell_of(no.pos.x, no.pos.z)
	check(w.is_soil(npc) and w.cell_info(npc).wet >= W.DAY_NEED - 0.01, "the spring starts bringing the land back")
	for k in 3:
		w.on_morning()
	check(w.green_of(npc) > 0.3, "and it greens over the mornings (%.2f)" % w.green_of(npc))
	# Saving and loading.
	sd = oa.save_data()
	var mud: Dictionary = mu.save_data()
	oa.load_data({"list": []})
	check(not oa.list[wild].claimed and b.outposts.is_empty() and oa._nodes[wild].zone == null, "(reset)")
	oa.load_data(sd)
	check(oa.list[wild].claimed and oa.list[wild].stash and oa.list[wild].found and b.outposts.size() == 1 and oa._nodes[wild].zone != null, "loading brings the outpost back")
	check(oa.list[nest_i].nest == "gone" and not oa._nodes[nest_i].nest.visible, "and the burned nest stays burned")
	check(saved_guard.get("guard", -1) == wild, "guards are saved as guards")
	mu.load_data({"list": [saved_guard]})
	check(mu.alive().size() == 1 and mu.alive()[0].guard_of == wild, "and load as guards")
	w.load_data({})
	oa.load_data({})
	check(not oa.list[wild].claimed and not oa.list[wild].found and oa.list[nest_i].nest == "alive" and w.green_of(wc) > 0.5, "an older save gets a new world's oases, green round the wild springs")
	oa.load_data({"list": [5, "x", {"guards": "a", "claimed": "yes", "nest": 3, "reeds": 999}]})
	check(oa.count() == n and oa.list[2].guards == (O.NEST_GUARDS if oa.list[2].has_nest else O.GUARDS) and not oa.list[2].claimed and oa.list[2].reeds == O.REEDS_DAY, "a broken save falls back to defaults")
	oa.load_data({})
	check(main.collect_save_data().has("oases"), "the game saves the oases")
	# Map.
	oa.list[wild].found = true
	main.map_ui.toggle()
	check(main.map_ui.is_open(), "the map opens with a found oasis on it")
	main.map_ui.toggle()
	oa.message.disconnect(oa.message.get_connections().back().callable)
	inv.load_data({})
	mu.clear()
	b.load_data([])
	w.load_data({})
	oa.load_data({"list": []})


## Fills `n` squares far from the base fully green (for the green %).
func _green_squares(w, n: int) -> void:
	w.cells = {}
	var i := 0
	var x := -40
	while i < n:
		for z in range(-40, 40):
			if i >= n:
				break
			w.cells[Vector2i(x, z)] = {"wet": 0.0, "total": 24.0, "green": 1.0, "dry": 0}
			i += 1
		x += 1


## v1.19: green milestones, new seeds and machines, the weather station and rain,
## the ending, and peaceful mode.
func _test_goals() -> void:
	var g = main.goals
	var w = main.water
	var b = main.building
	var sh = main.shop
	var we = main.weather
	var fa = main.farming
	var lv = main.livable
	var G = load("res://scripts/goals.gd")
	var W = load("res://scripts/water.gd")
	var WE = load("res://scripts/weather.gd")
	var F = load("res://scripts/farming.gd")
	var I = load("res://scripts/items.gd")
	var M = load("res://scripts/market.gd")
	var S = load("res://scripts/survival.gd")
	var banners: Array = []
	g.message.connect(func(t): banners.append(t))
	var ended := [0]
	g.ended.connect(func(): ended[0] += 1)
	b.load_data([])
	fa.load_data({})
	w.load_data({})
	we.load_data({})
	g.load_data({})
	check(G.level_of(0.99) == 0 and G.level_of(1.0) == 1 and G.level_of(4.0) == 2 and G.level_of(50.0) == G.GOALS.size(), "green milestones at %s" % str(G.GOALS.map(func(e): return e.at)))
	check(G.at_text(2) == "2.5%" and G.at_text(1) == "1%", "milestone text: %s, %s" % [G.at_text(1), G.at_text(2)])
	check(g.reached == 0 and sh.goal_level == 0 and lv.next_goal == 1.0, "a dead desert has no milestones")
	var locked := []
	for i in sh.DRONE.size():
		if int(sh.DRONE[i].get("goal", 0)) > 0:
			locked.append(i)
	check(locked.size() == 4 and locked.all(func(i): return not sh.order_unlocked(i)), "4 drone orders wait for milestones")
	sh.cash = 5000
	check(not sh.can_order(locked[0]), "a locked order can't be bought, cash or not")
	main.shop_ui.refresh()
	check(main.shop_ui.drone_buttons[locked[0]].text.contains("Locked: reach 1% green"), "the drone page says so: " + main.shop_ui.drone_buttons[locked[0]].text.replace("\n", " / "))
	# The first milestone.
	var land: int = lv.land_squares()
	_green_squares(w, int(ceil(land * 0.01)) + 1)
	g.check()
	check(g.reached == 1 and banners.size() == 1 and banners[0].contains("First green"), "1%% green: the first milestone (%s)" % str(banners))
	check(sh.goal_level == 1 and sh.order_unlocked(locked[0]) and sh.order_unlocked(locked[1]) and not sh.order_unlocked(locked[2]), "it unlocks the new seeds only")
	lv.refresh(false)
	check(lv.hud_text().contains("/ 2.5%"), "the HUD shows the next milestone: " + lv.hud_text())
	g.check()
	check(banners.size() == 1, "a milestone is announced once")
	_green_squares(w, int(ceil(land * 0.05)) + 1)
	g.check()
	check(g.reached == 3 and banners.size() == 3 and sh.order_unlocked(locked[3]), "5%%: the dew collector and the weather station (%d banners)" % banners.size())
	check(ended[0] == 0 and not we.rain_back, "no ending yet")
	var lines: Array = g.summary_lines()
	check(lines.size() == G.GOALS.size() and lines[2].begins_with("[x]") and lines[3].begins_with("[ ]"), "the map lists them: " + " | ".join(lines))
	_green_squares(w, 10)
	g.check()
	check(g.reached == 3, "milestones stay reached when the green fades")
	# New seeds.
	var ok := true
	for crop in F.CROPS:
		ok = ok and I.ITEMS.has(F.seed_of(crop))
		for y in F.CROPS[crop].yield:
			ok = ok and I.ITEMS.has(y) and M.GOODS.has(y)
	check(ok, "every crop has a seed item and its harvest sells at the market")
	check(F.CROPS.olive.kind == "tree" and F.CROPS.prickly_pear.get("hardy", false) and S.CONSUMABLES.has("olives") and S.CONSUMABLES.has("prickly_pear"), "olive trees (fruit tree) and prickly pears (hardy), both good to eat")
	fa.plants = {Vector2i(30, 30): {"crop": "olive", "grow": 7.0, "hp": 1.0, "dead": false, "fruited": true}}
	check(fa.shaded(Vector2i(31, 30)), "a grown olive tree shades the plants next to it")
	fa.redraw()
	fa.plants = {}
	# The dew collector.
	w.cells = {}
	var ds := {"kind": "obj", "cx": 6, "cz": -6, "dir": 0}
	var ev: Dictionary = b.evaluate("dew_collector", ds)
	check(ev.ok, "a dew collector can be built in the base (%s)" % ev.get("reason", ""))
	var dk: String = b.place("dew_collector", ds, ev.y)
	var dp: Vector3 = b.pieces[dk].node.global_position
	check(we.prompt(dk).begins_with("Dew collector") and main._prompt_for("weather:" + dk) == we.prompt(dk), "its prompt: " + we.prompt(dk).replace("\n", " / "))
	var n: int = we.dew()
	var dc: Vector2i = W.cell_of(dp.x, dp.z)
	check(n >= 9 and is_equal_approx(w.cell_info(dc).wet, WE.DEW_L), "every morning it waters %d squares round it (%.1f L)" % [n, w.cell_info(dc).wet])
	check(w.cell_info(W.cell_of(dp.x + 14.0, dp.z)).wet == 0.0, "but not further out")
	b.remove(dk)
	# The weather station.
	w.cells = {}
	check(we.chance() == 0.0, "no rain without a station")
	var ws := {"kind": "obj", "cx": -6, "cz": 6, "dir": 0}
	ev = b.evaluate("weather_station", ws)
	check(ev.ok, "a weather station can be built (%s)" % ev.get("reason", ""))
	var wk: String = b.place("weather_station", ws, ev.y)
	var wp: Vector3 = b.pieces[wk].node.global_position
	check(is_equal_approx(we.chance(), WE.SHOWER_CHANCE), "with one, a %d%% chance of rain each morning" % int(we.chance() * 100))
	var wet_days := []
	var dry_days := []
	for d in range(1, 41):
		if we.rains_on(d):
			wet_days.append(d)
		else:
			dry_days.append(d)
	check(wet_days.size() > 15 and wet_days.size() < 35 and wet_days.all(func(d): return we.rains_on(d)), "it rains on %d of 40 mornings, the same ones every time" % wet_days.size())
	var far: Vector2i = W.cell_of(wp.x + 30.0, wp.z)
	var out: Vector2i = W.cell_of(wp.x + 50.0, wp.z)
	var sq: int = we.rain(wet_days[0])
	check(sq > 250 and w.is_soil(far) and is_equal_approx(w.cell_info(far).wet, WE.RAIN_L), "a shower waters %d squares and turns sand 30 m away to soil" % sq)
	check(w.cell_info(out).wet == 0.0, "but not 50 m away")
	check(we.prompt(wk).contains("60% chance"), "station prompt: " + we.prompt(wk).replace("\n", " / "))
	var dn = main.day_night
	var day0: int = dn.day
	var hour0: float = dn.hour
	dn.day = we.rain_day
	dn.hour = 8.0
	main.player.global_position = wp + Vector3(5, 0, 0)
	we._process(0.1)
	check(we.is_raining() and we.raining_here() and we._rain.emitting, "it rains in the morning by the station")
	main.player.global_position = wp + Vector3(120, 0, 0)
	check(not we.raining_here(), "but not far from it")
	dn.hour = 11.0
	check(not we.is_raining(), "and the rain stops at %d:00" % int(WE.RAIN_END))
	w.cells = {}
	w.on_morning()
	we.on_morning(dry_days[0])
	check(not w.cells.has(far), "a dry morning brings no rain")
	we.on_morning(wet_days[1])
	check(w.is_soil(far) and we.rain_day == wet_days[1], "a rainy morning does (day %d)" % wet_days[1])
	var sd: Dictionary = we.save_data()
	we.load_data({})
	check(we.rain_day == -1, "(reset)")
	we.load_data(JSON.parse_string(JSON.stringify(sd)))
	check(we.rain_day == wet_days[1], "the last rain is saved")
	we.load_data({"rain_day": "x", "rain_wide": 3})
	check(we.rain_day == -1 and not we.rain_wide, "a broken weather save falls back")
	b.remove(wk)
	# The ending.
	_green_squares(w, int(ceil(land * 0.1)) + 1)
	banners.clear()
	g.check()
	check(g.is_over() and ended[0] == 1 and we.rain_back and banners.size() == 1, "10%% green: the rain returns (%s)" % str(banners))
	check(main.ending_ui.is_open() and main.get_tree().paused, "the ending screen opens")
	check(we.rain_day == dn.day and we.rain_wide, "and the first rain falls over the whole desert")
	main.ending_ui.close()
	check(not main.ending_ui.is_open() and not main.get_tree().paused, "Keep playing goes on")
	check(we.chance() >= WE.RAIN_BACK_CHANCE and lv.next_goal < 0.0 and not lv.hud_text().contains("/"), "rain comes without a station now, and the HUD has no next goal")
	var c0: Vector2i = w.cells.keys()[0]
	w.cells[c0].wet = 0.0
	we.rain(dn.day)
	check(is_equal_approx(w.cell_info(c0).wet, WE.RAIN_L), "rain falls on every green square on the map")
	# Saving.
	var gsd: Dictionary = g.save_data()
	w.cells = {}
	g.load_data({})
	check(g.reached == 0 and not we.rain_back and sh.goal_level == 0, "(reset)")
	_green_squares(w, int(ceil(land * 0.1)) + 1)
	g.load_data(JSON.parse_string(JSON.stringify(gsd)))
	check(g.reached == G.GOALS.size() and we.rain_back and ended[0] == 1 and not main.ending_ui.is_open(), "goals are saved, and loading doesn't show the ending again")
	w.cells = {}
	g.load_data(gsd)
	check(g.reached == G.GOALS.size(), "reached milestones load even with the green gone")
	_green_squares(w, int(ceil(land * 0.025)) + 1)
	banners.clear()
	g.load_data({})
	check(g.reached == 2 and banners.is_empty(), "an older save gets the milestones its land reaches, quietly")
	g.load_data({"reached": "lots"})
	check(g.reached == 2, "a broken save falls back to what the land reaches")
	var data: Dictionary = main.collect_save_data()
	check(data.has("goals") and data.has("weather"), "the game saves goals and weather")
	main.map_ui.toggle()
	check(main.map_ui.is_open(), "the map opens with the goals panel")
	main.map_ui.toggle()
	# Peaceful mode.
	check(game.DIFFICULTIES.has("peaceful"), "a peaceful difficulty")
	game.difficulty = "peaceful"
	check(game.is_peaceful(), "peaceful mode is on")
	var wv = main.waves
	var mu = main.mutants
	var oa = main.oases
	wv.peaceful = true
	mu.peaceful = true
	oa.peaceful = true
	mu.clear()
	check(mu.top_up(dn.day) == 0 and mu.alive().is_empty(), "no mutants roam the desert")
	var wave0: int = wv.wave
	var summaries: Array = []
	wv.wave_ended.connect(func(s): summaries.append(s))
	wv.on_dusk(dn.day)
	wv.start_wave()
	check(not wv.active and wv.wave == wave0 + 1 and mu.alive().is_empty(), "nightfall brings no wave")
	var cash0: int = sh.cash
	wv.on_dawn(dn.day + 1)
	check(summaries.size() == 1 and summaries[0].get("quiet", false) and int(summaries[0].cash) > 0 and sh.cash > cash0, "a quiet night still pays at dawn ($%d)" % (sh.cash - cash0))
	check(load("res://scripts/waves.gd").summary_lines(summaries[0])[0].begins_with("Dawn: a quiet night"), "the summary says so")
	check(not wv.call_horde(Vector3.ZERO) and main.horde_prompt().contains("peaceful"), "the horde button does nothing: " + main.horde_prompt())
	var ni := -1
	for i in oa.count():
		if oa.list[i].has_nest:
			ni = i
	oa.load_data({})
	check(oa.wake_guards(0) == 0 and mu.alive().is_empty(), "no oasis guards come out")
	if ni >= 0:
		var gg: int = oa.list[ni].guards
		oa.tick(100.0)
		check(oa.list[ni].guards == gg, "nests don't breed")
	main.inventory.add("wood", 6)
	main.inventory.add("cloth", 2)
	check(oa.claim_problem(0) == "", "an oasis can be claimed without fighting: '%s'" % oa.claim_problem(0))
	wv.wave_ended.disconnect(wv.wave_ended.get_connections().back().callable)
	game.difficulty = "normal"
	wv.peaceful = false
	mu.peaceful = false
	oa.peaceful = false
	oa.load_data({})
	main.inventory.load_data({})
	dn.day = day0
	dn.hour = hour0
	g.message.disconnect(g.message.get_connections().back().callable)
	g.ended.disconnect(g.ended.get_connections().back().callable)
	w.load_data({})
	g.load_data({})
	we.load_data({})
	b.load_data([])


## v2.0: throwables (stones, molotovs, pipe bombs) and bags as physics props.
var throw := {}

func _test_throwables() -> void:
	var th = main.throwables
	var inv = main.inventory
	var Items = load("res://scripts/items.gd")
	var Throwables = load("res://scripts/throwables.gd")
	main.mutants.clear()
	main.building.load_data([])
	main.terrain.load_data({})
	check(Throwables.is_throwable("stone") and Throwables.is_throwable("molotov") and Throwables.is_throwable("pipe_bomb") and not Throwables.is_throwable("wood"), "stones, molotovs and pipe bombs can be thrown, wood can't")
	check(Items.RECIPES.has("molotov") and Items.RECIPES.has("pipe_bomb") and Items.recipe_tier("pipe_bomb") == 2, "molotovs are made at the workbench, pipe bombs at tier 2")
	check(main.melee.TOOLS.has("molotov") and main.melee._models.has("pipe_bomb"), "the hands hold a throwable")
	# Drawing back: a click lobs it, holding throws hard.
	th.charge = -1.0
	check(is_equal_approx(th.power(), th.MIN_POWER), "a quick click throws at %.0f%% power" % (th.power() * 100.0))
	th.charge = th.CHARGE_TIME * 2.0
	check(is_equal_approx(th.power(), 1.0), "held long enough, full power")
	inv.load_data({})
	inv.add_all({"stone": 3})
	inv.selected = 0
	check(main.holding_throwable() and th.held_prompt("stone").contains("Throw:"), "the prompt shows the draw: " + th.held_prompt("stone").replace("\n", " / "))
	th.charge = -1.0
	check(th.held_prompt("stone").contains("[LMB] Throw"), "and how to throw: " + th.held_prompt("stone").replace("\n", " / "))
	var body = th.throw_held("stone", 1.0)
	check(body is RigidBody3D and inv.count_of("stone") == 2 and th.flying.size() == 1, "throwing takes one from your hands and sends it flying")
	check(body.linear_velocity.length() > 15.0 and body.linear_velocity.normalized().dot(-main.player.camera.global_transform.basis.z) > 0.9, "where you look, fast (%.1f m/s)" % body.linear_velocity.length())
	check(body.is_in_group("loose_props"), "a blast can throw it about")
	inv.load_data({})
	check(th.throw_held("stone", 1.0) == null and th.flying.size() == 1, "nothing to throw with empty hands")
	# A landed stone lies on the ground to pick up again, and piles up.
	var bags_before: int = main.loot.drops.size()
	var spot := Vector3(-40, main.terrain.surface_height(-40, 30), 30)
	th.flying[0].node.global_position = spot + Vector3(0, 0.09, 0)
	th.land_stone(th.flying[0])
	check(th.flying.is_empty() and main.loot.drops.size() == bags_before + 1, "a stone that stops becomes a stone on the ground")
	var sid: String = main.loot.drops.keys().back()
	check(main.loot.drops[sid].items == {"stone": 1} and main.loot.prompt(sid) == "[E] Pick up 1 stone", "picked up like a bag: " + main.loot.prompt(sid))
	th.throw("stone", spot + Vector3(0.4, 1.0, 0), Vector3.ZERO)
	th.land_stones()
	check(main.loot.drops.size() == bags_before + 1 and main.loot.drops[sid].items.get("stone", 0) == 2, "a second stone lands on the pile (%s)" % str(main.loot.drops[sid].items))
	main.interact(sid)
	check(inv.count_of("stone") == 2 and not main.loot.drops.has(sid), "E picks the stones up again")
	# Saving with a stone in the air: it lands, nothing is lost.
	th.throw("stone", spot + Vector3(0, 3.0, 0), Vector3(0, 5, 0))
	var data: Dictionary = main.collect_save_data()
	check(th.flying.is_empty() and data.loot.drops.any(func(b): return b.items.has("stone")), "saving lands stones still in the air")
	th.ignite(spot)
	th.throw("pipe_bomb", spot + Vector3(0, 3.0, 0), Vector3.ZERO)
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(th.fires.is_empty() and th.flying.is_empty(), "loading puts fires out and drops what's in the air")
	for id in main.loot.drops.keys():
		main.loot.set_drop_items(id, {})
	# Fire burns you (now and then, not every frame).
	var p = main.player
	main.survival.health = 100.0
	th.ignite(p.global_position)
	th._player_burn = 0.0
	th._burn(0.1)
	th._burn(0.1)
	var burnt: float = 100.0 - main.survival.health
	check(burnt > 0.0 and burnt <= th.FIRE_PLAYER_DAMAGE + 0.01, "standing in your own fire burns (%.0f)" % burnt)
	th.clear()
	main.survival.health = 100.0
	# Fire sets a nest alight with no fuel can, and a fuel can is still needed by hand.
	var oa = main.oases
	var saved: Dictionary = oa.save_data()
	var k := -1
	for i in oa.count():
		if oa.list[i].nest == "alive":
			k = i
	if k >= 0:
		inv.load_data({})
		check(not oa.burn_nest(k), "without a fuel can E still can't burn a nest")
		th.ignite(oa.list[k].nest_pos + Vector3(2.0, 0, 0))
		check(oa.list[k].nest == "burning", "a molotov's fire 2 m from a nest sets it alight")
		th.clear()
		oa.load_data(JSON.parse_string(JSON.stringify(saved)))
	else:
		check(false, "the world has a nest to burn")
	# Bags are physics props now: they rest on what's under them and blasts throw them.
	var b = main.building
	var slot := {"kind": "cell", "cx": 5, "cz": 5, "dir": 0, "level": 0}
	var fk: String = b.place("foundation", slot, b.evaluate("foundation", slot).y)
	var fpos: Vector3 = b.pieces[fk].node.global_position
	var bag: String = main.loot.spawn_drop({"wood": 2}, Vector3(fpos.x, main.terrain.surface_height(fpos.x, fpos.z), fpos.z))
	var bn = main.loot.drops[bag].node
	check(bn is RigidBody3D and bn.is_in_group("loose_props"), "a dropped bag is a physics prop")
	var top: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(fpos + Vector3(0, 3, 0), fpos - Vector3(0, 2, 0), 1))
	check(not top.is_empty() and bn.global_position.y > top.position.y - 0.05, "a bag spilled on a foundation sits on top of it, not inside (%.2f / %.2f)" % [bn.global_position.y, top.get("position", Vector3.ZERO).y])
	main.loot.set_drop_items(bag, {})
	b.load_data([])
	var tossed: String = main.loot.toss_drop({"cloth": 1}, Vector3(-40, 5, 40), Vector3(2, 1, 0))
	check(main.loot.drops[tossed].node.linear_velocity.x > 1.0, "a bag dropped with G is tossed forward")
	main.loot.set_drop_items(tossed, {})


## Starts the moving throws: a stone at a walker, a molotov among two more,
## a pipe bomb next to one, with a bag lying beside it.
func _start_throws() -> void:
	var th = main.throwables
	var ms = main.mutants
	ms.clear()
	var t = main.terrain
	main.player.position = Vector3(-30, t.surface_height(-30, -55), -55)
	main.player.velocity = Vector3.ZERO
	main.survival.health = 100.0
	main.survival.stop_bleeding()
	var c := Vector3(-30, 0, -30)
	var g := func(v: Vector3) -> Vector3: return Vector3(v.x, t.surface_height(v.x, v.z), v.z)
	throw.stone_w = ms.spawn("walker", c + Vector3(12, 0, 0))
	throw.stone_w.set_physics_process(false)
	var sw: Vector3 = throw.stone_w.global_position
	throw.stone = th.throw("stone", sw + Vector3(0, 1.3, -4.0), Vector3(0, 0, 18))
	# A row of walkers, each hit by the same full-speed throw: continuous
	# collision slows a stone a frame before it reports the touch, which used
	# to make about one throw in fourteen do no harm.
	throw.row = []
	for i in 16:
		var rw = ms.spawn("walker", Vector3(-75 + i * 5.0, 0, -8))
		rw.set_physics_process(false)
		throw.row.append(rw)
		th.throw("stone", rw.global_position + Vector3(0, 1.3, -4.0), Vector3(0, 0, 18))
	throw.fire_in = ms.spawn("walker", c + Vector3(0.8, 0, 0))
	throw.fire_out = ms.spawn("walker", c + Vector3(6, 0, 0))
	for w in [throw.fire_in, throw.fire_out]:
		w.set_physics_process(false)
	th.throw("molotov", g.call(c) + Vector3(0, 2.0, 0), Vector3(0, -6, 0))
	var bc := c + Vector3(-12, 0, 0)
	throw.bomb_w = ms.spawn("walker", bc + Vector3(2.5, 0, 0))
	throw.bomb_w.set_physics_process(false)
	throw.bomb = th.throw("pipe_bomb", g.call(bc) + Vector3(0, 1.5, 0), Vector3(0, -3, 0))
	throw.bomb_top = 0.0
	throw.bag = main.loot.spawn_drop({"wood": 1}, g.call(bc + Vector3(0, 0, 2.0)))
	throw.bag_from = main.loot.drops[throw.bag].node.global_position


func _check_throws() -> void:
	var th = main.throwables
	var sw = throw.stone_w
	check(sw.health < 100.0, "a thrown stone hits a walker (%.0f health left)" % sw.health)
	var missed: Array = throw.row.filter(func(w): return w.health >= 100.0)
	check(missed.is_empty(), "every one of %d full-speed stones hurts the walker it hits (%d did no harm)" % [throw.row.size(), missed.size()])
	check(not th.flying.any(func(r): return r.node == throw.stone) and main.loot.drops.values().any(func(d): return d.items.has("stone")), "and then lies on the sand as a stone")
	check(throw.fire_in.health < 40.0, "a molotov's fire burns a walker standing in it (%.0f left)" % throw.fire_in.health)
	check(is_equal_approx(throw.fire_out.health, 100.0), "but not one 6 m away")
	check(th.fires.size() == 1, "the fire is still burning after 3 s")
	check(not is_instance_valid(throw.bomb) or throw.bomb.is_queued_for_deletion(), "the pipe bomb went off after its fuse")
	check(throw.bomb_w.health < 30.0 or throw.bomb_w.is_dead(), "and its blast hurt the walker 2.5 m away (%.0f left)" % throw.bomb_w.health)
	var moved: float = main.loot.drops[throw.bag].node.global_position.distance_to(throw.bag_from) if main.loot.drops.has(throw.bag) else 0.0
	check(moved > 0.5, "the blast threw the bag lying beside it (%.1f m)" % moved)
	check(is_equal_approx(main.survival.health, 100.0), "you were far enough away (health %.0f)" % main.survival.health)
	th.clear()
	main.mutants.clear()
	for id in main.loot.drops.keys():
		main.loot.set_drop_items(id, {})


## v2.1: warmth and cold nights, bleeding wounds, cooking, food going bad, heavy loads.
func _test_survival_depth() -> void:
	var Survival = load("res://scripts/survival.gd")
	var Camp = load("res://scripts/camp.gd")
	# Warmth.
	var a = Survival.new()
	var b = Survival.new()
	a.tick(60.0, 23.0, false, false)
	b.shelter = 1.0
	b.tick(60.0, 23.0, false, false)
	check(a.warmth < 70.0 and is_equal_approx(b.warmth, 100.0), "a cold night chills you in the open (%.0f), not indoors (%.0f)" % [a.warmth, b.warmth])
	check(Survival.is_cold_hour(2.0) and Survival.is_cold_hour(21.5) and not Survival.is_cold_hour(13.0) and not Survival.is_cold_hour(20.5), "the cold hours are 21:00 to 05:00")
	var c = Survival.new()
	c.shelter = 0.4
	c.tick(60.0, 23.0, false, false)
	check(c.warmth > a.warmth and c.warmth < 100.0, "a roof alone keeps some of the cold off (%.0f)" % c.warmth)
	a.near_fire = true
	var before: float = a.warmth
	a.tick(5.0, 23.0, false, false)
	check(a.warmth > before + 25.0, "a fire warms you up fast (%.0f to %.0f)" % [before, a.warmth])
	a.near_fire = false
	a.warmth = 50.0
	a.tick(10.0, 10.0, false, true)
	check(a.warmth > 60.0, "the day warms you back up (%.0f)" % a.warmth)
	# Cold: hungrier, no healing; no warmth at all hurts.
	var warm = Survival.new()
	var cold = Survival.new()
	warm.health = 50.0
	cold.health = 50.0
	cold.warmth = 20.0
	cold.tick(4.0, 13.0, false, true)
	warm.tick(4.0, 13.0, false, true)
	check(cold.is_cold() and not warm.is_cold(), "below %d warmth you are cold" % int(Survival.COLD_AT))
	check(100.0 - cold.food > (100.0 - warm.food) * 1.4, "being cold makes you hungrier")
	check(is_equal_approx(cold.health, 50.0) and warm.health > 50.0, "and you don't heal while cold (%.1f vs %.1f)" % [cold.health, warm.health])
	cold.warmth = 0.0
	cold.tick(4.0, 2.0, false, false)
	check(cold.health < 49.0 and cold.cause == "The cold got you.", "freezing hurts (%.1f)" % cold.health)
	check(cold.status_text().contains("Freezing"), "and the HUD says so: " + cold.status_text())
	c.warmth = 20.0
	check(c.status_text().contains("Cold"), "cold: " + c.status_text())
	# Bleeding.
	var w = Survival.new()
	var warned := []
	w.warning.connect(func(t): warned.append(t))
	check(not w.wound(12.0) and not w.bleeding(), "one claw doesn't open a wound yet")
	check(w.wound(12.0) and w.bleeding() and warned.any(func(t): return t.contains("bleeding")), "a second one does, with a warning")
	w.health = 80.0
	w.tick(10.0, 10.0, false, true)
	check(w.health < 80.0 - Survival.BLEED * 9.0, "a wound bleeds (%.1f)" % w.health)
	check(w.status_text().contains("Bleeding"), "the HUD says: " + w.status_text())
	for i in 10:
		w.wound(20.0)
	check(w.wounds.size() == Survival.WOUND_MAX, "at most %d wounds" % Survival.WOUND_MAX)
	w.consume("bandage")
	check(not w.bleeding(), "a bandage stops the bleeding")
	w.wound(25.0)
	w.health = 100.0
	w.tick(Survival.WOUND_TIME + 1.0, 10.0, false, true)
	check(not w.bleeding() and w.health > 50.0, "a wound closes on its own in time (%.0f health)" % w.health)
	w.wound(25.0)
	w.damage(500.0)
	w.respawn()
	check(not w.bleeding() and w.warmth >= 60.0, "respawning clears wounds and warms you")
	# Rotten food: a desperate meal.
	w.health = 5.0
	w.food = 10.0
	w.consume("rotten_food")
	check(w.food > 15.0 and w.health >= 1.0 and w.health < 5.0, "rotten food fills you a little and makes you sick")
	check(Survival.can_consume("flatbread") and Survival.can_consume("stew"), "flatbread and stew can be eaten")
	a.free(); b.free(); c.free(); warm.free(); cold.free(); w.free()
	# Claws open wounds, a brute's fist and acid don't.
	var sv = main.survival
	sv.health = 100.0
	sv.stop_bleeding()
	var near: Vector3 = main.player.global_position + Vector3(1, 0, 0)
	main._on_player_hit(30.0, near, "brute")
	main._on_player_hit(14.0, near, "spitter")
	check(not sv.bleeding(), "a brute's fist and acid don't make you bleed")
	sv.health = 100.0
	main._on_player_hit(12.0, near, "walker")
	main._on_player_hit(12.0, near, "walker")
	check(sv.bleeding(), "two walker claws do")
	sv.stop_bleeding()
	sv.health = 100.0
	# Saving.
	sv.warmth = 33.0
	sv.wound(25.0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	sv.warmth = 100.0
	sv.stop_bleeding()
	main.apply_save_data(data)
	check(is_equal_approx(sv.warmth, 33.0) and sv.wounds.size() == 1, "warmth and wounds are saved")
	data.survival.erase("warmth")
	data.survival.erase("wounds")
	main.apply_save_data(data)
	check(is_equal_approx(sv.warmth, 100.0) and not sv.bleeding(), "older saves load warm and unhurt")
	data.survival["warmth"] = "toasty"
	data.survival["wounds"] = [5.0, "x", -3, 9999.0, 1.0, 2.0]
	main.apply_save_data(data)
	check(is_equal_approx(sv.warmth, 100.0) and sv.wounds.size() == Survival.WOUND_MAX and sv.wounds[1] <= Survival.WOUND_TIME, "broken values fall back (%s)" % str(sv.wounds))
	sv.stop_bleeding()
	sv.health = 100.0
	sv.warmth = 100.0
	# Cooking at a fire pit.
	var cp = main.camp
	var bd = main.building
	var inv = main.inventory
	bd.load_data([])
	inv.load_data({})
	var fs := {"kind": "obj", "cx": -3, "cz": 6, "dir": 0, "level": 0}
	var pk: String = bd.place("fire_pit", fs, bd.evaluate("fire_pit", fs).y)
	var rec: Dictionary = bd.pieces[pk]
	inv.add_all({"raw_meat": 3, "millet": 5, "water": 2, "melon": 1})
	check(main._prompt_for("fire:" + pk).contains("Light the fire to cook"), "a cold fire can't cook")
	rec.burn = 200.0
	var pr: String = main._prompt_for("fire:" + pk)
	check(pr.contains("[E] Cook 3 raw meat, 4 flatbread"), "the fire pit offers what you can cook: " + pr.replace("\n", " / "))
	main.interact("fire:" + pk)
	check(inv.count_of("raw_meat") == 0 and inv.count_of("cooked_meat") == 3 and inv.count_of("flatbread") == 4, "E cooks the meat and bakes flatbread")
	check(inv.count_of("millet") == 1 and inv.count_of("water") == 0, "using 4 millet and 2 water")
	check(is_equal_approx(rec.burn, 200.0 - 5 * Camp.COOK_EACH), "each batch burns the fire down (%.0f)" % rec.burn)
	pr = main._prompt_for("fire:" + pk)
	check(pr.contains("[E] Cook 2 stew"), "cooked meat and a melon make stew: " + pr.replace("\n", " / "))
	main.interact("fire:" + pk)
	check(inv.count_of("stew") == 2 and inv.count_of("cooked_meat") == 2 and inv.count_of("melon") == 0, "two bowls of stew")
	check(cp.cook_prompt(rec) == "", "nothing left to cook")
	inv.load_data({})
	inv.add("raw_meat", 7)
	check(cp.cook_plan() == [[0, Camp.COOK_MAX]], "at most %d at a time" % Camp.COOK_MAX)
	# Warm by the fire.
	var fpos: Vector3 = rec.node.global_position
	check(cp.fire_near(fpos + Vector3(2, 0, 0)), "a burning fire warms you 2 m away")
	check(not cp.fire_near(fpos + Vector3(8, 0, 0)), "but not 8 m away")
	rec.burn = 0.0
	check(not cp.fire_near(fpos + Vector3(2, 0, 0)), "nor once it is out")
	# Food going bad.
	var Inv = load("res://scripts/inventory.gd")
	var i1 = Inv.new(60)
	var i2 = Inv.new(60)
	for x in [i1, i2]:
		x.add_all({"raw_meat": 40, "canned_food": 10, "dates": 10, "flatbread": 10})
	var n1: int = cp.spoil(i1, 1.0, "test", 4)
	var n2: int = cp.spoil(i2, 1.0, "test", 4)
	check(n1 > 8 and n1 < 32 and i1.count_of("raw_meat") == 40 - n1, "raw meat rots overnight (%d of 40)" % n1)
	check(i1.count_of("rotten_food") == n1, "into rotten food")
	check(i1.count_of("canned_food") == 10 and i1.count_of("dates") == 10 and i1.count_of("flatbread") == 10, "canned food, dates and flatbread keep")
	check(n1 == n2, "the same world and day rot the same food (%d, %d)" % [n1, n2])
	var pockets := 0
	var chests := 0
	for d in 20:
		var p = Inv.new(60)
		p.add("raw_meat", 40)
		pockets += cp.spoil(p, 1.0, "p", d)
		var q = Inv.new(60)
		q.add("raw_meat", 40)
		chests += cp.spoil(q, Camp.CHEST_KEEP, "q", d)
	check(chests < pockets * 0.7, "food keeps longer in a chest (%d vs %d rotted)" % [chests, pockets])
	inv.load_data({})
	inv.add("raw_meat", 10)
	var cs := {"kind": "obj", "cx": 2, "cz": 7, "dir": 0, "level": 0}
	var ck: String = bd.place("chest", cs, bd.evaluate("chest", cs).y)
	bd.storage_of(ck).add("raw_meat", 10)
	var rotted: int = cp.on_morning(main.day_night.day + 1)
	check(rotted > 0 and inv.count_of("raw_meat") + bd.storage_of(ck).count_of("raw_meat") == 20 - rotted, "each morning food rots in your pockets and chests (%d)" % rotted)
	# Heavy loads.
	check(Camp.load_factor(10.0, 50.0) == 1.0 and Camp.load_factor(25.0, 50.0) == 1.0, "a light load is no trouble")
	check(is_equal_approx(Camp.load_factor(50.0, 50.0), Camp.LOAD_FULL) and Camp.load_factor(60.0, 50.0) == Camp.LOAD_OVER, "a full bag makes work and climbing harder, too heavy even more")
	inv.load_data({})
	check(is_equal_approx(main.player.load_mult, 1.0), "empty pockets: climbing at full speed")
	inv.add("log", 10)
	inv.add("stone", 20)
	check(main.player.load_mult > 1.2 and cp.load_mult() == main.player.load_mult, "a heavy load slows climbing (x%.2f, %.0f kg)" % [main.player.load_mult, inv.weight()])
	inv.load_data({})
	bd.load_data([])


## v2.2 crafting chain: the furnace, brick pieces, glass panes and steel tools.
func _test_crafting_chain() -> void:
	var Furnace = load("res://scripts/furnace.gd")
	var Items = load("res://scripts/items.gd")
	var Melee = load("res://scripts/melee.gd")
	var Building = load("res://scripts/building.gd")
	var bd = main.building
	var inv = main.inventory
	bd.load_data([])
	inv.load_data({})
	var fs := {"kind": "obj", "cx": -4, "cz": 6, "dir": 0, "level": 0}
	var ev: Dictionary = bd.evaluate("furnace", fs)
	check(ev.ok, "a furnace can be built on open sand (%s)" % ev.get("reason", ""))
	var fk: String = bd.place("furnace", fs, ev.y)
	var f: Dictionary = bd.pieces[fk]
	check(f.node.get_meta("interact_id") == "furnace:" + fk and f.heat == 0.0 and f.load == 0, "a new furnace is cold and empty")
	check(main._prompt_for("furnace:" + fk).contains("Hold scrap, sand or clay"), "its prompt says what to hold: " + main._prompt_for("furnace:" + fk).replace("\n", " / "))
	inv.add_all({"clay": 40, "wood": 20, "sand": 9, "scrap": 4})
	var lines: Array = Furnace.use(f, inv, "clay")
	check(f.smelt == "clay" and f.load == Furnace.LOAD_MAX and inv.count_of("clay") == 40 - Furnace.LOAD_MAX, "E with clay in hand loads the hopper, up to %d (%s)" % [Furnace.LOAD_MAX, str(lines)])
	lines = Furnace.use(f, inv, "sand")
	check(f.smelt == "clay" and inv.count_of("sand") == 9 and lines[0].begins_with("!"), "one kind at a time: %s" % str(lines))
	check(not Furnace.work(f, 10.0) and f.made.is_empty(), "no fuel, no smelting")
	check(Furnace.prompt(f, "").contains("out of fuel"), "and the prompt says it's out of fuel")
	Furnace.use(f, inv, "wood")
	check(is_equal_approx(f.heat, Furnace.HEAT_MAX) and inv.count_of("wood") == 20 - int(Furnace.HEAT_MAX / Furnace.FUEL.wood), "E with wood burns it, up to %d s of fuel (%.0f)" % [int(Furnace.HEAT_MAX), f.heat])
	for i in 30:
		Furnace.work(f, 0.5)  # 15 s at 6 s a batch: 2 batches
	check(int(f.made.get("brick", 0)) == 4 and f.load == Furnace.LOAD_MAX - 4, "2 clay make 2 bricks every 6 s (%s, %d left)" % [str(f.made), f.load])
	check(is_equal_approx(f.heat, Furnace.HEAT_MAX - 15.0), "burning fuel only while it smelts (%.1f)" % f.heat)
	check(Furnace.prompt(f, "").contains("smelting clay to bricks") and Furnace.prompt(f, "").contains("4 bricks ready"), "the prompt: " + Furnace.prompt(f, "").replace("\n", " / "))
	# The furnace node does the same four times a second, shows its glow and warms you.
	main.furnace.tick(0.25)
	check(f.working and f.glow.visible, "a working furnace glows")
	check(main.camp.fire_near(f.node.global_position + Vector3(2, 0, 0)), "and keeps you warm like a fire pit")
	lines = Furnace.use(f, inv, "")
	check(inv.count_of("brick") == 4 and f.made.is_empty() and lines.size() == 1, "E takes out what's ready (%s)" % str(lines))
	for i in 200:
		Furnace.work(f, 1.0)
	check(f.load == 0 and f.smelt == "" and int(f.made.get("brick", 0)) == 26, "it smelts the whole load and then rests (%s)" % str(f.made))
	check(not Furnace.work(f, 1.0) and Furnace.prompt(f, "").contains("cold"), "an empty furnace is idle")
	# Full: it stops until you take things out.
	Furnace.use(f, inv, "sand")
	f.made = {"glass": Furnace.MADE_MAX}
	check(not Furnace.can_work(f) and Furnace.prompt(f, "").contains("full"), "a full furnace stops: " + Furnace.prompt(f, "").replace("\n", " / "))
	f.made = {}
	for i in 30:
		Furnace.work(f, 1.0)
	check(int(f.made.get("glass", 0)) == 3 and f.load == 0, "3 sand make a glass (%s)" % str(f.made))
	Furnace.use(f, inv, "scrap")
	for i in 30:
		Furnace.work(f, 1.0)
	check(int(f.made.get("metal_plate", 0)) == 2 and inv.count_of("scrap") == 0, "2 scrap make a metal plate (%s)" % str(f.made))
	check(inv.count_of("glass") == 3, "loading the scrap took out the glass")
	# Saving.
	Furnace.use(f, inv, "clay")
	Furnace.work(f, 2.0)
	f.made = {"glass": 2}
	var data: Dictionary = JSON.parse_string(JSON.stringify(main.collect_save_data()))
	main.apply_save_data(data)
	var fk2: Array = bd.keys_of(["furnace"])
	var g: Dictionary = bd.pieces[fk2[0]] if fk2.size() == 1 else {}
	check(not g.is_empty() and g.smelt == "clay" and g.load == 10 and int(g.made.get("glass", 0)) == 2 and absf(g.heat - f.heat) < 0.01 and absf(g.progress - 2.0) < 0.01, "a furnace's fuel, load, progress and finished goods are saved")
	check(g.has("glow") and g.node.get_meta("interact_id") == "furnace:" + fk2[0], "and it loads as a working furnace")
	var broken := {"heat": "hot", "smelt": "gold", "load": 5, "made": {"brick": "lots", "nope": 3, "glass": 999}, "progress": [1]}
	var h := {}
	Furnace.restore(h, broken)
	check(h.heat == 0.0 and h.smelt == "" and h.load == 0 and h.made == {"glass": Furnace.MADE_MAX} and h.progress == 0.0, "a broken furnace in a save falls back (%s)" % str(h))
	var old := {}
	Furnace.restore(old, {})
	check(old.smelt == "" and old.made.is_empty(), "missing fields load as an empty furnace")
	# Brick pieces.
	bd.load_data([])
	inv.load_data({})
	var ws: Dictionary = Building.slot_for("brick_wall", Vector3(-6, 0, 10), 0)
	var wev: Dictionary = bd.evaluate("brick_wall", ws)
	var wk: String = bd.place("brick_wall", ws, wev.y)
	var w: Dictionary = bd.pieces[wk]
	check(is_equal_approx(bd.max_hp(w), 1200.0) and bd.describe(w) == "Brick wall" and bd.upgrade_cost(w).is_empty(), "a brick wall: 1200 hit points, no tiers")
	bd.damage(wk, 400.0)
	check(bd.repair_cost(w) == {"brick": 2}, "it is mended with bricks (%s)" % str(bd.repair_cost(w)))
	check(bd.refund(w) == {"brick": 6, "clay": 1}, "and knocked down for half its bricks back (%s)" % str(bd.refund(w)))
	check("brick_wall" in Building.WALLISH and "glass_window" in Building.WALLISH, "brick walls hold up floors like walls")
	var gs: Dictionary = Building.slot_for("glass_window", Vector3(-4, 0, 10), 0)
	var gk: String = bd.place("glass_window", gs, bd.evaluate("glass_window", gs).y)
	var has_glass: bool = bd.pieces[gk].node.get_children().any(func(c): return c is MeshInstance3D and c.get_meta("mat", "") == "glass")
	check(has_glass and Building.piece_colliders("glass_window").size() == 1, "the glass window wall has a pane and is solid all over")
	check("furnace" in Building.ORDER and "brick_wall" in Building.ORDER and "glass_window" in Building.ORDER, "the new pieces are in build mode")
	# Workbench parts and tools.
	inv.add_all({"glass": 2, "metal_plate": 7, "wood": 6, "cloth": 1})
	check(Items.craft("glass_pane", inv) != null and inv.count_of("glass_pane") == 1, "2 glass and a piece of wood make a glass pane")
	check(Items.craft("steel_shovel", inv) != null and Items.craft("sledgehammer", inv) != null, "metal plates make a steel shovel and a sledgehammer")
	check(Melee.is_weapon("sledgehammer") and "steel_shovel" in Melee.TOOLS, "the sledgehammer is a weapon, the steel shovel a tool")
	# The steel shovel digs faster.
	inv.selected = inv.slots.find(inv.slots.filter(func(sl): return not sl.is_empty() and sl.item == "steel_shovel")[0])
	check(main.dig_tool() == "shovel" and is_equal_approx(main.dig_speed(), 2.0), "the steel shovel is a shovel that digs twice as fast")
	# A sledgehammer blow knocks a piece down at once, with the half refund.
	inv.selected = inv.slots.find(inv.slots.filter(func(sl): return not sl.is_empty() and sl.item == "sledgehammer")[0])
	main.melee.swing_time = -1.0
	main.player.stamina = 100.0
	var bricks: int = inv.count_of("brick")
	check(main.sledge.blow(wk) and not bd.pieces.has(wk) and inv.count_of("brick") == bricks + 6, "one sledgehammer blow knocks the brick wall down (+6 bricks)")
	check(main.sledge.blow(gk) and bd.pieces.has(gk), "the next blow waits for the swing")
	main.melee.swing_time = -1.0
	var rock := -1
	for i in main.props.rocks.size():
		if not main.broken_rocks.has(i) and main.rock_hits_left(i) > _sledge_rock_hits():
			rock = i
			break
	var stones: int = inv.count_of("stone")
	var hits: int = main.rock_hits_left(rock) if rock >= 0 else 0
	check(rock >= 0 and main.sledge.blow("", rock) and inv.count_of("stone") == stones + _sledge_rock_hits() and main.rock_hits_left(rock) == hits - _sledge_rock_hits(), "a blow at a rock smashes off %d stone" % _sledge_rock_hits())
	if rock >= 0:
		main.rock_hits.erase(rock)
	main.melee.swing_time = -1.0
	inv.load_data({})
	bd.load_data([])


func _sledge_rock_hits() -> int:
	return load("res://scripts/sledge.gd").ROCK_HITS


var shelter := {}

## Builds a cabin to stand in for the shelter check (its bodies need a physics frame).
func _start_shelter() -> void:
	var b = main.building
	var Prefabs = load("res://scripts/prefabs.gd")
	b.load_data([])
	var at := Vector2i(-8, -8)
	for e in Prefabs.entries("cabin"):
		var slot: Dictionary = {"kind": e.kind, "cx": e.cx + at.x, "cz": e.cz + at.y, "dir": e.dir, "level": e.level}
		var ev: Dictionary = b.evaluate(e.type, slot)
		if ev.ok:
			b.place(e.type, slot, ev.y)
	var mid := Vector3.ZERO
	var roofs: Array = b.keys_of(["roof"])
	for k in roofs:
		mid += b.pieces[k].node.global_position
	mid /= maxf(roofs.size(), 1)
	shelter.mid = mid
	shelter.roofs = roofs.size()


func _check_shelter() -> void:
	var cp = main.camp
	var player = main.player
	var mid: Vector3 = shelter.mid
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(mid.x, mid.y - 0.5, mid.z), Vector3(mid.x, mid.y - 8.0, mid.z), 1))
	player.position = down.get("position", Vector3(mid.x, main.terrain.surface_height(mid.x, mid.z), mid.z)) + Vector3(0, 0.05, 0)
	var inside: float = cp.shelter_at(player)
	check(shelter.roofs > 0 and inside > 0.8, "inside a cabin you are sheltered (%.2f)" % inside)
	player.position = Vector3(40, main.terrain.surface_height(40, 90), 90)
	var open: float = cp.shelter_at(player)
	check(open < 0.2, "on open sand you are not (%.2f)" % open)
	main.building.load_data([])
	player.position = Vector3(0, main.terrain.surface_height(0, 8), 8)


## v2.3 events: sandstorms, the Behemoth and day raids on outposts.
func _test_events() -> void:
	var Events = load("res://scripts/events.gd")
	var Waves = load("res://scripts/waves.gd")
	var Mutant = load("res://scripts/mutant.gd")
	var ev = main.events
	var dn = main.day_night
	var mu = main.mutants
	var t = main.terrain
	main.building.load_data([])
	mu.clear()
	# Planning: the same world and day always plan the same.
	check(Events.plan_for(7, 12, [0]) == Events.plan_for(7, 12, [0]), "the same seed and day plan the same events")
	var storms := 0
	var raids := 0
	var early := false
	var in_range := true
	for d in range(1, 101):
		var p: Dictionary = Events.plan_for(99, d, [1])
		if p.has("storm"):
			storms += 1
			early = early or d < Events.STORM_FIRST_DAY
			in_range = in_range and p.storm.start >= Events.STORM_FROM and p.storm.end <= Events.STORM_TO + Events.STORM_MAX_H and p.storm.end < 18.5
		if p.has("raid"):
			raids += 1
			in_range = in_range and p.raid.outpost == 1 and p.raid.hour >= Events.RAID_FROM and p.raid.hour <= Events.RAID_TO
	check(storms > 15 and storms < 50 and not early, "storms blow on some days, never on the first two (%d in 100)" % storms)
	check(raids > 20 and raids < 60, "outposts are raided on some days (%d in 100)" % raids)
	check(in_range, "storms and raids keep to their hours (and storms are over before dusk)")
	var none := true
	for d in range(1, 60):
		none = none and not Events.plan_for(99, d, []).has("raid") and not Events.plan_for(99, d, [0], true).has("raid")
	check(none, "no raids without an outpost, nor in peaceful mode")
	var st := {"start": 10.0, "end": 13.0, "dir": 0.0}
	check(Events.strength_at(st, 9.9) == 0.0 and Events.strength_at(st, 11.5) == 1.0 and Events.strength_at(st, 10.2) > 0.0 and Events.strength_at(st, 10.2) < 1.0, "a storm builds up, blows and dies down")
	check(Events.dir_name(PI) == "west" and Events.dir_name(0.0) == "east", "wind directions are named")
	# A storm blowing now.
	var base_fog: float = main.env.fog_density
	dn.hour = 11.0
	ev.plan_day(dn.day)
	ev.plan = {"storm": {"start": 10.0, "end": 13.0, "dir": 0.0}}
	var msgs: Array = []
	var grab := func(text): msgs.append(text)
	ev.message.connect(grab)
	ev.tick(0.25)
	check(ev.strength == 1.0 and is_equal_approx(main.env.fog_density, Events.STORM_FOG) and dn.dust == 1.0, "in a storm the fog closes in and the sky turns brown")
	check(mu.storm and main.ambience.storm == 1.0 and ev._sand.emitting, "mutants see less, the wind howls and sand blows past")
	var band: Array = ev.band("storm")
	check(band.size() == Events.storm_size_for(dn.day) and band.all(func(m): return m.hunter and m.global_position.x > 100.0), "a band of %d mutants comes in on the wind (from the east)" % band.size())
	check(msgs.any(func(m): return "sandstorm" in m.to_lower()), "a banner warns of the storm")
	check("Sandstorm" in ev.hud_text(), "the HUD says there is a sandstorm")
	# Saving and loading keeps who came with the storm.
	var md: Dictionary = mu.save_data()
	mu.load_data(md)
	check(ev.band("storm").size() == band.size(), "storm mutants stay storm mutants when saved and loaded")
	var sd: Dictionary = ev.save_data()
	ev.load_data(sd)
	check(ev.storm_spawned and ev.warned and ev.day == dn.day, "the day's events are saved")
	check(main.collect_save_data().get("events", {}).get("storm_spawned", false) == true, "and go into the save file")
	ev.plan = {"storm": {"start": 10.0, "end": 13.0, "dir": 0.0}}
	ev.load_data({"day": "x", "storm_spawned": 3, "raid": 5})
	check(not ev.storm_spawned and ev.raid_state == "", "a broken events save falls back to a fresh day")
	ev.load_data({})
	check(ev.day == dn.day and ev.raid_state == "", "an older save without events plans the day it loads into")
	ev.plan = {"storm": {"start": 10.0, "end": 13.0, "dir": 0.0}}
	ev.storm_spawned = true
	ev.warned = true
	ev.tick(0.25)
	# Drifting sand fills dug holes, never above the old ground.
	t.load_data({})
	var hole := Vector2(14.5, 14.5)
	for i in 4:
		t.dig(hole.x, hole.y)
	var c: Vector2i = t.dig_cell(hole.x, hole.y)
	check(t.dug_cells().has(hole), "the dug hole is found")
	var depth0: float = t.cell_depth(c)
	check(ev.drift() >= 1 and t.cell_depth(c) < depth0 - 0.2, "a drift of sand fills the hole a step (%.2f m to %.2f m)" % [depth0, t.cell_depth(c)])
	for i in 12:
		ev.drift()
	check(absf(t.cell_depth(c)) < 0.01 and t.dug_cells().is_empty(), "drifts fill it up to the old ground and no higher")
	check(not t.silt(20.5, 20.5), "flat ground gets no sand piled on it")
	for i in 4:
		t.dig(hole.x, hole.y)
	var fs := {"kind": "obj", "cx": 7, "cz": 7, "dir": 0, "level": 0}
	var bev: Dictionary = main.building.evaluate("chest", fs)
	var ck: String = main.building.place("chest", fs, bev.y) if bev.ok else ""
	var near: bool = ck != "" and Vector2(main.building.pieces[ck].node.global_position.x, main.building.pieces[ck].node.global_position.z).distance_to(hole) < 1.6
	var d1: float = t.cell_depth(c)
	ev.drift()
	check(not near or absf(t.cell_depth(c) - d1) < 0.001, "holes right by a building piece are left alone (%s)" % ("tested" if near else "chest elsewhere"))
	main.building.load_data([])
	t.load_data({})
	# The storm passes: its mutants sink into the sand and the sky clears.
	dn.hour = 13.5
	ev.tick(0.25)
	check(ev.strength == 0.0 and ev.band("storm").is_empty() and is_equal_approx(main.env.fog_density, base_fog) and dn.dust == 0.0, "when the storm passes its mutants go and the fog lifts")
	check(not mu.storm and msgs.any(func(m): return "passed" in m), "and a banner says it has passed")
	mu.clear()
	# A day raid on an outpost.
	var oa = main.oases
	var was_claimed: bool = oa.list[0].claimed
	oa.list[0].claimed = true
	dn.hour = 12.0
	ev.plan_day(dn.day)
	ev.plan = {"raid": {"outpost": 0, "hour": 11.5, "size": 4}}
	ev.tick(0.25)
	var post: Vector3 = oa.list[0].post_pos
	var raiders: Array = ev.band("raid")
	check(ev.raid_state == "on" and raiders.size() == 4, "raiders come for the outpost (%s, %d)" % [ev.raid_state, raiders.size()])
	check(raiders.all(func(m): return m.hunter and Vector2(m.home.x - post.x, m.home.z - post.z).length() < 0.1 and Vector2(m.base_goal.x - post.x, m.base_goal.z - post.z).length() < 0.1), "and stay at the outpost")
	check(raiders.all(func(m): return Vector2(m.global_position.x - post.x, m.global_position.z - post.z).length() > 40.0), "they start out in the desert")
	check("Raid on outpost 1: 4 left" in ev.hud_text(), "the HUD counts the raiders")
	var cash: int = main.shop.cash
	for m in raiders:
		m.hurt(99999.0)
	ev.tick(0.25)
	check(ev.raid_state == "won" and main.shop.cash == cash + Events.RAID_PAY + 4 * Events.RAID_PAY_EACH, "driving them off pays $%d" % (main.shop.cash - cash))
	ev.tick(0.25)
	check(ev.band("raid").is_empty() and ev.raid_state == "won", "a raid happens once a day")
	ev.plan_day(dn.day)
	ev.plan = {"raid": {"outpost": 0, "hour": 11.5, "size": 3}}
	ev.tick(0.25)
	dn.hour = 19.2
	ev.tick(0.25)
	check(ev.raid_state == "gone" and ev.band("raid").is_empty(), "raiders still about at dusk slink off")
	oa.list[0].claimed = false
	ev.plan_day(dn.day)
	ev.plan = {"raid": {"outpost": 0, "hour": 11.5, "size": 3}}
	dn.hour = 12.0
	ev.tick(0.25)
	check(ev.raid_state == "gone" and ev.band("raid").is_empty(), "no raid on an outpost that isn't claimed")
	oa.list[0].claimed = was_claimed
	mu.clear()
	# The Behemoth.
	check(Waves.boss_night(10) and Waves.boss_night(20) and not Waves.boss_night(9) and not Waves.boss_night(0), "a Behemoth comes every tenth night")
	var wv = main.waves
	var w0: int = wv.wave
	wv.wave = 9
	var lineup: Array = wv.preview_next()
	check(lineup.count("behemoth") == 1 and lineup.back() == "behemoth", "night 10's wave ends with a Behemoth (%s)" % Waves.mix_text(lineup))
	wv.wave = 10
	check(not wv.preview_next().has("behemoth"), "night 11 has none")
	wv.wave = 9
	check(ev.boss_tonight(), "the dusk before night 10 warns of it")
	wv.wave = w0
	check("behemoth" in Mutant.WRECKERS and Waves.BOUNTY.behemoth >= 200, "it walks through walls and is worth a big bounty")
	var b = mu.spawn("behemoth", Vector3(30, 0, 60))
	check(is_equal_approx(b.health, Mutant.TYPES.behemoth.health * mu.health_mult) and b.stats.wall_damage > 200.0, "a Behemoth has %d health" % int(b.health))
	check("Behemoth: " in ev.hud_text(), "its health shows on the HUD")
	var drops: Array = []
	var grab2 := func(items, _pos): drops.append(items)
	ev.spilled.connect(grab2)
	b.hurt(99999.0)
	check(drops.size() == 1 and drops[0].get("metal_plate", 0) > 0, "it drops a pile of scrap and metal plates")
	ev.spilled.disconnect(grab2)
	ev.message.disconnect(grab)
	mu.clear()
	ev.plan_day(dn.day)
	dn.hour = 9.0
	ev.tick(0.25)

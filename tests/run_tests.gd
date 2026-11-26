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


func _initialize() -> void:
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
	check(b.velocity.length() < w.velocity.length() * 0.5, "brutes barely flinch when hit")
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


## A wave mutant smells you behind a wall and breaks through it.
func _start_break_in() -> void:
	var b = main.building
	var player = main.player
	var slot := {"kind": "edge", "cx": 0, "cz": -2, "dir": 0, "level": 0}
	break_wall = b.place("wall", slot, b.evaluate("wall", slot).y, false, 0, 60.0)
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


func _process(_delta: float) -> bool:
	frame += 1
	var player = main.player
	var terrain = main.terrain
	if frame > 2010 and frame < 2250 and not main.mutants.spits().is_empty():
		spit_seen = true
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
			_start_ladder()
		3300:
			_check_debris()
			_check_ladder()
		3310:
			if failures.is_empty():
				print("== ALL TESTS PASSED ==")
				quit(0)
			else:
				print("== %d TEST(S) FAILED ==" % failures.size())
				quit(1)
	return false

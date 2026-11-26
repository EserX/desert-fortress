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
	inv.add_all({"wood": 5, "scrap": 20, "nails": 10, "cement": 10})
	main.hammer_use(key)
	check(rec.hp == 250.0 and inv.count_of("wood") == 3, "hammer repairs for 2 wood")
	main.hammer_use(key)
	check(rec.tier == 1 and rec.hp == 600.0 and inv.count_of("scrap") == 16, "hammer upgrades wood to scrap metal (4 scrap)")
	main.hammer_use(key)
	check(rec.tier == 2 and rec.hp == 1500.0 and inv.count_of("cement") == 7, "and scrap metal to concrete (3 cement)")
	check(b.upgrade_cost(rec).is_empty(), "concrete is the top tier")
	check(main.hammer_prompt(key).contains("Fully upgraded"), "prompt: " + main.hammer_prompt(key).replace("\n", " | "))
	# Saved with tier and hit points.
	b.damage(key, 400.0)
	var data: Array = JSON.parse_string(JSON.stringify(b.save_data()))
	b.load_data(data)
	rec = b.pieces[key]
	check(rec.tier == 2 and rec.hp == 1100.0, "tier and hit points are saved")
	# Too late to undo in build mode; the hammer demolishes for half back.
	rec.built_at -= 61000
	main.build_mode.active = true
	main.build_mode.looking_at_piece = key
	check(main.build_mode.try_remove() == "old", "build-mode undo only right after building")
	main.build_mode.active = false
	var refund: Dictionary = b.refund(rec)
	check(refund == {"wood": 1, "nails": 2, "scrap": 2, "cement": 1}, "demolish refunds half %s" % str(refund))
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


func _process(_delta: float) -> bool:
	frame += 1
	var player = main.player
	var terrain = main.terrain
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
		820:
			if failures.is_empty():
				print("== ALL TESTS PASSED ==")
				quit(0)
			else:
				print("== %d TEST(S) FAILED ==" % failures.size())
				quit(1)
	return false

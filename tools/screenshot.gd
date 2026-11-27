extends SceneTree
## Renders screenshots from several viewpoints and times of day into screenshots/.
## Needs a display (use xvfb-run on servers):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . -s tools/screenshot.gd \
##       --rendering-method gl_compatibility --resolution 1280x720
## Optional: add "-- only=05_wreck" to render a single shot.

var main: Node
var frame := 0
var idx := 0
var shots := [
	{"name": "01_spawn", "pos": Vector3(0, 0, 9), "yaw": 0.0, "pitch": -0.05, "hour": 10.0},
	{"name": "02_dunes", "pos": Vector3(40, 0, 60), "yaw": 2.4, "pitch": -0.02, "hour": 13.0},
	{"name": "03_overview", "pos": Vector3(0, 30, 0), "yaw": 0.8, "pitch": -0.35, "hour": 15.0},
	{"name": "04_sunset", "pos": Vector3(0, 0, 9), "yaw": -1.57, "pitch": 0.05, "hour": 19.6},
	{"name": "05_night", "pos": Vector3(0, 0, 9), "yaw": 0.5, "pitch": 0.15, "hour": 23.0},
	{"name": "06_wreck", "target": "wreck", "hour": 11.0},
	{"name": "07_ruin", "target": "ruin", "hour": 16.0},
	{"name": "09_crate", "target": "crate", "hour": 10.5},
	{"name": "10_inventory", "pos": Vector3(0, 0, 9), "yaw": 0.6, "pitch": -0.05, "hour": 10.0, "inventory": true},
	{"name": "11_death", "pos": Vector3(0, 0, 9), "yaw": 0.6, "pitch": -0.05, "hour": 13.0, "death": true},
	{"name": "12_map", "pos": Vector3(20, 0, 40), "yaw": 0.9, "pitch": 0.0, "hour": 9.0, "map": true},
	{"name": "13_build", "pos": Vector3(13, 0, 20), "yaw": 0.55, "pitch": -0.2, "hour": 15.5, "build": true},
	{"name": "14_tiers", "pos": Vector3(7, 0, 16.5), "yaw": 0.0, "pitch": -0.1, "hour": 10.0, "tiers": true},
	{"name": "15_base", "pos": Vector3(1, 0, 10), "yaw": PI + 0.15, "pitch": -0.12, "hour": 16.0, "base": true, "zone": true},
	{"name": "16_bench", "pos": Vector3(-1, 0, 19.6), "yaw": 0.0, "pitch": -0.3, "hour": 16.0, "base": true, "bench": true},
	{"name": "17_melee", "pos": Vector3(-2.6, 0, 6.0), "yaw": 0.2, "pitch": -0.08, "hour": 9.5, "melee": true},
	{"name": "18_walker", "pos": Vector3(60, 0, 60), "yaw": 0.4, "pitch": -0.05, "hour": 17.5, "walker": true},
	{"name": "19_walker_night", "pos": Vector3(60, 0, 60), "yaw": 0.4, "pitch": -0.02, "hour": 22.5, "walker": true},
	{"name": "20_wave", "pos": Vector3(2, 0, 14), "yaw": 0.3, "pitch": -0.04, "hour": 21.2, "wave": true},
	{"name": "21_summary", "pos": Vector3(2, 0, 14), "yaw": 0.3, "pitch": -0.04, "hour": 6.4, "summary": true},
	{"name": "22_breakin", "pos": Vector3(3.0, 0, -0.5), "yaw": 0.25, "pitch": -0.1, "hour": 19.4, "breakin": true},
	{"name": "23_types", "pos": Vector3(60, 0, 60), "yaw": 0.4, "pitch": -0.03, "hour": 16.5, "types": true},
	{"name": "24_pistol", "pos": Vector3(60, 0, 60), "yaw": 0.4, "pitch": -0.03, "hour": 10.5, "gun": "pistol", "aim": false},
	{"name": "25_pistol_ads", "pos": Vector3(60, 0, 60), "yaw": 0.4, "pitch": -0.03, "hour": 18.8, "gun": "pistol", "aim": true},
	{"name": "26_shotgun", "pos": Vector3(60, 0, 60), "yaw": 0.4, "pitch": -0.03, "hour": 9.0, "gun": "shotgun", "aim": false},
	{"name": "27_rifle_scope", "pos": Vector3(60, 0, 60), "yaw": 0.4, "pitch": -0.0, "hour": 9.0, "gun": "rifle", "aim": true},
	{"name": "28_traps", "pos": Vector3(5, 0, -0.5), "yaw": 0.55, "pitch": -0.3, "hour": 16.5, "traps": true},
	{"name": "29_power", "pos": Vector3(6, 0, 10), "yaw": 0.35, "pitch": -0.12, "hour": 22.0, "power": true},
	{"name": "30_turret", "pos": Vector3(8, 0, 5), "yaw": -0.1, "pitch": 0.02, "hour": 17.0, "turret": true},
	{"name": "31_terminal", "pos": Vector3(-0.6, 0, 4.2), "yaw": 0.5, "pitch": -0.2, "hour": 10.0, "terminal": true},
	{"name": "32_shop", "pos": Vector3(-0.6, 0, 4.2), "yaw": 0.5, "pitch": -0.2, "hour": 10.0, "shop": true},
	{"name": "33_drone", "pos": Vector3(4.5, 0, 12.5), "yaw": 0.17, "pitch": 0.28, "hour": 15.0, "drone": true},
	{"name": "34_drone_shop", "pos": Vector3(4, 0, 9), "yaw": 0.6, "pitch": 0.0, "hour": 15.0, "drone_shop": true},
	{"name": "35_upgrades", "pos": Vector3(-0.6, 0, 4.2), "yaw": 0.5, "pitch": -0.2, "hour": 10.0, "upgrades": true},
	{"name": "36_chest", "pos": Vector3(-0.6, 0, 4.2), "yaw": 0.5, "pitch": -0.2, "hour": 10.0, "bigchest": true},
	{"name": "37_hint", "pos": Vector3(0, 0, 9), "yaw": 0.3, "pitch": -0.05, "hour": 9.0, "hint": true},
	{"name": "38_controls", "pos": Vector3(0, 0, 9), "yaw": 0.0, "pitch": 0.0, "hour": 12.0, "menu": true, "page": "controls"},
	{"name": "39_settings", "pos": Vector3(0, 0, 9), "yaw": 0.0, "pitch": 0.0, "hour": 12.0, "menu": true, "page": "settings"},
	{"name": "40_wave_map", "pos": Vector3(20, 0, 40), "yaw": 0.9, "pitch": 0.0, "hour": 21.5, "wave_map": true},
	{"name": "41_digging", "pos": Vector3(12, 0, 13.4), "yaw": 0.0, "pitch": -0.9, "hour": 15.5, "digging": true},
	{"name": "42_trench", "pos": Vector3(12, 12, 22), "yaw": 0.0, "pitch": -0.7, "hour": 15.5, "digging": true},
	{"name": "43_layers", "pos": Vector3(-10, 0, -1.5), "yaw": 0.0, "pitch": -0.75, "hour": 14.0, "layers": true},
	{"name": "44_detector", "pos": Vector3(0, 0, 9), "yaw": 0.4, "pitch": -0.3, "hour": 10.0, "detector": true},
	{"name": "45_well", "pos": Vector3(-11, 0, -1.6), "yaw": 0.0, "pitch": -0.3, "hour": 10.0, "well": true},
	{"name": "46_support", "pos": Vector3(15, 0, -1.5), "yaw": 0.0, "pitch": 0.12, "hour": 16.0, "support": true},
	{"name": "47_pieces", "pos": Vector3(-7, 0, 25), "yaw": 0.0, "pitch": -0.08, "hour": 15.0, "pieces2": true},
	{"name": "48_prefabs", "pos": Vector3(6, 0, 16), "yaw": 0.25, "pitch": -0.1, "hour": 16.5, "prefabs": true},
	{"name": "49_blueprint", "pos": Vector3(10, 0, 15), "yaw": 0.0, "pitch": -0.2, "hour": 11.0, "prefab_ghost": true},
	{"name": "50_horde", "pos": Vector3(-1.4, 0, 8.9), "yaw": 1.5, "pitch": -0.35, "hour": 12.0, "horde": true},
	{"name": "51_nav", "pos": Vector3(13, 22, 30), "yaw": 0.0, "pitch": -0.95, "hour": 15.0, "nav": true},
	{"name": "52_trees", "pos": Vector3(0, 0, 0), "yaw": 0.0, "pitch": 0.05, "hour": 9.5, "trees": true},
	{"name": "53_machines", "pos": Vector3(-8, 0, 12.5), "yaw": 0.1, "pitch": -0.3, "hour": 14.0, "machines": true},
	{"name": "54_blast", "pos": Vector3(0, 0, 0), "yaw": 0.0, "pitch": -0.05, "hour": 16.0, "blast": true},
	{"name": "55_greening", "pos": Vector3(15, 0, 13), "yaw": 0.62, "pitch": -0.3, "hour": 10.0, "greening": true},
	{"name": "56_watering_can", "pos": Vector3(16, 0, 6), "yaw": 0.59, "pitch": -0.6, "hour": 15.0, "greening": true, "can": true},
	{"name": "57_farm", "pos": Vector3(24, 0, 29.5), "yaw": 0.0, "pitch": -0.42, "hour": 10.0, "farm": true},
	{"name": "58_seeds", "pos": Vector3(19, 0, 25.2), "yaw": 0.0, "pitch": -0.6, "hour": 16.0, "farm": true, "seeds": true},
	{"name": "59_market", "pos": Vector3(-0.6, 0, 4.2), "yaw": 0.5, "pitch": -0.2, "hour": 10.0, "market": true},
	{"name": "08_menu", "pos": Vector3(0, 0, 9), "yaw": 0.0, "pitch": 0.0, "hour": 12.0, "menu": true},
]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			var want := arg.substr(5)
			shots = shots.filter(func(s): return s.name == want)
	root.get_node("Settings").hints = false  # no tips in the pictures (not saved)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 20:
		return false
	if idx >= shots.size():
		quit(0)
		return false
	var s: Dictionary = shots[idx]
	var p: Node3D = main.player
	if frame % 20 == 0:
		main.day_night.time_scale = 0.0
		main.day_night.hour = s.hour
		main.day_night._apply()
		p.set_physics_process(false)
		if s.has("target"):
			_look_at_target(p, s.target)
		else:
			var pos: Vector3 = s.pos
			if pos.y == 0:
				pos.y = main.terrain.surface_height(pos.x, pos.z)
			p.position = pos
			p.rotation.y = s.yaw
			p.head.rotation.x = s.pitch
		if s.get("inventory", false):
			if main.inventory.weight() == 0.0:
				main.inventory.add_all({"scrap": 12, "wood": 25, "nails": 37, "cloth": 3, "water": 2, "canned_food": 4})
			main.inventory_ui.open()
		elif main.inventory_ui.is_open():
			main.inventory_ui.close()
		if s.get("death", false):
			main.survival.water = 0.0
			main.survival.damage(999.0)
		elif main.death_screen.is_open():
			main.respawn()
		if s.get("map", false):
			for place in main.places.slice(0, 15):
				main.discovered[place.key] = true
			main.interact(main.places[0].key + "_trunk")
			main.interact(main.places[0].key + "_glovebox")
			main._on_morning(2)
			if not main.map_ui.is_open():
				main.map_ui.toggle()
		elif main.map_ui.is_open():
			main.map_ui.toggle()
		if s.get("tiers", false):
			var b = main.building
			b.load_data([])
			for i in 4:
				var slot := {"kind": "edge", "cx": 1 + i, "cz": 6, "dir": 0, "level": 0}
				var k: String = b.place("wall", slot, b.evaluate("wall", slot).y, false, i)
				b.damage(k, [60.0, 400.0, 300.0, 1200.0][i])
			main.inventory.load_data({})
			main.inventory.add_all({"hammer": 1, "scrap": 9})
			main.inventory.selected = 0
		if s.get("base", false):
			_base_sample()
		if s.get("bench", false):
			main.inventory.add_all({"cloth": 5, "wood": 8, "nails": 6, "scrap": 3})
			main.inventory_ui.open_bench(main.building.slot_key({"kind": "obj", "cx": -1, "cz": 8, "dir": 0, "level": 0}))
		elif main.inventory_ui.bench_key != "":
			main.inventory_ui.close()
		if s.get("melee", false):
			main.inventory.load_data({})
			main.inventory.add("machete", 1)
			main.inventory.selected = 0
			main.melee.set_item("machete")
			main.melee.play_swing(30.0)
			main.melee.swing_time = 0.12
			main.dummy.take_hit(40.0, main.dummy.global_position + Vector3(0, 1.5, 0.2), Vector3(0, 0, -1))
			main.hud.show_hitmarker("target")
		if s.get("digging", false):
			_digging_sample()
		if s.get("layers", false):
			_layers_sample()
		if s.get("pieces2", false):
			_pieces2_sample()
		if s.get("prefabs", false):
			_prefabs_sample()
		if s.get("trees", false):
			# Stand back from the biggest grove and look at it.
			var props = main.props
			var best := 0
			var best_n := 0
			for i in props.trees.size():
				var n := 0
				for t in props.trees:
					if t.node.position.distance_to(props.trees[i].node.position) < 14.0:
						n += 1
				if n > best_n:
					best_n = n
					best = i
			var c: Vector3 = props.trees[best].node.position
			var from := c + (Vector3.ZERO - c).normalized() * 22.0
			from.y = main.terrain.surface_height(from.x, from.z)
			p.position = from
			var d := c - from
			p.rotation.y = atan2(-d.x, -d.z)
			main.inventory.load_data({})
			main.inventory.add("axe", 1)
			main.inventory.selected = 0
		if s.get("machines", false):
			_machines_sample()
		if s.get("blast", false):
			_blast_sample(p)
		if s.get("greening", false):
			_greening_sample(s.get("can", false))
		if s.get("farm", false):
			_farm_sample(s.get("seeds", false))
		if s.get("horde", false):
			main.building.load_data([])
			main.building.sites_load_data([])
			main.mutants.clear()
		if s.get("support", false):
			var b = main.building
			main.terrain.load_data({})
			b.load_data([])
			for e in b.cell_edges(6, -6, 0):
				b.place("wall", e, b.evaluate("wall", e).y)
			for i in 5:
				var fs := {"kind": "cell", "cx": 6 + i, "cz": -6, "dir": 0, "level": 1}
				b.place("floor", fs, b.evaluate("floor", fs).y)
			b.collapse_unsupported()  # the fifth, at 15%, comes down
		if s.get("well", false):
			main.building.load_data([])
			main.terrain.load_data({})
			main.inventory.load_data({})
			for i in 14:
				main.dig_at(Vector3(-10.5, 0, -4.5), false, "pickaxe")
			var b = main.building
			var ws := {"kind": "obj", "cx": -6, "cz": -3, "dir": 0}
			var wk: String = b.place("well", ws, b.evaluate("well", ws).y)
			b.level_under(wk)
			b.pieces[wk].water = 4.0
			p.head.rotation.x = -0.3
		if s.get("detector", false):
			main.terrain.load_data({})
			main.building.load_data([])
			main.inventory.load_data({})
			main.inventory.add("metal_detector", 1)
			main.inventory.selected = 0
			var c: Dictionary = main.caches.caches[0]
			p.position = Vector3(c.x + 4.0, main.terrain.surface_height(c.x + 4.0, c.z), c.z)
		if s.get("walker", false):
			_walker_sample(p)
		if s.has("gun"):
			_gun_sample(p, s.gun, s.aim)
		elif main.guns.item != "":
			main.guns.set_item("")
		if s.get("terminal", false) or s.get("shop", false):
			main.building.load_data([])
			main.mutants.clear()
			main.shop.cash = 340
			main.inventory.load_data({})
			main.inventory.add_all({"hammer": 1, "pistol": 1})
		if s.get("drone", false) or s.get("drone_shop", false):
			_drone_sample()
		if s.get("hint", false):
			main.building.load_data([])
			main.mutants.clear()
			main.hud.show_hint(main.hints.HINTS.welcome)
			main.hud._hint_time = 5.0
		elif main.hud.hint_box.visible:
			main.hud.hint_box.visible = false
			main.hud._hint_time = 0.0
		if s.get("upgrades", false):
			main.shop.cash = 520
			main.shop.upgrades = {"zone": 1, "storage": 0, "bench": 2, "radio": 0, "well": 1, "pump": 0}
			main.shop_ui.open()
			main.shop_ui.show_page(2)
		elif s.get("bigchest", false):
			if main.shop_ui.is_open():
				main.shop_ui.close()
			var b = main.building
			main.shop.upgrades.storage = 2
			main.apply_upgrades()
			var cs := {"kind": "obj", "cx": -1, "cz": 1, "dir": 0, "level": 0}
			var ck: String = b.place("chest", cs, b.evaluate("chest", cs).y)
			b.storage_of(ck).add_all({"wood": 55, "scrap": 30, "nails": 120, "cement": 4, "ammo_9mm": 90, "shells": 20})
			main.inventory.add_all({"wood": 8, "medkit": 2})
			main.inventory_ui.open_chest(ck, b.storage_of(ck))
		elif s.get("shop", false):
			main.shop_ui.open()
		elif s.get("market", false):
			main.inventory.add_all({"millet": 12, "dates": 8, "rope": 3, "saffron": 2})
			main.shop_ui.open()
			main.shop_ui.show_page(3)
		elif s.get("drone_shop", false):
			main.shop_ui.open()
			main.shop_ui.show_page(true)
		elif main.shop_ui.is_open():
			main.shop_ui.close()
		if s.get("turret", false):
			_turret_sample()
		elif main.build_mode.range_ring.visible and not s.get("build", false):
			main.build_mode.range_ring.visible = false
		if s.get("power", false):
			_power_sample()
		if s.get("traps", false):
			_traps_sample()
		if s.get("types", false):
			_types_sample(p)
		if s.get("breakin", false):
			_breakin_sample(p)
		if s.get("nav", false):
			_nav_sample()
		if s.get("wave", false):
			_wave_sample(p)
		if s.get("summary", false):
			main.mutants.clear()
			main.hud.show_summary(main.Waves.summary_lines({"wave": 3, "cleared": false, "kills": 7, "damage": 46.0, "lost": 2, "deaths": 0}))
			main.hud._summary_time = 5.0
		if s.get("build", false):
			_build_sample()
		elif s.get("prefab_ghost", false):
			_prefabs_sample(true)
			var bm = main.build_mode
			if not bm.active:
				bm.toggle()
			if not bm.prefab_mode:
				bm.toggle_prefabs()
			bm.select(1)  # cabin
			bm.dir = 1
		elif s.get("zone", false):
			main.build_mode.active = true
			main.build_mode.select(10)
		elif main.build_mode.active and not s.get("turret", false):
			main.build_mode.toggle()
		if s.get("wave_map", false):
			main.building.load_data([])
			main.mutants.clear()
			main.waves.wave = 3
			main.waves.start_wave()
			for i in 30:
				main.waves._process(1.0)
			for m in main.mutants.alive():
				m.global_position = m.global_position * randf_range(0.3, 0.8)
				m.set_physics_process(false)
			if not main.map_ui.is_open():
				main.map_ui.toggle()
		if s.get("menu", false):
			main.pause_menu.open()
			if s.has("page"):
				main.pause_menu.show_page(s.page)
		else:
			main.pause_menu.resume()
	elif frame % 20 == 15:
		DirAccess.make_dir_recursive_absolute("res://screenshots")
		if not FileAccess.file_exists("res://screenshots/.gdignore"):
			FileAccess.open("res://screenshots/.gdignore", FileAccess.WRITE).store_string("")  # keep Godot from importing the PNGs
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://screenshots/%s.png" % s.name)
		print("saved ", s.name)
		idx += 1
	return false


## Stand 9 m from the first wreck/ruin and look at it.
func _look_at_target(p: Node3D, kind: String) -> void:
	if kind == "crate":
		var c: Dictionary = main.props.containers.filter(func(x): return x.kind == "crate")[0]
		var cp: Vector3 = c.lid.global_position
		p.position = cp + Vector3(1.4, -p.EYE_HEIGHT + 0.5, 0.6)
		var dc := cp - p.position - Vector3(0, p.EYE_HEIGHT, 0)
		p.rotation.y = atan2(-dc.x, -dc.z)
		p.head.rotation.x = atan2(dc.y, Vector2(dc.x, dc.z).length())
		return
	var list: Array = main.props.wreck_positions if kind == "wreck" else main.props.ruin_positions
	var t: Vector3 = list[0]
	var from := t + Vector3(7, 0, 6)
	from.y = main.terrain.surface_height(from.x, from.z)
	p.position = from
	var d := t - from
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = -0.15


## A small hut using every piece near the base, and build mode on.
func _build_sample() -> void:
	var b = main.building
	if not b.pieces.is_empty():
		return
	for cx in [2, 3]:
		for cz in [5, 6]:
			var slot := {"kind": "cell", "cx": cx, "cz": cz, "dir": 0, "level": 0}
			b.place("foundation", slot, b.evaluate("foundation", slot).y)
	var walls := [["wall", 2, 5, 0], ["window", 3, 5, 0], ["wall", 2, 5, 1], ["window", 2, 6, 1],
		["window", 4, 5, 1], ["wall", 4, 6, 1], ["doorway", 2, 7, 0], ["wall", 3, 7, 0]]
	for w in walls:
		var slot := {"kind": "edge", "cx": w[1], "cz": w[2], "dir": w[3], "level": 0}
		b.place(w[0], slot, b.evaluate(w[0], slot).y)
	b.set_gate(b.slot_key({"kind": "edge", "cx": 2, "cz": 7, "dir": 0, "level": 0}), true)
	for cx in [2, 3]:
		for cz in [5, 6]:
			var slot := {"kind": "cell", "cx": cx, "cz": cz, "dir": 0, "level": 1}
			b.place("roof", slot, b.evaluate("roof", slot).y)
	var st := {"kind": "cell", "cx": 4, "cz": 6, "dir": 0, "level": 0}
	b.place("stairs", st, b.evaluate("stairs", st).y)
	main.inventory.add_all({"wood": 20, "nails": 20})
	main.build_mode.active = true
	main.build_mode.select(1)
	main.build_mode.dir = 0


## A chest, a workbench and spike barricades near the zone edge (v0.11).
func _base_sample() -> void:
	var b = main.building
	if b.pieces.has(b.slot_key({"kind": "obj", "cx": -1, "cz": 8, "dir": 0, "level": 0})):
		return
	var f := {"kind": "cell", "cx": -3, "cz": 8, "dir": 0, "level": 0}
	b.place("foundation", f, b.evaluate("foundation", f).y)
	for o in [["chest", -3, 8, 0], ["workbench", -1, 8, 0], ["spikes", 0, 10, 0], ["spikes", 1, 10, 0], ["spikes", -1, 10, 0]]:
		var slot := {"kind": "obj", "cx": o[1], "cz": o[2], "dir": o[3], "level": 0}
		b.place(o[0], slot, b.evaluate(o[0], slot).y)


## Two walkers coming at you and one lying dead (v0.13).
func _walker_sample(p: Node3D) -> void:
	var ms = main.mutants
	ms.clear()
	var fwd := -p.global_transform.basis.z
	var right := p.global_transform.basis.x
	var spots := [fwd * 3.2 + right * 0.6, fwd * 7.5 - right * 2.5, fwd * 5.0 + right * 3.5]
	for i in spots.size():
		var w = ms.spawn("walker", p.position + spots[i])
		w.rotation.y = p.rotation.y + PI - 0.3 * (i - 1)
		w.set_physics_process(false)
		w._anim_t = 1.0 + i * 1.7
		w._animate(0.0, 2.5)
		if i == 0:
			w._attack_t = 0.4
			w._animate(0.0, 0.5)
		if i == 2:
			w.take_hit(200.0, w.global_position, -fwd)
	main.inventory.load_data({})
	main.inventory.add("machete", 1)
	main.inventory.selected = 0
	main.melee.set_item("machete")


## A night wave walking in on the base, with the wave counter on the HUD (v0.14).
func _wave_sample(p: Node3D) -> void:
	var ms = main.mutants
	ms.clear()
	main.waves.wave = 3
	main.waves.active = true
	main.waves.to_spawn = 3
	var fwd := -p.global_transform.basis.z
	var right := p.global_transform.basis.x
	for i in 6:
		var w = ms.spawn("walker", p.position + fwd * (9.0 + i * 3.5) + right * ((i % 3) - 1) * 3.0)
		w.make_hunter(Vector3.ZERO)
		w.rotation.y = p.rotation.y + PI
		w.set_physics_process(false)
		w._anim_t = i * 1.3
		w._animate(0.0, 2.2)
	main.inventory.load_data({})
	main.inventory.add("pipe", 1)
	main.inventory.selected = 0
	main.melee.set_item("pipe")


## Walkers tearing at a wall line north of the flag; one wall just gave way (v0.15).
func _breakin_sample(p: Node3D) -> void:
	var b = main.building
	var ms = main.mutants
	b.load_data([])
	ms.clear()
	var keys := []
	for cx in [-2, -1, 0, 1, 2]:
		var slot := {"kind": "edge", "cx": cx, "cz": -5, "dir": 0, "level": 0}
		keys.append(b.place("wall", slot, b.evaluate("wall", slot).y, false, 1 if cx == 2 else 0))
	b.damage(keys[1], 190.0)
	b.damage(keys[3], 120.0)
	for i in 3:
		var w = ms.spawn("walker", [Vector3(1.2, 0, -10.8 + 4.0), Vector3(-2.5, 0, -10.5), Vector3(4.5, 0, -10.8)][i])
		w.rotation.y = PI
		w.set_physics_process(false)
		w._anim_t = i * 2.0
		w._attack_t = [0.35, 0.2, 0.42][i]
		w._animate(0.0, 0.3)
	b.damage(keys[2], 9999.0)
	main.mutants.night = true


## v1.10: a walled yard with its gate open on the south side, the paths the
## nav field gives from three spots outside (yellow dots), and walkers on them.
func _nav_sample() -> void:
	var b = main.building
	var ms = main.mutants
	b.load_data([])
	ms.clear()
	for c in main.get_children():
		if c.name.begins_with("NavDots"):
			c.queue_free()
	var cx0 := 5
	var cz0 := 5
	for dz in 3:
		for dx in 3:
			var f := {"kind": "cell", "cx": cx0 + dx, "cz": cz0 + dz, "dir": 0, "level": 0}
			b.place("foundation", f, b.evaluate("foundation", f).y)
	for k in 3:
		for e in [
			{"kind": "edge", "cx": cx0 + k, "cz": cz0, "dir": 0, "level": 0},
			{"kind": "edge", "cx": cx0 + k, "cz": cz0 + 3, "dir": 0, "level": 0},
			{"kind": "edge", "cx": cx0, "cz": cz0 + k, "dir": 1, "level": 0},
			{"kind": "edge", "cx": cx0 + 3, "cz": cz0 + k, "dir": 1, "level": 0},
		]:
			var door: bool = e.cz == cz0 + 3 and e.dir == 0 and k == 1
			b.place("doorway" if door else "wall", e, b.evaluate("wall", e).y, door)
	var nav = main.nav
	var f = nav.compute_now("player", Vector3(13, 0, 12))
	var dots := MultiMeshInstance3D.new()
	dots.name = "NavDots"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	sphere.material = mat
	mm.mesh = sphere
	var pts: Array = []
	var starts := [Vector3(13, 0, 1), Vector3(1, 0, 13), Vector3(26, 0, 6)]
	for st in starts:
		for c in nav.trace(f, st):
			pts.append(nav.cell_point(c) + Vector3(0, 0.25, 0))
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
	dots.multimesh = mm
	main.add_child(dots)
	for i in starts.size():
		var path: Array = nav.trace(f, starts[i])
		var at: Vector3 = nav.cell_point(path[mini(6, path.size() - 1)])
		var nx: Vector3 = nav.cell_point(path[mini(7, path.size() - 1)])
		var w = ms.spawn(["walker", "runner", "walker"][i], at)
		w.look_at_from_position(at, Vector3(nx.x, at.y, nx.z) if nx.distance_to(at) > 0.1 else at + Vector3.FORWARD)
		w.set_physics_process(false)
		w._anim_t = i * 1.7
		w._animate(0.0, 2.0)


## Walker, runner, brute and spitter in a row, and a glob of acid in the air (v0.16).
func _types_sample(p: Node3D) -> void:
	var ms = main.mutants
	ms.clear()
	var fwd := -p.global_transform.basis.z
	var right := p.global_transform.basis.x
	var kinds := ["runner", "walker", "brute", "spitter"]
	for i in kinds.size():
		var w = ms.spawn(kinds[i], p.position + fwd * (6.5 + (i % 2) * 1.5) + right * (i - 1.5) * 2.2)
		w.rotation.y = p.rotation.y + PI
		w.set_physics_process(false)
		w._anim_t = i * 1.1
		w._animate(0.0, 1.5)
	var sp = ms.alive()[3]
	ms._on_spat(sp.global_position + Vector3(0, 1.4, 0) + fwd * -1.2, Vector3.ZERO, sp)
	for g in ms.spits():
		g.set_physics_process(false)
	main.inventory.load_data({})
	main.inventory.add("machete", 1)
	main.inventory.selected = 0
	main.melee.set_item("machete")


## The pistol at the hip, or aimed with the muzzle flashing at a walker (v0.17).
func _gun_sample(p: Node3D, gun: String, aimed: bool) -> void:
	var ms = main.mutants
	ms.clear()
	var w = ms.spawn("walker", p.position - p.global_transform.basis.z * (25.0 if gun == "rifle" else 9.0))
	w.rotation.y = p.rotation.y + PI
	w.set_physics_process(false)
	w._animate(0.0, 2.0)
	main.inventory.load_data({})
	main.inventory.add_all({gun: 1, main.guns.GUNS[gun].ammo: 24})
	main.inventory.selected = 0
	main.melee.set_item("")
	main.guns.set_item(gun)
	main.guns.raise_t = 0.0
	main.guns.mag = {gun: 3}
	main.guns.set_ads(aimed)
	main.guns.ads_amount = 1.0 if aimed else 0.0
	if aimed and gun == "pistol":
		main.guns._flash.visible = true
		main.guns._flash_t = 30.0
		main.guns._kick = 0.4


## A line of traps north of the flag, a walker caught in the wire and a mine going off (v0.19).
func _traps_sample() -> void:
	var b = main.building
	var ms = main.mutants
	b.load_data([])
	ms.clear()
	for o in [["spike_strip", -1, -2], ["spike_strip", 0, -2], ["spike_strip", 1, -2], ["barbed_wire", -1, -4], ["barbed_wire", 0, -4], ["barbed_wire", 1, -4], ["landmine", -1, -6], ["landmine", 1, -6]]:
		var slot := {"kind": "obj", "cx": o[1], "cz": o[2], "dir": 0, "level": 0}
		b.place(o[0], slot, b.evaluate(o[0], slot).y)
	var w = ms.spawn("walker", Vector3(1.5, 0, -6.8))
	w.rotation.y = PI
	w.set_physics_process(false)
	w._animate(0.0, 0.5)
	main.traps._explosion(Vector3(-3.5, main.terrain.surface_height(-3.5, -11), -11))


## A generator powering floodlights and an electric fence at night, and a fire pit (v0.20).
func _power_sample() -> void:
	var b = main.building
	var ms = main.mutants
	b.load_data([])
	ms.clear()
	var g: String = ""
	for o in [["generator", "obj", 0, 2, 0], ["floodlight", "obj", -2, 0, 0], ["floodlight", "obj", 3, 0, 0], ["fire_pit", "obj", 2, 3, 0],
			["electric_fence", "edge", -2, -1, 0], ["electric_fence", "edge", -1, -1, 0], ["electric_fence", "edge", 0, -1, 0], ["electric_fence", "edge", 1, -1, 0], ["electric_fence", "edge", 2, -1, 0]]:
		var slot := {"kind": o[1], "cx": o[2], "cz": o[3], "dir": o[4], "level": 0}
		var k: String = b.place(o[0], slot, b.evaluate(o[0], slot).y)
		if o[0] == "generator":
			g = k
		if o[0] == "fire_pit":
			b.pieces[k].burn = 200.0
	b.pieces[g].fuel = 6.0
	# Cables from the generator through a switch (v1.8).
	var sw: String = b.place("switch", {"kind": "obj", "cx": 1, "cz": 1, "dir": 0, "level": 0}, b.evaluate("switch", {"kind": "obj", "cx": 1, "cz": 1, "dir": 0, "level": 0}).y, true)
	b.connect_cable(g, sw)
	for k in b.keys_of(["floodlight", "electric_fence"]):
		b.connect_cable(sw, k)
	main.day_night.restore(1, 22.0)
	main.power.tick(0.25)
	for i in 2:
		var w = ms.spawn("walker", Vector3(-1.0 + i * 3.0, 0, -5.5))
		w.rotation.y = PI
		w.set_physics_process(false)
		w._animate(0.0, 1.0)


## A turret firing at a walker, and build mode placing a second with its range circle (v0.21).
func _turret_sample() -> void:
	var b = main.building
	var ms = main.mutants
	b.load_data([])
	ms.clear()
	var slot := {"kind": "obj", "cx": 4, "cz": -3, "dir": 0, "level": 0}
	var k: String = b.place("turret", slot, b.evaluate("turret", slot).y)
	var rec: Dictionary = b.pieces[k]
	rec.ammo = 120
	rec.head.rotation.y = -0.35
	rec.gun.rotation.x = 0.02
	rec.flash.visible = true
	var w = ms.spawn("walker", rec.node.global_position + Vector3(4.5, 0, -12))
	w.rotation.y = PI - 0.4
	w.set_physics_process(false)
	w._animate(0.0, 2.0)
	main.turrets.set_physics_process(false)
	main.inventory.load_data({})
	main.inventory.add_all({"scrap": 40, "nails": 20, "wood": 4})
	main.shop.unlocked["turret"] = true
	main.build_mode.active = true
	main.build_mode.select(b.ORDER.find("turret"))


## A landing pad with the drone coming down over it, and sandbag walls (v0.23).
func _drone_sample() -> void:
	var b = main.building
	b.load_data([])
	main.mutants.clear()
	main.shop.cash = 420
	main.shop.unlocked = {"sandbags": true}
	var pad := {"kind": "obj", "cx": 1, "cz": 1, "dir": 0, "level": 0}
	b.place("landing_pad", pad, b.evaluate("landing_pad", pad).y)
	for cx in [0, 1, 2]:
		var sb := {"kind": "edge", "cx": cx, "cz": 0, "dir": 0, "level": 0}
		b.place("sandbags", sb, b.evaluate("sandbags", sb).y)
	var dr = main.drone
	dr.load_data({})
	dr.order({"wood": 40, "bp_turret": 1})
	dr._process(0.0)
	dr.phase = "down"
	dr._t = 2.4
	dr._process(0.0)
	dr.set_process(false)


## A trench across the view, a deep pit, a sand pile, and a wall standing by the trench.
func _digging_sample() -> void:
	main.waves.active = false
	main.hud._summary_time = 0.0
	main.building.load_data([])
	main.mutants.clear()
	main.terrain.load_data({})
	main.inventory.load_data({})
	main.inventory.add("shovel", 1)
	main.inventory.selected = 0
	for i in 3:
		for x in range(6, 18):
			main.dig_at(Vector3(x + 0.5, 0, 11.5))
	for i in 8:
		for o in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			main.dig_at(Vector3(13.0 + o.x, 0, 7.0 + o.y))
	for i in 6:
		main.dig_at(Vector3(9.5, 0, 7.5), true)
	var b = main.building
	var slot := {"kind": "edge", "cx": 5, "cz": 5, "dir": 0}
	b.place("wall", slot, b.evaluate("wall", slot).y)


## A stepped pit 3 m deep: sand, a band of clay, then grey stone; pickaxe in hand.
func _layers_sample() -> void:
	main.building.load_data([])
	main.mutants.clear()
	main.terrain.load_data({})
	main.inventory.load_data({})
	main.inventory.add("pickaxe", 1)
	main.inventory.selected = 0
	for x in range(-13, -7):
		for z in range(-7, -3):
			var depth := 12 if z < -5 else (8 if z < -4 else 4)
			for i in depth:
				main.dig_at(Vector3(x + 0.5, 0, z + 0.5), false, "pickaxe")
	main.inventory.load_data({})
	main.inventory.add("pickaxe", 1)


## The v1.6 pieces: triangle foundations, a metal door, a gun slit wall, half
## and low walls, pillars holding a floor, and an open trapdoor.
func _pieces2_sample() -> void:
	var b = main.building
	main.terrain.load_data({})
	main.mutants.clear()
	b.load_data([])
	var put := func(t: String, slot: Dictionary) -> String:
		var ev: Dictionary = b.evaluate(t, slot)
		return b.place(t, slot, ev.y) if ev.ok else ""
	put.call("foundation", {"kind": "cell", "cx": -5, "cz": 8, "dir": 0})
	put.call("foundation", {"kind": "cell", "cx": -4, "cz": 8, "dir": 0})
	put.call("tri_foundation", {"kind": "cell", "cx": -6, "cz": 8, "dir": 1})
	put.call("tri_foundation", {"kind": "cell", "cx": -3, "cz": 8, "dir": 0})
	put.call("metal_door", {"kind": "edge", "cx": -5, "cz": 9, "dir": 0})
	put.call("slit_wall", {"kind": "edge", "cx": -4, "cz": 9, "dir": 0})
	put.call("wall", {"kind": "edge", "cx": -5, "cz": 8, "dir": 0})
	put.call("wall", {"kind": "edge", "cx": -4, "cz": 8, "dir": 0})
	put.call("wall", {"kind": "edge", "cx": -5, "cz": 8, "dir": 1})
	put.call("wall", {"kind": "edge", "cx": -3, "cz": 8, "dir": 1})
	var tk: String = put.call("trapdoor", {"kind": "cell", "cx": -5, "cz": 8, "dir": 0, "level": 1})
	put.call("floor", {"kind": "cell", "cx": -4, "cz": 8, "dir": 0, "level": 1})
	if tk != "":
		b.set_gate(tk, true)
	for i in 2:
		put.call("half_wall", {"kind": "edge", "cx": -5 + i, "cz": 9, "dir": 0, "level": 1})
	put.call("low_wall", {"kind": "edge", "cx": -2, "cz": 11, "dir": 0})
	put.call("low_wall", {"kind": "edge", "cx": -1, "cz": 11, "dir": 0})
	for o in [Vector2i(-8, 9), Vector2i(-7, 9), Vector2i(-8, 10), Vector2i(-7, 10)]:
		put.call("pillar", {"kind": "post", "cx": o.x, "cz": o.y, "dir": 0})
	put.call("floor", {"kind": "cell", "cx": -8, "cz": 9, "dir": 0, "level": 1})
	put.call("tri_roof", {"kind": "cell", "cx": -9, "cz": 9, "dir": 1, "level": 1})


## v1.9: a cabin, a big cabin and a watchtower built from blueprints, and a
## shelter blueprint half built. With half_only, just a half-built blueprint.
func _prefabs_sample(half_only := false) -> void:
	var b = main.building
	var bm = main.build_mode
	main.terrain.load_data({})
	main.mutants.clear()
	b.load_data([])
	b.sites_load_data([])
	var spots: Array = [["cabin", Vector2i(5, -3), 0, 9]] if half_only else [["cabin", Vector2i(-2, -3), 0, 99], ["long_cabin", Vector2i(3, -6), 1, 99], ["watchtower", Vector2i(-5, 0), 0, 99], ["shelter", Vector2i(2, 0), 0, 7], ["gatehouse", Vector2i(-4, -8), 0, 99]]
	for sp in spots:
		var ev: Dictionary = bm.evaluate_prefab(sp[0], sp[1].x, sp[1].y, sp[2])
		if not ev.ok:
			print("prefab ", sp[0], " does not fit: ", ev.reason)
			continue
		var id: int = b.add_site(sp[0], ev.plan, ev.y)
		for i in sp[3]:
			if not b.sites.has(id):
				break
			var nxt: Dictionary = b.site_next(id)
			if not nxt.has("i"):
				print("prefab ", sp[0], " stuck: ", nxt.reason)
				break
			b.build_site_piece(id, nxt)


## v1.11: a generator powering a sawmill, a rock crusher and a nail press by
## cable, with log stakes in front.
## v2.0: a landmine goes off under a group of walkers, a quarter of a second
## before the picture: bodies thrown up and away, a Brute standing firm.
func _blast_sample(p: Node3D) -> void:
	var b = main.building
	main.terrain.load_data({})
	main.mutants.clear()
	b.load_data([])
	b.sites_load_data([])
	var sl := {"kind": "obj", "cx": 0, "cz": -6, "dir": 0, "level": 0}
	var k: String = b.place("landmine", sl, b.evaluate("landmine", sl).y)
	var mine: Vector3 = b.pieces[k].node.global_position
	var eye := mine + Vector3(0, 0, 11)
	p.position = Vector3(eye.x, main.terrain.surface_height(eye.x, eye.z), eye.z)
	p.rotation.y = 0.0
	for o in [Vector3(0.4, 0, 0.3), Vector3(-1.6, 0, 0.8), Vector3(1.9, 0, -0.6), Vector3(-0.5, 0, -2.4)]:
		var w = main.mutants.spawn("walker", mine + o)
		w.rotation.y = PI
	var br = main.mutants.spawn("brute", mine + Vector3(3.2, 0, 1.2))
	br.rotation.y = PI
	main.traps.detonate(k)


## v1.13: green squares round the main well, two piped sprinklers, the hand pump.
func _greening_sample(can: bool) -> void:
	var b = main.building
	var w = main.water
	main.terrain.load_data({})
	main.mutants.clear()
	b.load_data([])
	b.sites_load_data([])
	w.load_data({})
	main.shop.upgrades.pump = 1
	main.apply_upgrades()
	var put := func(cx: int, cz: int) -> String:
		var sl := {"kind": "obj", "cx": cx, "cz": cz, "dir": 0, "level": 0}
		var ev: Dictionary = b.evaluate("sprinkler", sl)
		return b.place("sprinkler", sl, ev.y) if ev.ok else ""
	var s1: String = put.call(5, -1)
	var s2: String = put.call(8, 3)
	if s1 != "":
		w.connect_pipe("main", s1)
		if s2 != "":
			w.connect_pipe(s1, s2)
	# Squares at every stage: damp sand, bare soil, young grass, full green with plants.
	for x in range(0, 6):
		for z in range(-3, 3):
			var c := Vector2i(x, z)
			var d := Vector2(x - 3, z).length()
			w.water_cell(c, 3.0 if d > 3.2 else 8.0)
			if d <= 3.2:
				w.cells[c].total = 20.0
				w.cells[c].green = clampf(1.1 - d * 0.3, 0.0, 1.0)
				w.cells[c].wet = 2.0 if (x + z) % 3 == 0 else 6.0
	w.tick(1.1, true)
	w.redraw()
	if can:
		main.inventory.load_data({})
		main.inventory.add("watering_can", 1)
		main.inventory.selected = 0
		w.can = 7.0


## A field with every crop, from new seed beds (back) to ripe (front), and a dead one.
func _farm_sample(seeds: bool) -> void:
	var w = main.water
	var f = main.farming
	main.terrain.load_data({})
	main.mutants.clear()
	main.building.load_data([])
	main.building.sites_load_data([])
	w.load_data({})
	f.load_data({})
	for x in range(3, 9):
		for z in range(2, 7):
			var c := Vector2i(x, z)
			w.water_cell(c, 8.0)
			w.cells[c].total = 20.0
			w.cells[c].green = 0.3 if (x == 3 or x == 8 or z == 2) else 0.05
			w.cells[c].wet = 5.0
	var crops: Array = f.CROPS.keys()
	for i in crops.size():
		var crop: String = crops[i]
		for row in 4:  # z spot 6 (back, new) .. 11 (front, ripe)
			var sp := Vector2i(7 + i, 6 + row * 2)
			var e := {"crop": crop, "grow": float(f.CROPS[crop].days) * row / 3.0, "hp": 1.0, "dead": false, "fruited": false}
			f.plants[sp] = e
	f.plants[Vector2i(16, 13)] = {"crop": "millet", "grow": 1.0, "hp": 0.0, "dead": true, "fruited": false}
	w.redraw()
	f.redraw()
	if seeds:
		main.inventory.load_data({})
		main.inventory.add("seed_millet", 6)
		main.inventory.selected = 0


func _machines_sample() -> void:
	var b = main.building
	main.terrain.load_data({})
	main.mutants.clear()
	b.load_data([])
	b.sites_load_data([])
	main.day_night.restore(main.day_night.day, 14.0)
	var put := func(t: String, cx: int, cz: int, d := 0, turn := 0) -> String:
		var sl := {"kind": "obj", "cx": cx, "cz": cz, "dir": d, "level": 0}
		if turn != 0:
			sl.turn = turn
		var ev: Dictionary = b.evaluate(t, sl)
		return b.place(t, sl, ev.y) if ev.ok else ""
	var g: String = put.call("generator", -5, 4)
	var keys: Array = [put.call("sawmill", -6, 3, 2), put.call("crusher", -4, 3, 2), put.call("nail_press", -3, 4, 3)]
	if g != "":
		b.pieces[g].fuel = 5.0
		for k in keys:
			if k != "":
				b.connect_cable(g, k)
				b.pieces[k].input = 10
	put.call("log_stakes", -6, 6, 0, 1)
	put.call("log_stakes", -4, 6, 0, 5)
	main.power.tick(0.25)

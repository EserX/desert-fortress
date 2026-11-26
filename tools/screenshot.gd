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
	{"name": "08_menu", "pos": Vector3(0, 0, 9), "yaw": 0.0, "pitch": 0.0, "hour": 12.0, "menu": true},
]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			var want := arg.substr(5)
			shots = shots.filter(func(s): return s.name == want)
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
			for i in 3:
				var slot := {"kind": "edge", "cx": 2 + i, "cz": 6, "dir": 0, "level": 0}
				var k: String = b.place("wall", slot, b.evaluate("wall", slot).y, false, i)
				b.damage(k, [60.0, 400.0, 1200.0][i])
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
		if s.get("walker", false):
			_walker_sample(p)
		if s.get("breakin", false):
			_breakin_sample(p)
		if s.get("wave", false):
			_wave_sample(p)
		if s.get("summary", false):
			main.mutants.clear()
			main.hud.show_summary(main.Waves.summary_lines({"wave": 3, "cleared": false, "kills": 7, "damage": 46.0, "lost": 2, "deaths": 0}))
			main.hud._summary_time = 5.0
		if s.get("build", false):
			_build_sample()
		elif s.get("zone", false):
			main.build_mode.active = true
			main.build_mode.select(10)
		elif main.build_mode.active:
			main.build_mode.toggle()
		if s.get("menu", false):
			main.pause_menu.open()
		else:
			main.pause_menu.resume()
	elif frame % 20 == 15:
		DirAccess.make_dir_recursive_absolute("res://screenshots")
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

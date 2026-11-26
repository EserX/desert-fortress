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

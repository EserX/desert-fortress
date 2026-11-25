extends SceneTree
## Renders screenshots from a few viewpoints into screenshots/.
## Needs a display (use xvfb-run on servers):
##   godot --path . -s tools/screenshot.gd --rendering-method gl_compatibility

var main: Node
var frame := 0
var shots := [
	{"pos": Vector3(0, 0, 9), "yaw": 0.0, "pitch": -0.05, "name": "01_spawn"},
	{"pos": Vector3(40, 0, 60), "yaw": 2.4, "pitch": -0.02, "name": "02_dunes"},
	{"pos": Vector3(0, 30, 0), "yaw": 0.8, "pitch": -0.35, "name": "03_overview"},
]
var idx := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	frame += 1
	if frame < 20:
		return false
	if idx >= shots.size():
		quit(0)
		return false
	var s = shots[idx]
	var p: Node3D = main.player
	if frame % 20 == 0:
		var pos: Vector3 = s.pos
		if pos.y == 0:
			pos.y = main.terrain.height_at(pos.x, pos.z)
		p.set_physics_process(false)
		p.position = pos
		p.rotation.y = s.yaw
		p.head.rotation.x = s.pitch
	elif frame % 20 == 15:
		DirAccess.make_dir_recursive_absolute("res://screenshots")
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://screenshots/%s.png" % s.name)
		print("saved ", s.name)
		idx += 1
	return false

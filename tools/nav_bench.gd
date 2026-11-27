extends SceneTree
## Times the nav grid: map rebuild and a full flow field (prints milliseconds).
##   godot --headless --path . -s tools/nav_bench.gd

var main: Node
var frame := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		var nav = main.nav
		var t0 := Time.get_ticks_usec()
		nav.rebuild_map()
		var t1 := Time.get_ticks_usec()
		nav.compute_now("base", Vector3.ZERO)
		var t2 := Time.get_ticks_usec()
		var f = nav.fields.base
		nav._begin(f, Vector3(5, 0, 5))
		var steps := 0
		var worst := 0
		while true:
			var a := Time.get_ticks_usec()
			var done: bool = nav._advance(f, nav.BUDGET)
			worst = maxi(worst, Time.get_ticks_usec() - a)
			steps += 1
			if done:
				break
		print("grid %d x %d: map %.1f ms, field %.1f ms, sliced into %d frames, worst slice %.2f ms" % [nav.n, nav.n, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, steps, worst / 1000.0])
		var b = main.building
		var slot := {"kind": "edge", "cx": 3, "cz": 3, "dir": 0, "level": 0}
		b.place("wall", slot, b.evaluate("wall", slot).y)
		var t3 := Time.get_ticks_usec()
		nav.rebuild_map()
		print("map after one wall: %.1f ms" % ((Time.get_ticks_usec() - t3) / 1000.0))
		quit(0)
	return false

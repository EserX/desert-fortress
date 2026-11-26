extends SceneTree
## Soak test: builds a small fortress (walls, gate, sandbags, wire, mines,
## turrets, generator, floodlights, fence), skips to a big night wave and lets
## it play out for a few thousand frames. Reports how the night went, how long
## frames took, and fails if anything odd happened (errors show in the log).
##   godot --headless --path . -s tools/soak_test.gd --fixed-fps 60
## Optional: -- wave=8 frames=4000

var main: Node
var frame := 0
var wave := 8
var frames := 4000
var _t0 := 0
var _worst := 0.0
var _total := 0.0
var _max_alive := 0
var _kills0 := 0
var walls_only := false  # -- walls=1: just the ring of walls, no traps or turrets
var away := false   # -- away=1: the player is far out in the desert all night


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("wave="):
			wave = int(arg.substr(5))
		elif arg.begins_with("frames="):
			frames = int(arg.substr(7))
		elif arg == "walls=1":
			walls_only = true
		elif arg == "away=1":
			away = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _fortress() -> void:
	var b = main.building
	var sh = main.shop
	for t in b.PIECES:
		sh.unlocked[t] = true
	var place := func(t: String, kind: String, cx: int, cz: int, dir := 0) -> String:
		var slot := {"kind": kind, "cx": cx, "cz": cz, "dir": dir, "level": 0}
		var ev: Dictionary = b.evaluate(t, slot)
		return b.place(t, slot, ev.y) if ev.ok else ""
	# A 6x6 square of walls round the flag, with a gate on the south side.
	for i in range(-3, 3):
		place.call("wall", "edge", i, -3)
		place.call("wall" if i != 0 else "doorway", "edge", i, 3)
		place.call("wall", "edge", -3, i, 1)
		place.call("wall", "edge", 3, i, 1)
	if walls_only:
		print("fortress: %d pieces (walls only)" % b.pieces.size())
		return
	for i in range(-3, 3):
		place.call("barbed_wire", "obj", i, -6)
		place.call("sandbags", "edge", i, -8)
		place.call("landmine", "obj", i * 2, -11)
	var tk: String = place.call("turret", "obj", -2, -2)
	var tk2: String = place.call("turret", "obj", 1, 1)
	for k in [tk, tk2]:
		if k != "":
			b.pieces[k].ammo = 240
	var g: String = place.call("generator", "obj", 1, -2)
	if g != "":
		b.pieces[g].fuel = 10.0
	place.call("floodlight", "obj", -2, 1)
	place.call("fire_pit", "obj", 0, 0)
	for i in range(-2, 2):
		place.call("electric_fence", "edge", i, -4)
	print("fortress: %d pieces" % b.pieces.size())


func _process(delta: float) -> bool:
	frame += 1
	var player = main.player
	if frame == 5:
		main.survival.set_process(false)
		_fortress()
		player.position = Vector3(0.5, main.terrain.surface_height(0.5, 0.5) + 0.2, 0.5)
		if away:
			player.position = Vector3(150, main.terrain.surface_height(150, 120) + 0.5, 120)
		main.waves.wave = wave - 1
		main.day_night.restore(1, 20.0)
		main.waves.start_wave()
		_kills0 = main.mutants.kills
		print("wave %d: %s" % [main.waves.wave, main.waves.mix_text(main.waves.queue)])
		_t0 = Time.get_ticks_usec()
	elif frame > 5:
		# Keep the player alive and in place: this is about the base.
		main.survival.health = 100.0
		var dt := delta * 1000.0
		_total += dt
		_worst = maxf(_worst, dt)
		_max_alive = maxi(_max_alive, main.mutants.alive().size())
		if frame % 600 == 0:
			print("frame %d: %d alive, %d to come, %d pieces, %d kills" % [frame, main.mutants.alive().size(), main.waves.to_spawn, main.building.pieces.size(), main.mutants.kills - _kills0])
	if frame >= frames or (frame > 200 and not main.waves.active):
		var real := (Time.get_ticks_usec() - _t0) / 1000.0
		for m in main.mutants.alive():
			print("   left: %s state=%d at %s (%.0f m from the flag) hp %.0f break=%s blocked_by=%s" % [m.type, m.state, m.global_position.snapped(Vector3.ONE * 0.1), Vector2(m.global_position.x, m.global_position.z).length(), m.health, m.break_key, m._blocking_piece(-m.global_transform.basis.z)])
		print("== SOAK DONE after %d frames: wave active=%s, kills %d, most alive at once %d, pieces left %d" % [frame, main.waves.active, main.mutants.kills - _kills0, _max_alive, main.building.pieces.size()])
		print("   real time %.0f ms for %d frames (%.2f ms per frame, headless, no rendering)" % [real, frame - 5, real / maxf(frame - 5, 1)])
		quit(0)
	return false

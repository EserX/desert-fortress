extends SceneTree
## Throws many stones at standing walkers and counts the misses, to find out
## whether a thrown stone can pass through a mutant. Run with:
##   godot --headless --path . -s tools/throw_probe.gd --fixed-fps 60
## Prints one line per batch and the total.

const BATCH := 24
const ROUNDS := 8

var main: Node
var frame := 0
var round_i := 0
var walkers: Array = []
var stones: Array = []
var closest: Array = []
var hits := 0
var thrown := 0
var miss_notes: Array[String] = []
var contacts: Array[String] = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _start_round() -> void:
	var ms = main.mutants
	var th = main.throwables
	ms.clear()
	walkers.clear()
	stones.clear()
	closest.clear()
	var t = main.terrain
	main.player.position = Vector3(-30, t.surface_height(-30, -80), -80)
	for i in BATCH:
		var c := Vector3(-60 + i * 5.0, 0, -30 + (round_i % 2) * 20)
		var w = ms.spawn("walker", c)
		w.set_physics_process(false)
		walkers.append(w)
		# Same shot as the test: from 4 m in front, 1.3 m up, at 18 m/s.
		var p: Vector3 = w.global_position
		var b: RigidBody3D = th.throw("stone", p + Vector3(0, 1.3, -4.0), Vector3(0, 0, 18))
		stones.append(b)
		var idx := walkers.size() - 1
		var r := round_i
		b.body_entered.connect(func(o: Node):
			var rec = th.flying.filter(func(x): return x.node == b)
			var sp: float = rec[0].speed if not rec.is_empty() else -1.0
			contacts.append("round %d walker %d: touched %s at frame %d, rec.speed %.1f, vel %.1f, pos %s" % [r, idx, o.name, frame, sp, b.linear_velocity.length(), b.global_position]))
		closest.append(99.0)
		thrown += 1


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		_start_round()
	if frame > 30:
		for i in walkers.size():
			var s = stones[i]
			if is_instance_valid(s):
				var w: Vector3 = walkers[i].global_position
				var d := Vector2(s.global_position.x - w.x, s.global_position.z - w.z).length()
				closest[i] = minf(closest[i], d)
	if frame > 30 and (frame - 30) % 120 == 0:
		var n := 0
		for i in walkers.size():
			if walkers[i].health < 100.0:
				n += 1
			else:
				for c in contacts:
					if c.begins_with("round %d walker %d:" % [round_i, i]):
						miss_notes.append("   " + c)
				miss_notes.append("round %d walker %d at %s: closest %.2f m" % [round_i, i, walkers[i].global_position, closest[i]])
		hits += n
		print("round %d: %d of %d hit" % [round_i, n, walkers.size()])
		round_i += 1
		if round_i >= ROUNDS:
			print("TOTAL: %d of %d hit" % [hits, thrown])
			for m in miss_notes:
				print("  miss ", m)
			return true
		_start_round()
	return false

extends SceneTree
## Headless smoke tests. Run with:
##   godot --headless --path . -s tests/run_tests.gd --fixed-fps 60
## Exits with code 0 when everything passes, 1 otherwise.

var main: Node
var frame := 0
var failures: Array[String] = []
var start_pos: Vector3
var events: Array[String] = []


func _initialize() -> void:
	print("== Desert Fortress tests ==")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		failures.append(msg)


func _process(_delta: float) -> bool:
	frame += 1
	var player = main.player
	var terrain = main.terrain
	match frame:
		2:
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
		720:
			if failures.is_empty():
				print("== ALL TESTS PASSED ==")
				quit(0)
			else:
				print("== %d TEST(S) FAILED ==" % failures.size())
				quit(1)
	return false

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
	var got: Dictionary = loot.open(crate.id)
	check(not got.is_empty(), "searching gives loot %s" % str(got))
	check(loot.open(crate.id).is_empty(), "a searched crate is empty")
	check(loot.prompt(crate.id).ends_with("(empty)"), "prompt shows empty")
	var data: Dictionary = main.collect_save_data()
	var before: Dictionary = loot.inventory.duplicate()
	loot.containers[crate.id].opened = false
	loot.inventory = {}
	main.apply_save_data(JSON.parse_string(JSON.stringify(data)))
	check(loot.is_opened(crate.id), "opened containers are saved")
	check(loot.inventory == before, "picked-up items are saved")
	# Same seed and id always roll the same loot.
	var Items = load("res://scripts/items.gd")
	var r1 := RandomNumberGenerator.new()
	r1.seed = 9
	var r2 := RandomNumberGenerator.new()
	r2.seed = 9
	check(Items.roll("trunk", r1) == Items.roll("trunk", r2), "loot rolls are repeatable")


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
		710:
			check(title.world.menu_mode and title.world.player == null, "title screen shows the world without a player")
			check(title._col.get_child_count() >= 5, "title menu has its buttons")
			title.queue_free()
		720:
			if failures.is_empty():
				print("== ALL TESTS PASSED ==")
				quit(0)
			else:
				print("== %d TEST(S) FAILED ==" % failures.size())
				quit(1)
	return false

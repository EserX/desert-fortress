extends SceneTree
## End-to-end menu flow with a real display. Writes screenshots to screenshots/flow_*.png
##   xvfb-run -a godot --path . -s tools/flow_test.gd --rendering-method gl_compatibility --resolution 1280x720

var game: Node
var frame := 0
var failures := 0
var saved_pos: Vector3

func _initialize() -> void:
	game = root.get_node("Game")
	for s in game.SLOTS:
		game.delete_slot(s)
	change_scene_to_file("res://scenes/title.tscn")

func shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	root.get_viewport().get_texture().get_image().save_png("res://screenshots/flow_%s.png" % name)

func check(c: bool, m: String) -> void:
	print("  ", "PASS  " if c else "FAIL  ", m)
	if not c: failures += 1

func _process(_d: float) -> bool:
	frame += 1
	match frame:
		30:
			check(current_scene.name == "Title", "starts on title screen")
			shot("1_title")
			game.new_game()
		33:
			shot("2_loading")
		90:
			check(current_scene.name == "Main" and game.in_game, "new game started")
			var p = current_scene.player
			p.position = Vector3(20, current_scene.terrain.surface_height(20, 30), 30)
			p.rotation.y = 2.0
		120:
			current_scene.pause_menu.open()
			current_scene.pause_menu.show_page("save")
		125:
			shot("3_save_page")
			saved_pos = current_scene.player.position
			check(game.save_game("1", current_scene.pause_menu._shot), "saved to slot 1 with thumbnail")
			check(FileAccess.file_exists(game.thumb_path("1")), "thumbnail written")
			current_scene.pause_menu.show_page("load")
		130:
			shot("4_load_page")
			game.go_to_title()
		160:
			check(current_scene.name == "Title", "back on title screen")
			check(game.latest_slot() != "", "continue available")
			shot("5_title_continue")
			game.continue_game()
		230:
			check(current_scene.name == "Main", "continued game")
			var d: float = current_scene.player.position.distance_to(saved_pos)
			check(d < 1.0, "player back where they were (%.2f m)" % d)
			shot("6_continued")
		240:
			for s in game.SLOTS:
				game.delete_slot(s)
			print("== FLOW %s ==" % ("PASSED" if failures == 0 else "FAILED"))
			game.quiet_then_quit(self, 1 if failures else 0)
	return false

extends Node
## Title screen: the desert at sunset in the background, with Continue,
## New game, Load game, Settings and Quit.

const UI = preload("res://scripts/menu_ui.gd")
const MainScene = preload("res://scenes/main.tscn")

var world: Node3D
var _col: VBoxContainer


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world = MainScene.instantiate()
	world.menu_mode = true
	add_child(world)

	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)

	var logo := Label.new()
	logo.text = "DESERT FORTRESS"
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.size = Vector2(1000, 90)
	logo.position = Vector2(-500, 60)
	logo.add_theme_font_size_override("font_size", 64)
	logo.add_theme_color_override("font_color", UI.ACCENT)
	logo.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.03))
	logo.add_theme_constant_override("outline_size", 10)
	root.add_child(logo)

	var version := Label.new()
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-90, -36)
	version.modulate = Color(1, 1, 1, 0.7)
	root.add_child(version)

	_col = UI.panel(root, 520.0)
	show_page("main")
	Game.hide_loading()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		show_page("main")


func show_page(page: String) -> void:
	UI.clear(_col)
	match page:
		"main":
			var latest := Game.latest_slot()
			var cont := UI.button(_col, "Continue", func(): Game.continue_game(), latest != "")
			if latest != "":
				cont.tooltip_text = Game.describe_slot(latest)
			UI.button(_col, "New game", func(): show_page("new"))
			UI.button(_col, "Load game", func(): show_page("load"), Game.has_any_save())
			UI.button(_col, "Settings", func(): show_page("settings"))
			UI.button(_col, "Quit to desktop", Game.quit_to_desktop)
			if latest != "":
				UI.note(_col, "Last save: " + Game.describe_slot(latest))
		"new":
			UI.title(_col, "NEW GAME", 28)
			UI.note(_col, "Pick a difficulty. It stays with this game.")
			for level in ["easy", "normal", "hard"]:
				var d: Dictionary = Game.DIFFICULTIES[level]
				var b := UI.button(_col, d.name, Game.new_game.bind(level))
				b.tooltip_text = d.info
				UI.note(_col, d.info)
			UI.button(_col, "Back", func(): show_page("main"))
		"load":
			UI.title(_col, "LOAD GAME", 28)
			UI.slot_list(_col, "load", func(slot: String): Game.load_game(slot))
			UI.button(_col, "Back", func(): show_page("main"))
		"settings":
			UI.title(_col, "SETTINGS", 28)
			UI.settings_page(_col)
			UI.button(_col, "Back", func(): show_page("main"))

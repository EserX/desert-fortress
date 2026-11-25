extends CanvasLayer
## Esc menu: resume, save, load, settings, main menu, quit to desktop.
## Pages are rebuilt each time they open so save slots are always current.

const UI = preload("res://scripts/menu_ui.gd")

var _root: Control
var _col: VBoxContainer
var _page := "main"
var _shot: Image  # the game frame from just before the menu opened


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_col = UI.panel(_root, 560.0)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if not is_open():
		open()
	elif _page != "main":
		show_page("main")
	else:
		resume()
	get_viewport().set_input_as_handled()


func open() -> void:
	if DisplayServer.get_name() != "headless":
		_shot = get_viewport().get_texture().get_image()
	get_tree().paused = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_page("main")


func resume() -> void:
	get_tree().paused = false
	_root.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func show_page(page: String) -> void:
	_page = page
	UI.clear(_col)
	match page:
		"main":
			UI.title(_col, "PAUSED", 34)
			UI.button(_col, "Resume", resume)
			UI.button(_col, "Save game", func(): show_page("save"))
			UI.button(_col, "Load game", func(): show_page("load"), Game.has_any_save())
			UI.button(_col, "Settings", func(): show_page("settings"))
			UI.button(_col, "Main menu", Game.go_to_title)
			UI.button(_col, "Quit to desktop", Game.quit_to_desktop)
			UI.note(_col, "Main menu and Quit autosave your game.\nF5 quicksave   F9 quickload")
		"save":
			UI.title(_col, "SAVE GAME", 28)
			UI.slot_list(_col, "save", func(slot: String):
				Game.save_game(slot, _shot)
				show_page("saved"))
			UI.button(_col, "Back", func(): show_page("main"))
		"saved":
			UI.title(_col, "Game saved", 28)
			UI.button(_col, "Resume", resume)
			UI.button(_col, "Back", func(): show_page("main"))
		"load":
			UI.title(_col, "LOAD GAME", 28)
			UI.note(_col, "Unsaved progress will be lost.")
			UI.slot_list(_col, "load", func(slot: String): Game.load_game(slot))
			UI.button(_col, "Back", func(): show_page("main"))
		"settings":
			UI.title(_col, "SETTINGS", 28)
			UI.settings_page(_col)
			UI.button(_col, "Back", func(): show_page("main"))

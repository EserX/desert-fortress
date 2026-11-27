extends Node
## Game flow and saving (autoload "Game").
## Scenes: title screen -> game world. Saves are JSON files in user://saves/
## (on Linux: ~/.local/share/godot/app_userdata/Desert Fortress/saves/),
## each with a small screenshot thumbnail.

signal saved(slot: String)

const TITLE_SCENE := "res://scenes/title.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const SAVE_DIR := "user://saves/"
const SAVE_VERSION := 1
const SLOTS := ["auto", "quick", "1", "2", "3"]
const DEFAULT_SEED := 1337
## How hard the nights are: wave size, mutant health and damage, the pay,
## and how fast you get hungry and thirsty.
const DIFFICULTIES := {
	"easy": {"name": "Easy", "waves": 0.7, "health": 0.8, "damage": 0.6, "cash": 1.25, "needs": 0.7,
		"info": "Smaller waves, weaker mutants, more pay, slower hunger and thirst."},
	"normal": {"name": "Normal", "waves": 1.0, "health": 1.0, "damage": 1.0, "cash": 1.0, "needs": 1.0,
		"info": "The game as designed."},
	"hard": {"name": "Hard", "waves": 1.4, "health": 1.25, "damage": 1.4, "cash": 0.9, "needs": 1.3,
		"info": "Bigger waves, tougher mutants that hit harder, less pay, hungrier days."},
	"peaceful": {"name": "Peaceful", "waves": 0.0, "health": 1.0, "damage": 0.5, "cash": 1.0, "needs": 0.7, "peaceful": true,
		"info": "Terraform only: no mutants, no night waves, no nests breeding guards. Quiet nights still pay."},
}

var world_seed := DEFAULT_SEED
var difficulty := "normal"
## True right after New game (not when loading), for the welcome hint.
var fresh_game := false
var playtime := 0.0
var pending_load: Dictionary = {}  # save data to apply when the world is built
var in_game := false
var world: Node = null             # the running main.gd, set by it
var _loading: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _process(delta: float) -> void:
	if in_game and not get_tree().paused:
		playtime += delta


func _notification(what: int) -> void:
	# Window close button: autosave first, like Quit to desktop.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_to_desktop()


# --- Flow --------------------------------------------------------------------

## One of the difficulty values ("waves", "health", "damage", "cash", "needs").
func diff(key: String) -> float:
	return float(DIFFICULTIES.get(difficulty, DIFFICULTIES.normal)[key])


## True in the peaceful terraform-only mode (v1.19): no mutants at all.
func is_peaceful() -> bool:
	return bool(DIFFICULTIES.get(difficulty, DIFFICULTIES.normal).get("peaceful", false))


func new_game(level := "normal") -> void:
	difficulty = level if DIFFICULTIES.has(level) else "normal"
	fresh_game = true
	pending_load = {}
	world_seed = randi() % 1000000
	playtime = 0.0
	_start_world("Generating a new desert...")


func load_game(slot: String) -> bool:
	var data := read_slot(slot)
	if data.is_empty():
		return false
	pending_load = data
	fresh_game = false
	difficulty = str(data.get("difficulty", "normal"))
	if not DIFFICULTIES.has(difficulty):
		difficulty = "normal"
	world_seed = int(data.get("seed", DEFAULT_SEED))
	playtime = float(data.get("playtime", 0.0))
	_start_world("Loading...")
	return true


func continue_game() -> bool:
	var slot := latest_slot()
	return slot != "" and load_game(slot)


## Autosaves the running game, then returns to the title screen.
func go_to_title() -> void:
	if in_game:
		save_game("auto", _world_thumbnail())
	in_game = false
	world = null
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


## Autosaves the running game, then closes the program.
func quit_to_desktop() -> void:
	if in_game:
		save_game("auto", _world_thumbnail())
	get_tree().quit()


func _world_thumbnail() -> Image:
	if world and is_instance_valid(world):
		return world.thumbnail_image()
	return null


func _start_world(message: String) -> void:
	get_tree().paused = false
	in_game = false
	world = null
	_show_loading(message)
	# Let the loading screen draw before the (blocking) world generation.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE)


## Called by the world when it has finished building.
func world_ready(main: Node) -> void:
	world = main
	in_game = true
	if not pending_load.is_empty():
		main.apply_save_data(pending_load)
		pending_load = {}
	hide_loading()


func _show_loading(message: String) -> void:
	hide_loading()
	_loading = CanvasLayer.new()
	_loading.layer = 100
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.07, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	var label := Label.new()
	label.text = message
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.6))
	_loading.add_child(label)
	get_tree().root.add_child(_loading)


func hide_loading() -> void:
	if is_instance_valid(_loading):
		_loading.queue_free()
	_loading = null


# --- Saving ------------------------------------------------------------------

func slot_path(slot: String) -> String:
	return SAVE_DIR + "slot_%s.json" % slot


func thumb_path(slot: String) -> String:
	return SAVE_DIR + "slot_%s.png" % slot


func slot_label(slot: String) -> String:
	match slot:
		"auto":
			return "Autosave"
		"quick":
			return "Quicksave"
	return "Slot %s" % slot


## Saves the running game. `thumbnail` is an optional screenshot.
func save_game(slot: String, thumbnail: Image = null) -> bool:
	if world == null or not is_instance_valid(world):
		return false
	var data: Dictionary = world.collect_save_data()
	data["save_version"] = SAVE_VERSION
	data["game_version"] = ProjectSettings.get_setting("application/config/version", "")
	data["saved_at"] = Time.get_unix_time_from_system()
	data["seed"] = world_seed
	data["playtime"] = playtime
	data["difficulty"] = difficulty
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Could not write save %s" % slot_path(slot))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if thumbnail:
		var img := thumbnail.duplicate()
		img.resize(256, 144, Image.INTERPOLATE_BILINEAR)
		img.save_png(thumb_path(slot))
	saved.emit(slot)
	return true


## Returns the save data, or {} if the slot is empty or unreadable.
func read_slot(slot: String) -> Dictionary:
	if not FileAccess.file_exists(slot_path(slot)):
		return {}
	var text := FileAccess.get_file_as_string(slot_path(slot))
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or int(data.get("save_version", 0)) > SAVE_VERSION:
		return {}
	return data


func latest_slot() -> String:
	var best := ""
	var best_time := -1.0
	for slot in SLOTS:
		var data := read_slot(slot)
		if not data.is_empty() and float(data.get("saved_at", 0)) > best_time:
			best_time = float(data.get("saved_at", 0))
			best = slot
	return best


func has_any_save() -> bool:
	return latest_slot() != ""


func delete_slot(slot: String) -> void:
	for p in [slot_path(slot), thumb_path(slot)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## One-line description of a slot for menus.
func describe_slot(slot: String) -> String:
	var data := read_slot(slot)
	if data.is_empty():
		return "%s - empty" % slot_label(slot)
	var world_data: Dictionary = data.get("world", {})
	var hour := float(world_data.get("hour", 0.0))
	var when := Time.get_datetime_dict_from_unix_time(int(data.get("saved_at", 0)) + _utc_offset())
	var mins := int(float(data.get("playtime", 0.0)) / 60.0)
	return "%s - Day %d %02d:%02d - played %dh %02dm - saved %02d.%02d %02d:%02d" % [
		slot_label(slot), int(world_data.get("day", 1)), int(hour), int(fmod(hour, 1.0) * 60.0),
		mins / 60, mins % 60, when.day, when.month, when.hour, when.minute]


func thumbnail(slot: String) -> Texture2D:
	if not FileAccess.file_exists(thumb_path(slot)):
		return null
	var img := Image.load_from_file(thumb_path(slot))
	return ImageTexture.create_from_image(img) if img else null


func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

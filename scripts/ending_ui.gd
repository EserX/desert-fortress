extends CanvasLayer
## The ending (v1.19): shown once, when the final green milestone brings the rain
## back. Pauses the game; "Keep playing" goes on in free play.

const UI = preload("res://scripts/menu_ui.gd")

signal closed

var _root: Control
var _lines: Label


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.12, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var col := UI.panel(_root, 520.0)
	UI.title(col, "The rain is back", 40)
	UI.note(col, "Clouds roll in over the green you made, and for the first time in years rain falls on the desert.")
	_lines = UI.note(col, "")
	UI.note(col, "Keep playing: rain now comes over the whole desert on many mornings, and the green spreads from your land.")
	UI.button(col, "Keep playing", close)
	UI.button(col, "Main menu", func():
		close()
		Game.go_to_title())
	_root.visible = false


func is_open() -> bool:
	return _root.visible


## Opens with a few lines about the game so far.
func open(lines: Array) -> void:
	_lines.text = "\n".join(lines)
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Swallow Esc so the pause menu doesn't open over the ending.
	if is_open() and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()

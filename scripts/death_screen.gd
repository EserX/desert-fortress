extends CanvasLayer
## Shown when you die: pauses the game and offers a respawn at the base.

const UI = preload("res://scripts/menu_ui.gd")

signal respawn_pressed

var _root: Control
var _cause: Label


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0.02, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var col := UI.panel(_root, 420.0)
	UI.title(col, "You died", 40)
	_cause = UI.note(col, "")
	UI.note(col, "You keep everything you were carrying.")
	UI.button(col, "Respawn at base", func(): respawn_pressed.emit())
	UI.button(col, "Main menu", func():
		respawn_pressed.emit()
		Game.go_to_title())
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open(cause: String) -> void:
	_cause.text = cause
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_root.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# Swallow Esc so the pause menu doesn't open over the death screen.
	if is_open() and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()

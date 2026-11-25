extends CanvasLayer
## Inventory screen (Tab): a grid of slots. Click a stack, then click another
## slot to move, merge or swap it. Right-click drops the whole stack.
## The top row's first 9 slots are the hotbar.

const UI = preload("res://scripts/menu_ui.gd")
const Items = preload("res://scripts/items.gd")
const Inventory = preload("res://scripts/inventory.gd")

signal drop_requested(slot: int)

const COLUMNS := 10
const SLOT_SIZE := Vector2(84, 72)

var inventory: Inventory
var held := -1  # slot picked up with the mouse, or -1
var _root: Control
var _buttons: Array[Button] = []
var _weight: Label


func _ready() -> void:
	layer = 9
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var col := UI.panel(_root, COLUMNS * (SLOT_SIZE.x + 6))
	UI.title(col, "Inventory", 28)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for i in Inventory.SIZE:
		var b := Button.new()
		b.custom_minimum_size = SLOT_SIZE
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 13)
		b.gui_input.connect(_on_slot_input.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	_weight = UI.note(col, "")
	UI.note(col, "Click a stack, then a slot to move it.   Right-click drops it.   Slots 1–9 are your hotbar.   Tab closes.")
	_root.visible = false
	if inventory:
		inventory.changed.connect(refresh)
	refresh()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	held = -1
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close() -> void:
	held = -1
	_root.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("inventory"):
		close() if is_open() else open()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _on_slot_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		click(i)
	elif event.button_index == MOUSE_BUTTON_RIGHT and not inventory.slots[i].is_empty():
		held = -1
		drop_requested.emit(i)


## Left click on a slot: pick a stack up, or put the held one down there.
func click(i: int) -> void:
	if held < 0:
		if not inventory.slots[i].is_empty():
			held = i
	else:
		inventory.move(held, i)
		held = -1
	refresh()


func refresh() -> void:
	if inventory == null or _buttons.is_empty():
		return
	for i in Inventory.SIZE:
		var s: Dictionary = inventory.slots[i]
		var b := _buttons[i]
		var key := "%d " % (i + 1) if i < Inventory.HOTBAR else ""
		b.text = key if s.is_empty() else "%s%s\nx%d" % [key, Items.display_name(s.item), s.count]
		var tint := Color(1, 1, 1)
		if i == held:
			tint = Color(1.4, 1.2, 0.6)
		elif i < Inventory.HOTBAR:
			tint = Color(1.0, 0.92, 0.8)
		b.modulate = tint
	var w := inventory.weight()
	_weight.text = "Weight %.1f / %.0f kg%s" % [w, Inventory.MAX_WEIGHT, "   TOO HEAVY: no sprinting" if inventory.overloaded() else ""]

extends CanvasLayer
## The shop screen: your cash and the catalogue in categories. Click to buy.
## E, Tab or Esc closes it.

const UI = preload("res://scripts/menu_ui.gd")
const Items = preload("res://scripts/items.gd")

signal bought(index: int, left: Dictionary)

var shop  # Shop
var inventory  # Inventory
var _root: Control
var _cash: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var col := UI.panel(_root, 760)
	UI.title(col, "Shop terminal", 28)
	_cash = UI.title(col, "", 22)
	var cat := ""
	var grid: GridContainer
	for i in shop.CATALOG.size():
		var e: Dictionary = shop.CATALOG[i]
		if e.cat != cat:
			cat = e.cat
			var l := Label.new()
			l.text = cat
			l.add_theme_font_size_override("font_size", 17)
			l.add_theme_color_override("font_color", UI.ACCENT)
			col.add_child(l)
			grid = GridContainer.new()
			grid.columns = 4
			grid.add_theme_constant_override("h_separation", 6)
			grid.add_theme_constant_override("v_separation", 6)
			col.add_child(grid)
		var b := UI.button(grid, "%s\n$%d" % [e.name, e.price], buy.bind(i))
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(182, 44)
		_buttons.append(b)
	UI.note(col, "Cash comes in at the end of each night: kills, the night survived and how well the base held.   E or Esc closes.")
	_root.visible = false
	shop.cash_changed.connect(func(_c): refresh())


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close() -> void:
	_root.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func buy(i: int) -> void:
	var left = shop.buy(i, inventory)
	if left != null:
		bought.emit(i, left)
	refresh()


func refresh() -> void:
	_cash.text = "Cash: $%d" % shop.cash
	for i in _buttons.size():
		_buttons[i].disabled = not shop.can_buy(i)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or get_tree().paused:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()

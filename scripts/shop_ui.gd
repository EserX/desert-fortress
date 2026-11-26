extends CanvasLayer
## The shop screen: your cash and two pages, the counter (bought straight into
## your pockets) and drone orders (flown to your landing pad). Click to buy.
## E, Tab or Esc closes it.

const UI = preload("res://scripts/menu_ui.gd")
const Items = preload("res://scripts/items.gd")

signal bought(index: int, left: Dictionary)
signal ordered(index: int)

var shop  # Shop
var inventory  # Inventory
var _root: Control
var _cash: Label
var _buttons: Array[Button] = []
var drone_buttons: Array[Button] = []
var _counter: VBoxContainer
var _drone_page: VBoxContainer
var _drone_note: Label
var _tabs: Array[Button] = []


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
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	for t in ["Counter", "Drone orders"]:
		var tb := UI.button(tabs, t, show_page.bind(t == "Drone orders"))
		tb.custom_minimum_size = Vector2(220, 36)
		tb.toggle_mode = true
		_tabs.append(tb)
	_counter = VBoxContainer.new()
	_counter.add_theme_constant_override("separation", 8)
	col.add_child(_counter)
	_drone_page = VBoxContainer.new()
	_drone_page.add_theme_constant_override("separation", 8)
	col.add_child(_drone_page)
	_drone_note = UI.note(_drone_page, "")
	var dgrid := GridContainer.new()
	dgrid.columns = 3
	dgrid.add_theme_constant_override("h_separation", 6)
	dgrid.add_theme_constant_override("v_separation", 6)
	_drone_page.add_child(dgrid)
	for i in shop.DRONE.size():
		var b := UI.button(dgrid, "", order.bind(i))
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(244, 52)
		drone_buttons.append(b)
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
			_counter.add_child(l)
			grid = GridContainer.new()
			grid.columns = 4
			grid.add_theme_constant_override("h_separation", 6)
			grid.add_theme_constant_override("v_separation", 6)
			_counter.add_child(grid)
		var b := UI.button(grid, "%s\n$%d" % [e.name, e.price], buy.bind(i))
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(182, 44)
		_buttons.append(b)
	UI.note(col, "Cash comes in at the end of each night: kills, the night survived and how well the base held.   E or Esc closes.")
	_root.visible = false
	shop.cash_changed.connect(func(_c): refresh())


func is_open() -> bool:
	return _root.visible


func show_page(drone: bool) -> void:
	_counter.visible = not drone
	_drone_page.visible = drone
	_tabs[0].set_pressed_no_signal(not drone)
	_tabs[1].set_pressed_no_signal(drone)
	refresh()


func open() -> void:
	_root.visible = true
	show_page(false)
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


func order(i: int) -> void:
	if shop.order(i):
		ordered.emit(i)
	refresh()


func refresh() -> void:
	_cash.text = "Cash: $%d" % shop.cash
	for i in _buttons.size():
		_buttons[i].disabled = not shop.can_buy(i)
	if shop.drone == null:
		return
	var has_pad: bool = shop.drone.pad_position() != null
	if not has_pad:
		_drone_note.text = "Build a drone landing pad (build mode) to order by drone."
	elif shop.drone.phase != "idle":
		_drone_note.text = "The drone is on its way. New orders go on the next flight."
	else:
		_drone_note.text = "Orders are flown to your landing pad in about 20 seconds. Blueprints unlock new builds."
	for i in drone_buttons.size():
		var e: Dictionary = shop.DRONE[i]
		var owned := false
		for item in e.items:
			if shop.BLUEPRINTS.has(item) and shop.blueprint_owned(item):
				owned = true
		drone_buttons[i].text = "%s\n%s" % [e.name, "Owned" if owned else "$%d" % e.price]
		drone_buttons[i].disabled = not shop.can_order(i)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or get_tree().paused:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()

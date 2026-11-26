extends CanvasLayer
## Inventory screen (Tab): a grid of slots. Click a stack, then click another
## slot to move, merge or swap it. Right-click drops the whole stack.
## The top row's first 9 slots are the hotbar.
## Opened at a storage chest it also shows the chest's slots (right click moves
## a stack across); opened at a workbench it shows the crafting recipes.

const UI = preload("res://scripts/menu_ui.gd")
const Items = preload("res://scripts/items.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Building = preload("res://scripts/building.gd")

signal drop_requested(slot: int)
## A recipe was made. left: what did not fit in your pockets.
signal crafted(id: String, left: Dictionary)

const COLUMNS := 10
const SLOT_SIZE := Vector2(84, 72)

var inventory: Inventory
var held := -1  # slot picked up with the mouse, or -1
var held_in_chest := false  # the held slot is one of the chest's
## The open chest's storage and piece key, when opened at a chest.
var chest: Inventory
var chest_key := ""
var bench_key := ""  # set when opened at a workbench
var _root: Control
var _buttons: Array[Button] = []
var _chest_buttons: Array[Button] = []
var _chest_box: VBoxContainer
var _bench_box: VBoxContainer
var _recipe_buttons := {}
var _weight: Label
var _help: Label


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
		_buttons.append(_slot_button(grid, _on_slot_input.bind(i)))
	_weight = UI.note(col, "")

	_chest_box = VBoxContainer.new()
	col.add_child(_chest_box)
	UI.title(_chest_box, "Storage chest", 22)
	var cgrid := GridContainer.new()
	cgrid.columns = COLUMNS
	cgrid.add_theme_constant_override("h_separation", 6)
	cgrid.add_theme_constant_override("v_separation", 6)
	_chest_box.add_child(cgrid)
	for i in Building.CHEST_SLOTS:
		_chest_buttons.append(_slot_button(cgrid, _on_chest_input.bind(i)))

	_bench_box = VBoxContainer.new()
	_bench_box.add_theme_constant_override("separation", 6)
	col.add_child(_bench_box)
	UI.title(_bench_box, "Workbench", 22)
	for id in Items.RECIPES:
		var b := UI.button(_bench_box, "", craft.bind(id))
		b.add_theme_font_size_override("font_size", 15)
		_recipe_buttons[id] = b

	_help = UI.note(col, "")
	_root.visible = false
	if inventory:
		inventory.changed.connect(refresh)
	refresh()


func _slot_button(grid: GridContainer, handler: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = SLOT_SIZE
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
	b.gui_input.connect(handler)
	grid.add_child(b)
	return b


func is_open() -> bool:
	return _root.visible


## Plain inventory (Tab).
func open() -> void:
	_open("", null, "")


## Inventory next to a chest's slots.
func open_chest(key: String, storage: Inventory) -> void:
	_open(key, storage, "")


## Inventory with the workbench recipes.
func open_bench(key: String) -> void:
	_open("", null, key)


func _open(ck: String, storage: Inventory, bk: String) -> void:
	if chest and chest.changed.is_connected(refresh):
		chest.changed.disconnect(refresh)
	held = -1
	chest_key = ck
	chest = storage
	bench_key = bk
	if chest:
		chest.changed.connect(refresh)
	_chest_box.visible = chest != null
	_bench_box.visible = bench_key != ""
	if chest:
		_help.text = "Click a stack, then a slot to move it.   Right-click moves a stack between chest and pockets.   Tab or E closes."
	else:
		_help.text = "Click a stack, then a slot to move it.   Right-click drops it.   Slots 1–9 are your hotbar.   Tab%s closes." % (" or E" if bench_key != "" else "")
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close() -> void:
	held = -1
	if chest and chest.changed.is_connected(refresh):
		chest.changed.disconnect(refresh)
	chest = null
	chest_key = ""
	bench_key = ""
	_root.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("inventory"):
		close() if is_open() else open()
		get_viewport().set_input_as_handled()
	elif is_open() and (event.is_action_pressed("pause") or (event.is_action_pressed("interact") and (chest or bench_key != ""))):
		close()
		get_viewport().set_input_as_handled()


func _on_slot_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		click(i)
	elif event.button_index == MOUSE_BUTTON_RIGHT and not inventory.slots[i].is_empty():
		held = -1
		if chest:
			inventory.transfer(i, chest)
			refresh()
		else:
			drop_requested.emit(i)


func _on_chest_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton and event.pressed) or chest == null:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		click(i, true)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		held = -1
		chest.transfer(i, inventory)
		refresh()


## Left click on a slot (in_chest: one of the chest's): pick a stack up, or
## put the held one down there.
func click(i: int, in_chest := false) -> void:
	var here: Inventory = chest if in_chest else inventory
	if here == null:
		return
	if held < 0:
		if not here.slots[i].is_empty():
			held = i
			held_in_chest = in_chest
	else:
		var from: Inventory = chest if held_in_chest else inventory
		from.move_to(held, here, i)
		held = -1
	refresh()


## Makes one of a recipe at the workbench.
func craft(id: String) -> void:
	var left = Items.craft(id, inventory)
	if left != null:
		crafted.emit(id, left)
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
		if i == held and not held_in_chest:
			tint = Color(1.4, 1.2, 0.6)
		elif i < Inventory.HOTBAR:
			tint = Color(1.0, 0.92, 0.8)
		b.modulate = tint
	var w := inventory.weight()
	if chest:
		for i in _chest_buttons.size():
			var s: Dictionary = chest.slots[i]
			_chest_buttons[i].text = "" if s.is_empty() else "%s\nx%d" % [Items.display_name(s.item), s.count]
			_chest_buttons[i].modulate = Color(1.4, 1.2, 0.6) if (i == held and held_in_chest) else Color(0.9, 1.0, 0.9)
	if bench_key != "":
		for id in _recipe_buttons:
			var r: Dictionary = Items.RECIPES[id]
			var parts: Array = []
			for item in r.cost:
				parts.append("%d %s (%d)" % [r.cost[item], Items.display_name(item).to_lower(), inventory.count_of(item)])
			var b: Button = _recipe_buttons[id]
			b.text = "Make %s:  %s   — %s" % [Items.display_name(id).to_lower(), ", ".join(parts), r.info]
			b.disabled = not Items.can_craft(id, inventory)
	_weight.text = "Weight %.1f / %.0f kg%s" % [w, Inventory.MAX_WEIGHT, "   TOO HEAVY: no sprinting" if inventory.overloaded() else ""]

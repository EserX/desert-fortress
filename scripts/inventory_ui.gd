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
const RECIPE_COLUMNS := 4
## Room kept free above and below the panel, plus the panel's own margins and
## border, when the chest or recipe list is fitted to the window height.
const SCREEN_GAP := 12.0
const PANEL_EDGES := 2 * 26.0 + 2 * 2.0
const MIN_LIST_HEIGHT := 100.0

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
const MAX_CHEST := 40      # biggest chest after storage upgrades
## Workbench tier (base upgrades): recipes above it are shown but locked.
var bench_tier := 1
var _col: VBoxContainer
var _chest_box: VBoxContainer
var _bench_box: VBoxContainer
## The chest slots and the recipes scroll when the window is too short for them.
var _chest_scroll: ScrollContainer
var _recipe_scroll: ScrollContainer
var _recipe_buttons := {}
var _weight: Label
var _help: Label
var window_height_override := 0.0
var _refit_queued := false
var _help_base := ""  # help line before the "scroll for more" note


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
	_col = col
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
	_chest_scroll = _list_scroll(_chest_box)
	_chest_scroll.add_child(cgrid)
	cgrid.minimum_size_changed.connect(_on_list_resized)
	for i in MAX_CHEST:
		var cb := _slot_button(cgrid, _on_chest_input.bind(i))
		cb.custom_minimum_size.y = 50  # flatter, so a 40-slot chest still fits on screen
		_chest_buttons.append(cb)

	_bench_box = VBoxContainer.new()
	_bench_box.add_theme_constant_override("separation", 6)
	col.add_child(_bench_box)
	UI.title(_bench_box, "Workbench", 22)
	var rgrid := GridContainer.new()
	rgrid.columns = RECIPE_COLUMNS
	rgrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rgrid.add_theme_constant_override("h_separation", 5)
	rgrid.add_theme_constant_override("v_separation", 5)
	_recipe_scroll = _list_scroll(_bench_box)
	_recipe_scroll.add_child(rgrid)
	rgrid.minimum_size_changed.connect(_on_list_resized)
	for id in Items.RECIPES:
		var b := UI.button(rgrid, "", craft.bind(id))
		b.add_theme_font_size_override("font_size", 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(200, 40)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.tooltip_text = Items.RECIPES[id].info
		_recipe_buttons[id] = b

	_help = UI.note(col, "")
	_root.visible = false
	if inventory:
		inventory.changed.connect(refresh)
	get_viewport().size_changed.connect(_on_window_resized)
	refresh()


## A scroll box (vertical only) for the chest slots or the recipes.
func _list_scroll(parent: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	return sc


func _on_window_resized() -> void:
	if is_open():
		fit_to_window()


## Wrapped button texts only get their real height once laid out, so fit
## again then (once per frame at most).
func _on_list_resized() -> void:
	if is_open() and not _refit_queued:
		_refit_queued = true
		_refit.call_deferred()


func _refit() -> void:
	_refit_queued = false
	if is_open():
		var keep := (_recipe_scroll if bench_key != "" else _chest_scroll).scroll_vertical
		fit_to_window()
		(_recipe_scroll if bench_key != "" else _chest_scroll).scroll_vertical = keep


## Window height the panel may use (window_height_override > 0 stands in for
## it in tests, since the headless window has a fixed size).
func _window_height() -> float:
	return window_height_override if window_height_override > 0.0 else get_viewport().get_visible_rect().size.y


## Makes the open chest or recipe list as tall as it needs, but no taller than
## the window leaves room for (the rest of the list then scrolls), so the help
## line under it stays on screen at 1280x720.
func fit_to_window() -> void:
	for sc: ScrollContainer in [_chest_scroll, _recipe_scroll]:
		sc.custom_minimum_size.y = 0.0
		sc.scroll_vertical = 0
	_help.text = _help_base
	var sc: ScrollContainer = _recipe_scroll if bench_key != "" else (_chest_scroll if chest else null)
	if sc == null:
		return
	var want: float = (sc.get_child(0) as Control).get_combined_minimum_size().y
	sc.custom_minimum_size.y = minf(want, _list_room())
	if not list_fits():
		# A shorter help line that mentions scrolling; measure the room again.
		if bench_key != "":
			_help.text = "Click a recipe to make it.   Mouse wheel scrolls the recipes.   Right-click drops a stack.   Tab or E closes."
		else:
			_help.text = "Right-click moves a stack between chest and pockets.   Mouse wheel scrolls the chest.   Tab or E closes."
		sc.custom_minimum_size.y = 0.0
		sc.custom_minimum_size.y = minf(want, _list_room())


## Room left for the chest or recipe list (at height 0 while this runs).
func _list_room() -> float:
	# The first time the screen opens nothing is laid out yet, and a wrapping
	# label measures its height at its old width (1 px, so thousands of px
	# tall). Give the labels the panel's width before measuring.
	var width := maxf(_col.size.x, _col.custom_minimum_size.x)
	for c in _col.get_children():
		if c is Label:
			(c as Label).size.x = width
			(c as Label).update_minimum_size()  # resizing alone leaves the cached height
	var rest: float = _col.get_combined_minimum_size().y  # everything but the list
	return maxf(_window_height() - 2.0 * SCREEN_GAP - PANEL_EDGES - rest, MIN_LIST_HEIGHT)


## Height the open panel needs, margins included (for tests and tools).
func panel_height() -> float:
	return _col.get_combined_minimum_size().y + PANEL_EDGES


## True when the whole list fits without scrolling (for tests and tools).
func list_fits() -> bool:
	var sc: ScrollContainer = _recipe_scroll if bench_key != "" else _chest_scroll
	return sc.custom_minimum_size.y >= (sc.get_child(0) as Control).get_combined_minimum_size().y - 0.5


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
		_help_base = "Click a stack, then a slot to move it.   Right-click moves a stack between chest and pockets.   Tab or E closes."
	else:
		_help_base = "Click a stack, then a slot to move it.   Right-click drops it.   Slots 1–9 are your hotbar.   Tab%s closes." % (" or E" if bench_key != "" else "")
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()
	fit_to_window()


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
	if Items.recipe_tier(id) > bench_tier:
		return
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
			_chest_buttons[i].visible = i < chest.slots.size()
			if i >= chest.slots.size():
				continue
			var s: Dictionary = chest.slots[i]
			_chest_buttons[i].text = "" if s.is_empty() else "%s\nx%d" % [Items.display_name(s.item), s.count]
			_chest_buttons[i].modulate = Color(1.4, 1.2, 0.6) if (i == held and held_in_chest) else Color(0.9, 1.0, 0.9)
	if bench_key != "":
		for id in _recipe_buttons:
			var r: Dictionary = Items.RECIPES[id]
			var parts: Array = []
			for item in r.cost:
				parts.append("%d %s (%d)" % [r.cost[item], Items.display_name(item).to_lower().replace("scrap metal", "scrap"), inventory.count_of(item)])
			var b: Button = _recipe_buttons[id]
			var made: String = Items.display_name(id) if r.count == 1 else "%d %s" % [r.count, Items.display_name(id).to_lower()]
			if Items.recipe_tier(id) > bench_tier:
				b.text = "%s\nneeds workbench tier %d" % [made, Items.recipe_tier(id)]
				b.disabled = true
			else:
				b.text = "Make %s\n%s" % [made, ", ".join(parts)]
				b.disabled = not Items.can_craft(id, inventory)
	_weight.text = "Weight %.1f / %.0f kg%s" % [w, Inventory.MAX_WEIGHT, "   TOO HEAVY: no sprinting" if inventory.overloaded() else ""]

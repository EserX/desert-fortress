extends CanvasLayer
## The blueprint menu (build mode, T): every ready-made building as a card
## with a drawing, its size in pieces and its price in the material picked
## along the top. Click a card (or press 1-7) to pick it and lay it with the
## left mouse button as before. The material row does what G does. T or the
## "Single pieces" card goes back to single pieces; Esc or Tab just closes it.

const UI = preload("res://scripts/menu_ui.gd")
const Items = preload("res://scripts/items.gd")
const Prefabs = preload("res://scripts/prefabs.gd")
const Building = preload("res://scripts/building.gd")
const Picture = preload("res://scripts/blueprint_picture.gd")

signal picked(id: String)
signal tier_picked(tier: int)
signal singles

const CARD := Vector2(196, 186)
const PICTURE := Vector2(184, 112)

var build_mode  # BuildMode
var _root: Control
## One per building in Prefabs.ORDER order.
var cards: Array[Button] = []
var pictures: Array = []
var _costs: Array[Label] = []
var tier_buttons: Array[Button] = []


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
	var col := UI.panel(_root, CARD.x * 4 + 18)
	col.add_theme_constant_override("separation", 10)
	UI.title(col, "Ready-made buildings", 24)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var l := Label.new()
	l.text = "Material [G]:"
	row.add_child(l)
	for t in Building.TIER_NAMES.size():
		var tb := UI.button(row, String(Building.TIER_NAMES[t]).capitalize(), set_tier.bind(t))
		tb.toggle_mode = true
		tb.custom_minimum_size = Vector2(130, 34)
		tb.add_theme_font_size_override("font_size", 15)
		tier_buttons.append(tb)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for i in Prefabs.ORDER.size():
		_add_card(grid, i)
	var sb := UI.button(grid, "Single pieces\n\nfoundations, walls,\ntraps, machines...\n\n[T]", go_singles)
	sb.custom_minimum_size = CARD
	sb.add_theme_font_size_override("font_size", 15)
	UI.note(col, "Click a building, then left click lays its blueprint for free; E at it builds it piece by piece.   Esc closes.")
	_root.visible = false


func _add_card(grid: GridContainer, i: int) -> void:
	var id: String = Prefabs.ORDER[i]
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = CARD
	b.pressed.connect(pick.bind(i))
	grid.add_child(b)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = 6
	box.offset_bottom = -4
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var pic = Picture.new()
	pic.custom_minimum_size = PICTURE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.prefab = id
	box.add_child(pic)
	pictures.append(pic)
	var title_l := Label.new()
	title_l.text = "%d  %s" % [i + 1, Prefabs.display_name(id)]
	title_l.add_theme_font_size_override("font_size", 14)
	title_l.add_theme_color_override("font_color", UI.ACCENT)
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_l.clip_text = true
	box.add_child(title_l)
	var cost := Label.new()
	cost.add_theme_font_size_override("font_size", 11)
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.modulate = Color(1, 1, 1, 0.8)
	box.add_child(cost)
	_costs.append(cost)
	cards.append(b)


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_root.visible = true
	refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## What a card says under its name: how many pieces and the whole price.
static func card_text(id: String, tier: int) -> String:
	var cost: Dictionary = Building.prefab_cost(id, tier)
	var parts: Array = []
	for item in cost:
		parts.append("%d %s" % [cost[item], Items.display_name(item).to_lower()])
	return "%d pieces: %s" % [Prefabs.entries(id).size(), ", ".join(parts)]


## Highlights the building and material picked, and redraws for the material.
func refresh() -> void:
	var t: int = build_mode.prefab_tier
	for i in cards.size():
		cards[i].set_pressed_no_signal(i == build_mode.prefab_index)
		pictures[i].tier = t
		_costs[i].text = card_text(Prefabs.ORDER[i], t)
	for i in tier_buttons.size():
		tier_buttons[i].set_pressed_no_signal(i == t)


func pick(i: int) -> void:
	if i < 0 or i >= Prefabs.ORDER.size():
		return
	build_mode.select(i)
	close()
	picked.emit(Prefabs.ORDER[i])


func set_tier(t: int) -> void:
	build_mode.prefab_tier = clampi(t, 0, Building.TIER_NAMES.size() - 1)
	refresh()
	tier_picked.emit(build_mode.prefab_tier)


func go_singles() -> void:
	if build_mode.prefab_mode:
		build_mode.toggle_prefabs()
	close()
	singles.emit()


func _process(_delta: float) -> void:
	# Build mode can end under the menu (you die): don't leave it up.
	if is_open() and (build_mode == null or not build_mode.active or not build_mode.prefab_mode):
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or get_tree().paused:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
		close()
	elif event.is_action_pressed("build_menu"):
		go_singles()
	elif event.is_action_pressed("move_piece"):
		set_tier((build_mode.prefab_tier + 1) % Building.TIER_NAMES.size())
	else:
		for i in Prefabs.ORDER.size():
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				pick(i)
				get_viewport().set_input_as_handled()
				return
		return
	get_viewport().set_input_as_handled()

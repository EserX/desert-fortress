extends CanvasLayer
## v2.9: the base status page (J). A list of every machine, furnace,
## generator and defence (turrets, floodlights, fences): where it is and whether it is working, and why not (the lines
## come from base_status.gd). Like the map, it only shows; the game goes on.

const BaseStatus = preload("res://scripts/base_status.gd")

const TEXT := Color(1, 0.95, 0.85)
const COLOURS := {
	BaseStatus.RUNNING: Color(0.6, 1.0, 0.5),
	BaseStatus.STUCK: Color(1.0, 0.55, 0.4),
	BaseStatus.IDLE: Color(0.85, 0.8, 0.7),
}
const MARKS := {BaseStatus.RUNNING: "[x]", BaseStatus.STUCK: "[!]", BaseStatus.IDLE: "[ ]"}
const REFRESH := 0.25   # seconds between new lines while open
const ROW := 24.0

var main: Node  # main.gd
var _root: Control
var _canvas: Control
var _t := 0.0
## The lines last worked out (base_status.gd entries), for drawing and tests.
var list: Array = []


func _ready() -> void:
	layer = 8
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_page)
	_root.add_child(_canvas)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		if main and main.map_ui and main.map_ui.is_open():
			main.map_ui.toggle()  # one full-screen page at a time
		refresh()


## Works the lines out again (four times a second while open).
func refresh() -> void:
	if main == null:
		return
	list = BaseStatus.entries(main.building, main.water, main.oases)
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	if not is_open():
		return
	_t -= delta
	if _t <= 0.0:
		_t = REFRESH
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("base_status"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open() and (event.is_action_pressed("pause") or event.is_action_pressed("map")):
		toggle()
		if event.is_action_pressed("map"):
			return  # let the map open
		get_viewport().set_input_as_handled()


## How many lines fit on the page at this window size.
func rows_that_fit() -> int:
	return maxi(int((_canvas.size.y - 200.0) / ROW), 1)


func _draw_page() -> void:
	var font := ThemeDB.fallback_font
	var x := 80.0
	var y := 90.0
	_canvas.draw_string(font, Vector2(x, y), "BASE STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TEXT)
	y += 34.0
	_canvas.draw_string(font, Vector2(x, y), BaseStatus.summary(list), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)
	y += 36.0
	var fit := rows_that_fit()
	var width := _canvas.size.x - x * 2.0
	for i in mini(list.size(), fit):
		var e: Dictionary = list[i]
		var col: Color = COLOURS.get(e.state, TEXT)
		var head := "%s %s, %s:" % [MARKS.get(e.state, "[ ]"), e.name, e.where]
		_canvas.draw_string(font, Vector2(x, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)
		var hw := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		_canvas.draw_string(font, Vector2(x + hw + 10.0, y), e.text, HORIZONTAL_ALIGNMENT_LEFT, maxf(width - hw - 10.0, 50.0), 17, col)
		y += ROW
	if list.size() > fit:
		_canvas.draw_string(font, Vector2(x, y), "...and %d more" % (list.size() - fit), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
	_canvas.draw_string(font, Vector2(x, _canvas.size.y - 50.0), "[!] stuck: needs you (red ! on the map, M)    [ ] idle: nothing to do    [x] working        J or Esc closes", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)

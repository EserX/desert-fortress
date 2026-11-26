extends CanvasLayer
## Map (M): a top-down view of the play area with the base, the places you
## have discovered, spotted supply crates and where you are facing.

var main: Node  # main.gd
var _root: Control
var _canvas: Control

const SAND := Color(0.86, 0.72, 0.5, 0.95)
const MOUNTAIN := Color(0.55, 0.38, 0.27)
const INK := Color(0.2, 0.12, 0.06)


func _ready() -> void:
	layer = 8
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	_root.add_child(_canvas)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	_root.visible = not _root.visible


func _process(_d: float) -> void:
	if is_open():
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("map"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


## Map radius in pixels: fits the window with room for the legend.
func radius_px() -> float:
	return minf(_canvas.size.x, _canvas.size.y) * 0.5 - 70.0


## World x/z to a point on the canvas.
func to_map(p: Vector3) -> Vector2:
	var scale: float = radius_px() / main.terrain.PLAY_RADIUS
	return _canvas.size * 0.5 + Vector2(p.x, p.z) * scale


func _draw_map() -> void:
	var c := _canvas.size * 0.5
	var RADIUS_PX := radius_px()
	var font := ThemeDB.fallback_font
	_canvas.draw_circle(c, RADIUS_PX + 16.0, MOUNTAIN)
	_canvas.draw_circle(c, RADIUS_PX, SAND)
	_canvas.draw_string(font, c + Vector2(-8, -RADIUS_PX - 22), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.85))
	# Base.
	var b := to_map(Vector3.ZERO)
	_canvas.draw_rect(Rect2(b - Vector2(7, 7), Vector2(14, 14)), Color(0.8, 0.15, 0.1))
	_canvas.draw_string(font, b + Vector2(10, 5), "Base", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	# Discovered places.
	for place in main.places:
		if not main.discovered.has(place.key):
			continue
		var p := to_map(place.pos)
		var left: bool = main.place_has_loot(place)
		var col := Color(0.6, 0.3, 0.12) if place.kind == "wreck" else Color(0.45, 0.43, 0.4)
		if not left:
			col.a = 0.45
		if place.kind == "wreck":
			_canvas.draw_rect(Rect2(p - Vector2(7, 4), Vector2(14, 8)), col)
		else:
			_canvas.draw_polyline(PackedVector2Array([p + Vector2(-7, -6), p + Vector2(-7, 6), p + Vector2(7, 6)]), col, 3.0)
		if left:
			_canvas.draw_circle(p + Vector2(9, -7), 3.0, Color(0.2, 0.55, 0.15))
	# Supply crates.
	for id in main.loot.supplies:
		var sp := to_map(main.loot.supplies[id].position)
		var col := Color(0.25, 0.4, 0.1) if not main.loot.is_opened(id) else Color(0.25, 0.4, 0.1, 0.35)
		_canvas.draw_rect(Rect2(sp - Vector2(7, 7), Vector2(14, 14)), col)
		_canvas.draw_string(font, sp + Vector2(10, 5), "Supply", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	# During a wave: the mutants coming (the radio picks them up), and a ring
	# for the build zone.
	_canvas.draw_arc(b, main.building.zone_radius * RADIUS_PX / main.terrain.PLAY_RADIUS, 0.0, TAU, 48, Color(0.8, 0.15, 0.1, 0.5), 1.5)
	if main.waves and main.waves.active:
		for m in main.waves.hunters():
			_canvas.draw_circle(to_map(m.global_position), 4.0 if m.type != "brute" else 6.0, Color(0.85, 0.1, 0.05))
	# Player arrow.
	var pp := to_map(main.player.global_position)
	var fwd3: Vector3 = -main.player.global_transform.basis.z
	var f := Vector2(fwd3.x, fwd3.z).normalized()
	var s := Vector2(-f.y, f.x)
	_canvas.draw_colored_polygon(PackedVector2Array([pp + f * 12, pp - f * 7 + s * 7, pp - f * 3, pp - f * 7 - s * 7]), Color(0.1, 0.3, 0.9))
	# Legend.
	var y := 120.0
	for line in ["MAP", "Brown block: wreck", "Grey corner: ruin", "Green dot: still has loot", "Green square: supply crate", "Red dots: tonight's wave", "Blue arrow: you", "", "M or Esc closes"]:
		_canvas.draw_string(font, Vector2(30, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 22 if line == "MAP" else 16, Color(1, 0.95, 0.85))
		y += 26.0

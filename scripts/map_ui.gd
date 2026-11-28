extends CanvasLayer
## Map (M): a top-down view of the play area with the base, the places you
## have discovered, spotted supply crates, the water network and where you are facing.

var main: Node  # main.gd
var _root: Control
var _canvas: Control
## v2.8.4: how far the map is zoomed in on the base (mouse wheel while it's open).
var zoom := 1.0
const ZOOMS := [1.0, 2.0, 4.0, 8.0]

const SAND := Color(0.86, 0.72, 0.5, 0.95)
const MOUNTAIN := Color(0.55, 0.38, 0.27)
const INK := Color(0.2, 0.12, 0.06)
const WET := Color(0.15, 0.45, 0.95)   # pipes, sprinklers, purifiers with water
const DRY := Color(0.5, 0.52, 0.56)    # ...without
const OFF := Color(0.25, 0.25, 0.28)   # a sprinkler turned off
const DEW := Color(0.1, 0.6, 0.55)     # dew collectors
const FRAME := Color(0.12, 0.08, 0.05)  # round the map while zoomed in


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
	if _root.visible and main and main.get("base_status_ui") and main.base_status_ui.is_open():
		main.base_status_ui.toggle()  # v2.9: one full-screen page at a time


func _process(_d: float) -> void:
	if is_open():
		_canvas.queue_redraw()


## Mouse wheel while the map is open zooms in and out on the base (and doesn't
## change the hotbar slot).
func _input(event: InputEvent) -> void:
	if not is_open() or get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_step(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		get_viewport().set_input_as_handled()


## One zoom step in (+1) or out (-1), within ZOOMS.
func zoom_step(dir: int) -> void:
	var i := ZOOMS.find(zoom)
	if i < 0:
		i = 0
	zoom = ZOOMS[clampi(i + dir, 0, ZOOMS.size() - 1)]


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


## Pixels per metre at the current zoom.
func map_scale() -> float:
	return radius_px() / main.terrain.PLAY_RADIUS * zoom


## World x/z to a point on the canvas (the base is always in the middle).
func to_map(p: Vector3) -> Vector2:
	return _canvas.size * 0.5 + Vector2(p.x, p.z) * map_scale()


func _draw_map() -> void:
	var c := _canvas.size * 0.5
	var RADIUS_PX := radius_px()
	var font := ThemeDB.fallback_font
	_canvas.draw_circle(c, RADIUS_PX + 16.0, MOUNTAIN)
	_canvas.draw_circle(c, RADIUS_PX, SAND)
	_draw_green()
	# Base.
	var b := to_map(Vector3.ZERO)
	_canvas.draw_rect(Rect2(b - Vector2(7, 7), Vector2(14, 14)), Color(0.8, 0.15, 0.1))
	_canvas.draw_string(font, b + Vector2(10, 5), "Base", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	_draw_water()
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
	# Oases you've found (v1.18): blue, a purple dot while a nest stands, a ring once claimed.
	if main.oases:
		var scale: float = map_scale()
		for i in main.oases.list.size():
			var o: Dictionary = main.oases.list[i]
			if not o.found:
				continue
			var op := to_map(o.pos)
			_canvas.draw_circle(op, 6.0, Color(0.2, 0.5, 0.78))
			if main.oases.nest_alive(i):
				_canvas.draw_circle(op + Vector2(8, -7), 4.0, Color(0.45, 0.12, 0.5))
			if o.claimed:
				_canvas.draw_arc(to_map(o.post_pos), main.oases.OUTPOST_R * scale, 0.0, TAU, 32, Color(0.8, 0.15, 0.1, 0.7), 1.5)
			_canvas.draw_string(font, op + Vector2(10, 14), ("Outpost %d" % (i + 1)) if o.claimed else "Oasis", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	# During a wave: the mutants coming (the radio picks them up), and a ring
	# for the build zone.
	_canvas.draw_arc(b, main.building.zone_radius * map_scale(), 0.0, TAU, 48, Color(0.8, 0.15, 0.1, 0.5), 1.5)
	if main.waves and main.waves.active:
		for m in main.waves.hunters():
			_canvas.draw_circle(to_map(m.global_position), {"brute": 6.0, "behemoth": 8.0}.get(m.type, 4.0), Color(0.85, 0.1, 0.05))
	# Zoomed in: cover what spills past the edge with the rim and a dark frame.
	if zoom > 1.0:
		var far := _canvas.size.length()
		_canvas.draw_arc(c, RADIUS_PX + 8.0, 0.0, TAU, 96, MOUNTAIN, 16.0)
		_canvas.draw_arc(c, RADIUS_PX + 16.0 + far * 0.5, 0.0, TAU, 96, FRAME, far + 2.0)
	_canvas.draw_string(font, c + Vector2(-8, -RADIUS_PX - 22), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.85))
	# Player arrow.
	var pp := to_map(main.player.global_position)
	if pp.distance_to(c) > RADIUS_PX:  # zoomed in and you're off the edge: on the rim
		pp = c + (pp - c).normalized() * RADIUS_PX
	var fwd3: Vector3 = -main.player.global_transform.basis.z
	var f := Vector2(fwd3.x, fwd3.z).normalized()
	var s := Vector2(-f.y, f.x)
	_canvas.draw_colored_polygon(PackedVector2Array([pp + f * 12, pp - f * 7 + s * 7, pp - f * 3, pp - f * 7 - s * 7]), Color(0.1, 0.3, 0.9))
	# Legend.
	var y := 120.0
	for line in ["MAP", "Brown block: wreck", "Grey corner: ruin", "Green dot: still has loot", "Green square: supply crate", "Blue: oasis (purple: nest)", "Red dots: tonight's wave", "Blue arrow: you", "Brown to green: your land", "Blue lines: water pipes", "Blue dots: sprinklers", "Blue squares: purifiers", "  (grey: no water, dark: off)", "Teal ring: dew collector", "Mouse wheel: zoom (x%d)" % int(zoom), "", "J: base status (machines, defences)", "M or Esc closes"]:
		_canvas.draw_string(font, Vector2(30, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 22 if line == "MAP" else 16, Color(1, 0.95, 0.85))
		y += 26.0
	_draw_livable(font)


## Soil and green land (v1.17): one small square for every watered ground square
## (a few hundred at most, only while the map is open).
func _draw_green() -> void:
	var w = main.water
	if w == null:
		return
	var scale: float = map_scale()
	var side: float = maxf(w.CELL * scale, 2.0)
	for c in w.cells:
		var e: Dictionary = w.cells[c]
		if e.total < w.SOIL_NEED:
			continue
		var col := Color(0.55, 0.4, 0.25).lerp(Color(0.25, 0.55, 0.15), float(e.green))
		_canvas.draw_rect(Rect2(to_map(Vector3(c.x * w.CELL, 0, c.y * w.CELL)), Vector2(side, side)), col)


## v2.8.4: the water network (water.map_marks()) and the dew collectors with
## their reach. A few dozen marks at most, only while the map is open.
func _draw_water() -> void:
	var scale: float = map_scale()
	if main.weather:
		for key in main.weather.collectors():
			var rec: Dictionary = main.building.pieces.get(key, {})
			if not is_instance_valid(rec.get("node")):
				continue
			var dp := to_map(rec.node.global_position)
			_canvas.draw_arc(dp, main.weather.DEW_R * scale, 0.0, TAU, 24, DEW, 1.5)
			_canvas.draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -4), dp + Vector2(4, 0), dp + Vector2(0, 4), dp + Vector2(-4, 0)]), DEW)
	var w = main.water
	if w == null:
		return
	var marks: Dictionary = w.map_marks()
	for l in marks.pipes:
		_canvas.draw_line(to_map(l[0]), to_map(l[1]), WET if l[2] else DRY, 2.5 if l[2] else 1.5)
	for e in marks.ends:
		var ep := to_map(e[0])
		var col: Color = {"wet": WET, "dry": DRY, "off": OFF}.get(e[2], DRY)
		if e[1] == "purifier":
			_canvas.draw_rect(Rect2(ep - Vector2(3.5, 3.5), Vector2(7, 7)), col)
		else:
			_canvas.draw_circle(ep, 3.0, col)


## The green % and the livable score with its parts and milestones, on the right.
func _draw_livable(font: Font) -> void:
	var lv = main.livable
	if lv == null:
		return
	_draw_panel(font, "LAND", lv.summary_lines(), 120.0, 362.0)
	if main.goals:
		_draw_panel(font, "GOALS (green %)", main.goals.summary_lines(), 496.0, 220.0)


## A dark box on the right with a title and lines ("[x] name: text" lines ticked).
func _draw_panel(font: Font, title: String, lines: Array, top: float, height: float) -> void:
	var x := _canvas.size.x - 320.0
	var y := top
	var box := Rect2(x - 14.0, y - 30.0, 316.0, height)
	_canvas.draw_rect(box, Color(0.08, 0.05, 0.03, 0.85))
	_canvas.draw_string(font, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.85))
	y += 28.0
	for line in lines:
		var text: String = line
		var col := Color(1, 0.95, 0.85)
		if text.begins_with("[x]"):
			col = Color(0.6, 1.0, 0.5)
		elif text.begins_with("[ ]"):
			col = Color(0.85, 0.8, 0.7)
		if text.begins_with("[") and text.contains(": "):
			var at := text.find(": ")
			_canvas.draw_string(font, Vector2(x, y), text.substr(0, at), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
			y += 20.0
			text = "      " + text.substr(at + 2)
			_canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		else:
			_canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		y += 24.0 if text != "" else 10.0

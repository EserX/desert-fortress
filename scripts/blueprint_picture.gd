extends Control
## A small drawing of a ready-made building for the blueprint menu: its pieces
## (from prefabs.gd) drawn as flat-shaded shapes seen from above at an angle,
## coloured by the material picked. Plain 2D polygons, no 3D viewport, so it
## looks the same with every renderer and costs next to nothing.

const Prefabs = preload("res://scripts/prefabs.gd")
const Building = preload("res://scripts/building.gd")

## Heights in grid squares (one square is Building.CELL metres).
const FOUND := Building.FOUNDATION_H / Building.CELL
const STOREY := Building.WALL_H / Building.CELL
const MARGIN := 6.0
## Wall colour per material: wood, scrap metal, stone, concrete.
const TIER_COLOR := [Color(0.66, 0.47, 0.29), Color(0.56, 0.52, 0.48), Color(0.62, 0.6, 0.55), Color(0.78, 0.77, 0.73)]
const SAND := Color(0.83, 0.7, 0.5)
const DARK := Color(0.12, 0.09, 0.07)
const GLASS := Color(0.55, 0.75, 0.85)
const METAL := Color(0.42, 0.45, 0.48)
const WATER := Color(0.25, 0.5, 0.75)
const LADDER := Color(0.5, 0.35, 0.2)

var prefab := "shelter":
	set(v):
		prefab = v
		_dirty = true
		queue_redraw()
var tier := 0:
	set(v):
		tier = v
		_dirty = true
		queue_redraw()

var _shapes: Array = []
var _dirty := true


## Grid point (x across, y up, z down the map) to the picture plane.
static func project(x: float, y: float, z: float) -> Vector2:
	return Vector2((x - z) * 0.866, (x + z) * 0.5 - y)


static func _height(type: String) -> float:
	match type:
		"half_wall":
			return Building.HALF_H / Building.CELL
		"low_wall":
			return Building.LOW_H / Building.CELL
	return STOREY


static func _level_y(level: int) -> float:
	return FOUND + level * STOREY


## A flat-shaded tile in the picture: `pts` in the picture plane. Drawn in
## order of `band` (foundations, then each storey's walls, then the deck on
## top of them...) and then `depth` (further back first).
static func _shape(pts: PackedVector2Array, color: Color, band: int, depth: float) -> Dictionary:
	return {"pts": pts, "color": color, "band": band, "depth": depth}


## An upright quad along the line (x0, z0)-(x1, z1) from height y0 to y1.
static func _upright(x0: float, z0: float, x1: float, z1: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([project(x0, y0, z0), project(x1, y0, z1), project(x1, y1, z1), project(x0, y1, z0)])


## A flat quad from (x0, z0) to (x1, z1) at height y.
static func _flat(x0: float, z0: float, x1: float, z1: float, y: float) -> PackedVector2Array:
	return PackedVector2Array([project(x0, y, z0), project(x1, y, z0), project(x1, y, z1), project(x0, y, z1)])


## Every shape of building `id` in material `t`, sorted for drawing (back to
## front). Coordinates are in the picture plane, not yet fitted to the box.
## Runs when the menu opens or the material changes: at most about 60 pieces.
static func shapes(id: String, t: int) -> Array:
	var out: Array = []
	var entries := Prefabs.entries(id)
	var wells := {}
	for e in entries:
		if e.type == "well":
			wells[Vector2i(e.cx, e.cz)] = true
	for e in entries:
		var type: String = e.type
		var lt := Building.tier_for(type, t)
		var col: Color = TIER_COLOR[lt]
		var cx := float(e.cx)
		var cz := float(e.cz)
		var lv := int(e.level)
		var y0 := _level_y(lv)
		match str(e.kind):
			"cell":
				if type in Building.FOUNDATIONS:
					var d := cx + cz + 1.0
					out.append(_shape(_flat(cx, cz, cx + 1, cz + 1, FOUND), col.lightened(0.12), 0, d))
					out.append(_shape(_upright(cx, cz + 1, cx + 1, cz + 1, 0.0, FOUND), col.darkened(0.25), 0, d + 0.01))
					out.append(_shape(_upright(cx + 1, cz, cx + 1, cz + 1, 0.0, FOUND), col.darkened(0.4), 0, d + 0.01))
				else:
					var top := y0 + (0.0 if lv > 0 else FOUND)
					var c := col.lightened(0.2) if type in ["roof", "tri_roof"] else col.lightened(0.05)
					out.append(_shape(_flat(cx, cz, cx + 1, cz + 1, top), c, 2 * lv, cx + cz + 1.0))
					if wells.has(Vector2i(e.cx, e.cz)):
						# The walls hide a well under a roof: mark it on top instead.
						out.append(_shape(_ring(cx + 0.5, cz + 0.5, 0.3, top), WATER, 2 * lv, cx + cz + 1.01))
					if type == "trapdoor":
						out.append(_shape(_flat(cx + 0.25, cz + 0.05, cx + 0.75, cz + 0.5, top), col.darkened(0.45), 2 * lv, cx + cz + 1.01))
			"edge":
				var x1 := cx + (1.0 if int(e.dir) == 0 else 0.0)
				var z1 := cz + (0.0 if int(e.dir) == 0 else 1.0)
				var h := _height(type)
				var d := (cx + x1) * 0.5 + (cz + z1) * 0.5
				var face := col.darkened(0.12) if int(e.dir) == 0 else col.darkened(0.3)
				if type == "metal_door":
					face = METAL
				var band := 2 * lv + 1
				out.append(_shape(_upright(cx, cz, x1, z1, y0, y0 + h), face, band, d))
				# Openings, as darker or glassy patches on the wall.
				var a := 0.5 - Building.DOOR_W / Building.CELL * 0.5
				var b := 1.0 - a
				var px := func(f: float) -> float: return cx + (x1 - cx) * f
				var pz := func(f: float) -> float: return cz + (z1 - cz) * f
				match type:
					"doorway":
						out.append(_shape(_upright(px.call(a), pz.call(a), px.call(b), pz.call(b), y0, y0 + Building.DOOR_H / Building.CELL), DARK, band, d + 0.01))
					"metal_door":
						out.append(_shape(_upright(px.call(a), pz.call(a), px.call(b), pz.call(b), y0, y0 + Building.DOOR_H / Building.CELL), METAL.lightened(0.15), band, d + 0.01))
					"window", "glass_window":
						out.append(_shape(_upright(px.call(0.3), pz.call(0.3), px.call(0.7), pz.call(0.7), y0 + 0.45, y0 + 0.85), GLASS, band, d + 0.01))
					"slit_wall":
						var sy := y0 + Building.SLIT_Y / Building.CELL
						var sw := Building.SLIT_W / Building.CELL * 0.5
						out.append(_shape(_upright(px.call(0.5 - sw), pz.call(0.5 - sw), px.call(0.5 + sw), pz.call(0.5 + sw), sy, sy + 0.12), DARK, band, d + 0.01))
			"post":
				var r := Building.PILLAR_T / Building.CELL * 0.5
				out.append(_shape(_upright(cx - r, cz + r, cx + r, cz - r, y0, y0 + STOREY), col.darkened(0.2), 2 * lv + 1, cx + cz + 0.02))
			"obj":
				if type == "well":
					out.append(_shape(_ring(cx + 0.5, cz + 0.5, 0.42, 0.12), Color(0.6, 0.58, 0.54), 0, cx + cz + 1.02))
					out.append(_shape(_ring(cx + 0.5, cz + 0.5, 0.3, 0.13), WATER, 0, cx + cz + 1.03))
				elif type == "ladder":
					var top := y0 + Building.LADDER_H / Building.CELL
					out.append(_shape(_upright(cx + 0.35, cz + 0.2, cx + 0.65, cz + 0.2, y0 + FOUND, top), LADDER, 2 * lv + 1, cx + cz + 0.45))
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		if p.band != q.band:
			return p.band < q.band
		return p.depth < q.depth)
	return out


## A flat round patch (12-sided) at height y.
static func _ring(x: float, z: float, r: float, y: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(project(x + cos(a) * r, y, z + sin(a) * r))
	return pts


## The shapes moved and scaled to fit a box of `box` pixels, keeping the
## proportions and leaving MARGIN round the edge.
static func fit(list: Array, box: Vector2) -> Array:
	if list.is_empty():
		return []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in list:
		for p in s.pts:
			lo = lo.min(p)
			hi = hi.max(p)
	var size := (hi - lo).max(Vector2(0.01, 0.01))
	var room := (box - Vector2(MARGIN, MARGIN) * 2.0).max(Vector2.ONE)
	var k := minf(room.x / size.x, room.y / size.y)
	var off := (box - size * k) * 0.5 - lo * k
	var out: Array = []
	for s in list:
		var pts := PackedVector2Array()
		for p in s.pts:
			pts.append(p * k + off)
		out.append({"pts": pts, "color": s.color})
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_dirty = true
		queue_redraw()


func _draw() -> void:
	if _dirty:
		_shapes = fit(shapes(prefab, tier), size)
		_dirty = false
	draw_rect(Rect2(Vector2.ZERO, size), SAND.darkened(0.55))
	for s in _shapes:
		draw_colored_polygon(s.pts, s.color)
		var line: PackedVector2Array = s.pts.duplicate()
		line.append(s.pts[0])
		draw_polyline(line, Color(0, 0, 0, 0.35 * s.color.a), 1.0)

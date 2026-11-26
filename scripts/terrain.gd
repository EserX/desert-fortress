extends StaticBody3D
## Procedural low-poly desert: rolling dunes, a flat clearing in the middle
## (the future fortress site) and a ring of mountains closing off the map.
## Around the base the ground is a finer 1 m grid in chunks that can be dug
## out and filled in (the shovel). Changes are kept as height deltas.

## The ground changed in this world-space rectangle (x, z).
signal ground_changed(area: Rect2)

const SIZE := 512.0          # world is SIZE x SIZE metres, centred on the origin
const CELLS := 128           # grid resolution (4 m per cell -> chunky facets)
const BASE_RADIUS := 28.0    # flat clearing for the fortress
const BASE_HEIGHT := 2.0
const PLAY_RADIUS := 225.0   # player cannot walk beyond this

const SAND_LOW := Color(0.74, 0.50, 0.30)
const SAND_HIGH := Color(0.88, 0.68, 0.45)
const ROCK := Color(0.55, 0.36, 0.25)
const ROCK_HIGH := Color(0.68, 0.50, 0.36)
const DAMP_SAND := Color(0.50, 0.32, 0.19)
const BEDROCK_COL := Color(0.42, 0.36, 0.33)
const CLAY_COL := Color(0.58, 0.30, 0.19)
const STONE_COL := Color(0.46, 0.43, 0.40)
## Layers under the sand: clay from SAND_DEPTH down, solid stone from CLAY_DEPTH
## (only a pickaxe gets through it) down to bedrock.
const SAND_DEPTH := 1.5
const CLAY_DEPTH := 2.75

## Diggable ground: a square of 1 m cells from -DIG_HALF to +DIG_HALF on x and z.
const DIG_HALF := 48.0
const DIG_CELLS := 96
const CHUNK := 16             # cells per chunk side
const DIG_STEP := 0.25        # metres a dig lowers (or a fill raises) a cell
const BEDROCK := 4.0          # you can't dig deeper than this below the original ground
const MAX_RAISE := 2.0        # nor pile sand higher than this above it

var dunes := FastNoiseLite.new()
var ripples := FastNoiseLite.new()
var crags := FastNoiseLite.new()
var heights := PackedFloat32Array()  # grid heights, (CELLS + 1)^2, row-major by z
## Fine grid around the base: original heights and how far each vertex was moved,
## (DIG_CELLS + 1)^2, row-major by z.
var fine_base := PackedFloat32Array()
var delta := PackedFloat32Array()
## Places nothing may dig: [Vector2 centre, radius] (props, the flag, the shop...).
var no_dig: Array = []
var _chunks := {}  # Vector2i -> {"mesh": MeshInstance3D, "col": CollisionShape3D}
var _mat: StandardMaterial3D
var _seed := 0


## Exact height of the rendered/collision surface at world (x, z), matching the
## triangles of the mesh. Use this to stand things on the ground.
func surface_height(x: float, z: float) -> float:
	if not delta.is_empty():
		var fx := x + DIG_HALF
		var fz := z + DIG_HALF
		if fx >= 0.0 and fz >= 0.0 and fx < DIG_CELLS and fz < DIG_CELLS:
			return _fine_height(fx, fz)
	return _coarse_height(x, z)


## Height of the coarse (4 m) grid surface.
func _coarse_height(x: float, z: float) -> float:
	var step := SIZE / CELLS
	var gx := (x + SIZE * 0.5) / step
	var gz := (z + SIZE * 0.5) / step
	if heights.is_empty() or gx < 0.0 or gz < 0.0 or gx >= CELLS or gz >= CELLS:
		return height_at(x, z)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var n := CELLS + 1
	var h00 := heights[iz * n + ix]
	var h10 := heights[iz * n + ix + 1]
	var h01 := heights[(iz + 1) * n + ix]
	var h11 := heights[(iz + 1) * n + ix + 1]
	if (ix + iz) % 2 == 0:
		# Diagonal p00 -> p11.
		if fx >= fz:
			return h00 + fx * (h10 - h00) + fz * (h11 - h10)
		return h00 + fz * (h01 - h00) + fx * (h11 - h01)
	# Diagonal p10 -> p01.
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)


## Height on the fine grid at grid coordinates (metres from its corner).
func _fine_height(gx: float, gz: float) -> float:
	var ix := mini(int(gx), DIG_CELLS - 1)
	var iz := mini(int(gz), DIG_CELLS - 1)
	return _tri_height(vertex_height(ix, iz), vertex_height(ix + 1, iz), vertex_height(ix, iz + 1),
		vertex_height(ix + 1, iz + 1), gx - ix, gz - iz, (ix + iz) % 2 == 0)


## Height inside one grid square from its corners, split along the same diagonal as the mesh.
static func _tri_height(h00: float, h10: float, h01: float, h11: float, fx: float, fz: float, diag00: bool) -> float:
	if diag00:
		if fx >= fz:
			return h00 + fx * (h10 - h00) + fz * (h11 - h10)
		return h00 + fz * (h01 - h00) + fx * (h11 - h01)
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)


## Lowest surface point under a footprint of the given radius (for big props).
func ground_under(x: float, z: float, radius: float) -> float:
	var h := surface_height(x, z)
	for o in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		h = minf(h, surface_height(x + o.x, z + o.y))
	return h


func setup_noise(seed_value: int) -> void:
	dunes.seed = seed_value
	dunes.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	dunes.frequency = 0.0055
	dunes.fractal_octaves = 3
	ripples.seed = seed_value + 1
	ripples.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ripples.frequency = 0.045
	ripples.fractal_octaves = 1
	crags.seed = seed_value + 2
	crags.noise_type = FastNoiseLite.TYPE_CELLULAR
	crags.frequency = 0.02


## Smooth analytic height of the terrain at world (x, z).
func height_at(x: float, z: float) -> float:
	var d := dunes.get_noise_2d(x, z) * 0.5 + 0.5
	var h := d * d * 16.0 + ripples.get_noise_2d(x, z) * 0.8
	var r := Vector2(x, z).length()
	# Mountain ring at the edge of the map.
	var edge := smoothstep(SIZE * 0.36, SIZE * 0.5, r)
	h += edge * (40.0 + crags.get_noise_2d(x, z) * 18.0)
	# Flatten the centre for the base.
	var flat := smoothstep(BASE_RADIUS, BASE_RADIUS + 35.0, r)
	return lerpf(BASE_HEIGHT, h, flat)


func generate(seed_value: int) -> void:
	setup_noise(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var step := SIZE / CELLS
	var half := SIZE * 0.5
	var n := CELLS + 1
	heights.resize(n * n)
	for iz in n:
		for ix in n:
			heights[iz * n + ix] = height_at(ix * step - half, iz * step - half)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in CELLS:
		for ix in CELLS:
			var x0 := ix * step - half
			var z0 := iz * step - half
			if x0 >= -DIG_HALF and x0 + step <= DIG_HALF and z0 >= -DIG_HALF and z0 + step <= DIG_HALF:
				continue  # the fine diggable grid covers this square
			var p00 := Vector3(x0, heights[iz * n + ix], z0)
			var p10 := Vector3(x0 + step, heights[iz * n + ix + 1], z0)
			var p01 := Vector3(x0, heights[(iz + 1) * n + ix], z0 + step)
			var p11 := Vector3(x0 + step, heights[(iz + 1) * n + ix + 1], z0 + step)
			# Alternate the diagonal for a less regular faceted look.
			if (ix + iz) % 2 == 0:
				_tri(st, p00, p10, p11, rng)
				_tri(st, p00, p11, p01, rng)
			else:
				_tri(st, p00, p10, p01, rng)
				_tri(st, p10, p11, p01, rng)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.metallic_specular = 0.15
	st.set_material(mat)
	var mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	add_child(mi)

	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	add_child(col)
	_mat = mat
	_seed = seed_value
	_setup_fine()


# --- Diggable ground ------------------------------------------------------------

## Samples the coarse surface onto the fine grid and builds every chunk.
func _setup_fine() -> void:
	var n := DIG_CELLS + 1
	fine_base.resize(n * n)
	for iz in n:
		for ix in n:
			fine_base[iz * n + ix] = _coarse_height(ix - DIG_HALF, iz - DIG_HALF)
	delta = PackedFloat32Array()
	delta.resize(n * n)
	delta.fill(0.0)
	var per := DIG_CELLS / CHUNK
	for cz in per:
		for cx in per:
			var mi := MeshInstance3D.new()
			mi.name = "Ground_%d_%d" % [cx, cz]
			add_child(mi)
			var col := CollisionShape3D.new()
			col.shape = ConcavePolygonShape3D.new()
			add_child(col)
			_chunks[Vector2i(cx, cz)] = {"mesh": mi, "col": col}
			_rebuild_chunk(Vector2i(cx, cz))


## Current height of fine grid vertex (ix, iz).
func vertex_height(ix: int, iz: int) -> float:
	var i := iz * (DIG_CELLS + 1) + ix
	return fine_base[i] + delta[i]


## How far vertex (ix, iz) was dug (negative) or raised from the original ground.
func vertex_delta(ix: int, iz: int) -> float:
	return delta[iz * (DIG_CELLS + 1) + ix]


## The 1 m cell under world (x, z), or (-1, -1) outside the diggable ground.
func dig_cell(x: float, z: float) -> Vector2i:
	var gx := floori(x + DIG_HALF)
	var gz := floori(z + DIG_HALF)
	if gx < 0 or gz < 0 or gx >= DIG_CELLS or gz >= DIG_CELLS:
		return Vector2i(-1, -1)
	return Vector2i(gx, gz)


## World (x, z) of a cell's centre.
static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x - DIG_HALF + 0.5, c.y - DIG_HALF + 0.5)


## The four corner heights of a cell: [x0z0, x1z0, x0z1, x1z1].
func cell_corners(c: Vector2i) -> Array:
	return [vertex_height(c.x, c.y), vertex_height(c.x + 1, c.y), vertex_height(c.x, c.y + 1), vertex_height(c.x + 1, c.y + 1)]


## How deep a cell is dug on average (positive = below the original ground).
func cell_depth(c: Vector2i) -> float:
	return -(vertex_delta(c.x, c.y) + vertex_delta(c.x + 1, c.y) + vertex_delta(c.x, c.y + 1) + vertex_delta(c.x + 1, c.y + 1)) * 0.25


## Why the shovel can't work at world (x, z), or "" if it can.
func dig_blocked(x: float, z: float) -> String:
	if dig_cell(x, z).x < 0:
		return "The ground is too hard out here (dig near the base)"
	var c := cell_center(dig_cell(x, z))
	for nd in no_dig:
		if c.distance_to(nd[0]) < nd[1]:
			return "Something is in the way"
	return ""


## Keeps the shovel away from something standing on the sand.
func add_no_dig(pos: Vector3, radius: float) -> void:
	if absf(pos.x) < DIG_HALF + radius and absf(pos.z) < DIG_HALF + radius:
		no_dig.append([Vector2(pos.x, pos.z), radius])


## Digs the cell at world (x, z): its highest corner comes down DIG_STEP and the
## others down to it (so a row of digs makes a level trench), never below bedrock.
## Returns true if any ground moved.
func dig(x: float, z: float) -> bool:
	if dig_blocked(x, z) != "":
		return false
	var c := dig_cell(x, z)
	var target: float = cell_corners(c).max() - DIG_STEP
	return _shape_cell(c, func(base: float, d: float) -> float: return maxf(minf(base + d, target) - base, -BEDROCK))


## Fills the cell at world (x, z): its lowest corner goes up DIG_STEP and the
## others up to it, never more than MAX_RAISE above the original ground.
func fill(x: float, z: float) -> bool:
	if dig_blocked(x, z) != "":
		return false
	var c := dig_cell(x, z)
	var target: float = cell_corners(c).min() + DIG_STEP
	return _shape_cell(c, func(base: float, d: float) -> float: return minf(maxf(base + d, target) - base, MAX_RAISE))


## How deep the ground is dug at world (x, z), at the nearest grid corner (0 outside).
func depth_at(x: float, z: float) -> float:
	var ix := roundi(x + DIG_HALF)
	var iz := roundi(z + DIG_HALF)
	if ix < 0 or iz < 0 or ix > DIG_CELLS or iz > DIG_CELLS:
		return 0.0
	return -vertex_delta(ix, iz)


## Raises every grid corner inside area (x, z, edges included) that is lower than
## height h up to h (foundations do this). Returns true if anything moved.
func raise_area(area: Rect2, h: float) -> bool:
	var n := DIG_CELLS + 1
	var moved := false
	var cells: Array = []
	for iz in range(maxi(ceili(area.position.y + DIG_HALF), 0), mini(floori(area.end.y + DIG_HALF), DIG_CELLS) + 1):
		for ix in range(maxi(ceili(area.position.x + DIG_HALF), 0), mini(floori(area.end.x + DIG_HALF), DIG_CELLS) + 1):
			var i := iz * n + ix
			var d := minf(h - fine_base[i], MAX_RAISE)
			if d > delta[i] + 0.0005:
				delta[i] = d
				moved = true
				cells.append(Vector2i(mini(ix, DIG_CELLS - 1), mini(iz, DIG_CELLS - 1)))
	if not moved:
		return false
	var done := {}
	for c in cells:
		var k := Vector2i(c.x / CHUNK, c.y / CHUNK)
		if not done.has(k):
			done[k] = true
			_rebuild_around(c)
	ground_changed.emit(area.grow(1.0))
	return true


## What a dig at world (x, z) brings up next: "sand", "clay" or "stone" ("" at bedrock).
func next_layer(x: float, z: float) -> String:
	var c := dig_cell(x, z)
	if c.x < 0 or at_bedrock(x, z):
		return ""
	return layer_at(cell_dug_max(c) + DIG_STEP * 0.5)


## The layer at a depth below the original ground.
static func layer_at(depth: float) -> String:
	if depth > CLAY_DEPTH:
		return "stone"
	if depth > SAND_DEPTH:
		return "clay"
	return "sand"


## How deep the least dug corner of a cell is (a dig takes that corner down next).
func cell_dug_max(c: Vector2i) -> float:
	return -maxf(maxf(vertex_delta(c.x, c.y), vertex_delta(c.x + 1, c.y)), maxf(vertex_delta(c.x, c.y + 1), vertex_delta(c.x + 1, c.y + 1)))


## True if the cell can't go any deeper.
func at_bedrock(x: float, z: float) -> bool:
	var c := dig_cell(x, z)
	if c.x < 0:
		return false
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if vertex_delta(c.x + o.x, c.y + o.y) > -BEDROCK + 0.001:
			return false
	return true


## Applies new_delta(base, delta) to a cell's corners, rebuilds what changed.
func _shape_cell(c: Vector2i, new_delta: Callable) -> bool:
	var n := DIG_CELLS + 1
	var moved := false
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var i: int = (c.y + o.y) * n + c.x + o.x
		var d: float = new_delta.call(fine_base[i], delta[i])
		if absf(d - delta[i]) > 0.0005:
			delta[i] = d
			moved = true
	if not moved:
		return false
	_rebuild_around(c)
	ground_changed.emit(Rect2(c.x - DIG_HALF - 1.0, c.y - DIG_HALF - 1.0, 3.0, 3.0))
	return true


## Rebuilds the chunks a cell's corners touch (corners on a chunk edge are shared).
func _rebuild_around(c: Vector2i) -> void:
	var done := {}
	var last := DIG_CELLS / CHUNK - 1
	for oz in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			var k := Vector2i(clampi((c.x + ox) / CHUNK, 0, last), clampi((c.y + oz) / CHUNK, 0, last))
			if not done.has(k):
				done[k] = true
				_rebuild_chunk(k)


## Mesh and collision for one chunk of the fine grid.
func _rebuild_chunk(k: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(k.x, k.y, _seed))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for iz in range(k.y * CHUNK, (k.y + 1) * CHUNK):
		for ix in range(k.x * CHUNK, (k.x + 1) * CHUNK):
			var x0 := ix - DIG_HALF
			var z0 := iz - DIG_HALF
			var p00 := Vector3(x0, vertex_height(ix, iz), z0)
			var p10 := Vector3(x0 + 1.0, vertex_height(ix + 1, iz), z0)
			var p01 := Vector3(x0, vertex_height(ix, iz + 1), z0 + 1.0)
			var p11 := Vector3(x0 + 1.0, vertex_height(ix + 1, iz + 1), z0 + 1.0)
			var dug := (vertex_delta(ix, iz) + vertex_delta(ix + 1, iz) + vertex_delta(ix, iz + 1) + vertex_delta(ix + 1, iz + 1)) * 0.25
			var tris: Array = [[p00, p10, p11], [p00, p11, p01]] if (ix + iz) % 2 == 0 else [[p00, p10, p01], [p10, p11, p01]]
			for t in tris:
				var a: Vector3 = t[0]
				var b: Vector3 = t[1]
				var cc: Vector3 = t[2]
				var nrm := (cc - a).cross(b - a)
				if nrm.y < 0.0:
					var tmp := b
					b = cc
					cc = tmp
					nrm = -nrm
				nrm = nrm.normalized()
				var col := _color_for(a, b, cc, nrm, rng)
				if dug < -0.02:
					var layer_col: Color = DAMP_SAND
					if -dug > CLAY_DEPTH:
						layer_col = STONE_COL.lerp(BEDROCK_COL, clampf((-dug - CLAY_DEPTH) / (BEDROCK - CLAY_DEPTH), 0.0, 1.0))
					elif -dug > SAND_DEPTH:
						layer_col = CLAY_COL
					col = col.lerp(layer_col, clampf(-dug / 0.5, 0.3, 1.0)).darkened(0.12 * (1.0 - nrm.y) + 0.06)
				elif dug > 0.02:
					col = col.lightened(0.06)
				for v in [a, b, cc]:
					verts.append(v)
					normals.append(nrm)
					colors.append(col)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _mat)
	var ch: Dictionary = _chunks[k]
	ch.mesh.mesh = mesh
	ch.col.shape.set_faces(verts)


## Dug and filled ground for a save: [ix, iz, delta, ...] for every moved vertex.
func save_data() -> Dictionary:
	var out: Array = []
	var n := DIG_CELLS + 1
	for i in delta.size():
		if absf(delta[i]) > 0.0005:
			out.append_array([i % n, i / n, snappedf(delta[i], 0.001)])
	return {"deltas": out}


## Restores dug ground. Anything missing (older saves) is untouched, flat ground.
## Doesn't emit ground_changed: what stands on it is loaded as saved.
func load_data(data: Dictionary) -> void:
	delta.fill(0.0)
	var d: Array = data.get("deltas", [])
	var n := DIG_CELLS + 1
	for j in range(0, d.size() - 2, 3):
		var ix := int(d[j])
		var iz := int(d[j + 1])
		if ix >= 0 and iz >= 0 and ix < n and iz < n:
			delta[iz * n + ix] = clampf(float(d[j + 2]), -BEDROCK, MAX_RAISE)
	for k in _chunks:
		_rebuild_chunk(k)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, rng: RandomNumberGenerator) -> void:
	# Godot treats clockwise (seen from the front) as the front face; its
	# face normal is (c - a) x (b - a). Make sure every triangle faces up.
	var n := (c - a).cross(b - a)
	if n.y < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = n.normalized()
	st.set_normal(n)
	st.set_color(_color_for(a, b, c, n, rng))
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _color_for(a: Vector3, b: Vector3, c: Vector3, n: Vector3, rng: RandomNumberGenerator) -> Color:
	var h := (a.y + b.y + c.y) / 3.0
	var slope := 1.0 - n.y  # 0 = flat, larger = steeper
	var sand := SAND_LOW.lerp(SAND_HIGH, clampf(h / 16.0, 0.0, 1.0))
	var rock := ROCK.lerp(ROCK_HIGH, clampf((h - 20.0) / 40.0, 0.0, 1.0))
	var rockiness := clampf((slope - 0.08) * 6.0, 0.0, 1.0) * clampf(h / 10.0, 0.0, 1.0)
	var col := sand.lerp(rock, rockiness)
	var j := rng.randf_range(-0.035, 0.035)
	return Color(col.r + j, col.g + j * 0.9, col.b + j * 0.7)

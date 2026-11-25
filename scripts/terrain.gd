extends StaticBody3D
## Procedural low-poly desert: rolling dunes, a flat clearing in the middle
## (the future fortress site) and a ring of mountains closing off the map.

const SIZE := 512.0          # world is SIZE x SIZE metres, centred on the origin
const CELLS := 128           # grid resolution (4 m per cell -> chunky facets)
const BASE_RADIUS := 28.0    # flat clearing for the fortress
const BASE_HEIGHT := 2.0
const PLAY_RADIUS := 225.0   # player cannot walk beyond this

const SAND_LOW := Color(0.74, 0.50, 0.30)
const SAND_HIGH := Color(0.88, 0.68, 0.45)
const ROCK := Color(0.55, 0.36, 0.25)
const ROCK_HIGH := Color(0.68, 0.50, 0.36)

var dunes := FastNoiseLite.new()
var ripples := FastNoiseLite.new()
var crags := FastNoiseLite.new()


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
	var heights := PackedFloat32Array()
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

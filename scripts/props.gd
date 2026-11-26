extends Node3D
## Scatters desert props: rocks, cacti, dry shrubs, rusted car wrecks and
## ruined concrete walls. Wrecks (glovebox, trunk) and ruins (crates) can be searched.

const LowPoly = preload("res://scripts/lowpoly.gd")
const Terrain = preload("res://scripts/terrain.gd")
const LootContainer = preload("res://scripts/loot_container.gd")

var rng := RandomNumberGenerator.new()
## Separate stream for loot spots so adding them doesn't move the other props.
var loot_rng := RandomNumberGenerator.new()
var terrain: Terrain

# Shared meshes/materials (built once).
var rock_mesh: Mesh
var trunk_mesh: Mesh
var arm_mesh: Mesh
var rock_mats: Array[StandardMaterial3D] = []
var cactus_mat: StandardMaterial3D
var rust_mats: Array[StandardMaterial3D] = []
var concrete_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D
var cloth_mat: StandardMaterial3D

## Spots other systems may want later (loot, mutant spawns...).
var wreck_positions: Array[Vector3] = []
var ruin_positions: Array[Vector3] = []
## Every searchable spot (LootContainer), in a stable order.
var containers: Array = []
var _box := BoxMesh.new()
var _dark_mat: StandardMaterial3D


func populate(terrain_node: Terrain, seed_value: int) -> void:
	terrain = terrain_node
	rng.seed = seed_value * 7 + 3
	loot_rng.seed = seed_value * 13 + 5
	_build_shared()
	_place_base_marker()
	for i in 260:
		_place_rock()
	for i in 140:
		_place_cactus()
	_place_shrubs(500)
	for i in 14:
		_place_wreck()
	for i in 9:
		_place_ruin()


func _build_shared() -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 7
	sphere.rings = 4
	rock_mesh = LowPoly.flat(sphere)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.3
	trunk.height = 3.0
	trunk.radial_segments = 6
	trunk.rings = 1
	trunk_mesh = LowPoly.flat(trunk)
	var arm := CylinderMesh.new()
	arm.top_radius = 0.15
	arm.bottom_radius = 0.18
	arm.height = 1.2
	arm.radial_segments = 6
	arm.rings = 1
	arm_mesh = LowPoly.flat(arm)
	for c in [Color(0.52, 0.40, 0.31), Color(0.60, 0.47, 0.36), Color(0.45, 0.33, 0.26)]:
		rock_mats.append(LowPoly.material(c))
	cactus_mat = LowPoly.material(Color(0.36, 0.52, 0.27))
	for c in [Color(0.48, 0.24, 0.12), Color(0.38, 0.22, 0.14), Color(0.55, 0.33, 0.18)]:
		rust_mats.append(LowPoly.material(c, 0.8))
	concrete_mat = LowPoly.material(Color(0.60, 0.56, 0.50))
	wood_mat = LowPoly.material(Color(0.45, 0.31, 0.19))
	cloth_mat = LowPoly.material(Color(0.75, 0.18, 0.12))
	_dark_mat = LowPoly.material(Color(0.08, 0.07, 0.06))


## Random point on the dunes, outside the base clearing and inside the mountains.
func _random_spot(min_r := 40.0, max_r := 210.0) -> Vector3:
	var ang := rng.randf() * TAU
	var r := sqrt(rng.randf_range(min_r * min_r, max_r * max_r))  # even spread
	var x := cos(ang) * r
	var z := sin(ang) * r
	return Vector3(x, terrain.surface_height(x, z), z)


func _body_at(pos: Vector3, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	return body


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _box_collider(parent: Node3D, size: Vector3, pos := Vector3.ZERO, rot := Vector3.ZERO) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	col.rotation = rot
	parent.add_child(col)


func _place_rock() -> void:
	var p := _random_spot()
	var s := rng.randf_range(0.5, 2.6)
	if rng.randf() < 0.08:
		s *= 2.2  # the odd boulder
	var scl := Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.4))
	var body := _body_at(p - Vector3(0, s * 0.25, 0), rng.randf() * TAU)
	_mesh(body, rock_mesh, rock_mats[rng.randi() % rock_mats.size()], Vector3.ZERO, scl,
		Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = min(scl.x, scl.y, scl.z) * 0.5
	col.shape = shape
	body.add_child(col)


func _place_cactus() -> void:
	var p := _random_spot(35.0, 205.0)
	var s := rng.randf_range(0.7, 1.4)
	var body := _body_at(p - Vector3(0, 0.1, 0), rng.randf() * TAU)
	body.scale = Vector3.ONE * s
	_mesh(body, trunk_mesh, cactus_mat, Vector3(0, 1.5, 0))
	var arms := rng.randi_range(0, 2)
	for i in arms:
		var side := -1.0 if i == 0 else 1.0
		var y := rng.randf_range(1.1, 1.9)
		# horizontal stub then vertical arm
		_mesh(body, arm_mesh, cactus_mat, Vector3(side * 0.45, y, 0), Vector3(1, 0.55, 1), Vector3(0, 0, PI / 2))
		_mesh(body, arm_mesh, cactus_mat, Vector3(side * 0.78, y + 0.5, 0))
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 3.0
	col.shape = shape
	col.position.y = 1.5
	body.add_child(col)


func _place_shrubs(count: int) -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 5
	sphere.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = LowPoly.flat(sphere)
	mm.instance_count = count
	for i in count:
		var p := _random_spot(32.0, 215.0)
		var s := rng.randf_range(0.25, 0.7)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.3, s * 0.6, s * 1.3))
		mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, s * 0.1, 0)))
		var t := rng.randf()
		mm.set_instance_color(i, Color(0.50, 0.45, 0.25).lerp(Color(0.62, 0.52, 0.30), t))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Shrubs"
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mmi.material_override = mat
	add_child(mmi)


func _place_wreck() -> void:
	var p := _random_spot(55.0, 200.0)
	wreck_positions.append(p)
	var yaw := rng.randf() * TAU
	# Follow the slope of the dune: sample ground at the bumpers and the sides.
	var fwd := Vector3(cos(yaw), 0, -sin(yaw))  # local +X after yaw
	var side := Vector3(sin(yaw), 0, cos(yaw))  # local +Z after yaw
	var hf := terrain.surface_height(p.x + fwd.x * 2.0, p.z + fwd.z * 2.0)
	var hb := terrain.surface_height(p.x - fwd.x * 2.0, p.z - fwd.z * 2.0)
	var hl := terrain.surface_height(p.x + side.x, p.z + side.z)
	var hr := terrain.surface_height(p.x - side.x, p.z - side.z)
	var body := _body_at(Vector3(p.x, (hf + hb + hl + hr) * 0.25 - 0.12, p.z), yaw)
	body.rotation.z = atan2(hf - hb, 4.0) + rng.randf_range(-0.04, 0.04)
	body.rotation.x = -atan2(hl - hr, 2.0) + rng.randf_range(-0.04, 0.04)

	var box := BoxMesh.new()
	var paint := rust_mats[rng.randi() % rust_mats.size()]
	var dark := LowPoly.material(Color(0.10, 0.09, 0.09), 0.6)
	var rust := LowPoly.material(Color(0.35, 0.17, 0.08))
	# Body, cabin with a dark window band, bumpers.
	_mesh(body, box, paint, Vector3(0, 0.78, 0), Vector3(4.4, 0.62, 1.9))
	_mesh(body, box, paint, Vector3(-0.35, 1.42, 0), Vector3(2.1, 0.7, 1.75))
	_mesh(body, box, dark, Vector3(-0.35, 1.45, 0), Vector3(2.16, 0.42, 1.8))
	_mesh(body, box, dark, Vector3(2.22, 0.62, 0), Vector3(0.12, 0.22, 1.95))
	_mesh(body, box, dark, Vector3(-2.22, 0.62, 0), Vector3(0.12, 0.22, 1.95))
	# Rust patches.
	for i in rng.randi_range(2, 4):
		var sz := Vector3(rng.randf_range(0.4, 1.0), 0.05, rng.randf_range(0.3, 0.8))
		_mesh(body, box, rust, Vector3(rng.randf_range(-1.8, 1.8), 1.1, rng.randf_range(-0.6, 0.6)), sz)
	# Wheels, one missing.
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.42
	wheel.bottom_radius = 0.42
	wheel.height = 0.32
	wheel.radial_segments = 8
	wheel.rings = 1
	var wheel_mesh := LowPoly.flat(wheel)
	var spots := [Vector3(1.4, 0.42, 0.92), Vector3(-1.4, 0.42, 0.92), Vector3(1.4, 0.42, -0.92), Vector3(-1.4, 0.42, -0.92)]
	spots.remove_at(rng.randi() % spots.size())
	for w in spots:
		_mesh(body, wheel_mesh, dark, w, Vector3.ONE, Vector3(PI / 2, 0, 0))
	_box_collider(body, Vector3(4.4, 1.0, 1.9), Vector3(0, 0.6, 0))
	_box_collider(body, Vector3(2.1, 0.7, 1.75), Vector3(-0.35, 1.42, 0))
	_add_wreck_loot(body, paint, wreck_positions.size() - 1)


## Glovebox (reached from either front door) and a trunk with a lid that opens.
func _add_wreck_loot(body: Node3D, paint: Material, index: int) -> void:
	var glove := LootContainer.new()
	glove.container_id = "wreck%d_glovebox" % index
	glove.kind = "glovebox"
	glove.label = "glovebox"
	glove.search_time = 0.8
	glove.add_box(Vector3(0.8, 0.7, 2.1), Vector3(0.4, 1.35, 0))
	body.add_child(glove)
	containers.append(glove)

	var trunk := LootContainer.new()
	trunk.container_id = "wreck%d_trunk" % index
	trunk.kind = "trunk"
	trunk.label = "trunk"
	trunk.search_time = 1.2
	trunk.add_box(Vector3(1.1, 0.5, 2.1), Vector3(-1.85, 1.0, 0))
	# Dark hole under the lid, hidden while the lid is shut.
	_mesh(body, _box, _dark_mat, Vector3(-1.82, 1.1, 0), Vector3(0.7, 0.02, 1.6))
	var pivot := Node3D.new()
	pivot.position = Vector3(-1.42, 1.11, 0)
	body.add_child(pivot)
	_mesh(pivot, _box, paint, Vector3(-0.39, 0, 0), Vector3(0.78, 0.05, 1.78))
	trunk.lid = pivot
	trunk.lid_open_rotation = Vector3(0, 0, -1.15)
	body.add_child(trunk)
	containers.append(trunk)


func _place_ruin() -> void:
	var p := _random_spot(60.0, 195.0)
	ruin_positions.append(p)
	var body := _body_at(p, rng.randf() * TAU)
	var box := BoxMesh.new()
	# An L-shaped broken wall made of uneven blocks. Each block is planted on
	# the ground under it (and extends 0.6 m into the sand) so none float.
	var segments := rng.randi_range(4, 7)
	for i in segments:
		var h := rng.randf_range(0.8, 3.6)
		var along_x := i < segments / 2 + 1
		var offset := i if along_x else i - segments / 2
		var local := Vector3(offset * 2.0, 0, 0) if along_x else Vector3(0, 0, offset * 2.0)
		var size := Vector3(2.0, h + 0.6, 0.45) if along_x else Vector3(0.45, h + 0.6, 2.0)
		var world := body.transform * local
		var ground := terrain.ground_under(world.x, world.z, 1.0) - p.y
		var pos := Vector3(local.x, ground + h * 0.5 - 0.3, local.z)
		var tilt := Vector3(rng.randf_range(-0.04, 0.04), 0, rng.randf_range(-0.04, 0.04))
		_mesh(body, box, concrete_mat, pos, size, tilt)
		_box_collider(body, size, pos, tilt)
	# Some rubble.
	for i in rng.randi_range(3, 6):
		var s := rng.randf_range(0.3, 0.7)
		var local := Vector3(rng.randf_range(-1, 5), 0, rng.randf_range(-1, 5))
		var world := body.transform * local
		local.y = terrain.surface_height(world.x, world.z) - p.y + s * 0.15
		_mesh(body, box, concrete_mat, local, Vector3(s, s * 0.6, s), Vector3(rng.randf(), rng.randf(), rng.randf()))
	# Supply crates sheltered inside the corner of the L.
	var index := ruin_positions.size() - 1
	var spots := [Vector3(1.1, 0, 1.0)]
	if loot_rng.randf() < 0.6:
		spots.append(Vector3(loot_rng.randf_range(2.6, 4.0), 0, 0.85))
	for i in spots.size():
		var world: Vector3 = body.transform * spots[i]
		_place_crate(world, body.rotation.y + loot_rng.randf_range(-0.4, 0.4), "ruin%d_crate%d" % [index, i])


## A wooden supply crate whose lid flips open when searched.
func _place_crate(pos: Vector3, yaw: float, id: String) -> void:
	var size := Vector3(0.9, 0.6, 0.6)
	var ground := terrain.ground_under(pos.x, pos.z, 0.45)
	var body := _body_at(Vector3(pos.x, ground - 0.05, pos.z), yaw)
	_mesh(body, _box, wood_mat, Vector3(0, size.y * 0.5, 0), size)
	# Darker slats so it reads as a crate.
	var slat := LowPoly.material(Color(0.33, 0.22, 0.13))
	for x in [-0.42, 0.42]:
		_mesh(body, _box, slat, Vector3(x, size.y * 0.5, 0), Vector3(0.08, size.y + 0.01, size.z + 0.02))
	_mesh(body, _box, _dark_mat, Vector3(0, size.y - 0.005, 0), Vector3(size.x - 0.1, 0.02, size.z - 0.1))
	_box_collider(body, size, Vector3(0, size.y * 0.5, 0))
	var pivot := Node3D.new()
	pivot.position = Vector3(0, size.y + 0.03, -size.z * 0.5)
	body.add_child(pivot)
	_mesh(pivot, _box, slat, Vector3(0, 0, size.z * 0.5), Vector3(size.x + 0.04, 0.06, size.z + 0.04))
	var crate := LootContainer.new()
	crate.container_id = id
	crate.kind = "crate"
	crate.label = "crate"
	crate.search_time = 1.5
	crate.add_box(size + Vector3(0.12, 0.15, 0.12), Vector3(0, size.y * 0.5, 0))
	crate.lid = pivot
	crate.lid_open_rotation = Vector3(-1.9, 0, 0)
	body.add_child(crate)
	containers.append(crate)


func container_by_id(id: String) -> Node:
	for c in containers:
		if c.container_id == id:
			return c
	return null


## A flag pole and a few crates marking where the fortress will be built.
func _place_base_marker() -> void:
	var y: float = terrain.surface_height(0, 0)
	var body := _body_at(Vector3(0, y, 0), 0.0)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.08
	pole.height = 6.0
	pole.radial_segments = 6
	_mesh(body, LowPoly.flat(pole), wood_mat, Vector3(0, 3, 0))
	var flag := BoxMesh.new()
	_mesh(body, flag, cloth_mat, Vector3(0.7, 5.4, 0), Vector3(1.4, 0.8, 0.04))
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.1
	shape.height = 6.0
	col.shape = shape
	col.position.y = 3
	body.add_child(col)
	var crate := BoxMesh.new()
	for c in [Vector3(2.5, 0.4, 1.5), Vector3(3.3, 0.4, 1.4), Vector3(2.9, 1.2, 1.5)]:
		var cb := _body_at(Vector3(c.x, y + c.y, c.z), rng.randf_range(-0.3, 0.3))
		_mesh(cb, crate, wood_mat, Vector3.ZERO, Vector3(0.8, 0.8, 0.8))
		_box_collider(cb, Vector3(0.8, 0.8, 0.8))

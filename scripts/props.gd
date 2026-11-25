extends Node3D
## Scatters desert props: rocks, cacti, dry shrubs, rusted car wrecks and
## ruined concrete walls. Wrecks and ruins are the future scavenging spots.

const LowPoly = preload("res://scripts/lowpoly.gd")

var rng := RandomNumberGenerator.new()
var terrain: Node

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


func populate(terrain_node: Node, seed_value: int) -> void:
	terrain = terrain_node
	rng.seed = seed_value * 7 + 3
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
	concrete_mat = LowPoly.material(Color(0.72, 0.68, 0.62))
	wood_mat = LowPoly.material(Color(0.45, 0.31, 0.19))
	cloth_mat = LowPoly.material(Color(0.75, 0.18, 0.12))


## Random point on the dunes, outside the base clearing and inside the mountains.
func _random_spot(min_r := 40.0, max_r := 210.0) -> Vector3:
	var ang := rng.randf() * TAU
	var r := sqrt(rng.randf_range(min_r * min_r, max_r * max_r))  # even spread
	var x := cos(ang) * r
	var z := sin(ang) * r
	return Vector3(x, terrain.height_at(x, z), z)


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
	var body := _body_at(p - Vector3(0, 0.2, 0), rng.randf() * TAU)
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
	var body := _body_at(p - Vector3(0, 0.35, 0), rng.randf() * TAU)
	# Half-sunk and tilted, like it has been there for decades.
	body.rotation.x = rng.randf_range(-0.12, 0.12)
	body.rotation.z = rng.randf_range(-0.15, 0.15)
	var box := BoxMesh.new()
	var mat := rust_mats[rng.randi() % rust_mats.size()]
	_mesh(body, box, mat, Vector3(0, 0.6, 0), Vector3(4.2, 0.9, 2.0))
	_mesh(body, box, mat, Vector3(-0.3, 1.4, 0), Vector3(2.0, 0.75, 1.8))
	# Wheels (one missing).
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.45
	wheel.bottom_radius = 0.45
	wheel.height = 0.3
	wheel.radial_segments = 8
	var wheel_mesh := LowPoly.flat(wheel)
	var tyre := LowPoly.material(Color(0.12, 0.11, 0.10))
	var spots := [Vector3(1.4, 0.3, 1.0), Vector3(-1.4, 0.3, 1.0), Vector3(1.4, 0.3, -1.0), Vector3(-1.4, 0.3, -1.0)]
	spots.remove_at(rng.randi() % spots.size())
	for w in spots:
		_mesh(body, wheel_mesh, tyre, w, Vector3.ONE, Vector3(PI / 2, 0, 0))
	_box_collider(body, Vector3(4.2, 0.9, 2.0), Vector3(0, 0.6, 0))
	_box_collider(body, Vector3(2.0, 0.75, 1.8), Vector3(-0.3, 1.4, 0))


func _place_ruin() -> void:
	var p := _random_spot(60.0, 195.0)
	ruin_positions.append(p)
	var body := _body_at(p - Vector3(0, 0.5, 0), rng.randf() * TAU)
	var box := BoxMesh.new()
	# An L-shaped broken wall made of uneven blocks.
	var segments := rng.randi_range(4, 7)
	for i in segments:
		var h := rng.randf_range(0.8, 3.6)
		var along_x := i < segments / 2 + 1
		var offset := i if along_x else i - segments / 2
		var pos := Vector3(offset * 2.0, h * 0.5, 0) if along_x else Vector3(0, h * 0.5, offset * 2.0)
		var size := Vector3(2.0, h, 0.45) if along_x else Vector3(0.45, h, 2.0)
		var tilt := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
		_mesh(body, box, concrete_mat, pos, size, tilt)
		_box_collider(body, size, pos, tilt)
	# Some rubble.
	for i in rng.randi_range(3, 6):
		var s := rng.randf_range(0.3, 0.7)
		_mesh(body, box, concrete_mat, Vector3(rng.randf_range(-1, 5), s * 0.3, rng.randf_range(-1, 5)),
			Vector3(s, s * 0.6, s), Vector3(rng.randf(), rng.randf(), rng.randf()))


## A flag pole and a few crates marking where the fortress will be built.
func _place_base_marker() -> void:
	var y: float = terrain.BASE_HEIGHT
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

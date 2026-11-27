extends StaticBody3D
## Straw training dummy on a post near the flag. Takes any number of hits:
## it wobbles, and the damage of each hit floats up above it.

const LowPoly = preload("res://scripts/lowpoly.gd")

var hits := 0
var total_damage := 0.0
var _top: Node3D
var _wobble := Vector2.ZERO      # current lean (x, z) in radians
var _wobble_vel := Vector2.ZERO


func _ready() -> void:
	var wood := LowPoly.material(Color(0.42, 0.29, 0.17))
	var straw := LowPoly.material(Color(0.86, 0.72, 0.38))
	var sack := LowPoly.material(Color(0.62, 0.52, 0.36))
	var rope := LowPoly.material(Color(0.3, 0.22, 0.14))
	_box(self, Vector3(0.12, 0.9, 0.12), Vector3(0, 0.45, 0), wood)
	_box(self, Vector3(0.6, 0.06, 0.6), Vector3(0, 0.03, 0), wood)
	_top = Node3D.new()
	_top.position.y = 0.9
	add_child(_top)
	_box(_top, Vector3(0.1, 1.0, 0.1), Vector3(0, 0.5, 0), wood)
	_box(_top, Vector3(0.5, 0.75, 0.32), Vector3(0, 0.55, 0), straw)
	_box(_top, Vector3(1.2, 0.09, 0.09), Vector3(0, 0.78, 0), wood)
	_box(_top, Vector3(0.52, 0.06, 0.34), Vector3(0, 0.35, 0), rope)
	_box(_top, Vector3(0.52, 0.06, 0.34), Vector3(0, 0.72, 0), rope)
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.36
	head.radial_segments = 7
	head.rings = 4
	var hm := MeshInstance3D.new()
	hm.mesh = LowPoly.flat(head)
	hm.material_override = sack
	hm.position.y = 1.12
	_top.add_child(hm)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.55, 1.95, 0.4)
	col.shape = shape
	col.position.y = 0.98
	add_child(col)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


## A melee hit: wobble away from the swing and show the damage.
func take_hit(damage: float, point: Vector3, dir: Vector3, _force := 0.0, _stagger := 0.0) -> void:
	hits += 1
	total_damage += damage
	var local := global_transform.basis.inverse() * dir
	_wobble_vel += Vector2(local.z, -local.x).normalized() * (1.5 + damage * 0.06)
	var l := Label3D.new()
	l.text = str(int(damage))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.outline_size = 12
	l.modulate = Color(1.0, 0.9, 0.4)
	l.pixel_size = 0.004
	add_child(l)
	l.global_position = point + Vector3(0, 0.25, 0)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.7, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _process(delta: float) -> void:
	# A damped spring pulls the dummy back upright.
	_wobble_vel += (-_wobble * 60.0 - _wobble_vel * 5.0) * delta
	_wobble += _wobble_vel * delta
	_top.rotation = Vector3(_wobble.x, 0, _wobble.y)


func leaning() -> float:
	return _wobble.length()

extends Node3D
## The base build zone: a ring of marker stakes with red rags around the flag.
## In build mode a bright dashed line on the sand shows the edge too.

const LowPoly = preload("res://scripts/lowpoly.gd")
const Building = preload("res://scripts/building.gd")

const STAKES := 48
const DASHES := 140

var terrain  # Terrain
var radius := Building.ZONE_RADIUS
var _glow: MultiMeshInstance3D


func _ready() -> void:
	_build()


## The zone grew (base upgrade): move the stakes and the line out.
func set_radius(r: float) -> void:
	if is_equal_approx(r, radius):
		return
	radius = r
	var lit := _glow.visible
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()
	_glow.visible = lit


## The ground under the ring changed (digging): stand the stakes on it again.
func rebuild() -> void:
	var lit := _glow.visible
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()
	_glow.visible = lit


func _build() -> void:
	var r := radius
	var stake := BoxMesh.new()
	stake.size = Vector3(0.09, 0.9, 0.09)
	var rag := BoxMesh.new()
	rag.size = Vector3(0.03, 0.18, 0.3)
	var posts: Array = []
	var rags: Array = []
	var stakes := int(STAKES * r / Building.ZONE_RADIUS)
	for i in stakes:
		var a := TAU * i / stakes
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = terrain.surface_height(p.x, p.z)
		var t := Transform3D(Basis(Vector3.UP, -a).rotated(Vector3(sin(a), 0, -cos(a)), 0.06), p + Vector3(0, 0.4, 0))
		posts.append(t)
		rags.append(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.33, 0.16)))
	add_child(_multi(stake, LowPoly.material(Color(0.42, 0.3, 0.18)), posts))
	add_child(_multi(rag, LowPoly.material(Color(0.75, 0.16, 0.1)), rags))
	var dash := BoxMesh.new()
	dash.size = Vector3(0.7, 0.04, 0.22)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.62, 0.15, 0.75)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dashes: Array = []
	for i in DASHES:
		var a := TAU * (i + 0.5) / DASHES
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = terrain.surface_height(p.x, p.z) + 0.04
		# The long side runs along the circle.
		dashes.append(Transform3D(Basis(Vector3.UP, -a - PI / 2), p))
	_glow = _multi(dash, glow_mat, dashes)
	_glow.visible = false
	add_child(_glow)


func _multi(mesh: Mesh, mat: Material, transforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## Shows the bright edge line (in build mode).
func set_highlight(on: bool) -> void:
	_glow.visible = on


func highlighted() -> bool:
	return _glow.visible

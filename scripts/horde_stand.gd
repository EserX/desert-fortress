extends StaticBody3D
## The horde button: a post at the base with a big red button and a sign
## behind it (the front faces +z). E presses it and a wave of mutants comes for you right away, day or
## night (see Waves.call_horde). The button sinks and the lamp blinks while
## the horde is out.

const LowPoly = preload("res://scripts/lowpoly.gd")

var button: MeshInstance3D
var lamp: MeshInstance3D
var _lamp_on: StandardMaterial3D
var _lamp_off: StandardMaterial3D
var _press_t := 0.0
var _blink := 0.0
## Set by the world: true while a wave is out.
var wave_active := Callable()


func _ready() -> void:
	set_meta("interact_id", "horde")
	var parts := [
		[Vector3(0.7, 0.12, 0.7), Vector3(0, 0.06, 0), Color(0.3, 0.3, 0.32)],      # base plate
		[Vector3(0.18, 1.0, 0.18), Vector3(0, 0.6, 0), Color(0.55, 0.45, 0.1)],    # post, hazard yellow
		[Vector3(0.2, 0.08, 0.2), Vector3(0, 0.35, 0), Color(0.1, 0.1, 0.1)],      # stripes
		[Vector3(0.2, 0.08, 0.2), Vector3(0, 0.65, 0), Color(0.1, 0.1, 0.1)],
		[Vector3(0.5, 0.16, 0.42), Vector3(0, 1.18, 0), Color(0.22, 0.22, 0.24)],  # button box
		[Vector3(0.52, 0.3, 0.04), Vector3(0, 1.45, -0.2), Color(0.85, 0.82, 0.7)], # sign board behind the button
		[Vector3(0.44, 0.06, 0.05), Vector3(0, 1.45, -0.17), Color(0.7, 0.1, 0.08)],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = p[0]
		mi.mesh = m
		mi.position = p[1]
		mi.material_override = LowPoly.material(p[2])
		add_child(mi)
	button = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.12
	bm.bottom_radius = 0.13
	bm.height = 0.1
	bm.radial_segments = 10
	button.mesh = bm
	button.position = Vector3(0, 1.3, 0.03)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.08, 0.05)
	red.emission_enabled = true
	red.emission = Color(0.6, 0.02, 0.0)
	red.emission_energy_multiplier = 0.6
	button.material_override = red
	add_child(button)
	lamp = MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.07
	lm.height = 0.12
	lm.radial_segments = 8
	lm.rings = 4
	lamp.mesh = lm
	lamp.position = Vector3(0, 1.66, -0.2)
	_lamp_off = LowPoly.material(Color(0.35, 0.12, 0.05))
	_lamp_on = StandardMaterial3D.new()
	_lamp_on.albedo_color = Color(1.0, 0.45, 0.1)
	_lamp_on.emission_enabled = true
	_lamp_on.emission = Color(1.0, 0.4, 0.05)
	_lamp_on.emission_energy_multiplier = 3.0
	lamp.material_override = _lamp_off
	add_child(lamp)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.55, 1.6, 0.5)
	col.shape = shape
	col.position.y = 0.8
	add_child(col)


## The button sinks and springs back.
func press() -> void:
	_press_t = 0.5


func _process(delta: float) -> void:
	_press_t = maxf(_press_t - delta, 0.0)
	button.position.y = 1.3 - (0.05 if _press_t > 0.0 else 0.0)
	var on: bool = wave_active.is_valid() and wave_active.call()
	_blink += delta
	lamp.material_override = _lamp_on if on and fmod(_blink, 0.8) < 0.4 else _lamp_off

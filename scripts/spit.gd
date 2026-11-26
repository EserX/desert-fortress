extends Node3D
## A glob of acid lobbed by a Spitter. Flies in an arc; burns the player for
## a few points or eats into a building piece, then splashes.

const GRAVITY := 9.8
const LIFETIME := 4.0

signal hit_player(damage: float, from: Vector3)

var velocity := Vector3.ZERO
var damage := 14.0
var wall_damage := 25.0
var target: Node3D        # the player
var building              # Building
var exclude: Array[RID] = []
var _age := 0.0
var _origin := Vector3.ZERO


func _ready() -> void:
	_origin = global_position
	var m := SphereMesh.new()
	m.radius = 0.11
	m.height = 0.22
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.95, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.9, 0.1)
	mat.emission_energy_multiplier = 2.5
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	var from := global_position
	velocity.y -= GRAVITY * delta
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		# Near misses still splash on you.
		if target and to.distance_to(target.global_position + Vector3(0, 1.0, 0)) < 0.55:
			_splash(to, target)
		return
	_splash(hit.position, hit.collider)


func _splash(at: Vector3, what: Object) -> void:
	if what == target:
		hit_player.emit(damage, _origin)
	elif building and what is Node:
		var key: String = building.piece_key_of(what)
		if key != "":
			building.damage(key, wall_damage)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 14
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.6, 1.0, 0.2)
	q.material = mat
	p.mesh = q
	get_parent().add_child(p)
	p.global_position = at
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	queue_free()

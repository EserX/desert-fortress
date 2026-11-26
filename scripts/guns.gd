extends Node3D
## Guns, held in both hands on the camera. Left click fires (semi-automatic),
## holding right click aims down the sights (tighter spread, zoomed view),
## R reloads from the ammo in your inventory. Each shot kicks the view up,
## flashes at the muzzle and is loud enough to bring mutants running.

const LowPoly = preload("res://scripts/lowpoly.gd")

## damage per hit, mag size, seconds between shots, reload seconds, ammo item,
## range in m, spread in degrees (hip / aimed), view kick in radians, aimed zoom.
const GUNS := {
	"pistol": {"damage": 34.0, "mag": 12, "rate": 0.2, "reload": 1.5, "ammo": "ammo_9mm",
		"range": 90.0, "spread_hip": 1.8, "spread_ads": 0.25, "kick": 0.035, "zoom": 0.75, "loud": 45.0},
}
const MIX_RATE := 22050.0
const HIP_POS := Vector3(0.2, -0.2, -0.42)
const ADS_POS := Vector3(0.0, -0.064, -0.58)

## A shot connected: "target" or "solid" (same as melee).
signal hit_landed(kind: String)
## A shot rang out here (mutants nearby hear it).
signal fired(pos: Vector3, loudness: float)

var player  # Player
var inventory  # Inventory
var item := ""              # the gun in your hands, or ""
var mag := {}               # gun id -> rounds loaded
var ads := false            # right mouse held
var ads_amount := 0.0       # 0 = hip, 1 = fully aimed
var reload_t := -1.0        # seconds into a reload, or -1
var _cooldown := 0.0
var _kick := 0.0            # gun model kick-back, decays
var _rng := RandomNumberGenerator.new()
var _rig: Node3D            # hands and gun, moves between hip and sights
var _models := {}
var _flash: Node3D
var _flash_light: OmniLight3D
var _flash_t := 0.0
var _audio: AudioStreamPlayer
var _sounds := {}


func _ready() -> void:
	var skin := LowPoly.material(Color(0.78, 0.56, 0.42))
	var sleeve := LowPoly.material(Color(0.4, 0.37, 0.28))
	var steel := LowPoly.material(Color(0.16, 0.16, 0.17), 0.5)
	var grip := LowPoly.material(Color(0.1, 0.09, 0.08))
	_rig = Node3D.new()
	_rig.position = HIP_POS
	add_child(_rig)
	var pistol := Node3D.new()
	_box(pistol, Vector3(0.034, 0.042, 0.2), Vector3(0, 0.03, -0.06), steel)        # slide
	_box(pistol, Vector3(0.03, 0.035, 0.17), Vector3(0, 0.0, -0.05), grip)          # frame
	var g := _box(pistol, Vector3(0.03, 0.11, 0.045), Vector3(0, -0.05, 0.02), grip)  # grip
	g.rotation.x = 0.25
	_box(pistol, Vector3(0.008, 0.012, 0.01), Vector3(0, 0.057, -0.15), steel)      # front sight
	_box(pistol, Vector3(0.026, 0.012, 0.01), Vector3(0, 0.057, 0.03), steel)       # rear sight
	_box(pistol, Vector3(0.012, 0.03, 0.04), Vector3(0, -0.03, -0.03), steel)       # trigger guard
	_models["pistol"] = pistol
	_rig.add_child(pistol)
	# Right fist wrapped round the grip, left hand cupping it, forearms back to the camera.
	_box(_rig, Vector3(0.07, 0.08, 0.08), Vector3(0.005, -0.06, 0.03), skin)
	_box(_rig, Vector3(0.09, 0.09, 0.36), Vector3(0.03, -0.09, 0.22), sleeve)
	_box(_rig, Vector3(0.06, 0.07, 0.08), Vector3(-0.035, -0.065, 0.0), skin)
	var left := _box(_rig, Vector3(0.09, 0.09, 0.36), Vector3(-0.12, -0.1, 0.18), sleeve)
	left.rotation.y = -0.45
	_flash = Node3D.new()
	_flash.position = Vector3(0, 0.03, -0.19)
	pistol.add_child(_flash)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.85, 0.4)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 3:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.05, 0.14)
		q.mesh = qm
		q.material_override = fm
		q.rotation = Vector3(PI / 2, i * PI / 3, 0)
		q.position.z = -0.05
		_flash.add_child(q)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.45)
	_flash_light.light_energy = 3.0
	_flash_light.omni_range = 6.0
	_flash.add_child(_flash_light)
	_flash.visible = false
	for c in _all(self):
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_sounds.shot = _make_sound("shot", 0.5)
	_sounds.dry = _make_sound("click", 0.08)
	_sounds.reload = _make_sound("reload", 0.9)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _all(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out


static func is_gun(id: String) -> bool:
	return GUNS.has(id)


## Rounds loaded in a gun.
func loaded(id: String) -> int:
	return int(mag.get(id, 0))


## Shows the gun (or hides everything for anything that isn't one).
func set_item(id: String) -> void:
	if not is_gun(id):
		id = ""
	if id == item:
		return
	item = id
	visible = id != ""
	for k in _models:
		_models[k].visible = k == id
	reload_t = -1.0
	if id == "":
		ads = false


func set_ads(on: bool) -> void:
	ads = on and item != ""


## Left click. Returns {"fired": bool, "kind": "target"/"solid"/"", "node"}.
func try_fire() -> Dictionary:
	if item == "" or reload_t >= 0.0 or _cooldown > 0.0:
		return {"fired": false, "kind": ""}
	var g: Dictionary = GUNS[item]
	if loaded(item) <= 0:
		_play(_sounds.dry, 1.0)
		_cooldown = 0.25
		start_reload()
		return {"fired": false, "kind": ""}
	mag[item] = loaded(item) - 1
	_cooldown = g.rate
	_kick = 1.0
	_flash_t = 0.05
	_flash.visible = true
	_flash.rotation.z = _rng.randf() * TAU
	_play(_sounds.shot, _rng.randf_range(0.95, 1.05))
	# The view kicks up and a little to the side.
	player.head.rotation.x = clampf(player.head.rotation.x + g.kick * lerpf(1.0, 0.6, ads_amount), -1.5, 1.5)
	player.rotate_y(_rng.randf_range(-0.3, 0.3) * g.kick)
	fired.emit(player.global_position, g.loud)
	return shoot_ray(g)


## The bullet: a ray from the eye within the spread cone.
func shoot_ray(g: Dictionary) -> Dictionary:
	var cam: Camera3D = player.camera
	var spread := deg_to_rad(lerpf(g.spread_hip, g.spread_ads, ads_amount))
	var dir := -cam.global_transform.basis.z
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * spread
	dir = dir.rotated(cam.global_transform.basis.x, sin(a) * r).rotated(cam.global_transform.basis.y, cos(a) * r)
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * g.range, 1 | 8, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var res := {"fired": true, "kind": ""}
	if hit.is_empty():
		return res
	var n: Node = hit.collider
	while n and not n.has_method("take_hit"):
		n = n.get_parent()
	res.kind = "target" if n else "solid"
	res.node = n
	res.point = hit.position
	if n:
		n.take_hit(g.damage, hit.position, dir)
	else:
		_impact(hit.position, hit.normal)
	hit_landed.emit(res.kind)
	return res


## R. Takes rounds from the inventory; finishes after the reload time.
func start_reload() -> bool:
	if item == "" or reload_t >= 0.0:
		return false
	var g: Dictionary = GUNS[item]
	if loaded(item) >= g.mag or inventory.count_of(g.ammo) <= 0:
		return false
	reload_t = 0.0
	_play(_sounds.reload, 1.0)
	return true


func _finish_reload() -> void:
	var g: Dictionary = GUNS[item]
	var want: int = g.mag - loaded(item)
	var got: int = inventory.remove(g.ammo, want)
	mag[item] = loaded(item) + got
	reload_t = -1.0


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target_ads := 1.0 if ads and reload_t < 0.0 and item != "" else 0.0
	ads_amount = move_toward(ads_amount, target_ads, delta * 7.0)
	if player:
		var zoom: float = GUNS[item].zoom if item != "" else 1.0
		player.camera.fov = Settings.fov * lerpf(1.0, zoom, ads_amount)
	if not visible:
		return
	if reload_t >= 0.0:
		reload_t += delta
		if reload_t >= GUNS[item].reload:
			_finish_reload()
	_kick = move_toward(_kick, 0.0, delta * 9.0)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.visible = false
	var pos := HIP_POS.lerp(ADS_POS, ads_amount)
	pos.z += _kick * 0.05
	var rot := Vector3(_kick * 0.25, 0, 0)
	if reload_t >= 0.0:
		# Tip the gun down and to the side while swapping the magazine.
		var t: float = reload_t / GUNS[item].reload
		var dip := sin(clampf(t, 0.0, 1.0) * PI)
		pos += Vector3(-0.04, -0.08, 0.04) * dip
		rot += Vector3(-0.5, 0.2, 0.6) * dip
	_rig.position = pos
	_rig.rotation = rot


## Dust kicked up where a bullet hits.
func _impact(at: Vector3, normal: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.gravity = Vector3(0, -4, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.75, 0.62, 0.45)
	q.material = mat
	p.mesh = q
	player.get_parent().add_child(p)
	p.global_position = at
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


func _play(stream: AudioStream, pitch: float) -> void:
	_audio.stream = stream
	_audio.pitch_scale = pitch
	_audio.play()


func save_data() -> Dictionary:
	return {"mag": mag}


func load_data(data: Dictionary) -> void:
	mag = {}
	var m: Dictionary = data.get("mag", {})
	for k in m:
		if GUNS.has(k):
			mag[k] = clampi(int(m[k]), 0, GUNS[k].mag)


## Generated sounds: a sharp crack with a low thump and a tail, an empty click,
## and the clacks of a magazine coming out, going in and the slide racking.
func _make_sound(kind: String, length: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var s := 0.0
		match kind:
			"shot":
				lp += (_rng.randf_range(-1, 1) - lp) * lerpf(0.9, 0.08, minf(t / 0.08, 1.0))
				s = lp * exp(-t * 18.0) * 1.6 + sin(TAU * 70.0 * t) * exp(-t * 30.0) * 0.9
				s += _rng.randf_range(-1, 1) * exp(-t * 7.0) * 0.06  # echo off the dunes
			"click":
				s = _rng.randf_range(-1, 1) * exp(-t * 300.0) + sin(TAU * 2400.0 * t) * exp(-t * 200.0) * 0.4
			"reload":
				for at in [0.08, 0.5, 0.75]:
					var u: float = t - at
					if u >= 0.0:
						s += (_rng.randf_range(-1, 1) * 0.6 + sin(TAU * 1700.0 * u) * 0.4) * exp(-u * 160.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.data = data
	return wav

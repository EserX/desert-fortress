extends Node3D
## Guns, held in both hands on the camera. Left click fires (semi-automatic),
## holding right click aims down the sights (tighter spread, zoomed view),
## R reloads from the ammo in your inventory. Each shot kicks the view up,
## flashes at the muzzle and is loud enough to bring mutants running.

const LowPoly = preload("res://scripts/lowpoly.gd")

## damage per hit (per pellet), pellets per shot, mag size, seconds between
## shots, reload seconds, ammo item, range in m, spread in degrees (hip / aimed),
## view kick in radians, aimed zoom, how far mutants hear it, where the gun sits
## at the hip and when aimed, whether aiming looks through a scope, and the
## knockback (m/s, per pellet) and stagger (s, once per shot) a hit gives.
const GUNS := {
	"pistol": {"damage": 34.0, "pellets": 1, "mag": 12, "rate": 0.2, "reload": 1.5, "ammo": "ammo_9mm",
		"range": 90.0, "spread_hip": 1.8, "spread_ads": 0.25, "kick": 0.035, "zoom": 0.75, "loud": 45.0,
		"hip": Vector3(0.2, -0.2, -0.42), "ads": Vector3(0.0, -0.064, -0.58), "pitch": 1.0, "knock": 1.2, "stagger": 0.12},
	"shotgun": {"damage": 13.0, "pellets": 9, "mag": 6, "rate": 0.85, "reload": 2.6, "ammo": "shells",
		"range": 32.0, "spread_hip": 5.0, "spread_ads": 3.0, "kick": 0.09, "zoom": 0.85, "loud": 60.0,
		"hip": Vector3(0.22, -0.22, -0.36), "ads": Vector3(0.0, -0.075, -0.3), "pitch": 0.62, "knock": 0.9, "stagger": 0.5},
	"rifle": {"damage": 90.0, "pellets": 1, "mag": 5, "rate": 1.1, "reload": 2.4, "ammo": "ammo_762",
		"range": 220.0, "spread_hip": 2.5, "spread_ads": 0.03, "kick": 0.07, "zoom": 0.32, "loud": 75.0,
		"hip": Vector3(0.22, -0.22, -0.34), "ads": Vector3(0.0, -0.1, -0.2), "pitch": 0.8, "scope": true, "knock": 3.5, "stagger": 0.45},
}
const HEADSHOT := 2.0     # damage multiplier for a hit on a mutant's head
const RAISE_TIME := 0.35  # seconds to bring a gun up after switching to it
const MIX_RATE := 22050.0

## A shot connected: "target", "head" or "solid".
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
var raise_t := 0.0          # counts down while a gun is being brought up
var _kick := 0.0            # gun model kick-back, decays
var _rng := RandomNumberGenerator.new()
var _rig: Node3D            # hands and gun, moves between hip and sights
var _models := {}
var _left: Node3D           # left hand: under the pistol grip or out on the fore-end
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
	_rig.position = GUNS.pistol.hip
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
	var wood := LowPoly.material(Color(0.42, 0.26, 0.14))
	var shotgun := Node3D.new()
	_box(shotgun, Vector3(0.036, 0.036, 0.62), Vector3(0, 0.035, -0.3), steel)     # barrel
	_box(shotgun, Vector3(0.03, 0.03, 0.5), Vector3(0, 0.0, -0.26), steel)         # tube magazine
	_box(shotgun, Vector3(0.05, 0.05, 0.16), Vector3(0, 0.005, -0.3), wood)        # pump
	_box(shotgun, Vector3(0.05, 0.07, 0.2), Vector3(0, 0.02, 0.02), steel)         # receiver
	var st := _box(shotgun, Vector3(0.045, 0.08, 0.3), Vector3(0, -0.03, 0.22), wood)  # stock
	st.rotation.x = 0.12
	_box(shotgun, Vector3(0.012, 0.012, 0.012), Vector3(0, 0.06, -0.59), LowPoly.material(Color(0.9, 0.85, 0.6)))  # bead sight
	_models["shotgun"] = shotgun
	_rig.add_child(shotgun)
	var rifle := Node3D.new()
	_box(rifle, Vector3(0.026, 0.026, 0.72), Vector3(0, 0.03, -0.36), steel)       # barrel
	_box(rifle, Vector3(0.05, 0.055, 0.5), Vector3(0, 0.005, -0.12), wood)         # fore-end
	_box(rifle, Vector3(0.045, 0.06, 0.16), Vector3(0, 0.03, 0.02), steel)         # action
	_box(rifle, Vector3(0.012, 0.012, 0.06), Vector3(0.04, 0.04, 0.05), steel)     # bolt handle
	var rs := _box(rifle, Vector3(0.045, 0.09, 0.32), Vector3(0, -0.035, 0.24), wood)
	rs.rotation.x = 0.1
	_box(rifle, Vector3(0.045, 0.045, 0.3), Vector3(0, 0.09, -0.02), steel)        # scope tube
	_box(rifle, Vector3(0.055, 0.055, 0.05), Vector3(0, 0.09, -0.17), steel)       # objective bell
	_box(rifle, Vector3(0.05, 0.05, 0.04), Vector3(0, 0.09, 0.13), steel)          # eyepiece
	_models["rifle"] = rifle
	_rig.add_child(rifle)
	# Right fist wrapped round the grip, left hand cupping it, forearms back to the camera.
	_box(_rig, Vector3(0.07, 0.08, 0.08), Vector3(0.005, -0.06, 0.03), skin)
	_box(_rig, Vector3(0.09, 0.09, 0.36), Vector3(0.03, -0.09, 0.22), sleeve)
	_left = Node3D.new()
	_rig.add_child(_left)
	_box(_left, Vector3(0.06, 0.07, 0.08), Vector3.ZERO, skin)
	var la := _box(_left, Vector3(0.09, 0.09, 0.36), Vector3(-0.085, -0.035, 0.18), sleeve)
	la.rotation.y = -0.45
	_flash = Node3D.new()
	_flash.position = Vector3(0, 0.03, -0.19)
	_rig.add_child(_flash)
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
	if id != "":
		raise_t = RAISE_TIME
		_flash.position = Vector3(0, 0.035, -{"pistol": 0.17, "shotgun": 0.62, "rifle": 0.73}[id])
		_left.position = {"pistol": Vector3(-0.035, -0.065, 0.0), "shotgun": Vector3(0.0, -0.035, -0.3), "rifle": Vector3(0.0, -0.04, -0.22)}[id]
	if id == "":
		ads = false


func set_ads(on: bool) -> void:
	ads = on and item != ""


## Left click. Returns {"fired": bool, "kind": "target"/"solid"/"", "node"}.
func try_fire() -> Dictionary:
	if item == "" or reload_t >= 0.0 or _cooldown > 0.0 or raise_t > 0.0:
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
	_play(_sounds.shot, g.pitch * _rng.randf_range(0.95, 1.05))
	var res := shoot_ray(g)
	# Then the view kicks up and a little to the side.
	player.head.rotation.x = clampf(player.head.rotation.x + g.kick * lerpf(1.0, 0.6, ads_amount), -1.5, 1.5)
	player.rotate_y(_rng.randf_range(-0.3, 0.3) * g.kick)
	fired.emit(player.global_position, g.loud)
	return res


## The bullet (or each pellet): a ray from the eye within the spread cone.
## Damage on the same target adds up into one hit; head hits count double.
func shoot_ray(g: Dictionary) -> Dictionary:
	var cam: Camera3D = player.camera
	var spread := deg_to_rad(lerpf(g.spread_hip, g.spread_ads, ads_amount))
	var from := cam.global_position
	var res := {"fired": true, "kind": ""}
	var totals := {}   # node -> [damage, point, dir, head, pellets]
	for i in g.pellets:
		var dir := -cam.global_transform.basis.z
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * spread
		dir = dir.rotated(cam.global_transform.basis.x, sin(a) * r).rotated(cam.global_transform.basis.y, cos(a) * r)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * g.range, 1 | 8, [player.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			continue
		var n: Node = hit.collider
		while n and not n.has_method("take_hit"):
			n = n.get_parent()
		if n == null:
			if i < 3:
				_impact(hit.position, hit.normal)
			if res.kind == "":
				res.kind = "solid"
			continue
		var head: bool = n.has_method("is_headshot") and n.is_headshot(hit.position)
		var dmg: float = g.damage * (HEADSHOT if head else 1.0)
		if not totals.has(n):
			totals[n] = [0.0, hit.position, dir, false, 0]
		totals[n][0] += dmg
		totals[n][4] += 1
		totals[n][3] = totals[n][3] or head
	for n in totals:
		var t: Array = totals[n]
		n.take_hit(t[0], t[1], t[2], float(g.knock) * t[4], g.stagger)
		res.kind = "head" if t[3] else (res.kind if res.kind == "head" else "target")
		res.node = n
		res.point = t[1]
		res.damage = t[0]
	if res.kind != "":
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
	var target_ads := 1.0 if ads and reload_t < 0.0 and item != "" and raise_t <= 0.0 else 0.0
	ads_amount = move_toward(ads_amount, target_ads, delta * 7.0)
	if player:
		var zoom: float = GUNS[item].zoom if item != "" else 1.0
		player.camera.fov = Settings.fov * lerpf(1.0, zoom, ads_amount)
	if not visible:
		return
	raise_t = maxf(raise_t - delta, 0.0)
	if reload_t >= 0.0:
		reload_t += delta
		if reload_t >= GUNS[item].reload:
			_finish_reload()
	_kick = move_toward(_kick, 0.0, delta * 9.0)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.visible = false
	var g: Dictionary = GUNS[item]
	var pos: Vector3 = (g.hip as Vector3).lerp(g.ads, ads_amount)
	# Looking through a scope: the gun itself gets out of the way.
	_models[item].visible = not (g.get("scope", false) and ads_amount > 0.9)
	pos.y -= raise_t / RAISE_TIME * 0.25
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

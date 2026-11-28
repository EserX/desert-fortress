extends Node3D
## v2.0 throwables: stones, molotovs and pipe bombs. Hold one and press the
## left mouse button to draw back; let go to throw. The longer you hold (up to
## CHARGE_TIME) the harder it flies. Each one is a rigid body that flies in an
## arc, bounces and rolls:
## - a stone hurts and shoves a mutant (or an animal) it hits hard enough, then
##   lies where it stops as a stone to pick up again;
## - a molotov shatters on the first thing it touches and leaves a pool of fire
##   for FIRE_SECONDS: it burns mutants (and you) and sets a nest alight;
## - a pipe bomb bounces, and when its fuse runs out it blows up like a big
##   landmine (the shared blast in traps.gd), also burning out a nest close by.
## Throwables in the air and fires are short-lived and not saved: stones in the
## air land on the spot when the game saves, fires go out.

const LowPoly = preload("res://scripts/lowpoly.gd")

## speed: m/s at full charge; damage/knock/stagger: a stone's hit at full speed.
const KINDS := {
	"stone": {"name": "Stone", "speed": 18.0, "mass": 1.5, "bounce": 0.3, "damage": 26.0, "knock": 4.5, "stagger": 0.45},
	"molotov": {"name": "Molotov", "speed": 15.0, "mass": 0.8, "bounce": 0.0},
	"pipe_bomb": {"name": "Pipe bomb", "speed": 15.0, "mass": 1.0, "bounce": 0.45, "fuse": 2.5},
}
const CHARGE_TIME := 0.8       # seconds of holding for a full throw
const MIN_POWER := 0.4         # a quick click still lobs it a few metres
const UP_TILT := 0.12          # throws leave a little above the crosshair
const STONE_HIT_SPEED := 5.0   # m/s a stone needs to hurt
const STONE_SETTLE := 0.4      # m/s: slower than this a stone is lying still
const MAX_FLIGHT := 8.0        # seconds before anything still moving lands anyway
const SPEED_FRAMES := 3       # a hit is judged on the fastest of the last few physics frames
const MERGE_DIST := 1.0        # a landed stone joins a stone pile this close
const FIRE_RADIUS := 2.6
const FIRE_SECONDS := 8.0
const FIRE_DPS := 30.0
const FIRE_SLOW := 0.6         # mutants in the flames stumble
const FIRE_PLAYER_DAMAGE := 5.0
const FIRE_PLAYER_EVERY := 0.5
const NEST_REACH := 4.0        # fire or a blast this close to a nest sets it alight
const TICK := 0.1
const BOMB_BLAST := {
	"radius": 6.5, "damage": 260.0, "push": 13.0, "lift": 7.5, "stagger": 1.4,
	"player_damage": 65.0, "player_push": 10.0, "piece_damage": 140.0, "piece_radius": 3.5,
	"debris_radius": 8.0,
}

signal player_hurt(damage: float, from: Vector3, cause: String)
signal hit_landed(kind: String)
signal message(text: String)

var inventory  # Inventory
var player     # Player
var melee      # Melee (the hands)
var mutants    # Mutants
var traps      # Traps (the blast)
var oases      # Oases (nests)
var loot       # Loot (landed stones become stone piles)
var terrain    # Terrain
## In the air or rolling: {"node": RigidBody3D, "item", "age", "speed", "recent": [m/s, ...],
## "fuse", "hit": {id: true}}. "speed" is the fastest of "recent" (the last
## SPEED_FRAMES physics frames): continuous collision slows a fast stone down
## a frame *before* it reports the touch, so the speed right then is too low.
var flying: Array = []
## Burning pools: {"pos": Vector3, "left": seconds, "node": Node3D}.
var fires: Array = []
## Seconds the throw button has been held, or -1 when not drawing back.
var charge := -1.0
var _tick := 0.0
var _player_burn := 0.0
var _meshes := {}
var _mats := {}
var _audio: AudioStreamPlayer3D


static func is_throwable(id: String) -> bool:
	return KINDS.has(id)


## How hard a throw would go now (MIN_POWER to 1).
func power() -> float:
	if charge < 0.0:
		return MIN_POWER
	return MIN_POWER + (1.0 - MIN_POWER) * clampf(charge / CHARGE_TIME, 0.0, 1.0)


## Left mouse with a throwable in hand: press draws back, release throws.
func handle_input(event: InputEvent, item: String) -> bool:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if event.pressed:
		charge = 0.0
	elif charge >= 0.0:
		throw_held(item, power())
		charge = -1.0
	return true


## What is in the hands now; anything else stops a throw being drawn back.
func set_held(item: String) -> void:
	if not is_throwable(item):
		charge = -1.0
	if melee:
		melee.wind_back = clampf(charge / CHARGE_TIME, 0.0, 1.0) if charge >= 0.0 else 0.0


func held_prompt(item: String) -> String:
	if not is_throwable(item):
		return ""
	var n: int = inventory.count_of(item) if inventory else 0
	if charge >= 0.0:
		var bars := int(round((power() - MIN_POWER) / (1.0 - MIN_POWER) * 10.0))
		return "%s (%d)\nThrow: [%s%s] let go to throw" % [KINDS[item].name, n, "=".repeat(bars), " ".repeat(10 - bars)]
	return "%s (%d)\n[LMB] Throw (hold to throw further)" % [KINDS[item].name, n]


## Throws one of the held item from your hand. Returns the body, or null.
func throw_held(item: String, strength: float) -> RigidBody3D:
	if not is_throwable(item) or inventory == null or inventory.remove(item, 1) < 1:
		return null
	var cam: Camera3D = player.camera
	var b := cam.global_transform.basis
	var dir := (-b.z + Vector3(0, UP_TILT, 0)).normalized()
	var from := cam.global_position - b.z * 0.5 + b.x * 0.18 - b.y * 0.12
	var v: Vector3 = dir * float(KINDS[item].speed) * clampf(strength, 0.0, 1.0)
	if player is CharacterBody3D:
		v += player.velocity * 0.5
	if melee:
		melee.wind_back = 0.0
		melee.play_swing(0.45)
	return throw(item, from, v)


## Sends a throwable flying from `from` with velocity v. Returns its body.
func throw(item: String, from: Vector3, v: Vector3) -> RigidBody3D:
	var k: Dictionary = KINDS[item]
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1 | 8 | 32  # the world, mutants, animals (and debris)
	body.mass = k.mass
	body.continuous_cd = true
	body.angular_damp = 1.5
	body.contact_monitor = true
	body.max_contacts_reported = 4
	var pm := PhysicsMaterial.new()
	pm.bounce = k.bounce
	pm.friction = 0.8
	pm.rough = true
	body.physics_material_override = pm
	var col := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(item)
	mi.material_override = _mat(item)
	match item:
		"stone":
			var sh := BoxShape3D.new()  # a box, not a ball: it tumbles to a stop instead of rolling on
			sh.size = Vector3(0.17, 0.13, 0.15)
			col.shape = sh
			mi.scale = Vector3(0.2, 0.16, 0.18)
		"molotov":
			var sh := BoxShape3D.new()
			sh.size = Vector3(0.1, 0.24, 0.1)
			col.shape = sh
			mi.scale = Vector3(0.1, 0.24, 0.1)
		"pipe_bomb":
			var sh := CylinderShape3D.new()
			sh.radius = 0.05
			sh.height = 0.26
			col.shape = sh
			mi.scale = Vector3(0.1, 0.26, 0.1)
	body.add_child(col)
	body.add_child(mi)
	if item == "pipe_bomb":
		var spark := OmniLight3D.new()
		spark.light_color = Color(1.0, 0.6, 0.2)
		spark.light_energy = 1.2
		spark.omni_range = 2.5
		spark.position.y = 0.16
		body.add_child(spark)
	if player is PhysicsBody3D:
		body.add_collision_exception_with(player)
	add_child(body)
	body.add_to_group("loose_props")  # blasts throw them about too
	body.global_position = from
	body.linear_velocity = v
	body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
	var rec := {"node": body, "item": item, "age": 0.0, "speed": v.length(), "recent": [v.length()], "fuse": float(k.get("fuse", 0.0)), "hit": {}}
	body.body_entered.connect(_on_body.bind(rec))
	flying.append(rec)
	return body


## A throwable touched something.
func _on_body(other: Node, rec: Dictionary) -> void:
	if not is_instance_valid(rec.node) or not rec in flying:
		return
	match rec.item:
		"stone":
			_stone_hit(rec, _target_of(other))
		"molotov":
			shatter(rec)


## A flying stone meets a living thing `t` (or null): it hurts it once, if the
## stone was going fast enough. Called from the contact report and the sweep.
func _stone_hit(rec: Dictionary, t: Node3D) -> void:
	if t == null or rec.hit.has(t.get_instance_id()) or rec.speed < STONE_HIT_SPEED:
		return
	rec.hit[t.get_instance_id()] = true
	var f := clampf(rec.speed / float(KINDS.stone.speed), 0.0, 1.0)
	var dir: Vector3 = rec.node.linear_velocity if rec.node.linear_velocity.length() > 0.1 else t.global_position - rec.node.global_position
	t.take_hit(KINDS.stone.damage * f, rec.node.global_position, dir, KINDS.stone.knock * f, KINDS.stone.stagger * f)
	hit_landed.emit("target")


## Before the physics step, sweeps a fast stone's shape along the way it is
## about to move and hits the living thing in its path. The contact report
## alone missed about one full-speed throw in a few hundred: continuous
## collision can turn a stone aside off a mutant without reporting the touch.
func _sweep_stone(rec: Dictionary, delta: float) -> void:
	var body: RigidBody3D = rec.node
	var v := body.linear_velocity
	if rec.speed < STONE_HIT_SPEED or v.length() < STONE_HIT_SPEED or body.get_child_count() == 0:
		return
	var col := body.get_child(0) as CollisionShape3D
	if col == null or col.shape == null:
		return
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = col.shape
	q.transform = col.global_transform
	q.motion = v * delta
	q.collision_mask = 8 | 32  # mutants and animals only: the ground is left to the contacts
	var ex: Array[RID] = [body.get_rid()]
	if player is PhysicsBody3D:
		ex.append(player.get_rid())
	q.exclude = ex
	var space := body.get_world_3d().direct_space_state
	var frac: PackedFloat32Array = space.cast_motion(q)
	if frac.size() < 2 or frac[1] >= 1.0:
		return
	q.transform.origin += q.motion * frac[1]
	q.motion = Vector3.ZERO
	for r in space.intersect_shape(q, 4):  # at most 4 results
		_stone_hit(rec, _target_of(r.collider))


## The living thing (mutant, animal, the dummy) a body belongs to, or null.
func _target_of(n: Node) -> Node3D:
	while n and not n.has_method("take_hit"):
		n = n.get_parent()
	if n == null or (n.has_method("is_dead") and n.is_dead()):
		return null
	return n as Node3D


func _physics_process(delta: float) -> void:
	for rec in flying.duplicate():  # a handful at a time
		var body: RigidBody3D = rec.node
		if not is_instance_valid(body):
			flying.erase(rec)
			continue
		rec.age += delta
		if terrain:
			var g: float = terrain.surface_height(body.global_position.x, body.global_position.z)
			if body.global_position.y < g - 0.5:  # safety net: never lost under the sand
				body.global_position.y = g + 0.15
				body.linear_velocity = Vector3.ZERO
		match rec.item:
			"stone":
				if (rec.age > 0.5 and body.linear_velocity.length() < STONE_SETTLE) or rec.age > MAX_FLIGHT:
					land_stone(rec)
					continue
				_sweep_stone(rec, delta)
			"molotov":
				if rec.age > MAX_FLIGHT:
					shatter(rec)
					continue
			"pipe_bomb":
				rec.fuse -= delta
				var spark := body.get_child(body.get_child_count() - 1) as OmniLight3D
				if spark:
					spark.light_energy = 0.8 + 0.8 * absf(sin(rec.age * 40.0))
				if rec.fuse <= 0.0:
					explode(rec)
					continue
		_note_speed(rec, body.linear_velocity.length())
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_burn(TICK)
	_player_burn = maxf(_player_burn - delta, 0.0)


## Keeps the last SPEED_FRAMES speeds of a throwable and its fastest as "speed".
static func _note_speed(rec: Dictionary, now: float) -> void:
	var recent: Array = rec.recent
	recent.append(now)
	while recent.size() > SPEED_FRAMES:
		recent.pop_front()
	rec.speed = recent.max()


func _process(delta: float) -> void:
	if charge >= 0.0:
		charge += delta
	for f in fires:  # a few pools at most: flicker
		if is_instance_valid(f.node):
			var k := clampf(f.left / 1.5, 0.0, 1.0)  # dies down over the last 1.5 s
			for c in f.node.get_children():
				if c is MeshInstance3D:
					c.scale.y = (0.6 + 0.5 * absf(sin(Time.get_ticks_msec() * 0.008 + c.position.x * 5.0))) * k + 0.05


## A thrown stone stops: it becomes a stone lying on the ground (joining a
## stone pile close by), to pick up with E.
func land_stone(rec: Dictionary) -> void:
	flying.erase(rec)
	var body: RigidBody3D = rec.node
	if not is_instance_valid(body):
		return
	var pos := body.global_position - Vector3(0, 0.09, 0)
	body.queue_free()
	if loot == null:
		return
	for id in loot.drops:  # every bag lying about (a few dozen at most)
		var d: Dictionary = loot.drops[id]
		if d.items.size() == 1 and d.items.has("stone") and d.node.global_position.distance_to(pos) < MERGE_DIST:
			loot.set_drop_items(id, {"stone": int(d.items.stone) + 1})
			return
	loot.spawn_drop({"stone": 1}, pos)


## Every thrown stone still moving lands where it is (before saving).
func land_stones() -> void:
	for rec in flying.duplicate():
		if rec.item == "stone":
			land_stone(rec)


## A molotov breaks: a pool of fire on the ground under it.
func shatter(rec: Dictionary) -> void:
	flying.erase(rec)
	var body: RigidBody3D = rec.node
	if not is_instance_valid(body):
		return
	var pos := body.global_position
	body.queue_free()
	ignite(_ground_under(pos))
	_sound(pos, "glass")


## Lights a pool of fire at pos for FIRE_SECONDS.
func ignite(pos: Vector3) -> void:
	var node := Node3D.new()
	add_child(node)
	node.global_position = pos
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 31.0 + pos.z * 17.0)  # only the look
	var flame := _mat("flame")
	for i in 9:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh("flame")
		mi.material_override = flame
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, FIRE_RADIUS * 0.8)
		mi.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var s := rng.randf_range(0.5, 1.0)
		mi.scale = Vector3(s, s, s)
		node.add_child(mi)
	var scorch := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = FIRE_RADIUS
	disc.bottom_radius = FIRE_RADIUS
	disc.height = 0.02
	disc.radial_segments = 10
	scorch.mesh = disc
	scorch.material_override = _mat("scorch")
	scorch.position.y = 0.03
	node.add_child(scorch)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.position.y = 1.0
	node.add_child(light)
	var smoke := CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 1.6
	smoke.direction = Vector3.UP
	smoke.spread = 20.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.0
	smoke.gravity = Vector3(0, 0.5, 0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = FIRE_RADIUS * 0.6
	var puff := SphereMesh.new()
	puff.radius = 0.2
	puff.height = 0.4
	puff.radial_segments = 6
	puff.rings = 3
	var pm := StandardMaterial3D.new()
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_color = Color(0.2, 0.18, 0.16, 0.5)
	puff.material = pm
	smoke.mesh = puff
	smoke.position.y = 0.8
	node.add_child(smoke)
	fires.append({"pos": pos, "left": FIRE_SECONDS, "node": node})
	_light_nests(pos)


## Ten times a second: the fires burn what stands in them and die down.
func _burn(dt: float) -> void:
	for f in fires.duplicate():  # a few pools at most
		f.left -= dt
		if f.left <= 0.0:
			if is_instance_valid(f.node):
				f.node.queue_free()
			fires.erase(f)
			continue
		if mutants:
			for m in mutants.alive():  # every living mutant (a few dozen at most)
				if _in_fire(m.global_position, f.pos):
					m.slow(FIRE_SLOW)
					m.hurt(FIRE_DPS * dt)
		if player and _player_burn <= 0.0 and _in_fire(player.global_position, f.pos, 0.85):
			_player_burn = FIRE_PLAYER_EVERY
			player_hurt.emit(FIRE_PLAYER_DAMAGE, f.pos, "Burned in your own fire.")
		_light_nests(f.pos)


func _in_fire(p: Vector3, at: Vector3, shrink := 1.0) -> bool:
	return Vector2(p.x - at.x, p.z - at.z).length() < FIRE_RADIUS * shrink and absf(p.y - at.y) < 1.6


## A nest within NEST_REACH of fire catches light (no fuel can needed).
func _light_nests(pos: Vector3) -> void:
	if oases == null:
		return
	for i in oases.count():  # 3 to 5 oases
		if oases.list[i].nest == "alive" and oases.list[i].nest_pos.distance_to(pos) < NEST_REACH:
			oases.burn_nest(i, true)


## The fuse runs out: the bomb blows up where it lies.
func explode(rec: Dictionary) -> void:
	flying.erase(rec)
	var body: RigidBody3D = rec.node
	if not is_instance_valid(body):
		return
	var pos := body.global_position
	body.queue_free()
	if traps:
		traps.blast_at(pos, BOMB_BLAST, "Caught in your own pipe bomb.")
	if mutants:
		mutants.alert(pos, 60.0)
	_light_nests(pos)


## Puts out every fire and drops everything in the air (loading a save).
func clear() -> void:
	for rec in flying:
		if is_instance_valid(rec.node):
			rec.node.queue_free()
	flying.clear()
	for f in fires:
		if is_instance_valid(f.node):
			f.node.queue_free()
	fires.clear()
	charge = -1.0


## The first solid ground under pos (a floor, the sand).
func _ground_under(pos: Vector3) -> Vector3:
	if is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.3, 0), pos - Vector3(0, 4.0, 0), 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			return hit.position
	if terrain:
		return Vector3(pos.x, terrain.surface_height(pos.x, pos.z), pos.z)
	return pos


func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	match kind:
		"stone":
			var s := SphereMesh.new()
			s.radial_segments = 5
			s.rings = 2
			m = LowPoly.flat(s)
		"flame":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.35
			c.height = 1.1
			c.radial_segments = 5
			c.rings = 1
			m = LowPoly.flat(c)
			# Stands on the ground: move the cone up by half its height.
			var st := SurfaceTool.new()
			st.create_from(m, 0)
			var arr := st.commit_to_arrays()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i].y += 0.55
			arr[Mesh.ARRAY_VERTEX] = verts
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m = am
		_:
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			m = b
	_meshes[kind] = m
	return m


func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m: StandardMaterial3D
	match kind:
		"stone":
			m = LowPoly.material(Color(0.52, 0.48, 0.44))
		"molotov":
			m = LowPoly.material(Color(0.35, 0.55, 0.3), 0.3)
		"pipe_bomb":
			m = LowPoly.material(Color(0.45, 0.46, 0.47), 0.4)
		"flame":
			m = StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.55, 0.15)
		_:
			m = LowPoly.material(Color(0.12, 0.1, 0.09))
	_mats[kind] = m
	return m


## Short generated sounds: breaking glass with a whoomph of fire.
func _sound(at: Vector3, _kind: String) -> void:
	if _audio == null:
		_audio = AudioStreamPlayer3D.new()
		_audio.unit_size = 10.0
		_audio.max_distance = 80.0
		var wav := AudioStreamWAV.new()
		var rate := 22050
		var n := int(rate * 0.6)
		var data := PackedByteArray()
		data.resize(n * 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var low := 0.0
		for i in n:
			var t := float(i) / rate
			var noise := rng.randf_range(-1, 1)
			low = lerpf(low, noise, 0.05)
			var s := noise * exp(-t * 30.0) * 0.6 + sin(TAU * (3200.0 + 900.0 * sin(t * 90.0)) * t) * exp(-t * 18.0) * 0.25 + low * 2.5 * exp(-t * 4.0) * minf(t * 20.0, 1.0)
			data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 22000.0))
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = rate
		wav.data = data
		_audio.stream = wav
		add_child(_audio)
	_audio.global_position = at
	_audio.play()

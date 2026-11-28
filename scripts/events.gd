extends Node3D
## Events (v2.3): sandstorms, the Behemoth and day raids on outposts.
## **Sandstorms** blow up on some days: the sky turns brown and you see about
## 30 m, the wind howls, a band of mutants comes in with the storm by day and
## heads for the main well, mutants see as little as at night, and drifting
## sand slowly fills the holes you dug. When the storm passes, the mutants in
## it sink back into the sand.
## A **Behemoth** (a huge boss mutant) walks at the back of every tenth night's
## wave (waves.gd puts it in the queue; this script announces it, shows its
## health and drops its loot).
## **Day raids**: on some days a band of mutants attacks one of your outposts
## by day. They wreck what you built there and trample its fields; drive them
## off for a bounty, or they slink away at dusk.
## What happens on a day comes from the world seed and the day, so the same
## world has the same storms and raids.

const Raids = preload("res://scripts/raids.gd")
const Waves = preload("res://scripts/waves.gd")

const STORM_FIRST_DAY := 3     # no storms before this day
const STORM_CHANCE := 0.3      # chance of a storm on a day
const STORM_FROM := 9.0        # a storm starts between these hours
const STORM_TO := 13.5
const STORM_MIN_H := 2.5       # and lasts this many hours (about 2 minutes)
const STORM_MAX_H := 4.0
const STORM_RAMP := 0.4        # hours it takes to build up and to die down
const STORM_WARN := 1.0        # the warning comes this many hours before
const STORM_FOG := 0.075       # fog at full strength (you see about 30 m)
const STORM_SKY_FOG := 1.0     # and the sky disappears in it
const STORM_SPAWN_R := 125.0   # the storm's mutants come from this far upwind
const STORM_KINDS := ["walker", "runner", "walker", "walker", "runner", "spitter"]
const SILT_EVERY := 3.0        # seconds between sand drifts in a storm
const SILT_CELLS := 5          # dug cells each drift fills one step (0.25 m)
## Cells this close to a building piece are left alone, so the ground under a
## piece and right round it (a well's shaft, a spiked pit) never moves.
const SILT_KEEP := 3.0
const RAID_FIRST_DAY := 3
const RAID_CHANCE := 0.4       # chance of a raid on a day, with an outpost claimed
const RAID_FROM := 10.0        # a raid starts between these hours
const RAID_TO := 16.0
const RAID_SPAWN_R := 50.0     # raiders come from this far from the outpost's flag
const RAID_END := 19.0         # raiders still about at this hour slink off
const RAID_KINDS := ["walker", "runner", "walker", "spitter", "walker", "brute"]
const RAID_PAY := 40           # cash for driving a raid off, plus RAID_PAY_EACH a raider
const RAID_PAY_EACH := 10
const BOSS_LOOT := {"scrap": 12, "metal_plate": 4, "nails": 30}
const TICK := 0.25
const DIRS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

signal message(text: String)
## The Behemoth's loot, where it fell (main drops it as a bag).
signal spilled(items: Dictionary, pos: Vector3)
## Cash for driving off a raid (main adds it to the shop).
signal paid(cash: int)

var mutants  # Mutants
var terrain  # Terrain (holes fill in)
var building  # Building (pieces keep the sand off the ground under them)
var day_night  # DayNight (the hour, the sky)
var ambience  # Ambience (the wind)
var oases  # Oases (which outposts are claimed)
var waves  # Waves (the Behemoth's night)
var player: Node3D
var env: Environment
var world_seed := 1337
var peaceful := false
## Today's plan (see plan_for) and how far it got.
var day := -1
var plan := {}
var warned := false
var storm_spawned := false
var raid_state := ""          # "" (not yet), "on", "won", "gone"
var raid_size := 0
## Strength of the storm right now (0..1).
var strength := 0.0
var drifts := 0               # sand drifts so far today (seeds which holes fill)
var _t := 0.0
var _silt_t := 0.0
var _base_fog := 0.0035
var _base_sky := 0.25
var _fogged := false
var _sand: CPUParticles3D


func _ready() -> void:
	_sand = CPUParticles3D.new()
	_sand.name = "Sandstorm"
	_sand.amount = 700
	_sand.lifetime = 1.6
	_sand.preprocess = 1.6
	_sand.emitting = false
	_sand.local_coords = false
	_sand.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sand.emission_box_extents = Vector3(18, 3.5, 18)
	_sand.spread = 8.0
	_sand.initial_velocity_min = 12.0
	_sand.initial_velocity_max = 18.0
	_sand.gravity = Vector3(0, -0.5, 0)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.03, 0.6, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.68, 0.45, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.material = mat
	_sand.mesh = streak
	_sand.particle_flag_align_y = true  # streaks point along the wind
	add_child(_sand)


## What happens on `day`: {"storm": {"start", "end", "dir"}} if a storm blows
## (dir: the angle the wind comes from) and {"raid": {"outpost", "hour", "size"}}
## if one of the `outposts` (claimed outpost indices) is raided.
static func plan_for(seed_value: int, d: int, outposts: Array, no_mutants := false) -> Dictionary:
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("events:%d:%d" % [seed_value, d])
	var storm_roll := rng.randf()
	var start := snappedf(rng.randf_range(STORM_FROM, STORM_TO), 0.25)
	var length := snappedf(rng.randf_range(STORM_MIN_H, STORM_MAX_H), 0.25)
	var dir := rng.randi_range(0, 7) * TAU / 8.0
	if d >= STORM_FIRST_DAY and storm_roll < STORM_CHANCE:
		out.storm = {"start": start, "end": start + length, "dir": dir}
	var raid_roll := rng.randf()
	var hour := snappedf(rng.randf_range(RAID_FROM, RAID_TO), 0.25)
	if not no_mutants and d >= RAID_FIRST_DAY and not outposts.is_empty() and raid_roll < RAID_CHANCE:
		var pick: int = outposts[rng.randi_range(0, outposts.size() - 1)]
		out.raid = {"outpost": pick, "hour": hour, "size": raid_size_for(d)}
	return out


## Raiders that come for an outpost on day d.
static func raid_size_for(d: int) -> int:
	return mini(3 + d / 4, 8)


## Mutants that come in with a storm on day d.
static func storm_size_for(d: int) -> int:
	return mini(4 + d / 4, 10)


## How strong the storm is at `hour` (0 outside it, 1 in the thick of it).
static func strength_at(storm: Dictionary, hour: float) -> float:
	if storm.is_empty() or hour < storm.start or hour > storm.end:
		return 0.0
	return clampf(minf(hour - storm.start, storm.end - hour) / STORM_RAMP, 0.0, 1.0)


## "the south-west"
static func dir_name(angle: float) -> String:
	return DIRS[posmod(int(round(angle / (TAU / 8.0))), 8)]


func claimed_outposts() -> Array:
	var out: Array = []
	if oases:
		for i in oases.list.size():
			if oases.list[i].claimed:
				out.append(i)
	return out


## Plans day d (each morning, and on a new game or a load).
func plan_day(d: int) -> void:
	day = d
	plan = plan_for(world_seed, d, claimed_outposts(), peaceful)
	warned = false
	storm_spawned = false
	raid_state = ""
	raid_size = 0
	drifts = 0


func on_morning(d: int) -> void:
	plan_day(d)


func storm_now() -> bool:
	return strength > 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = TICK
		tick(TICK)
	if _sand.emitting and player:
		var wind := _wind()
		_sand.direction = wind
		_sand.global_position = player.global_position + Vector3(0, 1.5, 0) - wind * 12.0


## The way the storm blows (from plan.storm.dir towards the other side).
func _wind() -> Vector3:
	var a: float = plan.storm.dir if plan.has("storm") else 0.0
	return -Vector3(cos(a), 0, sin(a))


## One update (four times a second).
func tick(dt: float) -> void:
	if day_night == null:
		return
	if day != day_night.day:
		plan_day(day_night.day)
	var hour: float = day_night.hour
	_storm_tick(dt, hour)
	_raid_tick(hour)


func _storm_tick(dt: float, hour: float) -> void:
	var storm: Dictionary = plan.get("storm", {})
	var was := strength
	strength = strength_at(storm, hour)
	if not storm.is_empty() and not warned and hour >= storm.start - STORM_WARN and hour < storm.end:
		warned = true
		message.emit("A sandstorm is coming from the %s! You won't see far, and mutants come with it." % dir_name(storm.dir))
	_apply_look()
	if mutants:
		mutants.storm = strength > 0.5
	if strength >= 0.5 and not storm_spawned:
		storm_spawned = true
		spawn_storm_band()
	if strength > 0.0:
		_silt_t -= dt
		if _silt_t <= 0.0:
			_silt_t = SILT_EVERY
			drift()
	elif was > 0.0:
		var gone := send_off("storm")
		message.emit("The sandstorm has passed." + (" The mutants in it sank back into the sand." if gone > 0 else ""))


## Sky, fog, wind and blowing sand for the storm's strength.
func _apply_look() -> void:
	if day_night:
		day_night.dust = strength
	if ambience:
		ambience.storm = strength
	_sand.emitting = strength > 0.15
	if env == null:
		return
	if strength > 0.0:
		if not _fogged:
			_fogged = true
			_base_fog = env.fog_density
			_base_sky = env.fog_sky_affect
		env.fog_density = lerpf(_base_fog, STORM_FOG, strength)
		env.fog_sky_affect = lerpf(_base_sky, STORM_SKY_FOG, strength)
	elif _fogged:
		_fogged = false
		env.fog_density = _base_fog
		env.fog_sky_affect = _base_sky


## The storm's band of mutants: they come in on the wind and head for the main well.
func spawn_storm_band() -> int:
	if mutants == null or peaceful or not plan.has("storm"):
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("storm-band:%d:%d" % [world_seed, day])
	var a: float = plan.storm.dir
	var from := Vector3(cos(a), 0, sin(a))
	var side := from.cross(Vector3.UP)
	var n := storm_size_for(day)
	var well := Raids.well_goal()
	for i in n:
		var p := from * (STORM_SPAWN_R + rng.randf_range(-6, 6)) + side * rng.randf_range(-25, 25)
		var m = mutants.spawn(STORM_KINDS[rng.randi_range(0, STORM_KINDS.size() - 1)], p)
		m.make_hunter(well)
		m.event = "storm"
	return n


## Mutants an event sent (kind: "storm" or "raid") that are still about.
func band(kind: String) -> Array:
	if mutants == null:
		return []
	return mutants.alive().filter(func(m): return m.event == kind)


## Sends an event's mutants off: they sink into the sand. Returns how many.
func send_off(kind: String) -> int:
	var list := band(kind)
	for m in list:
		m.crumble()
	return list.size()


## One gust of drifting sand: SILT_CELLS dug cells (not under or right next to
## a building piece) fill a step. Returns how many did.
func drift() -> int:
	if terrain == null:
		return 0
	var cells: Array = terrain.dug_cells()
	if cells.is_empty():
		return 0
	cells.sort()  # the scan's order is fixed, but keep the pick independent of it
	var keep: Array = []
	if building:
		for key in building.pieces:  # every piece (a few hundred), every SILT_EVERY s in a storm
			var rec: Dictionary = building.pieces[key]
			if rec.slot.level == 0 and is_instance_valid(rec.node):
				keep.append(Vector2(rec.node.global_position.x, rec.node.global_position.z))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("drift:%d:%d:%d" % [world_seed, day, drifts])
	drifts += 1
	var done := 0
	var tries := 0
	while done < SILT_CELLS and tries < SILT_CELLS * 4 and not cells.is_empty():
		tries += 1
		var i := rng.randi_range(0, cells.size() - 1)
		var c: Vector2 = cells[i]
		cells.remove_at(i)
		if keep.any(func(k): return k.distance_to(c) < SILT_KEEP):
			continue
		if terrain.silt(c.x, c.y):
			done += 1
	return done


func _raid_tick(hour: float) -> void:
	if not plan.has("raid") or oases == null:
		return
	var r: Dictionary = plan.raid
	match raid_state:
		"":
			if hour >= r.hour and hour < RAID_END:
				start_raid()
		"on":
			if band("raid").is_empty():
				raid_state = "won"
				var cash: int = RAID_PAY + RAID_PAY_EACH * raid_size
				paid.emit(cash)
				message.emit("You drove the raiders off outpost %d! +$%d" % [int(r.outpost) + 1, cash])
			elif hour >= RAID_END or day_night.is_night():
				raid_state = "gone"
				send_off("raid")
				message.emit("The raiders at outpost %d slunk off into the dusk." % (int(r.outpost) + 1))


## The raid starts: a band of mutants heads for the outpost's flag.
func start_raid() -> int:
	var r: Dictionary = plan.raid
	var i: int = r.outpost
	if i < 0 or i >= oases.list.size() or not oases.list[i].claimed:
		raid_state = "gone"
		return 0
	var post: Vector3 = oases.list[i].post_pos
	var goal := Vector3(post.x, 0, post.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("raid-band:%d:%d" % [world_seed, day])
	var a := rng.randf() * TAU
	var from := Vector3(cos(a), 0, sin(a))
	var side := from.cross(Vector3.UP)
	raid_size = int(r.size)
	for k in raid_size:
		var p := goal + from * (RAID_SPAWN_R + rng.randf_range(-4, 4)) + side * (k - (raid_size - 1) * 0.5) * 2.5
		var kinds: Array = RAID_KINDS if day >= 8 else RAID_KINDS.slice(0, 5)
		var m = mutants.spawn(kinds[rng.randi_range(0, kinds.size() - 1)], p)
		m.make_hunter(goal, goal)  # they stay at the outpost
		m.event = "raid"
	raid_state = "on"
	message.emit("Mutants are raiding outpost %d (%s)! Drive them off before they wreck it." % [i + 1, _dir_text(goal)])
	return raid_size


## "1.2 km north-east" style direction from the player to p.
func _dir_text(p: Vector3) -> String:
	if player == null:
		return "out in the desert"
	var to := p - player.global_position
	var deg := fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	return "%d m %s" % [int(Vector2(to.x, to.z).length()), names[int(round(deg / 45.0)) % 8]]


## A Behemoth tonight? (for the dusk warning)
func boss_tonight() -> bool:
	return waves != null and not waves.peaceful and Waves.boss_night(waves.wave + 1)


## At dusk: the siren and, on a Behemoth's night, a warning.
func on_dusk(_d: int) -> void:
	if boss_tonight():
		message.emit("The ground shakes. A Behemoth walks with tonight's wave!")


func bosses() -> Array:
	if mutants == null:
		return []
	return mutants.alive().filter(func(m): return m.type == "behemoth")


## A mutant died: a Behemoth leaves its loot behind.
func on_killed(m: Node) -> void:
	if m.type == "behemoth":
		spilled.emit(BOSS_LOOT.duplicate(), m.global_position + Vector3(0, 0.3, 0))
		message.emit("The Behemoth is down! It left a pile of scrap behind.")


## The HUD line under the clock ("" when nothing is going on).
func hud_text() -> String:
	var lines: Array = []
	var storm: Dictionary = plan.get("storm", {})
	if strength > 0.0:
		lines.append("Sandstorm")
	elif warned and not storm.is_empty() and day_night and day_night.hour < storm.start:
		lines.append("Sandstorm at %d:%02d" % [int(storm.start), int(fmod(storm.start, 1.0) * 60.0)])
	if raid_state == "on":
		lines.append("Raid on outpost %d: %d left" % [int(plan.raid.outpost) + 1, band("raid").size()])
	for b in bosses():
		lines.append("Behemoth: %d hp" % int(ceil(b.health)))
	return "\n".join(lines)


func save_data() -> Dictionary:
	return {"day": day, "warned": warned, "storm_spawned": storm_spawned, "raid": raid_state, "raid_size": raid_size, "drifts": drifts}


## Older saves (no events) plan the day they load into.
func load_data(data: Dictionary) -> void:
	var d: int = day_night.day if day_night else 1
	plan_day(d)
	var dd = data.get("day", -1)
	if not (dd is int or dd is float) or int(dd) != d:
		return  # saved on another day (or an older save): today starts fresh
	var w = data.get("warned", false)
	warned = w is bool and w
	var s = data.get("storm_spawned", false)
	storm_spawned = s is bool and s
	var r = data.get("raid", "")
	raid_state = r if r in ["", "on", "won", "gone"] else ""
	var n = data.get("raid_size", 0)
	raid_size = clampi(int(n), 0, 20) if (n is int or n is float) else 0
	var dr = data.get("drifts", 0)
	drifts = maxi(int(dr), 0) if (dr is int or dr is float) else 0

extends RefCounted
## v2.9: the base status page (J). One line for every machine, furnace and
## generator you have built (and since v2.9.2 every turret and floodlight, with
## electric fences grouped into one line per state): where it stands and whether it is working, and if
## not, why ("no logs loaded", "its generator is out of fuel", "a switch on its
## cable is off", "full: the chest next to it is full too"...). The reasons use
## the same rules the machines run on (building.gd, power.gd, furnace.gd,
## purifier.gd, chest_feed.gd), so the page can't say something the game doesn't do.
## base_status_ui.gd draws the lines; this script only works them out.

const Items = preload("res://scripts/items.gd")
const Furnace = preload("res://scripts/furnace.gd")
const Purifier = preload("res://scripts/purifier.gd")
const ChestFeed = preload("res://scripts/chest_feed.gd")
const Water = preload("res://scripts/water.gd")

## States, worst first (the page lists problems at the top).
const STUCK := "stuck"      # can't work until you do something
const IDLE := "idle"        # nothing to do, nothing wrong (an empty furnace, a generator standing by)
const RUNNING := "running"
const ORDER := [STUCK, IDLE, RUNNING]

const DEFENCES := ["turret", "floodlight", "electric_fence"]
const LOW_AMMO := 40        # a turret with fewer rounds than this is flagged (about 9 s of firing)

const COMPASS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]


## Every entry: {"key", "name", "where", "state", "text", "spots"}, problems first, then
## by distance from the base. "spots" holds where each piece of the line stands
## (one for most, every piece for a fence line), for the map's marks (v2.9.3).
## Runs only while the page or the map is open (four times a
## second), over the machines, furnaces, generators and defences (a few hundred
## at most, most of them fence pieces) plus a few walks of the cables.
static func entries(building, water = null, oases = null) -> Array:
	var out: Array = []
	if building == null:
		return out
	var power := power_reach(building)
	var springs: Array = oases.claimed_springs() if oases != null else []
	var fences := {}  # state + text -> one grouped entry
	for key in building.keys_of(building.MACHINES.keys() + ["furnace", "generator"] + DEFENCES):
		var rec: Dictionary = building.pieces.get(key, {})
		if rec.is_empty() or not is_instance_valid(rec.get("node")):
			continue
		var st: Array
		match rec.type:
			"furnace":
				st = furnace_state(building, rec)
			"generator":
				st = generator_state(building, rec)
			"turret":
				st = turret_state(building, rec, key, power)
			"floodlight", "electric_fence":
				st = powered_state(rec, key, power)
			_:
				st = machine_state(building, water, rec, key, power, springs)
		var dist := Vector2(rec.node.global_position.x, rec.node.global_position.z).length()
		if rec.type == "electric_fence":
			# A fence is many short pieces: one line per state, placed at the nearest piece.
			var gid: String = st[0] + "|" + st[1]
			if not fences.has(gid):
				fences[gid] = {"key": key, "keys": [], "spots": [], "name": "", "where": "", "state": st[0], "text": st[1], "dist": INF}
			var grp: Dictionary = fences[gid]
			grp.keys.append(key)
			grp.spots.append(rec.node.global_position)
			if dist < grp.dist:
				grp.dist = dist
				grp.key = key
				grp.where = where(rec.node.global_position, oases)
			continue
		out.append({"key": key, "name": building.PIECES[rec.type].name, "where": where(rec.node.global_position, oases),
				"state": st[0], "text": st[1], "dist": dist, "spots": [rec.node.global_position]})
	for grp in fences.values():
		var n: int = grp.keys.size()
		grp.name = "Electric fence" if n == 1 else "Electric fence (%d pieces)" % n
		if n > 1:
			grp.where = "nearest " + grp.where
		out.append(grp)
	out.sort_custom(func(a, b):
		var ra := ORDER.find(a.state)
		var rb := ORDER.find(b.state)
		return ra < rb if ra != rb else a.dist < b.dist)
	return out


## v2.9.3: the map's red marks: one {"pos", "name", "text", "first"} for every
## piece on a stuck line (each piece of a stuck fence line), in the page's
## order; "first" marks the first piece of each line (the map names that one).
static func problem_marks(list: Array) -> Array:
	var out: Array = []
	for e in list:
		if e.state != STUCK:
			continue
		var spots: Array = e.get("spots", [])
		for i in spots.size():
			out.append({"pos": spots[i], "name": e.name, "text": e.text, "first": i == 0})
	return out


## "3 machines: 1 running, 1 stuck, 1 idle" (or that there are none yet).
static func summary(list: Array) -> String:
	if list.is_empty():
		return "No machines, defences, furnaces or generators built yet"
	var n := {STUCK: 0, IDLE: 0, RUNNING: 0}
	for e in list:
		n[e.state] += 1
	var parts: Array = []
	for s in [RUNNING, STUCK, IDLE]:
		if n[s] > 0:
			parts.append("%d %s" % [n[s], s])
	return "%d %s: %s" % [list.size(), "piece" if list.size() == 1 else "pieces", ", ".join(parts)]


## What power could reach, keyed by piece: "fuel" if a generator with fuel
## would power it when it runs, "empty" if only generators without fuel are
## joined to it, "switch" if fuel is there but a switch on the way is off.
static func power_reach(building) -> Dictionary:
	var gens: Array = building.keys_of(["generator"])
	var fueled: Array = gens.filter(func(k): return float(building.pieces[k].get("fuel", 0.0)) > 0.0)
	var out := {}
	var through: Dictionary = building.power_network(fueled, true)
	for k in through:
		out[k] = "switch"
	for k in building.power_network(gens, true):
		if not out.has(k):
			out[k] = "empty"
	for k in building.power_network(fueled):
		out[k] = "fuel"
	# Plugged straight in: within PLUG_RANGE of a generator, no cable needed
	# (power.gd's rule; machines and defences, a few hundred at most).
	for mk in building.keys_of(building.MACHINES.keys() + DEFENCES):
		var m: Dictionary = building.pieces[mk]
		if out.get(mk, "") == "fuel" or not is_instance_valid(m.get("node")):
			continue
		for g in gens:
			var gp: Vector3 = building.pieces[g].node.global_position
			if gp.distance_to(m.node.global_position) <= building.PLUG_RANGE:
				out[mk] = "fuel" if float(building.pieces[g].fuel) > 0.0 else out.get(mk, "empty")
				if out[mk] == "fuel":
					break
	return out


## [state, text] for a sawmill, rock crusher, nail press or water purifier.
static func machine_state(building, water, rec: Dictionary, key: String, power: Dictionary, springs: Array = []) -> Array:
	var m: Dictionary = building.MACHINES[rec.type]
	var made := "%d %s ready" % [rec.output, Items.display_name(m.out).to_lower()]
	if rec.input < m.need:
		if rec.type == "purifier":
			return [STUCK, _purifier_dry(water, rec, key, springs)]
		return [STUCK, "empty: load %s with E" % Items.display_name(m.in).to_lower()]
	if rec.output + m.make > building.MACHINE_OUT_MAX:
		if ChestFeed.chest_for(building, rec) != "":
			return [STUCK, "full, and so is the chest next to it: empty the chest"]
		return [STUCK, "full (%s): take them, or set a chest next to it" % made]
	var reach: String = power.get(key, "")
	if not rec.powered and reach != "fuel":
		match reach:
			"switch":
				return [STUCK, "no power: a switch on its cable is off"]
			"empty":
				return [STUCK, "no power: its generator is out of fuel"]
		return [STUCK, "no power: cable it to a generator"]
	var inside := "%d %s in" % [rec.input, "L" if m.in == "litre" else Items.display_name(m.in).to_lower()]
	return [RUNNING, "running: %s, %s" % [inside, made]]


## Why a purifier's tank is empty, from where it could get water.
static func _purifier_dry(water, rec: Dictionary, key: String, springs: Array) -> String:
	var pipe := Purifier.piped(water, key)
	if pipe == "spring" or Purifier.near_spring(rec, springs):
		return "waiting for water from the spring"
	if Purifier.near_well(rec) or pipe == "well":
		return "no water: the main well is empty today" if water != null and water.store < 1.0 else "waiting for water from the main well"
	if water != null and key != "" and not water.pump and not water.pipes_of(key).is_empty():
		return "no water: its pipes need the main well's hand pump"
	return "no water: set it by the main well or a spring, pipe it, or pour a can in"


## [state, text] for a furnace (furnace.gd's rules).
static func furnace_state(building, rec: Dictionary) -> Array:
	var fuel := "fuel %d:%02d" % [int(rec.heat) / 60, int(rec.heat) % 60]
	if rec.smelt == "":
		if Furnace.made_total(rec) > 0:
			return [IDLE, "done: %d made, take them with E" % Furnace.made_total(rec)]
		return [IDLE, "nothing loaded (%s)" % fuel]
	var s: Dictionary = Furnace.SMELT[rec.smelt]
	var what := "%s to %s" % [Items.display_name(rec.smelt).to_lower(), Items.display_name(s.out).to_lower()]
	if Furnace.can_work(rec):
		return [RUNNING, "smelting %s, %s" % [what, fuel]]
	if rec.heat <= 0.0:
		return [STUCK, "out of fuel with %d %s in: burn wood or logs in it" % [rec.load, Items.display_name(rec.smelt).to_lower()]]
	if Furnace.made_total(rec) + int(s.make) > Furnace.MADE_MAX:
		if ChestFeed.chest_for(building, rec) != "":
			return [STUCK, "full, and so is the chest next to it: empty the chest"]
		return [STUCK, "full: take what's ready, or set a chest next to it"]
	return [STUCK, "needs %d %s to go on (%d in)" % [int(s.need), Items.display_name(rec.smelt).to_lower(), rec.load]]


## [state, text] for an auto-turret (turrets.gd): it fires without power, so
## only its rounds can stop it; power only makes it turn and fire faster.
static func turret_state(building, rec: Dictionary, key: String, power: Dictionary) -> Array:
	var rounds := "%d/%d rounds" % [rec.ammo, building.TURRET_AMMO]
	if rec.ammo <= 0:
		return [STUCK, "no rounds: load 9mm ammo with E"]
	if rec.ammo < LOW_AMMO:
		return [STUCK, "low, %s: load 9mm ammo with E" % rounds]
	if rec.get("powered", false):
		return [RUNNING, "ready, %s, on power (aims and fires faster)" % rounds]
	match power.get(key, ""):
		"fuel":
			return [RUNNING, "ready, %s (power at night makes it faster)" % rounds]
		"switch":
			return [RUNNING, "ready, %s (a switch on its cable is off: power makes it faster)" % rounds]
		"empty":
			return [RUNNING, "ready, %s (its generator is out of fuel: power makes it faster)" % rounds]
	return [RUNNING, "ready, %s (no power: a cable to a generator makes it faster)" % rounds]


## [state, text] for a floodlight or electric fence: they only work on power,
## and generators only run at night or in a wave (power.gd).
static func powered_state(rec: Dictionary, key: String, power: Dictionary) -> Array:
	var on := "lit" if rec.type == "floodlight" else "live"
	if rec.get("powered", false):
		return [RUNNING, on]
	match power.get(key, ""):
		"fuel":
			return [IDLE, "ready: its generator has fuel and runs at night and in waves"]
		"switch":
			return [STUCK, "no power: a switch on its cable is off"]
		"empty":
			return [STUCK, "no power: its generator is out of fuel"]
	return [STUCK, "no power: cable it to a generator"]


## [state, text] for a fuel generator.
static func generator_state(building, rec: Dictionary) -> Array:
	var cans := ceili(float(rec.fuel))
	var tank := "%d/%d cans" % [cans, int(building.GEN_TANK)]
	if rec.fuel <= 0.0:
		return [STUCK, "out of fuel: add a fuel can"]
	if rec.get("running", false):
		return [RUNNING, "running, %s" % tank]
	return [IDLE, "standing by, %s (runs at night, in a wave, or when a machine has work)" % tank]


## "by the main well", "14 m north-east", or "at outpost 2".
static func where(p: Vector3, oases = null) -> String:
	if oases != null:
		for i in oases.list.size():
			var o: Dictionary = oases.list[i]
			if o.claimed and Vector2(p.x, p.z).distance_to(Vector2(o.post_pos.x, o.post_pos.z)) <= oases.OUTPOST_R:
				return "at outpost %d" % (i + 1)
	var flat := Vector2(p.x, p.z)
	if flat.distance_to(Water.WELL_POS) <= 6.0:
		return "by the main well"
	var d := flat.length()
	if d < 3.0:
		return "by the flag"
	# North is -z (the map's top), east is +x.
	var ang := atan2(flat.x, -flat.y)
	var sector := int(round(fposmod(ang, TAU) / (TAU / 8.0))) % 8
	return "%d m %s" % [int(round(d)), COMPASS[sector]]

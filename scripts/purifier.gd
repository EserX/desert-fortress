extends RefCounted
## v2.8: the water purifier. A machine bought by drone once the desert is 2.5%
## green (with the dew collector) that filters well water into bottles of
## drinking water. It runs on generator power like the sawmill, and like it
## feeds a storage chest next to it (chest_feed.gd).
## Its tank (rec.input, in litres) is filled two ways:
## - set within REACH of the main well, it draws from the well's store by itself
##   (a float valve: no power needed for that), so every litre it takes is a
##   litre that won't green the land today, and counts as water drawn for the
##   night's lure;
## - set within SPRING_REACH of a claimed outpost's spring (v2.8.1), it draws
##   from the spring, which never runs dry and isn't the main well, so it takes
##   nothing from the well and doesn't add to the night's lure;
## - piped (v2.8.3): a water pipe from the main well (with the hand pump, through
##   sprinklers if you like) feeds it from the well's store wherever it stands,
##   like a sprinkler; a pipe from a spring's sprinkler inside an outpost's zone
##   feeds it spring water;
## - E with a watering can pours the can in.
## power.gd calls draw() before each work step; main.gd calls pour_can() and
## prompt() for E. `springs` is oases.gd's claimed_springs() (pond centres).

const Items = preload("res://scripts/items.gd")

## Furthest the purifier's middle may be from the main well's (flat distance).
const REACH := 6.0
## Furthest its middle may be from a claimed outpost's pond centre (the pond is
## 4.5 m across, so this is within about 4.5 m of the water's edge).
const SPRING_REACH := 9.0


## True if the purifier piece `rec` stands close enough to draw from the main well.
static func near_well(rec: Dictionary) -> bool:
	if rec.is_empty() or not is_instance_valid(rec.get("node")):
		return false
	var p: Vector3 = rec.node.global_position
	return Vector2(p.x, p.z).distance_to(preload("res://scripts/water.gd").WELL_POS) <= REACH


## Where a pipe brings the purifier `key` water from: "well", "spring" or "".
static func piped(water, key: String) -> String:
	if water == null or key == "":
		return ""
	if water.spring_purifiers().has(key):
		return "spring"
	if water.fed_purifiers().has(key):
		return "well"
	return ""


## True if the purifier piece `rec` stands by one of `springs` (claimed outposts' pond centres).
static func near_spring(rec: Dictionary, springs: Array) -> bool:
	if rec.is_empty() or not is_instance_valid(rec.get("node")):
		return false
	var p: Vector3 = rec.node.global_position
	for s in springs:
		if s is Vector3 and Vector2(p.x, p.z).distance_to(Vector2(s.x, s.z)) <= SPRING_REACH:
			return true
	return false


## Tops the tank up from the main well's store (whole litres only), or from an
## outpost's spring when it stands by one; `key` is its piece key, for pipes.
## Free spring water comes first. Returns litres drawn.
static func draw(building, water, rec: Dictionary, springs: Array = [], key := "") -> int:
	var pipe := piped(water, key)
	var well := near_well(rec) or pipe == "well"
	if pipe == "spring" or (not near_well(rec) and near_spring(rec, springs)):
		var free: int = building.MACHINE_IN_MAX - int(rec.input)
		if free > 0:
			rec.input += free  # a spring never runs dry and isn't the main well's store
		return maxi(free, 0)
	if water == null or not well:
		return 0
	var n := mini(building.MACHINE_IN_MAX - int(rec.input), int(floor(water.store)))
	if n <= 0:
		return 0
	n = int(water.drain(n))
	rec.input += n
	return n


## E: pours the watering can into the tank. Returns litres poured.
static func pour_can(building, water, rec: Dictionary) -> int:
	if water == null:
		return 0
	var n := mini(building.MACHINE_IN_MAX - int(rec.input), int(floor(water.can + 0.001)))
	if n <= 0:
		return 0
	rec.input += n
	water.can = maxf(water.can - n, 0.0)
	return n


## "Water purifier (running): 24 L in the tank, 3 bottles ready, drawing from the main well"
static func prompt(building, water, rec: Dictionary, has_can: bool, springs: Array = [], key := "") -> String:
	var m: Dictionary = building.MACHINES.purifier
	# A generator only runs by day while a machine has work, so an empty tank
	# is said first: "no power" would send you looking for a cable that's fine.
	var state := "running"
	if rec.input < m.need:
		state = "waiting for water"
	elif rec.output + m.make > building.MACHINE_OUT_MAX:
		state = "full"
	elif not rec.powered:
		state = "no power: cable it to a generator"
	var text := "Water purifier (%s): %d L in the tank, %d %s ready" % [state, rec.input, rec.output, "bottle" if rec.output == 1 else "bottles"]
	var near := near_well(rec)
	var pipe := piped(water, key)
	if pipe == "spring" or (not near and near_spring(rec, springs)):
		near = true
		text += ", drawing from the outpost's spring" + (" through a pipe" if pipe == "spring" else "")
	elif near:
		text += ", drawing from the main well"
	elif pipe == "well":
		near = true
		text += ", piped from the main well"
	elif water != null and key != "" and not water.pump and not water.pipes_of(key).is_empty():
		near = true
		text += ", piped to the main well, but the pipes need its hand pump (shop: base upgrades)"
	if preload("res://scripts/chest_feed.gd").chest_for(building, rec) != "":
		text += ", feeding the chest next to it"
	var acts: Array = []
	if has_can and water != null and water.can >= 1.0 and rec.input < building.MACHINE_IN_MAX:
		acts.append("pour in the watering can (%d L)" % int(floor(water.can + 0.001)))
	if rec.output > 0:
		acts.append("take the water bottles")
	if acts.is_empty():
		var how := "" if near else "\nSet it within %d m of the main well or by an outpost's spring, pipe it from the main well, or pour water in with a watering can" % int(REACH)
		return text + "\n%d L make a bottle of drinking water every %d s" % [m.need, int(m.secs)] + how
	var act: String = ", ".join(acts)
	return text + "\n[E] " + act.left(1).to_upper() + act.substr(1)

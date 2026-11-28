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
## - E with a watering can pours the can in (from an oasis spring, say).
## power.gd calls draw() before each work step; main.gd calls pour_can() and
## prompt() for E.

const Items = preload("res://scripts/items.gd")

## Furthest the purifier's middle may be from the main well's (flat distance).
const REACH := 6.0


## True if the purifier piece `rec` stands close enough to draw from the main well.
static func near_well(rec: Dictionary) -> bool:
	if rec.is_empty() or not is_instance_valid(rec.get("node")):
		return false
	var p: Vector3 = rec.node.global_position
	return Vector2(p.x, p.z).distance_to(preload("res://scripts/water.gd").WELL_POS) <= REACH


## Tops the tank up from the main well's store, whole litres only. Returns litres drawn.
static func draw(building, water, rec: Dictionary) -> int:
	if water == null or not near_well(rec):
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
static func prompt(building, water, rec: Dictionary, has_can: bool) -> String:
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
	if near:
		text += ", drawing from the main well"
	if preload("res://scripts/chest_feed.gd").chest_for(building, rec) != "":
		text += ", feeding the chest next to it"
	var acts: Array = []
	if has_can and water != null and water.can >= 1.0 and rec.input < building.MACHINE_IN_MAX:
		acts.append("pour in the watering can (%d L)" % int(floor(water.can + 0.001)))
	if rec.output > 0:
		acts.append("take the water bottles")
	if acts.is_empty():
		var how := "" if near else "\nSet it within %d m of the main well, or pour water in with a watering can" % int(REACH)
		return text + "\n%d L make a bottle of drinking water every %d s" % [m.need, int(m.secs)] + how
	var act: String = ", ".join(acts)
	return text + "\n[E] " + act.left(1).to_upper() + act.substr(1)

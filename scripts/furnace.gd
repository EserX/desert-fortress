extends Node
## v2.2 crafting chain: the furnace. A stone furnace (built in build mode)
## burns wood or logs to smelt what you load into it: scrap into metal plates,
## sand into glass and clay into bricks. Hold what you want to load (or the
## fuel) and press E; E always takes out what is ready. It only burns fuel
## while it has something to smelt and room for what it makes.
## The piece itself (model, hit points, saving its fields) is in building.gd;
## this script does the smelting, the prompt and E.

const Items = preload("res://scripts/items.gd")
const ChestFeed = preload("res://scripts/chest_feed.gd")

## What it smelts: input item -> how many `need` make `make` of `out` in `secs`.
const SMELT := {
	"scrap": {"need": 2, "out": "metal_plate", "make": 1, "secs": 10.0},
	"sand": {"need": 3, "out": "glass", "make": 1, "secs": 8.0},
	"clay": {"need": 2, "out": "brick", "make": 2, "secs": 6.0},
}
## Seconds of burning one piece of fuel gives.
const FUEL := {"wood": 40.0, "log": 120.0}
const HEAT_MAX := 600.0   # seconds of fuel it holds
const LOAD_MAX := 30      # items its hopper takes (one kind at a time)
const MADE_MAX := 40      # finished items it holds before it stops
const TICK := 0.25

var building  # Building
var _t := 0.0
var _flicker := 0.0


## Sets up the furnace fields on a new piece record.
static func init_rec(rec: Dictionary) -> void:
	rec.heat = 0.0
	rec.smelt = ""
	rec.load = 0
	rec.made = {}
	rec.progress = 0.0
	rec.working = false


## Reads the furnace fields back from saved piece data, checking types (a
## broken or hand-edited save falls back to an empty, cold furnace).
static func restore(rec: Dictionary, p: Dictionary) -> void:
	init_rec(rec)
	var heat = p.get("heat", 0.0)
	if heat is float or heat is int:
		rec.heat = clampf(float(heat), 0.0, HEAT_MAX)
	var smelt = p.get("smelt", "")
	var n = p.get("load", 0)
	if smelt is String and SMELT.has(smelt) and (n is float or n is int):
		rec.smelt = smelt
		rec.load = clampi(int(n), 0, LOAD_MAX)
	if rec.load == 0:
		rec.smelt = ""
	var made = p.get("made", {})
	if made is Dictionary:
		var total := 0
		for item in made:
			var c = made[item]
			if item is String and Items.ITEMS.has(item) and (c is float or c is int) and int(c) > 0:
				var k := mini(int(c), MADE_MAX - total)
				if k > 0:
					rec.made[item] = k
					total += k
	var prog = p.get("progress", 0.0)
	if (prog is float or prog is int) and rec.smelt != "":
		rec.progress = clampf(float(prog), 0.0, float(SMELT[rec.smelt].secs))


static func made_total(rec: Dictionary) -> int:
	var n := 0
	for item in rec.made:
		n += int(rec.made[item])
	return n


## True when it can smelt right now (fuel, enough loaded, room for the result).
static func can_work(rec: Dictionary) -> bool:
	if rec.smelt == "" or rec.heat <= 0.0:
		return false
	var s: Dictionary = SMELT[rec.smelt]
	return rec.load >= s.need and made_total(rec) + int(s.make) <= MADE_MAX


## One step of smelting. Returns true while it is busy (and burning fuel).
static func work(rec: Dictionary, dt: float) -> bool:
	if not can_work(rec):
		return false
	var s: Dictionary = SMELT[rec.smelt]
	rec.heat = maxf(rec.heat - dt, 0.0)
	rec.progress += dt
	if rec.progress >= s.secs:
		rec.progress -= s.secs
		rec.load -= int(s.need)
		rec.made[s.out] = int(rec.made.get(s.out, 0)) + int(s.make)
		if rec.load <= 0:
			rec.load = 0
			rec.smelt = ""
			rec.progress = 0.0
	return true


## E at a furnace holding `held`: takes out what is ready, then loads what you
## hold (fuel, or something to smelt). Returns pickup lines (or one line
## starting with "!" for a banner when nothing happened).
static func use(rec: Dictionary, inventory, held: String) -> Array:
	var lines: Array = []
	# Take out what is ready (what doesn't fit stays in).
	for item in rec.made.keys():  # a copy: entries are erased below
		var n := int(rec.made[item])
		var left: int = inventory.add(item, n)
		if n - left > 0:
			lines.append("+%d %s" % [n - left, Items.display_name(item)])
		if left > 0:
			rec.made[item] = left
		else:
			rec.made.erase(item)
	if FUEL.has(held):
		var per: float = FUEL[held]
		var n := 0
		while inventory.count_of(held) > 0 and rec.heat + per <= HEAT_MAX:
			inventory.remove(held, 1)
			rec.heat += per
			n += 1
		if n > 0:
			lines.append("Burning %d %s in the furnace" % [n, Items.display_name(held).to_lower()])
		elif lines.is_empty():
			lines.append("!The furnace has all the fuel it holds")
	elif SMELT.has(held):
		if rec.smelt != "" and rec.smelt != held and rec.load > 0:
			if lines.is_empty():
				lines.append("!The furnace is smelting %s: wait till it's done" % Items.display_name(rec.smelt).to_lower())
		else:
			var n := mini(inventory.count_of(held), LOAD_MAX - int(rec.load))
			if n > 0:
				if rec.smelt != held:
					rec.progress = 0.0
				rec.smelt = held
				inventory.remove(held, n)
				rec.load += n
				lines.append("Loaded %d %s into the furnace" % [n, Items.display_name(held).to_lower()])
			elif lines.is_empty():
				lines.append("!The furnace is full")
	elif lines.is_empty():
		lines.append("!Hold scrap, sand or clay to smelt, or wood or logs to burn, and press E")
	return lines


## "Furnace (smelting clay to bricks): 8 clay in, 4 bricks ready, fuel 2:40
## [E] Load sand, take the bricks"
## With `building` given, it also says when a chest next to it takes the goods.
static func prompt(rec: Dictionary, held: String, building = null) -> String:
	var state := "cold"
	if rec.smelt != "":
		var s: Dictionary = SMELT[rec.smelt]
		var what := "%s to %s" % [Items.display_name(rec.smelt).to_lower(), Items.display_name(s.out).to_lower()]
		if can_work(rec):
			state = "smelting " + what
		elif rec.heat <= 0.0:
			state = "out of fuel"
		elif made_total(rec) + int(s.make) > MADE_MAX:
			state = "full: take what's ready"
		else:
			state = "needs %d %s" % [int(s.need), Items.display_name(rec.smelt).to_lower()]
	var text := "Furnace (%s)" % state
	if rec.load > 0:
		text += ": %d %s in" % [rec.load, Items.display_name(rec.smelt).to_lower()]
	var ready: Array = []
	for item in rec.made:
		ready.append("%d %s" % [rec.made[item], Items.display_name(item).to_lower()])
	if not ready.is_empty():
		text += ", " + ", ".join(ready) + " ready"
	text += ", fuel %d:%02d" % [int(rec.heat) / 60, int(rec.heat) % 60]
	if building != null and ChestFeed.chest_for(building, rec) != "":
		text += ", feeding the chest next to it"
	var acts: Array = []
	if FUEL.has(held):
		acts.append("burn %s" % Items.display_name(held).to_lower())
	elif SMELT.has(held) and (rec.smelt == "" or rec.smelt == held or rec.load == 0):
		acts.append("load %s" % Items.display_name(held).to_lower())
	if not rec.made.is_empty():
		acts.append("take what's ready")
	if acts.is_empty():
		return text + "\nHold scrap, sand or clay to smelt, wood or logs to burn: 2 scrap make a metal plate, 3 sand a glass, 2 clay 2 bricks"
	var act: String = ", ".join(acts)
	return text + "\n[E] " + act.left(1).to_upper() + act.substr(1)


func _process(delta: float) -> void:
	if building == null:
		return
	_flicker += delta
	for key in building.keys_of(["furnace"]):  # every frame, the furnaces only (a handful)
		var rec: Dictionary = building.pieces[key]
		if rec.has("glow") and rec.glow.visible:
			var f := 1.0 + sin(_flicker * 11.0 + rec.node.position.x) * 0.1
			rec.glow.get_child(rec.glow.get_child_count() - 1).light_energy = 1.6 * f
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	tick(TICK)


## Smelts in every furnace. Four times a second, over the furnaces only.
func tick(dt: float) -> void:
	for key in building.keys_of(["furnace"]):
		var rec: Dictionary = building.pieces.get(key, {})
		if rec.is_empty():
			continue
		rec.working = work(rec, dt)
		ChestFeed.feed(building, rec)  # v2.7: into a chest next to it
		if rec.has("glow") and rec.glow.visible != rec.working:
			rec.glow.visible = rec.working

extends Node
## Green and livable (v1.17).
## The **green %** says how much of the whole desert you have turned green (the
## green of every ground square added up, over all the squares of the map). The
## **livable** score (0 to 100) says how good a place the base is to live: five
## parts of up to 20 points each (shade, water, food, plants, shelter), counted
## inside the build zone. Livable milestones give comforts while the score holds:
## faster healing at the base, resting through the midday heat there, and
## buildings that mend a little each morning.
## Green land also spreads on its own: a fully green square keeps the sand round
## it turning to soil, and grown date palms drop saplings on watered soil nearby.

const Water = preload("res://scripts/water.gd")
const Farming = preload("res://scripts/farming.gd")
const Building = preload("res://scripts/building.gd")

const PART_MAX := 20.0
const PARTS := ["shade", "water", "food", "plants", "shelter"]
const PART_NAMES := {"shade": "Shade", "water": "Water", "food": "Food", "plants": "Plants", "shelter": "Shelter"}
## Livable milestones: the score they need, a name and the comfort they give.
const LEVELS := [
	{"at": 25, "name": "Settled", "text": "you heal twice as fast at the base", "short": "heal twice as fast at the base"},
	{"at": 50, "name": "Cool camp", "text": "you rest through the midday heat at the base", "short": "no midday heat at the base"},
	{"at": 75, "name": "Homestead", "text": "your buildings mend a little every morning", "short": "buildings mend every morning"},
]
const HEAL_MULT := 2.0        # health regained this many times faster at a "Settled" base
const MEND := 0.1             # share of its hit points a piece gets back each morning at a "Homestead"
const PALM_SHADE := 4.0       # shade points for a grown date palm in the zone
const ROOF_SHADE := 2.0       # and for a roof
const FOOD_PLANT := 2.5       # food points for a living food plant
const FIRE_FOOD := 3.0        # and for a fire pit to cook on
const GREEN_PLANTS := 2.0     # plant points for each fully green square in the zone
const FOOD_CROPS := ["millet", "melon", "date_palm", "dragon_fruit", "olive", "prickly_pear"]
const SHELTER_TYPES := ["wall", "doorway", "window", "slit_wall", "metal_door", "half_wall", "floor", "roof", "trapdoor", "tri_roof"]
const SPREAD_SOIL := 2.0      # litres towards soil a fully green square gives each square next to it a morning
const SPREAD_GREEN := 0.05    # and green (less than a dry morning takes, so it needs your water to go green)
const SPROUT_CHANCE := 0.3    # chance a grown date palm drops a sapling each morning
const SPROUT_REACH := 2       # spots (2 m) away from the palm
const MAX_SPROUTS := 3        # new saplings a morning, all palms together
const REFRESH := 1.0          # seconds between score updates

signal message(text: String)

var water  # Water
var farming  # Farming
var building  # Building
var survival  # Survival (the comforts)
var player  # Player
var day_night  # DayNight (the day seeds where saplings fall)
var world_seed := 1337
## Best milestone reached so far (0 = none, 1 = Settled...), so each one is announced once.
var reached := 0
## The latest score, worked out every REFRESH seconds.
var parts := {}
var score := 0
## The next green milestone's % (goals.gd, v1.19), shown on the HUD; -1 for none.
var next_goal := -1.0
var _wait := 0.0
static var _land := 0


func _ready() -> void:
	refresh(false)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = REFRESH
		refresh()
	_apply_comforts()


## Ground squares on the whole map (a square counts if its centre is on the map).
static func land_squares() -> int:
	if _land == 0:
		var n := int(ceil(225.0 / Water.CELL)) + 1
		for x in range(-n, n + 1):  # once per run: about 13,000 squares
			for z in range(-n, n + 1):
				if Water.cell_center(Vector2i(x, z)).length() <= 225.0:
					_land += 1
	return _land


## How much of the desert is green, 0 to 100.
func green_percent() -> float:
	return water.green_total() / float(land_squares()) * 100.0 if water else 0.0


func _in_zone(p: Vector2) -> bool:
	return p.length() <= building.zone_radius


## Pieces of these types inside the base's build zone (not at outposts).
func _zone_keys(types: Array) -> Array:
	return building.keys_of(types).filter(func(k):
		var p: Vector3 = building.pieces[k].node.global_position
		return _in_zone(Vector2(p.x, p.z)))


## The five parts of the livable score, each 0 to PART_MAX.
func compute_parts() -> Dictionary:
	var palms := 0
	var food := 0
	# Every plant, once a second (a few dozen to a few hundred).
	for s in farming.plants:
		var e: Dictionary = farming.plants[s]
		if e.dead or not _in_zone(Farming.spot_center(s)):
			continue
		if e.crop == "date_palm" and farming.is_grown(e):
			palms += 1
		if e.crop in FOOD_CROPS:
			food += 1
	var green := 0.0
	# Every watered square, once a second (a few hundred at most).
	for c in water.cells:
		if _in_zone(Water.cell_center(c)):
			green += float(water.cells[c].green)
	var roofs: int = _zone_keys(["roof", "tri_roof"]).size()
	var shelter: int = _zone_keys(SHELTER_TYPES).size()
	if not _zone_keys(["chest"]).is_empty():
		shelter += 2
	if not _zone_keys(["workbench"]).is_empty():
		shelter += 2
	var wells: int = _zone_keys(["well"]).size()
	var wet: float = 6.0 + (water.capacity - Water.STORE_BASE) / 200.0 * 3.0 + (3.0 if water.pump else 0.0) + 2.0 * wells
	var out := {
		"shade": palms * PALM_SHADE + roofs * ROOF_SHADE,
		"water": wet,
		"food": food * FOOD_PLANT + (FIRE_FOOD if not _zone_keys(["fire_pit"]).is_empty() else 0.0),
		"plants": green * GREEN_PLANTS,
		"shelter": float(shelter),
	}
	for k in out:
		out[k] = clampf(round(out[k]), 0.0, PART_MAX)
	return out


## The milestone a score reaches (0 = none, 1 = Settled, 2 = Cool camp, 3 = Homestead).
static func level_of(points: int) -> int:
	var lv := 0
	for i in LEVELS.size():
		if points >= LEVELS[i].at:
			lv = i + 1
	return lv


func level() -> int:
	return level_of(score)


## Works the score out again. A milestone reached for the first time is announced.
func refresh(announce := true) -> void:
	if water == null or farming == null or building == null:
		return
	parts = compute_parts()
	score = 0
	for k in parts:
		score += int(parts[k])
	var lv := level()
	if lv > reached:
		if announce:
			var m: Dictionary = LEVELS[lv - 1]
			message.emit("Livable %d: %s! Now %s" % [m.at, m.name, m.text])
		reached = lv


## True when the player is inside the build zone.
func at_base() -> bool:
	return player != null and building != null and _in_zone(Vector2(player.global_position.x, player.global_position.z))


func _apply_comforts() -> void:
	if survival == null:
		return
	var home := at_base()
	survival.regen_mult = HEAL_MULT if home and level() >= 1 else 1.0
	survival.heat_shelter = home and level() >= 2


## "Livable 35 / 100" and the comfort it gives, for the map.
func summary_lines() -> Array:
	var lines: Array = ["Green: %s of the desert" % percent_text(), "Livable base: %d / 100" % score]
	for k in PARTS:
		lines.append("   %s  %d / %d" % [PART_NAMES[k], int(parts.get(k, 0)), int(PART_MAX)])
	lines.append("")
	for i in LEVELS.size():
		var m: Dictionary = LEVELS[i]
		lines.append("%s %d %s: %s" % ["[x]" if level() > i else "[ ]", m.at, m.name, m.short])
	return lines


func percent_text() -> String:
	var p := green_percent()
	return ("%.2f%%" % p) if p < 1.0 else ("%.1f%%" % p)


## For the HUD: "Green 0.4% / 1%   Livable 35" (with the next green milestone).
func hud_text() -> String:
	var goal := (" / %s%%" % str(next_goal).trim_suffix(".0")) if next_goal > 0.0 else ""
	return "Green %s%s   Livable %d" % [percent_text(), goal, score]


# --- Mornings ---------------------------------------------------------------------

## New day (water.gd's morning_tally, before the squares' litres are cleared):
## green land spreads and palms drop saplings.
func on_tally() -> void:
	spread_green()
	sprout_palms(day_night.day if day_night else 0)


## Every fully green square gives the squares next to it a little soil and green.
## Returns how many squares it reached.
func spread_green() -> int:
	var targets := {}
	# Once a day over every watered square (a few hundred at most); collected
	# first, because add_life adds new squares.
	for c in water.cells.keys():
		if float(water.cells[c].green) < 0.999:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if water.green_of(n) < 0.999:
				targets[n] = true
	for n in targets:
		water.add_life(n, SPREAD_SOIL, SPREAD_GREEN)
	return targets.size()


## Grown date palms drop saplings on watered soil near them (seeded by the world
## and the day, so the same world grows the same grove). Returns the new spots.
func sprout_palms(day: int) -> Array:
	var palms: Array = []
	for s in farming.plants:  # once a day, every plant
		var e: Dictionary = farming.plants[s]
		if e.crop == "date_palm" and farming.is_grown(e):
			palms.append(s)
	palms.sort()
	var out: Array = []
	for s in palms:
		if out.size() >= MAX_SPROUTS:
			break
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("sprout:%d:%d:%d:%d" % [world_seed, day, s.x, s.y])
		if rng.randf() >= SPROUT_CHANCE:
			continue
		for t in 4:  # a few tries at a free, watered spot
			var o: Vector2i = s + Vector2i(rng.randi_range(-SPROUT_REACH, SPROUT_REACH), rng.randi_range(-SPROUT_REACH, SPROUT_REACH))
			if o == s or water.cell_info(Farming.cell_of_spot(o)).wet < Water.DAY_NEED - 0.001:
				continue
			if farming.sprout(o, "date_palm"):
				out.append(o)
				break
	if not out.is_empty():
		message.emit("Your date palms dropped %d sapling%s" % [out.size(), "" if out.size() == 1 else "s"])
	return out


## New day: at a Homestead, every building mends a little.
func on_morning(_day := 0) -> void:
	refresh()
	if level() >= 3:
		building.mend_all(MEND)


# --- Saving ------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"reached": reached}


## Older saves (no "livable"): milestones already passed are taken as announced.
func load_data(data: Dictionary) -> void:
	var r = data.get("reached", 0)
	reached = clampi(int(r), 0, LEVELS.size()) if (r is int or r is float) else 0
	refresh(false)

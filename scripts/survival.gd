extends Node
## Health, hunger and thirst. Gentle by default: a full stomach lasts about
## 40 minutes and a full bottle of thirst about 25, faster in the midday heat
## unless you stand in the shade. Empty food or water slowly hurts.
## v2.1: warmth (cold nights; a fire or a roof and walls keep you warm) and
## bleeding wounds from claws and bites (a bandage stops them).

signal died
signal warning(text: String)

const MAX := 100.0
const FOOD_DRAIN := 100.0 / (40.0 * 60.0)   # per second
const WATER_DRAIN := 100.0 / (25.0 * 60.0)  # per second
const HEAT_FACTOR := 1.8     # midday sun, out of the shade
const SPRINT_FACTOR := 1.5
const NIGHT_FACTOR := 0.7
const STARVE_DAMAGE := 0.6   # health per second when food or water is empty
const REGEN := 0.25          # health per second when fed and watered
const FALL_SAFE_SPEED := 10.0
const FALL_DAMAGE := 9.0     # per m/s above the safe speed
## What eating or drinking an item restores: item -> {"food", "water", "health"}.
const CONSUMABLES := {
	"canned_food": {"food": 35.0, "water": 5.0},
	"water": {"water": 40.0},
	"millet": {"food": 12.0},
	"melon": {"food": 15.0, "water": 25.0},
	"dates": {"food": 20.0, "water": 2.0},
	"dragon_fruit": {"food": 12.0, "water": 12.0},
	"olives": {"food": 8.0},
	"prickly_pear": {"food": 10.0, "water": 10.0},
	"cooked_meat": {"food": 40.0},
	"flatbread": {"food": 22.0},
	"stew": {"food": 30.0, "water": 15.0},
	"rotten_food": {"food": 6.0, "health": -8.0},
	"bandage": {"health": 30.0, "stops_bleeding": true},
	"medkit": {"health": 70.0, "stops_bleeding": true},
}
## v2.1 warmth: the cold hours are 21:00 to 05:00 (the middle of the night).
const COLD_START := 21.0
const COLD_END := 5.0
const CHILL := 100.0 / 150.0  # warmth lost per second in the open in the cold hours
const WARM_FIRE := 6.0        # warmth gained per second by a burning fire
const WARM_MILD := 1.5        # warmth gained per second outside the cold hours
const COLD_AT := 35.0         # below this you are cold: hungrier, no healing
const COLD_FOOD := 1.5        # food drains this much faster when cold
const FREEZE_DAMAGE := 0.5    # health per second at no warmth
## v2.1 bleeding: claws and bites build up; every WOUND_AT of damage opens a wound.
const WOUND_AT := 20.0
const WOUND_MAX := 3
const BLEED := 0.25           # health per second per open wound
const WOUND_TIME := 120.0     # a wound closes on its own after this long

var health := MAX
var food := MAX
var water := MAX
var dead := false
var hot := false  # in the midday heat right now (for the HUD)
var regen_mult := 1.0  # v1.17: a livable base heals faster (livable.gd sets it)
var heat_shelter := false  # v1.17: resting through the midday heat at a livable base
var need_mult := 1.0  # difficulty: how fast food and water run down
var warmth := MAX
var near_fire := false  # by a burning fire pit (camp.gd sets it)
var shelter := 0.0      # 0 open sand .. 1 indoors: the share of the chill kept off (camp.gd)
var wounds: Array[float] = []  # seconds each open wound still bleeds
var _wound_build := 0.0
var cause := ""   # what hurt you last, for the death screen ("" = hunger, thirst or a fall)
var _warned := {}


## Midday heat: 11:00 to 16:00.
static func is_hot_hour(hour: float) -> bool:
	return hour >= 11.0 and hour < 16.0


## The coldest hours of the night (21:00 to 05:00).
static func is_cold_hour(hour: float) -> bool:
	return hour >= COLD_START or hour < COLD_END


func is_cold() -> bool:
	return warmth < COLD_AT


func bleeding() -> bool:
	return not wounds.is_empty()


## Advances the needs by delta seconds.
func tick(delta: float, hour: float, sprinting: bool, in_shade: bool) -> void:
	if dead:
		return
	hot = is_hot_hour(hour) and not in_shade and not heat_shelter
	var water_rate := WATER_DRAIN
	var food_rate := FOOD_DRAIN
	if hot:
		water_rate *= HEAT_FACTOR
	if sprinting:
		water_rate *= SPRINT_FACTOR
		food_rate *= SPRINT_FACTOR
	if hour < 6.0 or hour >= 20.0:
		water_rate *= NIGHT_FACTOR
		food_rate *= NIGHT_FACTOR
	_tick_warmth(delta, hour)
	if is_cold():
		food_rate *= COLD_FOOD
	food = maxf(food - food_rate * need_mult * delta, 0.0)
	water = maxf(water - water_rate * need_mult * delta, 0.0)
	if food <= 0.0 or water <= 0.0:
		damage(STARVE_DAMAGE * delta)
	elif food > 50.0 and water > 50.0 and not is_cold() and not bleeding():
		health = minf(health + REGEN * regen_mult * delta, MAX)
	if warmth <= 0.0:
		damage(FREEZE_DAMAGE * delta, "The cold got you.")
	_tick_wounds(delta)
	_check_warning("water", water, "You are thirsty. Drink some water.")
	_check_warning("food", food, "You are hungry. Eat something.")
	_check_warning("warmth", warmth, "You are cold. Get to a fire or under a roof.", COLD_AT, COLD_AT + 15.0)


## Warmth: a fire warms you, the cold hours chill you (less under a roof and
## between walls), and the rest of the day slowly warms you back up.
func _tick_warmth(delta: float, hour: float) -> void:
	if near_fire:
		warmth += WARM_FIRE * delta
	elif is_cold_hour(hour):
		warmth -= CHILL * (1.0 - clampf(shelter, 0.0, 1.0)) * need_mult * delta
	else:
		warmth += WARM_MILD * delta
	warmth = clampf(warmth, 0.0, MAX)


## Open wounds bleed until bandaged or until they close on their own.
func _tick_wounds(delta: float) -> void:
	if wounds.is_empty() or dead:
		return
	damage(BLEED * wounds.size() * delta, "You bled out.")
	for i in range(wounds.size() - 1, -1, -1):  # backwards: closed wounds are removed
		wounds[i] -= delta
		if wounds[i] <= 0.0:
			wounds.remove_at(i)


## A claw or a bite (after the difficulty): builds up until a wound opens.
## Returns true when a new wound opened.
func wound(dmg: float) -> bool:
	if dead or dmg <= 0.0:
		return false
	_wound_build += dmg
	if _wound_build < WOUND_AT:
		return false
	_wound_build -= WOUND_AT
	if wounds.size() >= WOUND_MAX:
		wounds[0] = WOUND_TIME  # the worst one opens up again
		return false
	wounds.append(WOUND_TIME)
	warning.emit("You are bleeding. Use a bandage (F).")
	return true


func stop_bleeding() -> void:
	wounds.clear()
	_wound_build = 0.0


## A short line for the HUD about the heat, the cold and bleeding ("" when fine).
func status_text() -> String:
	var lines: Array[String] = []
	if hot:
		lines.append("Hot sun: find shade")
	if warmth <= 0.0:
		lines.append("Freezing! Find a fire")
	elif is_cold():
		lines.append("Cold: find a fire or a roof")
	if bleeding():
		lines.append("Bleeding%s: use a bandage" % ("" if wounds.size() == 1 else " (%d wounds)" % wounds.size()))
	return "\n".join(lines)


func _check_warning(key: String, value: float, text: String, low := 25.0, ok := 35.0) -> void:
	if value < low and not _warned.get(key, false):
		_warned[key] = true
		warning.emit(text)
	elif value > ok:
		_warned[key] = false


func damage(amount: float, from := "") -> void:
	if dead:
		return
	cause = from
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		dead = true
		died.emit()


func fall(speed: float) -> void:
	if speed > FALL_SAFE_SPEED:
		damage((speed - FALL_SAFE_SPEED) * FALL_DAMAGE)


static func can_consume(item: String) -> bool:
	return CONSUMABLES.has(item)


## Applies the effect of eating or drinking one item.
func consume(item: String) -> void:
	var fx: Dictionary = CONSUMABLES.get(item, {})
	food = minf(food + fx.get("food", 0.0), MAX)
	water = minf(water + fx.get("water", 0.0), MAX)
	health = clampf(health + fx.get("health", 0.0), 1.0 if fx.get("health", 0.0) < 0.0 else 0.0, MAX)
	if fx.get("stops_bleeding", false):
		stop_bleeding()


## Back on your feet at the base: full health, needs topped up to at least 60.
func respawn() -> void:
	dead = false
	cause = ""
	health = MAX
	food = maxf(food, 60.0)
	water = maxf(water, 60.0)
	warmth = maxf(warmth, 60.0)
	stop_bleeding()


func save_data() -> Dictionary:
	return {"health": health, "food": food, "water": water, "warmth": warmth, "wounds": wounds.duplicate()}


func load_data(data: Dictionary) -> void:
	health = clampf(float(data.get("health", MAX)), 1.0, MAX)
	food = clampf(float(data.get("food", MAX)), 0.0, MAX)
	water = clampf(float(data.get("water", MAX)), 0.0, MAX)
	var w = data.get("warmth", MAX)
	warmth = clampf(float(w), 0.0, MAX) if (w is float or w is int) else MAX
	wounds.clear()
	var ws = data.get("wounds", [])
	if ws is Array:
		for t in ws:
			if (t is float or t is int) and float(t) > 0.0 and wounds.size() < WOUND_MAX:
				wounds.append(minf(float(t), WOUND_TIME))
	_wound_build = 0.0
	dead = false

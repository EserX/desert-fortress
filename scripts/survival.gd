extends Node
## Health, hunger and thirst. Gentle by default: a full stomach lasts about
## 40 minutes and a full bottle of thirst about 25, faster in the midday heat
## unless you stand in the shade. Empty food or water slowly hurts.

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
	"bandage": {"health": 30.0},
}

var health := MAX
var food := MAX
var water := MAX
var dead := false
var hot := false  # in the midday heat right now (for the HUD)
var cause := ""   # what hurt you last, for the death screen ("" = hunger, thirst or a fall)
var _warned := {}


## Midday heat: 11:00 to 16:00.
static func is_hot_hour(hour: float) -> bool:
	return hour >= 11.0 and hour < 16.0


## Advances the needs by delta seconds.
func tick(delta: float, hour: float, sprinting: bool, in_shade: bool) -> void:
	if dead:
		return
	hot = is_hot_hour(hour) and not in_shade
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
	food = maxf(food - food_rate * delta, 0.0)
	water = maxf(water - water_rate * delta, 0.0)
	if food <= 0.0 or water <= 0.0:
		damage(STARVE_DAMAGE * delta)
	elif food > 50.0 and water > 50.0:
		health = minf(health + REGEN * delta, MAX)
	_check_warning("water", water, "You are thirsty. Drink some water.")
	_check_warning("food", food, "You are hungry. Eat something.")


func _check_warning(key: String, value: float, text: String) -> void:
	if value < 25.0 and not _warned.get(key, false):
		_warned[key] = true
		warning.emit(text)
	elif value > 35.0:
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
	health = minf(health + fx.get("health", 0.0), MAX)


## Back on your feet at the base: full health, needs topped up to at least 60.
func respawn() -> void:
	dead = false
	cause = ""
	health = MAX
	food = maxf(food, 60.0)
	water = maxf(water, 60.0)


func save_data() -> Dictionary:
	return {"health": health, "food": food, "water": water}


func load_data(data: Dictionary) -> void:
	health = clampf(float(data.get("health", MAX)), 1.0, MAX)
	food = clampf(float(data.get("food", MAX)), 0.0, MAX)
	water = clampf(float(data.get("water", MAX)), 0.0, MAX)
	dead = false

extends Node3D
## Weather (v1.19): dew collectors, the weather station and rain.
## A **dew collector** (a machine bought by drone once the desert is 2.5% green)
## catches the night's dew and waters the ground round it every morning, without
## pipes. A **weather station** (5% green) seeds the clouds: most mornings a rain
## shower falls on the land round it. Once the final green milestone is reached
## the rain is back for good: on rainy mornings every watered square on the map
## gets rain, and green land spreads from there on its own.
## Whether a morning brings rain comes from the world seed and the day.

const Water = preload("res://scripts/water.gd")

const DEW_R := 8.0             # a dew collector waters squares whose centre is this close
const DEW_L := 4.0             # with this many litres each morning (a day's need)
const STATION_R := 40.0        # a weather station's shower covers this far
const RAIN_L := 6.0            # litres a shower gives each square (enough to turn sand to soil)
const SHOWER_CHANCE := 0.6     # chance of a shower each morning with a station standing
const RAIN_BACK_CHANCE := 0.5  # chance of rain over the whole desert each morning after the ending
const RAIN_END := 10.0         # the morning's rain stops at this hour
const RAIN_SEEN := 25.0        # you see a station's shower this far past its edge

signal message(text: String)

var water  # Water: the ground squares the rain falls on
var building  # Building: dew collectors and weather stations
var player: Node3D
var day_night  # DayNight (the hour, cloud cover)
var world_seed := 1337
## The final green milestone was reached: rain falls over the whole desert.
var rain_back := false
## The day it rained this morning (-1: not yet), and whether it was over the whole desert.
var rain_day := -1
var rain_wide := false
var _rain: CPUParticles3D
var _cloud := 0.0


func _ready() -> void:
	_rain = CPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 900
	_rain.lifetime = 1.1
	_rain.preprocess = 1.1  # full rain as soon as it starts
	_rain.emitting = false
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(22, 0.5, 22)
	_rain.direction = Vector3(0.08, -1, 0)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 16.0
	_rain.initial_velocity_max = 19.0
	_rain.gravity = Vector3(0, -6, 0)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.02, 0.5, 0.02)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.82, 0.9, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.material = mat
	_rain.mesh = streak
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)


func _process(delta: float) -> void:
	var on := raining_here()
	_rain.emitting = on
	if player:
		_rain.global_position = player.global_position + Vector3(0, 14, 0)
	_cloud = move_toward(_cloud, 1.0 if on else 0.0, delta * 0.25)
	if day_night:
		day_night.overcast = _cloud


func stations() -> Array:
	return building.keys_of(["weather_station"]) if building else []


func collectors() -> Array:
	return building.keys_of(["dew_collector"]) if building else []


func _flat(key: String) -> Vector2:
	var p: Vector3 = building.pieces[key].node.global_position
	return Vector2(p.x, p.z)


## The ground squares whose centre is within r of p.
static func cells_within(p: Vector2, r: float) -> Array:
	var out: Array = []
	var c0 := Water.cell_of(p.x, p.y)
	var n := int(ceil(r / Water.CELL)) + 1
	for dx in range(-n, n + 1):
		for dz in range(-n, n + 1):
			var c: Vector2i = c0 + Vector2i(dx, dz)
			if Water.cell_center(c).distance_to(p) <= r:
				out.append(c)
	return out


## The chance of rain this morning (0 without a station and before the rain is back).
func chance() -> float:
	var ch := 0.0
	if not stations().is_empty():
		ch = SHOWER_CHANCE
	if rain_back:
		ch = maxf(ch, RAIN_BACK_CHANCE)
	return ch


## True if it rains on the morning of this day (the same world rains on the same days).
func rains_on(day: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rain:%d:%d" % [world_seed, day])
	return rng.randf() < chance()


## True while this morning's rain falls (before RAIN_END).
func is_raining() -> bool:
	return day_night != null and rain_day == day_night.day and day_night.hour < RAIN_END and not day_night.is_night()


## True if it is raining where you are (everywhere after the ending, else near a station).
func raining_here() -> bool:
	if not is_raining() or player == null:
		return false
	if rain_wide:
		return true
	var pp := Vector2(player.global_position.x, player.global_position.z)
	for k in stations():
		if _flat(k).distance_to(pp) <= STATION_R + RAIN_SEEN:
			return true
	return false


## New day (after water.gd has counted yesterday and cleared the litres): dew
## collectors water the ground round them, and maybe it rains.
func on_morning(day := 0) -> void:
	dew()
	if rains_on(day):
		rain(day)


## Every dew collector waters the squares round it. Returns how many squares got water.
func dew() -> int:
	var n := 0
	for k in collectors():  # every morning, every collector (a handful)
		for c in cells_within(_flat(k), DEW_R):
			if water.water_cell(c, DEW_L) > 0.0:
				n += 1
	return n


## A rain shower this morning: the land round every weather station gets rain, and
## once the rain is back, every watered square on the map too. Returns the squares.
func rain(day: int) -> int:
	rain_day = day
	rain_wide = rain_back
	var targets := {}
	for k in stations():  # a station's circle is about 300 squares
		for c in cells_within(_flat(k), STATION_R):
			targets[c] = true
	if rain_back:
		# Every watered square on the map (up to a few thousand), once a rainy morning.
		for c in water.cells.keys():
			targets[c] = true
	var n := 0
	for c in targets:
		if water.water_cell(c, RAIN_L) > 0.0:
			n += 1
	if rain_wide:
		message.emit("Rain over the desert! The land drinks it up.")
	elif n > 0:
		message.emit("Rain! A shower falls round your weather station.")
	return n


## E-prompt text for a dew collector or weather station.
func prompt(key: String) -> String:
	if building == null or not building.pieces.has(key):
		return ""
	match building.pieces[key].type:
		"dew_collector":
			return "Dew collector\nWaters the ground within %d m every morning (%d L a square)" % [int(DEW_R), int(DEW_L)]
		"weather_station":
			var text := "Weather station\nA %d%% chance of a rain shower each morning within %d m" % [int(round(chance() * 100.0)), int(STATION_R)]
			if is_raining():
				text += "\nIt's raining"
			elif rain_day > 0:
				text += "\nLast rain: day %d" % rain_day
			return text
	return ""


func save_data() -> Dictionary:
	return {"rain_day": rain_day, "rain_wide": rain_wide}


## Older saves (no "weather"): it hasn't rained yet.
func load_data(data: Dictionary) -> void:
	var d = data.get("rain_day", -1)
	rain_day = int(d) if (d is int or d is float) else -1
	var w = data.get("rain_wide", false)
	rain_wide = w is bool and w

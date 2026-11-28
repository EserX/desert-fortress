extends Node
## Goals and an ending (v1.19).
## Green milestones: as the green % of the whole desert (livable.gd) passes each
## one, it is announced and unlocks new drone orders at the shop terminal: new
## seeds, then a machine, then the weather station. The final milestone brings
## the rain back over the whole desert: the ending screen, then free play.
## Milestones stay reached even if the green fades again later.

## The green % each milestone needs, its name and what it gives. The last one is the ending.
const GOALS := [
	{"at": 1.0, "name": "First green", "text": "new seeds by drone: olive trees and prickly pears", "short": "olive and prickly pear seeds"},
	{"at": 2.5, "name": "Green belt", "text": "new machines by drone: the dew collector and the water purifier", "short": "the dew collector and water purifier"},
	{"at": 5.0, "name": "Clouds gather", "text": "the weather station by drone: it brings rain showers", "short": "the weather station (rain)"},
	{"at": 10.0, "name": "The rain returns", "text": "rain falls over the whole desert again", "short": "rain over the whole desert"},
]
const REFRESH := 1.0

signal message(text: String)
## The final milestone was just reached (main shows the ending screen).
signal ended

var livable  # Livable: the green %
var shop  # Shop: the drone orders each milestone unlocks
var weather  # Weather: the rain coming back
var day_night  # DayNight (the first big rain falls straight away)
## Milestones reached so far (0 = none, GOALS.size() = the rain is back).
var reached := 0
var _wait := 0.0


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = REFRESH
		check()


## "2.5%" for milestone n (1 = the first).
static func at_text(n: int) -> String:
	if n < 1 or n > GOALS.size():
		return ""
	return "%s%%" % str(GOALS[n - 1].at).trim_suffix(".0")


## Milestones a green % reaches.
static func level_of(percent: float) -> int:
	var lv := 0
	for i in GOALS.size():
		if percent >= float(GOALS[i].at) - 0.0001:
			lv = i + 1
	return lv


func is_over() -> bool:
	return reached >= GOALS.size()


## The next milestone's green % (-1 once they're all reached).
func next_at() -> float:
	return -1.0 if is_over() else float(GOALS[reached].at)


## Checks the green % and announces milestones reached for the first time. Returns `reached`.
func check(announce := true) -> int:
	if livable == null:
		return reached
	var lv := level_of(livable.green_percent())
	if lv > reached:
		for i in range(reached, lv):
			if announce:
				var g: Dictionary = GOALS[i]
				message.emit("%s green: %s! %s" % [at_text(i + 1), g.name, g.text.substr(0, 1).to_upper() + g.text.substr(1)])
		reached = lv
		apply()
		if is_over() and announce:
			if weather and day_night:
				weather.rain(day_night.day)  # the first rain falls straight away
			ended.emit()
	return reached


## Passes what the milestones reached unlock on to the shop, the weather and the HUD.
func apply() -> void:
	if shop:
		shop.goal_level = reached
	if weather:
		weather.rain_back = is_over()
	if livable:
		livable.next_goal = next_at()


## Lines for the map: each milestone, ticked when reached.
func summary_lines() -> Array:
	var lines: Array = []
	for i in GOALS.size():
		var g: Dictionary = GOALS[i]
		lines.append("%s %s %s: %s" % ["[x]" if reached > i else "[ ]", at_text(i + 1), g.name, g.short])
	return lines


func save_data() -> Dictionary:
	return {"reached": reached}


## Older saves (no "goals"): milestones the land already reaches count as reached,
## without banners or the ending screen.
func load_data(data: Dictionary) -> void:
	var r = data.get("reached", 0)
	reached = clampi(int(r), 0, GOALS.size()) if (r is int or r is float) else 0
	apply()
	check(false)

extends Node
## Day/night cycle. Day (06:00-20:00) lasts DAY_SECONDS of real time and
## night (20:00-06:00) lasts NIGHT_SECONDS. Drives the sun, moon, sky, fog
## and ambient light, and announces dusk/night/dawn for the future wave system.

signal hour_changed(day: int, hour: int)
signal dusk_started(day: int)   # 18:30: warning before night
signal night_started(day: int)  # 20:00
signal day_started(day: int)    # 06:00

const DAY_SECONDS := 600.0
const NIGHT_SECONDS := 240.0
const SUNRISE := 6.0
const SUNSET := 20.0
const DUSK_WARNING := 18.5

## Look keyframes: hour -> sky top, horizon, sun colour, sun energy, ambient, fog colour.
const KEYS := [
	[0.0, Color(0.02, 0.03, 0.08), Color(0.06, 0.08, 0.16), Color(0.6, 0.7, 1.0), 0.0, 0.18, Color(0.07, 0.09, 0.16)],
	[5.0, Color(0.03, 0.04, 0.10), Color(0.10, 0.10, 0.18), Color(0.6, 0.7, 1.0), 0.0, 0.18, Color(0.10, 0.10, 0.18)],
	[6.0, Color(0.20, 0.28, 0.48), Color(0.95, 0.55, 0.32), Color(1.0, 0.55, 0.30), 0.5, 0.30, Color(0.75, 0.50, 0.36)],
	[8.0, Color(0.30, 0.50, 0.80), Color(0.92, 0.78, 0.62), Color(1.0, 0.86, 0.68), 0.95, 0.34, Color(0.88, 0.75, 0.60)],
	[13.0, Color(0.30, 0.53, 0.85), Color(0.90, 0.80, 0.68), Color(1.0, 0.95, 0.84), 1.05, 0.36, Color(0.90, 0.80, 0.65)],
	[18.0, Color(0.28, 0.45, 0.75), Color(0.95, 0.72, 0.52), Color(1.0, 0.80, 0.58), 0.9, 0.33, Color(0.90, 0.70, 0.52)],
	[19.5, Color(0.18, 0.20, 0.42), Color(0.98, 0.45, 0.22), Color(1.0, 0.45, 0.22), 0.45, 0.28, Color(0.70, 0.40, 0.28)],
	[20.5, Color(0.05, 0.06, 0.16), Color(0.25, 0.15, 0.20), Color(0.6, 0.7, 1.0), 0.0, 0.20, Color(0.14, 0.11, 0.18)],
	[24.0, Color(0.02, 0.03, 0.08), Color(0.06, 0.08, 0.16), Color(0.6, 0.7, 1.0), 0.0, 0.18, Color(0.07, 0.09, 0.16)],
]

var day := 1
var hour := 9.0            # 0..24
var time_scale := 1.0      # for testing / debugging
## Cloud cover 0..1 (rain, v1.19): a greyer sky and a weaker sun. Set by weather.gd.
var overcast := 0.0
## v2.3: a sandstorm's strength (0..1, set by events.gd): the sky and fog turn
## sandy brown and the sun dims.
var dust := 0.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var stars: MultiMeshInstance3D
var _star_mat: StandardMaterial3D
var _last_hour := -1
var _dusk_fired := false


func setup(sun_light: DirectionalLight3D, moon_light: DirectionalLight3D, environment: Environment, sky: ProceduralSkyMaterial) -> void:
	sun = sun_light
	moon = moon_light
	env = environment
	sky_mat = sky
	_build_stars()
	_apply()


## A dome of small unshaded quads that fades in at night and follows the camera.
func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = 700
	for i in mm.instance_count:
		# Random direction on the upper hemisphere.
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.05, 1), rng.randf_range(-1, 1)).normalized()
		var pos := dir * 700.0
		var s := rng.randf_range(0.4, 1.3)
		var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
		var basis := Basis.looking_at(dir, up).scaled(Vector3.ONE * s)
		mm.set_instance_transform(i, Transform3D(basis, pos))
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.disable_fog = true
	_star_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_star_mat.albedo_color = Color(1, 1, 1, 0)
	stars = MultiMeshInstance3D.new()
	stars.name = "Stars"
	stars.multimesh = mm
	stars.material_override = _star_mat
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stars.extra_cull_margin = 2000.0
	add_child(stars)


## Jump to a saved time without firing dusk/night/day events.
func restore(saved_day: int, saved_hour: float) -> void:
	day = saved_day
	hour = fposmod(saved_hour, 24.0)
	_dusk_fired = hour >= DUSK_WARNING and hour < SUNSET
	_last_hour = int(hour)
	_apply()


func is_night() -> bool:
	return hour >= SUNSET or hour < SUNRISE


## Game hours that pass per real second right now.
func hours_per_second() -> float:
	if is_night():
		return (24.0 - SUNSET + SUNRISE) / NIGHT_SECONDS
	return (SUNSET - SUNRISE) / DAY_SECONDS


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "%02d:%02d" % [h, m]


## Real seconds until night starts (0 while it is night).
func seconds_until_night() -> float:
	if is_night():
		return 0.0
	return (SUNSET - hour) / hours_per_second()


func _process(delta: float) -> void:
	var was_night := is_night()
	hour += hours_per_second() * delta * time_scale
	if hour >= 24.0:
		hour -= 24.0
	if not was_night and is_night():
		night_started.emit(day)
	elif was_night and not is_night():
		day += 1
		_dusk_fired = false
		day_started.emit(day)
	if not _dusk_fired and hour >= DUSK_WARNING and hour < SUNSET:
		_dusk_fired = true
		dusk_started.emit(day)
	if int(hour) != _last_hour:
		_last_hour = int(hour)
		hour_changed.emit(day, _last_hour)
	_apply()


func _apply() -> void:
	if sun == null:
		return
	# Interpolate the look keyframes.
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in KEYS.size() - 1:
		if hour >= KEYS[i][0] and hour <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t := inverse_lerp(a[0], b[0], hour)
	sky_mat.sky_top_color = (a[1] as Color).lerp(b[1], t)
	sky_mat.sky_horizon_color = (a[2] as Color).lerp(b[2], t)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = sky_mat.sky_horizon_color.darkened(0.5)
	sun.light_color = (a[3] as Color).lerp(b[3], t)
	sun.light_energy = lerpf(a[4], b[4], t)
	env.ambient_light_energy = lerpf(a[5], b[5], t)
	env.fog_light_color = (a[6] as Color).lerp(b[6], t)
	if overcast > 0.0:
		var grey := Color(0.45, 0.47, 0.5)
		sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(grey * sky_mat.sky_top_color.get_luminance() * 2.0, overcast * 0.8)
		sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(grey, overcast * 0.6)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
		sun.light_energy *= 1.0 - overcast * 0.6
		env.fog_light_color = env.fog_light_color.lerp(grey, overcast * 0.6)
	if dust > 0.0:
		var sand := Color(0.72, 0.55, 0.36) * clampf(sun.light_energy, 0.25, 1.0)
		sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(sand * 0.8, dust * 0.9)
		sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(sand, dust * 0.95)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
		sun.light_energy *= 1.0 - dust * 0.55
		env.fog_light_color = env.fog_light_color.lerp(sand, dust * 0.9)

	# Sun arc: rises in the east (+X), peaks at ~70 degrees, sets in the west.
	var day_frac := (hour - SUNRISE) / (SUNSET - SUNRISE)
	var elevation := sin(day_frac * PI) * 70.0
	sun.rotation_degrees = Vector3(-elevation, 90.0 - day_frac * 180.0, 0.0)
	sun.visible = elevation > -2.0 and sun.light_energy > 0.01

	# Moon: opposite arc, soft blue light, no shadows.
	var night_len := 24.0 - SUNSET + SUNRISE
	var night_frac := fposmod(hour - SUNSET, 24.0) / night_len
	var moon_elev := sin(clampf(night_frac, 0.0, 1.0) * PI) * 55.0
	moon.rotation_degrees = Vector3(-maxf(moon_elev, 5.0), 90.0 - night_frac * 180.0, 0.0)
	var moon_strength := clampf(moon_elev / 15.0, 0.0, 1.0) if is_night() else 0.0
	moon.light_energy = 0.28 * moon_strength
	moon.visible = moon_strength > 0.01

	# Stars fade in after sunset and out before sunrise.
	var dark := 1.0 - clampf(sky_mat.sky_top_color.get_luminance() / 0.12, 0.0, 1.0)
	_star_mat.albedo_color.a = dark * 0.9
	stars.visible = dark > 0.01
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		stars.global_position = cam.global_position

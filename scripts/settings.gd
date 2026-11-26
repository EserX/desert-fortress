extends Node
## Player settings, saved to user://settings.cfg
## (on Linux: ~/.local/share/godot/app_userdata/Desert Fortress/settings.cfg).

signal changed

const PATH := "user://settings.cfg"

var mouse_sensitivity := 1.0  # multiplier, 0.25 .. 3.0
var fov := 75.0
var volume := 0.8             # 0 .. 1
var fullscreen := false
## Graphics quality: 2 high, 1 medium, 0 low (for weaker laptops).
var quality := 2
## What each quality level changes: sun shadows (and how far), anti-aliasing, render scale, view distance.
const QUALITY := [
	{"name": "Low", "shadows": false, "shadow_dist": 0.0, "msaa": 0, "scale": 0.75, "far": 450.0},
	{"name": "Medium", "shadows": true, "shadow_dist": 90.0, "msaa": 0, "scale": 1.0, "far": 650.0},
	{"name": "High", "shadows": true, "shadow_dist": 160.0, "msaa": 2, "scale": 1.0, "far": 900.0},
]
var hints := true             # first-time hints
var hints_seen: Array = []    # ids of hints already shown


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	fov = cfg.get_value("video", "fov", fov)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	volume = cfg.get_value("audio", "volume", volume)
	hints = cfg.get_value("game", "hints", hints)
	quality = clampi(int(cfg.get_value("video", "quality", quality)), 0, 2)
	hints_seen = cfg.get_value("game", "hints_seen", hints_seen)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("game", "hints", hints)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("game", "hints_seen", hints_seen)
	cfg.save(PATH)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	var q: Dictionary = QUALITY[quality]
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_2X if q.msaa == 2 else Viewport.MSAA_DISABLED
		vp.scaling_3d_scale = q.scale
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	changed.emit()


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	apply()
	save_settings()

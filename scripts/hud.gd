extends CanvasLayer
## On-screen info: crosshair, compass, distance to base, stamina, controls help.

const DIRS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var player: Node
var base_position := Vector3.ZERO
var compass: Label
var base_label: Label
var stamina_bar: ProgressBar
var help: Label
var clock: Label
var banner: Label
var day_night  # DayNight
var _banner_time := 0.0
var _help_time := 12.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var cross := _label("+", 26)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.size = Vector2(40, 40)
	cross.position = -cross.size / 2
	root.add_child(cross)

	var title := _label("DESERT FORTRESS  v0.2", 18)
	title.position = Vector2(20, 16)
	root.add_child(title)

	compass = _label("N", 24)
	compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass.size = Vector2(240, 34)
	compass.position = Vector2(-120, 14)
	root.add_child(compass)

	base_label = _label("", 16)
	base_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_label.size = Vector2(300, 24)
	base_label.position = Vector2(-150, 48)
	root.add_child(base_label)

	stamina_bar = ProgressBar.new()
	stamina_bar.show_percentage = false
	stamina_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stamina_bar.size = Vector2(260, 10)
	stamina_bar.position = Vector2(-130, -40)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.80, 0.45)
	stamina_bar.add_theme_stylebox_override("background", bg)
	stamina_bar.add_theme_stylebox_override("fill", fill)
	root.add_child(stamina_bar)

	help = _label("WASD move   Shift sprint   Space jump   Mouse look   Ctrl crouch   Esc menu", 16)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(20, -36)
	root.add_child(help)

	clock = _label("Day 1  09:00", 20)
	clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.size = Vector2(320, 60)
	clock.position = Vector2(-340, 14)
	root.add_child(clock)

	banner = _label("", 34)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(800, 50)
	banner.position = Vector2(-400, 150)
	banner.modulate.a = 0.0
	root.add_child(banner)

	if day_night:
		day_night.dusk_started.connect(func(_d): show_banner("The sun is setting. Night is coming."))
		day_night.night_started.connect(func(d): show_banner("Night %d" % d))
		day_night.day_started.connect(func(d): show_banner("Day %d" % d))

	if player and player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_stamina_changed)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.03))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	if player == null:
		return
	var deg: float = player.heading_degrees()
	var dir: String = DIRS[int(round(deg / 45.0)) % 8]
	compass.text = "%s  %03d°" % [dir, int(deg)]
	var to_base: Vector3 = base_position - player.global_position
	to_base.y = 0
	var dist := to_base.length()
	if dist < 25.0:
		base_label.text = "At base"
	else:
		var bdeg := fposmod(rad_to_deg(atan2(to_base.x, -to_base.z)), 360.0)
		base_label.text = "Base: %d m  %s" % [int(dist), DIRS[int(round(bdeg / 45.0)) % 8]]
	if day_night:
		var text: String = "Day %d  %s" % [day_night.day, day_night.clock_text()]
		var left: float = day_night.seconds_until_night()
		if day_night.is_night():
			text += "\nNight"
		elif left < 120.0:
			text += "\nNight in %d:%02d" % [int(left) / 60, int(left) % 60]
		clock.text = text
	if _banner_time > 0.0:
		_banner_time -= delta
		banner.modulate.a = clampf(minf(_banner_time, 5.0 - _banner_time) * 1.5, 0.0, 1.0)
	if _help_time > 0.0:
		_help_time -= delta
		help.modulate.a = clampf(_help_time / 2.0, 0.0, 1.0)


func show_banner(text: String) -> void:
	banner.text = text
	_banner_time = 5.0


func _on_stamina_changed(value: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = value
	stamina_bar.modulate.a = 0.35 if value >= max_value else 1.0

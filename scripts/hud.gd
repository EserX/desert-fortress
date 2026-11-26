extends CanvasLayer
## On-screen info: crosshair, compass, distance to base, stamina, controls help.

const Items = preload("res://scripts/items.gd")
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
var prompt: Label
var pickups: VBoxContainer
var inventory  # Inventory
var hotbar: HBoxContainer
var _hotbar_labels: Array[Label] = []
var _hotbar_panels: Array[Panel] = []
var _slot_style: StyleBoxFlat
var _slot_selected_style: StyleBoxFlat
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

	var title := _label("DESERT FORTRESS  v%s" % ProjectSettings.get_setting("application/config/version", ""), 18)
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

	help = _label("WASD move   Shift sprint   Space jump   Mouse look   Ctrl crouch   E search   Tab inventory   1-9 hotbar   Q drop   F5 quicksave   Esc menu", 16)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(20, -36)
	root.add_child(help)

	clock = _label("Day 1  09:00", 20)
	clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.size = Vector2(320, 60)
	clock.position = Vector2(-340, 14)
	root.add_child(clock)

	prompt = _label("", 20)
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(400, 30)
	prompt.position = Vector2(-200, 34)
	root.add_child(prompt)

	pickups = VBoxContainer.new()
	pickups.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	pickups.alignment = BoxContainer.ALIGNMENT_END
	pickups.size = Vector2(300, 260)
	pickups.position = Vector2(-320, -40)
	pickups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pickups)

	_build_hotbar(root)

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


func _build_hotbar(root: Control) -> void:
	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = Color(0.1, 0.07, 0.04, 0.55)
	_slot_style.border_color = Color(0.85, 0.62, 0.35, 0.5)
	_slot_style.set_border_width_all(1)
	_slot_style.set_corner_radius_all(4)
	_slot_selected_style = _slot_style.duplicate()
	_slot_selected_style.border_color = Color(1.0, 0.9, 0.55)
	_slot_selected_style.set_border_width_all(3)
	hotbar = HBoxContainer.new()
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.add_theme_constant_override("separation", 4)
	hotbar.size = Vector2(9 * 68 + 8 * 4, 56)
	hotbar.position = Vector2(-hotbar.size.x / 2, -108)
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hotbar)
	for i in 9:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(68, 56)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar.add_child(p)
		var l := _label("", 12)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_constant_override("outline_size", 3)
		p.add_child(l)
		_hotbar_panels.append(p)
		_hotbar_labels.append(l)
	if inventory:
		inventory.changed.connect(refresh_hotbar)
	refresh_hotbar()


func refresh_hotbar() -> void:
	if inventory == null:
		hotbar.visible = false
		return
	for i in 9:
		var s: Dictionary = inventory.slots[i]
		_hotbar_labels[i].text = "%d" % (i + 1) if s.is_empty() else "%d %s\nx%d" % [i + 1, Items.display_name(s.item), s.count]
		_hotbar_panels[i].add_theme_stylebox_override("panel", _slot_selected_style if i == inventory.selected else _slot_style)


func set_prompt(text: String) -> void:
	prompt.text = text


## Shows "+3 Scrap metal" lines that fade out after a few seconds.
func show_pickup(lines: Array) -> void:
	for text in lines:
		var l := _label(text, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))
		pickups.add_child(l)
		var tw := l.create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(l, "modulate:a", 0.0, 1.0)
		tw.tween_callback(l.queue_free)
	while pickups.get_child_count() > 8:
		var old := pickups.get_child(0)
		pickups.remove_child(old)
		old.queue_free()


func _on_stamina_changed(value: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = value
	stamina_bar.modulate.a = 0.35 if value >= max_value else 1.0

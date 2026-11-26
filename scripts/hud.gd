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
var waves  # Waves
var guns  # Guns
var ammo_label: Label
var scope: Control
var _cross: Label
var summary: PanelContainer
var _summary_lines: VBoxContainer
var _summary_time := 0.0
var prompt: Label
var hitmarker: Label
var damage_vignette: TextureRect
var damage_arrow: Control
var pickups: VBoxContainer
var inventory  # Inventory
var survival  # Survival
var _need_bars: Array[ProgressBar] = []
var heat_label: Label
var build_label: Label
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
	_cross = cross
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.size = Vector2(40, 40)
	cross.position = -cross.size / 2
	root.add_child(cross)

	hitmarker = _label("X", 30)
	hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hitmarker.size = Vector2(40, 40)
	hitmarker.position = -hitmarker.size / 2
	hitmarker.modulate.a = 0.0
	root.add_child(hitmarker)

	_build_damage(root)
	ammo_label = _label("", 26)
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.size = Vector2(300, 40)
	ammo_label.position = Vector2(-320, -150)
	root.add_child(ammo_label)
	scope = Control.new()
	scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.visible = false
	scope.draw.connect(_draw_scope)
	root.add_child(scope)
	root.move_child(scope, 0)
	_build_summary(root)

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

	help = _label("WASD move  Shift sprint  Space jump  Ctrl crouch  E use  LMB attack  RMB aim  R reload  Tab bag  Q drop  F eat  M map  B build  F5 save  Esc menu", 16)
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
	prompt.size = Vector2(1000, 50)
	prompt.position = Vector2(-500, 34)
	root.add_child(prompt)

	pickups = VBoxContainer.new()
	pickups.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	pickups.alignment = BoxContainer.ALIGNMENT_END
	pickups.size = Vector2(300, 260)
	pickups.position = Vector2(-320, -40)
	pickups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pickups)

	_build_hotbar(root)
	_build_needs(root)

	build_label = _label("", 18)
	build_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_label.size = Vector2(900, 50)
	build_label.position = Vector2(-450, -170)
	build_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	root.add_child(build_label)

	banner = _label("", 34)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(1000, 50)
	banner.position = Vector2(-500, 150)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_update_needs()
	_update_ammo()
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
		if waves and waves.active:
			text += "\nWave %d: %d left" % [waves.wave, waves.remaining()]
		clock.text = text
	if _banner_time > 0.0:
		_banner_time -= delta
		banner.modulate.a = clampf(minf(_banner_time, 5.0 - _banner_time) * 1.5, 0.0, 1.0)
	if _summary_time > 0.0:
		_summary_time -= delta
		summary.modulate.a = clampf(minf(_summary_time, 10.0 - _summary_time) * 2.0, 0.0, 1.0)
		summary.visible = _summary_time > 0.0
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


## Health, food and water bars in the bottom-left corner.
func _build_needs(root: Control) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.position = Vector2(20, -150)
	box.size = Vector2(230, 90)
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	heat_label = _label("Hot sun: find shade", 15)
	heat_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	heat_label.visible = false
	box.add_child(heat_label)
	for spec in [["Health", Color(0.85, 0.22, 0.18)], ["Food", Color(0.9, 0.6, 0.25)], ["Water", Color(0.3, 0.6, 0.95)]]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(row)
		var l := _label(spec[0], 14)
		l.custom_minimum_size = Vector2(60, 0)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(160, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.45)
		var fill := StyleBoxFlat.new()
		fill.bg_color = spec[1]
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		_need_bars.append(bar)
	box.visible = survival != null


func _update_needs() -> void:
	if survival == null:
		return
	var values := [survival.health, survival.food, survival.water]
	for i in 3:
		_need_bars[i].value = values[i]
		# Blink when low.
		var low: bool = values[i] < 25.0
		_need_bars[i].modulate.a = 0.4 + 0.6 * absf(sin(Time.get_ticks_msec() * 0.006)) if low else 1.0
	heat_label.visible = survival.hot


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
## Flashes an X on the crosshair: orange for a hit on a target, grey on a wall or rock.
func show_hitmarker(kind: String) -> void:
	var colors := {"target": Color(1.0, 0.55, 0.2), "head": Color(1.0, 0.15, 0.1)}
	hitmarker.add_theme_color_override("font_color", colors.get(kind, Color(0.75, 0.75, 0.75)))
	hitmarker.scale = Vector2.ONE * (1.5 if kind == "head" else 1.0)
	hitmarker.pivot_offset = hitmarker.size / 2.0
	hitmarker.modulate.a = 1.0
	var tw := hitmarker.create_tween()
	tw.tween_property(hitmarker, "modulate:a", 0.0, 0.3)


## Red edges and a red wedge pointing to where the hit came from.
func _build_damage(root: Control) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.7, 0.0, 0.0, 0.0))
	grad.set_color(1, Color(0.7, 0.0, 0.0, 0.75))
	grad.add_point(0.55, Color(0.7, 0.0, 0.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	damage_vignette = TextureRect.new()
	damage_vignette.texture = tex
	damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_vignette.modulate.a = 0.0
	root.add_child(damage_vignette)
	damage_arrow = Control.new()
	damage_arrow.set_anchors_preset(Control.PRESET_CENTER)
	damage_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_arrow.modulate.a = 0.0
	root.add_child(damage_arrow)
	var wedge := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(-0.35, 0.35, i / 8.0) - PI / 2
		pts.append(Vector2(cos(a), sin(a)) * 150.0)
	for i in 9:
		var a := lerpf(0.3, -0.3, i / 8.0) - PI / 2
		pts.append(Vector2(cos(a), sin(a)) * 132.0)
	wedge.polygon = pts
	wedge.color = Color(1.0, 0.15, 0.1, 0.85)
	damage_arrow.add_child(wedge)


## "Pistol 9 / 24" while a gun is in your hands; the crosshair fades when aiming.
func _update_ammo() -> void:
	if guns == null or guns.item == "":
		ammo_label.text = ""
		_cross.modulate.a = 1.0
		return
	var g: Dictionary = guns.GUNS[guns.item]
	var text := "%s  %d / %d" % [Items.display_name(guns.item), guns.loaded(guns.item), inventory.count_of(g.ammo)]
	if guns.reload_t >= 0.0:
		text += "\nReloading..."
	elif guns.loaded(guns.item) == 0:
		text += "\n[R] Reload" if inventory.count_of(g.ammo) > 0 else "\nNo ammo"
	ammo_label.text = text
	_cross.modulate.a = 1.0 - guns.ads_amount
	var scoped: bool = g.get("scope", false) and guns.ads_amount > 0.9
	if scoped != scope.visible:
		scope.visible = scoped
		scope.queue_redraw()


## Looking through the rifle scope: black all round a circle, with thin cross hairs.
func _draw_scope() -> void:
	var sz := scope.size
	var c := sz / 2.0
	var r := sz.y * 0.44
	var w := sz.length()
	scope.draw_arc(c, r + w / 2.0, 0.0, TAU, 96, Color.BLACK, w)
	scope.draw_arc(c, r, 0.0, TAU, 96, Color(0.1, 0.1, 0.1), 6.0)
	var line := Color(0, 0, 0, 0.85)
	scope.draw_line(Vector2(c.x - r, c.y), Vector2(c.x - 14, c.y), line, 2.0)
	scope.draw_line(Vector2(c.x + 14, c.y), Vector2(c.x + r, c.y), line, 2.0)
	scope.draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y - 14), line, 2.0)
	scope.draw_line(Vector2(c.x, c.y + 14), Vector2(c.x, c.y + r), line, 2.0)
	scope.draw_circle(c, 2.0, Color(0.9, 0.1, 0.05))


## End-of-wave summary card under the compass.
func _build_summary(root: Control) -> void:
	summary = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.05, 0.03, 0.78)
	st.border_color = Color(0.95, 0.7, 0.35, 0.8)
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(18)
	summary.add_theme_stylebox_override("panel", st)
	summary.set_anchors_preset(Control.PRESET_CENTER_TOP)
	summary.position = Vector2(-190, 210)
	summary.custom_minimum_size = Vector2(380, 0)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.visible = false
	root.add_child(summary)
	_summary_lines = VBoxContainer.new()
	_summary_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(_summary_lines)


## Shows the summary for 10 seconds. The first line is the heading.
func show_summary(lines: Array) -> void:
	for c in _summary_lines.get_children():
		c.queue_free()
	for i in lines.size():
		var l := _label(lines[i], 28 if i == 0 else 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if i == 0:
			l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		_summary_lines.add_child(l)
	summary.visible = true
	summary.modulate.a = 0.0
	_summary_time = 10.0


## Flash for a hit from a mutant. angle: 0 = straight ahead, positive = to the right.
func show_damage(angle: float) -> void:
	damage_vignette.modulate.a = 1.0
	damage_arrow.modulate.a = 1.0
	damage_arrow.rotation = angle
	var tw := damage_vignette.create_tween()
	tw.set_parallel(true)
	tw.tween_property(damage_vignette, "modulate:a", 0.0, 0.8)
	tw.tween_property(damage_arrow, "modulate:a", 0.0, 1.4)


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

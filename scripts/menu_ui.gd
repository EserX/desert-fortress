extends RefCounted
## Shared building blocks for the title screen and the pause menu:
## styled panel, buttons, the settings page and the save-slot list.

const ACCENT := Color(0.98, 0.85, 0.6)
const BORDER := Color(0.85, 0.62, 0.35)


## A centred panel with a vertical list inside. Returns the list (VBoxContainer).
static func panel(parent: Node, width := 460.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.11, 0.07, 0.94)
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(26)
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(width, 0)
	box.add_child(col)
	return col


static func title(parent: Node, text: String, size := 32) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT)
	parent.add_child(l)
	return l


static func note(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(1, 1, 1, 0.65)
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 18)
	b.disabled = not enabled
	b.pressed.connect(action)
	parent.add_child(b)
	return b


static func clear(container: Node) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()


## Mouse sensitivity, field of view, volume and fullscreen. Saved automatically.
static func settings_page(col: VBoxContainer) -> void:
	_slider(col, "Mouse sensitivity: %.2fx", "mouse_sensitivity", 0.25, 3.0, 0.05, 1.0)
	_slider(col, "Field of view: %d°", "fov", 60.0, 100.0, 1.0, 1.0)
	_slider(col, "Volume: %d%%", "volume", 0.0, 1.0, 0.05, 100.0)
	var ql := Label.new()
	ql.text = "Graphics quality"
	col.add_child(ql)
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 8)
	col.add_child(qrow)
	var qbuttons: Array = []
	for i in [0, 1, 2]:
		var qb := Button.new()
		qb.text = Settings.QUALITY[i].name
		qb.toggle_mode = true
		qb.button_pressed = Settings.quality == i
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qrow.add_child(qb)
		qbuttons.append(qb)
		qb.pressed.connect(func():
			Settings.set_value("quality", i)
			for j in qbuttons.size():
				qbuttons[j].set_pressed_no_signal(j == i))
	var fs := CheckButton.new()
	fs.text = "Fullscreen (F11)"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool): Settings.set_value("fullscreen", on))
	col.add_child(fs)
	var hints := CheckButton.new()
	hints.text = "First-time hints (turning them on shows them all again)"
	hints.button_pressed = Settings.hints
	hints.toggled.connect(func(on: bool):
		if on:
			Settings.hints_seen = []
		Settings.set_value("hints", on))
	col.add_child(hints)


static func _slider(col: VBoxContainer, fmt: String, key: String, lo: float, hi: float, step: float, shown_scale: float) -> void:
	var label := Label.new()
	col.add_child(label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = Settings.get(key)
	slider.custom_minimum_size = Vector2(0, 24)
	var refresh := func():
		var v: float = Settings.get(key) * shown_scale
		label.text = fmt % (int(v) if fmt.contains("%d") else v)
	refresh.call()
	slider.value_changed.connect(func(v: float):
		Settings.set_value(key, v)
		refresh.call())
	col.add_child(slider)


## One row per save slot with a thumbnail. `mode` is "load" or "save".
## `on_pick(slot)` is called when a slot is chosen (saving over a used slot
## needs a second click to confirm).
static func slot_list(col: VBoxContainer, mode: String, on_pick: Callable) -> void:
	for slot in Game.SLOTS:
		var data := Game.read_slot(slot)
		# You can load from any slot, but you only save manually to 1-3.
		if mode == "save" and slot in ["auto", "quick"]:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)
		var thumb := TextureRect.new()
		thumb.custom_minimum_size = Vector2(112, 63)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.texture = Game.thumbnail(slot)
		row.add_child(thumb)
		var b := Button.new()
		b.text = Game.describe_slot(slot)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 63)
		b.clip_text = true
		if mode == "load":
			b.disabled = data.is_empty()
			b.pressed.connect(func(): on_pick.call(slot))
		else:
			var armed := [false]
			b.pressed.connect(func():
				if not data.is_empty() and not armed[0]:
					armed[0] = true
					b.text = "Overwrite %s? Click again to confirm" % Game.slot_label(slot)
					return
				on_pick.call(slot))
		row.add_child(b)

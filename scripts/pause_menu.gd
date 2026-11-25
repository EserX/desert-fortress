extends CanvasLayer
## Esc menu: pauses the game, settings (mouse sensitivity, field of view,
## volume, fullscreen) and quit. Settings are saved automatically.

var _panel: Control
var _sens_label: Label
var _fov_label: Label
var _vol_label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			resume()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	get_tree().paused = true
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	get_tree().paused = false
	_panel.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.11, 0.07, 0.95)
	style.border_color = Color(0.85, 0.62, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(420, 0)
	box.add_child(col)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.6))
	col.add_child(title)

	col.add_child(_button("Resume", resume))

	_sens_label = _slider_row(col, "mouse_sensitivity", 0.25, 3.0, 0.05)
	_fov_label = _slider_row(col, "fov", 60.0, 100.0, 1.0)
	_vol_label = _slider_row(col, "volume", 0.0, 1.0, 0.05)
	_update_labels()

	var fs := CheckButton.new()
	fs.text = "Fullscreen (F11)"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool): Settings.set_value("fullscreen", on))
	Settings.changed.connect(func(): fs.set_pressed_no_signal(Settings.fullscreen))
	col.add_child(fs)

	col.add_child(_button("Quit game", func(): get_tree().quit()))

	var hint := Label.new()
	hint.text = "Esc to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	col.add_child(hint)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(action)
	return b


func _slider_row(parent: Container, key: String, lo: float, hi: float, step: float) -> Label:
	var label := Label.new()
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = Settings.get(key)
	slider.custom_minimum_size = Vector2(0, 24)
	slider.value_changed.connect(func(v: float):
		Settings.set_value(key, v)
		_update_labels())
	parent.add_child(slider)
	return label


func _update_labels() -> void:
	_sens_label.text = "Mouse sensitivity: %.2fx" % Settings.mouse_sensitivity
	_fov_label.text = "Field of view: %d°" % int(Settings.fov)
	_vol_label.text = "Volume: %d%%" % int(Settings.volume * 100.0)

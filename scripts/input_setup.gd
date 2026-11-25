extends Node
## Registers all input actions in code so the key map lives in one readable place.
## Physical keycodes are used so WASD works on any keyboard layout (e.g. Lithuanian).

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"pause": [KEY_ESCAPE],
	"toggle_fullscreen": [KEY_F11],
	"crouch": [KEY_CTRL, KEY_C],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"interact": [KEY_E],
}


func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		Settings.set_value("fullscreen", not Settings.fullscreen)

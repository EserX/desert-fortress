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
	"inventory": [KEY_TAB, KEY_I],
	"drop": [KEY_Q],
	"use_item": [KEY_F],
	"map": [KEY_M],
	"build": [KEY_B],
	"rotate": [KEY_R],
	"hotbar_1": [KEY_1], "hotbar_2": [KEY_2], "hotbar_3": [KEY_3],
	"hotbar_4": [KEY_4], "hotbar_5": [KEY_5], "hotbar_6": [KEY_6],
	"hotbar_7": [KEY_7], "hotbar_8": [KEY_8], "hotbar_9": [KEY_9],
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

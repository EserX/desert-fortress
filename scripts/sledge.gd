extends RefCounted
## v2.2: the sledgehammer, made at the workbench from metal plates. Left click
## on a building piece knocks it down in one blow (the same half refund as the
## hammer's demolish, no second click), on a rock it smashes off ROCK_HITS hits'
## worth of stone at once. At anything else it swings as a heavy weapon (its
## stats are in melee.gd). main.gd routes input and the prompt here.

const Melee = preload("res://scripts/melee.gd")

const ROCK_HITS := 3

var main  # Main: piece_under_crosshair(), demolish_piece(), rock_under_crosshair(), mine_rock()


## Left click with the sledgehammer at a piece or a rock. Returns true if used
## (false lets the click swing it as a weapon).
func handle_input(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	var key: String = main.piece_under_crosshair()
	var rock: int = main.rock_under_crosshair() if key == "" else -1
	if key == "" and rock < 0:
		return false
	return blow(key, rock)


## One blow at a piece (key) or a rock. Returns true if the click was used
## (also while the last swing is still going or you are out of breath).
func blow(key: String, rock := -1) -> bool:
	var melee = main.melee
	var w: Dictionary = Melee.WEAPONS["sledgehammer"]
	if melee.swing_time >= 0.0 and melee.swing_time < w.cooldown:
		return true
	if not main.use_stamina(w.stamina * main.camp.load_mult()):
		return true
	melee.play_swing(w.cooldown)
	if key != "":
		main.demolish_piece(key)
		return true
	var got := 0
	for i in ROCK_HITS:
		var n: int = main.mine_rock(rock)
		if n <= 0:
			break
		got += n
	if got > 0:
		main.hud.show_pickup(["+%d Stone" % got])
	return true


## "Brick wall 1200/1200\n[LMB] Knock it down (back: 6 brick, 1 clay)", or "".
func prompt() -> String:
	var key: String = main.piece_under_crosshair()
	if key != "":
		var rec: Dictionary = main.building.pieces[key]
		var back: Dictionary = main.building.refund(rec)
		return "%s  %d/%d\n[LMB] Knock it down (back: %s)" % [main.building.describe(rec), rec.hp, main.building.max_hp(rec),
				main._cost_text(back) if not back.is_empty() else "nothing"]
	var rock: int = main.rock_under_crosshair()
	if rock >= 0:
		return "Rock\n[LMB] Smash it for stone (%d hits left, %d a blow)" % [main.rock_hits_left(rock), ROCK_HITS]
	return ""

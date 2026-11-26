extends Node3D
## Builds the world at startup: sky, sun and moon, day/night cycle, terrain,
## props, player, HUD, ambience and the pause menu.

const Terrain = preload("res://scripts/terrain.gd")
const Props = preload("res://scripts/props.gd")
const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")
const DayNight = preload("res://scripts/day_night.gd")
const Ambience = preload("res://scripts/ambience.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const Loot = preload("res://scripts/loot.gd")
const Items = preload("res://scripts/items.gd")
const Inventory = preload("res://scripts/inventory.gd")
const InventoryUI = preload("res://scripts/inventory_ui.gd")
const Survival = preload("res://scripts/survival.gd")
const DeathScreen = preload("res://scripts/death_screen.gd")
const MapUI = preload("res://scripts/map_ui.gd")
const Building = preload("res://scripts/building.gd")
const BuildMode = preload("res://scripts/build_mode.gd")
const BaseZone = preload("res://scripts/base_zone.gd")
const Melee = preload("res://scripts/melee.gd")
const Dummy = preload("res://scripts/dummy.gd")
const Mutants = preload("res://scripts/mutants.gd")
const Waves = preload("res://scripts/waves.gd")
const Guns = preload("res://scripts/guns.gd")
const Traps = preload("res://scripts/traps.gd")
const Power = preload("res://scripts/power.gd")
const Turrets = preload("res://scripts/turrets.gd")

const DISCOVER_RANGE := 45.0
const REFILLS_PER_MORNING := 4
const SUPPLY_CHANCE := 0.5
const HAMMER_REACH := 3.5
const CHEST_REACH := 4.0  # walk further than this from an open chest or bench and it closes

## When true the world is only a backdrop for the title screen:
## no player, HUD or pause menu, just a slowly orbiting camera.
var menu_mode := false
var world_seed := 1337
var _orbit_camera: Camera3D
var _orbit_angle := 0.6

var terrain: Terrain
var props: Props
var player: Player
var hud: Hud
var day_night: DayNight
var ambience: Ambience
var pause_menu: PauseMenu
var loot: Loot
var inventory: Inventory
var inventory_ui: InventoryUI
var survival: Survival
var death_screen: DeathScreen
var in_shade := false
var _shade_timer := 0.0
var map_ui: MapUI
var building: Building
var build_mode: BuildMode
var base_zone: BaseZone
var melee: Melee
var dummy: Dummy
var mutants: Mutants
var waves: Waves
var guns: Guns
var traps: Traps
var power: Power
var turrets: Turrets
## Wrecks and ruins: {"key": "w3", "kind": "wreck", "pos": Vector3}.
var places: Array = []
## Keys of places you have been near.
var discovered := {}
var _demolish_armed := ""
var _demolish_until := 0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial


func _ready() -> void:
	if not menu_mode:
		world_seed = Game.world_seed
	_setup_environment()

	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.generate(world_seed)

	props = Props.new()
	props.name = "Props"
	add_child(props)
	props.populate(terrain, world_seed)

	for i in props.wreck_positions.size():
		places.append({"key": "w%d" % i, "kind": "wreck", "pos": props.wreck_positions[i]})
	for i in props.ruin_positions.size():
		places.append({"key": "r%d" % i, "kind": "ruin", "pos": props.ruin_positions[i]})

	building = Building.new()
	building.name = "Building"
	building.terrain = terrain
	add_child(building)

	base_zone = BaseZone.new()
	base_zone.name = "BaseZone"
	base_zone.terrain = terrain
	add_child(base_zone)

	dummy = Dummy.new()
	dummy.name = "TrainingDummy"
	dummy.position = Vector3(-3.0, terrain.surface_height(-3.0, 4.0), 4.0)
	dummy.rotation.y = 0.5
	add_child(dummy)

	loot = Loot.new()
	loot.name = "Loot"
	loot.world_seed = world_seed
	for c in props.containers:
		loot.register(c.id, c.kind, c.lid)
	add_child(loot)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, moon, env, sky_mat)

	if menu_mode:
		_setup_orbit_camera()
		ambience = Ambience.new()
		add_child(ambience)
		return

	player = Player.new()
	player.name = "Player"
	var spawn := Vector3(0, terrain.surface_height(0, 9) + 1.0, 9)
	player.position = spawn
	player.spawn_point = spawn
	player.play_radius = terrain.PLAY_RADIUS
	add_child(player)

	ambience = Ambience.new()
	ambience.name = "Ambience"
	ambience.player = player
	ambience.day_night = day_night
	add_child(ambience)

	mutants = Mutants.new()
	mutants.name = "Mutants"
	mutants.terrain = terrain
	mutants.building = building
	mutants.player = player
	mutants.world_seed = world_seed
	mutants.player_dead = func(): return survival == null or survival.dead
	add_child(mutants)
	mutants.top_up(day_night.day)

	traps = Traps.new()
	traps.name = "Traps"
	traps.building = building
	traps.mutants = mutants
	traps.player = player
	add_child(traps)
	traps.exploded.connect(func(pos): mutants.alert(pos, 60.0))

	turrets = Turrets.new()
	turrets.name = "Turrets"
	turrets.building = building
	turrets.mutants = mutants
	add_child(turrets)
	turrets.fired.connect(mutants.alert)

	power = Power.new()
	power.name = "Power"
	power.building = building
	power.day_night = day_night
	add_child(power)

	waves = Waves.new()
	waves.name = "Waves"
	waves.mutants = mutants
	waves.world_seed = world_seed
	add_child(waves)
	power.waves = waves
	day_night.dusk_started.connect(waves.on_dusk)
	day_night.night_started.connect(func(_d): waves.start_wave())
	day_night.day_started.connect(waves.on_dawn)
	mutants.mutant_killed.connect(waves.note_kill)
	building.piece_destroyed.connect(func(_k, _t): waves.note_lost())
	building.piece_collapsed.connect(func(_k, _t): waves.note_lost())

	inventory = Inventory.new()
	inventory.changed.connect(func(): player.overloaded = inventory.overloaded())
	inventory.add("hammer", 1)  # everyone starts with a hammer
	inventory.add("pipe", 1)    # and a rusty pipe

	melee = Melee.new()
	melee.name = "Hands"
	melee.player = player
	player.camera.add_child(melee)

	guns = Guns.new()
	guns.name = "Guns"
	guns.player = player
	guns.inventory = inventory
	player.camera.add_child(guns)

	build_mode = BuildMode.new()
	build_mode.name = "BuildMode"
	build_mode.building = building
	build_mode.inventory = inventory
	build_mode.player = player
	add_child(build_mode)

	survival = Survival.new()
	survival.name = "Survival"
	add_child(survival)
	player.landed.connect(survival.fall)

	hud = Hud.new()
	hud.survival = survival
	hud.inventory = inventory
	hud.name = "HUD"
	hud.player = player
	hud.day_night = day_night
	hud.waves = waves
	add_child(hud)

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	# Added after the pause menu so it sees Esc first while open.
	inventory_ui = InventoryUI.new()
	inventory_ui.name = "InventoryUI"
	inventory_ui.inventory = inventory
	inventory_ui.drop_requested.connect(drop_slot)
	inventory_ui.crafted.connect(_on_crafted)
	building.spilled.connect(func(items, pos): loot.spawn_drop(items, Vector3(pos.x, terrain.surface_height(pos.x, pos.z), pos.z)))
	add_child(inventory_ui)

	death_screen = DeathScreen.new()
	death_screen.name = "DeathScreen"
	death_screen.respawn_pressed.connect(respawn)
	add_child(death_screen)
	map_ui = MapUI.new()
	map_ui.name = "MapUI"
	map_ui.main = self
	add_child(map_ui)

	survival.died.connect(_on_died)
	survival.died.connect(waves.note_death)
	waves.wave_started.connect(func(n, _size): hud.show_banner("Wave %d is coming: %s. Defend the base!" % [n, Waves.mix_text(waves.queue)]))
	waves.wave_ended.connect(func(s): hud.show_summary(Waves.summary_lines(s)))
	waves.siren.connect(func(): hud.show_banner("Siren! Mutants come at nightfall. Get back to the base."))
	mutants.player_hit.connect(_on_player_hit)
	mutants.piece_hit.connect(_on_piece_attacked)
	traps.player_hurt.connect(func(dmg, from, cause):
		if survival.dead:
			return
		survival.damage(dmg, cause)
		var local: Vector3 = player.global_transform.basis.inverse() * (from - player.global_position)
		hud.show_damage(atan2(local.x, -local.z)))
	building.piece_destroyed.connect(func(_k, t): hud.show_pickup(["%s was destroyed!" % Building.PIECES[t].name]))
	building.piece_collapsed.connect(func(_k, t): hud.show_pickup(["%s collapsed" % Building.PIECES[t].name]))
	melee.hit_landed.connect(hud.show_hitmarker)
	guns.hit_landed.connect(hud.show_hitmarker)
	guns.fired.connect(mutants.alert)
	hud.guns = guns
	survival.warning.connect(hud.show_banner)

	day_night.day_started.connect(_on_morning)
	day_night.day_started.connect(mutants.top_up)
	# Autosave every morning (after the morning loot is in place).
	day_night.day_started.connect(func(_d): Game.save_game("auto", _screenshot()))
	Game.saved.connect(func(slot): hud.show_banner("Game saved (%s)" % Game.slot_label(slot)))
	Game.world_ready(self)


func _unhandled_input(event: InputEvent) -> void:
	if menu_mode or get_tree().paused:
		return
	if event.is_action_pressed("quick_save"):
		Game.save_game("quick", _screenshot())
	elif inventory_ui.is_open():
		return
	elif event.is_action_pressed("build"):
		build_mode.toggle()
		hud.show_pickup(["Build mode on" if build_mode.active else "Build mode off"])
	elif build_mode.active and _build_input(event):
		get_viewport().set_input_as_handled()
	elif holding_hammer() and _hammer_input(event):
		get_viewport().set_input_as_handled()
	elif guns.item != "" and _gun_input(event):
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Melee.is_weapon(melee.item):
		melee.try_swing()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		interact(player.interact_target())
	elif event.is_action_pressed("use_item"):
		use_selected()
	elif event.is_action_pressed("drop"):
		drop_slot(inventory.selected)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var step := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		select_hotbar(posmod(inventory.selected + step, Inventory.HOTBAR))
	elif event.is_action_pressed("quick_load"):
		if not Game.load_game("quick"):
			hud.show_banner("No quicksave yet (F5 to quicksave)")


func _process(delta: float) -> void:
	if survival and not get_tree().paused:
		_shade_timer -= delta
		if _shade_timer <= 0.0:
			_shade_timer = 0.5
			in_shade = _check_shade()
			_discover_nearby()
		survival.tick(delta, day_night.hour, player.sprinting, in_shade)
		mutants.night = day_night.is_night()
	if hud and not get_tree().paused:
		var text := ""
		if not inventory_ui.is_open():
			text = _prompt_for(player.interact_target())
			if text == "" and holding_hammer():
				text = hammer_prompt(piece_under_crosshair())
		hud.set_prompt(text)
		for i in Inventory.HOTBAR:
			if Input.is_action_just_pressed("hotbar_%d" % (i + 1)) and not inventory_ui.is_open():
				if build_mode.active:
					build_mode.select(i)
				else:
					select_hotbar(i)
		hud.build_label.text = build_mode.status_text() if build_mode.active else ""
		base_zone.set_highlight(build_mode.active)
		var held: Dictionary = inventory.selected_stack()
		var hand: String = "" if build_mode.active or survival.dead or held.is_empty() else held.item
		melee.set_item(hand)
		guns.set_item(hand)
		if inventory_ui.is_open() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			guns.set_ads(false)
		_check_station_reach()
	if _orbit_camera:
		_orbit_angle += delta * 0.04
		var target := Vector3(0, terrain.BASE_HEIGHT + 3.0, 0)
		_orbit_camera.position = target + Vector3(cos(_orbit_angle) * 48.0, 16.0, sin(_orbit_angle) * 48.0)
		_orbit_camera.look_at(target)


func _setup_orbit_camera() -> void:
	_orbit_camera = Camera3D.new()
	_orbit_camera.fov = 60.0
	_orbit_camera.far = 900.0
	add_child(_orbit_camera)
	_orbit_camera.make_current()
	day_night.hour = 18.9
	day_night.time_scale = 0.0
	day_night._apply()
	_process(0.0)


## Current frame as an image (for save thumbnails), or null when headless.
func _screenshot() -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	return get_viewport().get_texture().get_image()


## Best picture for a save thumbnail: the game frame from before the pause
## menu opened, otherwise the current frame.
func thumbnail_image() -> Image:
	if pause_menu and pause_menu.is_open() and pause_menu._shot:
		return pause_menu._shot
	return _screenshot()


func holding_hammer() -> bool:
	var s := inventory.selected_stack()
	return not s.is_empty() and s.item == "hammer" and not build_mode.active


## Slot key of the built piece under the crosshair (within hammer reach), or "".
func piece_under_crosshair() -> String:
	var hit := player.look_hit(HAMMER_REACH)
	var n: Node = hit.get("collider")
	while n and n != building:
		if n.has_meta("piece_key"):
			return n.get_meta("piece_key")
		n = n.get_parent()
	return ""


static func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for item in cost:
		parts.append("%d %s" % [cost[item], Items.display_name(item).to_lower()])
	return ", ".join(parts)


## "Scrap metal wall 420/600   [LMB] Upgrade to concrete (3 cement bag, 1 scrap metal)   [RMB] Demolish"
func hammer_prompt(key: String) -> String:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty():
		return ""
	var text := "%s  %d/%d" % [building.describe(rec), rec.hp, building.max_hp(rec)]
	var rep := building.repair_cost(rec)
	var up := building.upgrade_cost(rec)
	if not rep.is_empty():
		text += "\n[LMB] Repair (%s)" % _cost_text(rep)
	elif not up.is_empty():
		text += "\n[LMB] Upgrade to %s (%s)" % [building.TIER_NAMES[rec.tier + 1], _cost_text(up)]
	elif not Building.PIECES[rec.type].get("fixed", false):
		text += "\nFully upgraded"
	else:
		text += "\n"
	if _demolish_armed == key and Time.get_ticks_msec() < _demolish_until:
		return text + "   [RMB again] Demolish for real"
	return text + "   [RMB] Demolish"


func _pay(cost: Dictionary) -> bool:
	for item in cost:
		if inventory.count_of(item) < cost[item]:
			hud.show_banner("Not enough materials: " + _cost_text(cost))
			return false
	for item in cost:
		inventory.remove(item, cost[item])
	return true


## Hammer: left click repairs or upgrades, right click twice demolishes.
func hammer_use(key: String) -> void:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty():
		return
	var rep := building.repair_cost(rec)
	melee.play_swing(0.45)
	if not rep.is_empty():
		if _pay(rep):
			building.repair(key)
			hud.show_pickup(["Repaired " + building.describe(rec).to_lower()])
	elif not building.upgrade_cost(rec).is_empty():
		if _pay(building.upgrade_cost(rec)):
			building.upgrade(key)
			hud.show_pickup(["Upgraded to " + building.describe(rec).to_lower()])


## First right click arms, a second within 3 seconds demolishes with a half refund.
func hammer_demolish(key: String) -> bool:
	if _demolish_armed != key or Time.get_ticks_msec() > _demolish_until:
		_demolish_armed = key
		_demolish_until = Time.get_ticks_msec() + 3000
		return false
	_demolish_armed = ""
	var back: Dictionary = building.refund(building.pieces[key])
	building.remove(key)
	building.collapse_unsupported()  # whatever it held up comes down too
	var left := inventory.add_all(back)
	if not left.is_empty():
		loot.spawn_drop(left, _drop_spot())
	hud.show_pickup(["Demolished, got back " + (_cost_text(back) if not back.is_empty() else "nothing")])
	return true


func _hammer_input(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return false
	var key := piece_under_crosshair()
	if key == "":
		return false
	if event.button_index == MOUSE_BUTTON_LEFT:
		hammer_use(key)
	else:
		hammer_demolish(key)
	return true


## Left click fires, right click (held) aims, R reloads. Returns true if used.
func _gun_input(event: InputEvent) -> bool:
	if event.is_action_pressed("rotate"):
		guns.start_reload()
		return true
	if not event is InputEventMouseButton or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		guns.try_fire()
		return true
	if event.button_index == MOUSE_BUTTON_RIGHT:
		guns.set_ads(event.pressed)
		return true
	return false


func _prompt_for(id: String) -> String:
	for prefix in ["gate:", "chest:", "bench:", "gen:", "fire:", "turret:"]:
		if id.begins_with(prefix):
			return building.prompt(id)
	return loot.prompt(id)


## Mouse and R while building. Returns true if the event was used.
func _build_input(event: InputEvent) -> bool:
	if event.is_action_pressed("rotate"):
		build_mode.rotate_piece()
		return true
	if not (event is InputEventMouseButton and event.pressed) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			build_mode.try_place()
		MOUSE_BUTTON_RIGHT:
			var t := build_mode.try_remove()
			if t == "old":
				hud.show_banner("Too late to undo. Use the hammer (right click) to demolish.")
			elif t != "":
				hud.show_pickup(["Took down " + Building.PIECES[t].name.to_lower()])
		MOUSE_BUTTON_WHEEL_UP:
			build_mode.cycle(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			build_mode.cycle(1)
		_:
			return false
	return true


## E on a container or a dropped bag: put what fits in the inventory.
func interact(id: String) -> void:
	if id == "":
		return
	if id.begins_with("gate:"):
		building.toggle_gate(id.trim_prefix("gate:"))
		return
	if id.begins_with("chest:"):
		var storage = building.storage_of(id.trim_prefix("chest:"))
		if storage:
			inventory_ui.open_chest(id.trim_prefix("chest:"), storage)
		return
	if id.begins_with("bench:"):
		if building.pieces.has(id.trim_prefix("bench:")):
			inventory_ui.open_bench(id.trim_prefix("bench:"))
		return
	if id.begins_with("gen:"):
		if not power.add_fuel(id.trim_prefix("gen:"), inventory):
			hud.show_banner("The tank is full" if inventory.count_of("fuel") > 0 else "You have no fuel cans. Search car trunks.")
		return
	if id.begins_with("turret:"):
		var n := load_turret(id.trim_prefix("turret:"))
		if n > 0:
			hud.show_pickup(["Loaded %d rounds into the turret" % n])
		else:
			hud.show_banner("The turret is full" if inventory.count_of("ammo_9mm") > 0 else "You have no 9mm rounds to load")
		return
	if id.begins_with("fire:"):
		if not power.add_wood(id.trim_prefix("fire:"), inventory):
			hud.show_banner("The fire pit is full" if inventory.count_of("wood") > 0 else "You need wood for the fire")
		return
	var items: Dictionary
	if loot.drops.has(id):
		items = loot.drops[id].items
	else:
		items = loot.open(id)
	if items.is_empty():
		return
	var left := inventory.add_all(items)
	var lines: Array = []
	for item in items:
		var n: int = items[item] - int(left.get(item, 0))
		if n > 0:
			lines.append("+%d %s" % [n, Items.display_name(item)])
	hud.show_pickup(lines)
	if loot.drops.has(id):
		loot.set_drop_items(id, left)
	elif not left.is_empty():
		loot.spawn_drop(left, _drop_spot())
	if not left.is_empty():
		hud.show_banner("Inventory full")


## Moves your 9mm rounds into a turret's ammo box. Returns how many went in.
func load_turret(key: String) -> int:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty():
		return 0
	var n := inventory.remove("ammo_9mm", Building.TURRET_AMMO - rec.ammo)
	rec.ammo += n
	return n


## Closes the chest or workbench screen when you walk off or it is taken down.
func _check_station_reach() -> void:
	var key: String = inventory_ui.chest_key if inventory_ui.chest_key != "" else inventory_ui.bench_key
	if key == "" or not inventory_ui.is_open():
		return
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty() or rec.node.global_position.distance_to(player.global_position) > CHEST_REACH:
		inventory_ui.close()


func _on_crafted(id: String, left: Dictionary) -> void:
	hud.show_pickup(["Made %s" % Items.display_name(id).to_lower()])
	if not left.is_empty():
		loot.spawn_drop(left, _drop_spot())
		hud.show_banner("Inventory full: it is in a bag at your feet")


## Drops a whole stack in a bag at your feet.
func drop_slot(i: int) -> void:
	var s := inventory.take_slot(i)
	if not s.is_empty():
		loot.spawn_drop({s.item: s.count}, _drop_spot())


## Eat or drink the selected hotbar item.
func use_selected() -> void:
	var s := inventory.selected_stack()
	if s.is_empty() or not Survival.can_consume(s.item):
		return
	survival.consume(s.item)
	var verb := {"water": "Drank", "bandage": "Used"}.get(s.item, "Ate") as String
	hud.show_pickup(["%s %s" % [verb, Items.display_name(s.item).to_lower()]])
	inventory.take_one(inventory.selected)


## True when something (a wall, a wreck, a dune) blocks the sun.
func _check_shade() -> bool:
	if day_night.is_night():
		return true
	var to_sun := sun.global_transform.basis.z.normalized()
	if to_sun.y < 0.05:
		return true
	var from := player.head.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + to_sun * 150.0, 1, [player.get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _discover_nearby() -> void:
	for place in places:
		if not discovered.has(place.key) and Vector2(place.pos.x - player.position.x, place.pos.z - player.position.z).length() < DISCOVER_RANGE:
			discovered[place.key] = true


## True if a place still has an unsearched container.
func place_has_loot(place: Dictionary) -> bool:
	var prefix: String = place.key + "_"
	for id in loot.containers:
		if id.begins_with(prefix) and not loot.containers[id].opened:
			return true
	return false


## New day: clear out empty supply crates, refill a few searched spots and
## maybe drop a new supply crate.
func _on_morning(d: int) -> void:
	loot.remove_empty_supplies()
	var n := loot.refill(d, REFILLS_PER_MORNING)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("supply:%d:%d" % [world_seed, d])
	var text := "Some searched spots have new loot." if n > 0 else ""
	if rng.randf() < SUPPLY_CHANCE:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(60.0, 200.0)
		var x := cos(ang) * r
		var z := sin(ang) * r
		loot.spawn_supply("supply_%d" % d, Vector3(x, terrain.surface_height(x, z), z))
		text = (text + " " if text != "" else "") + "A supply crate was dropped. Check your map (M)."
	if text != "":
		# After the "Day N" banner has had its moment.
		get_tree().create_timer(5.5).timeout.connect(func(): hud.show_banner(text))


func _on_died() -> void:
	var cause := "You fell too far."
	if survival.cause != "":
		cause = survival.cause
	elif survival.water <= 0.0:
		cause = "You died of thirst."
	elif survival.food <= 0.0:
		cause = "You starved."
	if inventory_ui.is_open():
		inventory_ui.close()
	death_screen.open(cause)


## A mutant clawed you: lose health, red flash on the side it came from.
func _on_player_hit(dmg: float, from: Vector3, kind := "walker") -> void:
	if survival.dead:
		return
	var who: String = Mutants.Mutant.TYPES.get(kind, {}).get("name", "mutant").to_lower()
	survival.damage(dmg, ("Acid from a spitter got you." if kind == "spitter" and dmg > 10.0 else "A %s got you." % who))
	waves.note_damage(dmg)
	var to: Vector3 = from - player.global_position
	var local: Vector3 = player.global_transform.basis.inverse() * to
	hud.show_damage(atan2(local.x, -local.z))


var _attack_warned_at := -100000

## Mutants clawing at the base: a warning now and then, saying which way.
func _on_piece_attacked(key: String) -> void:
	if Time.get_ticks_msec() - _attack_warned_at < 20000 or not building.pieces.has(key):
		return
	_attack_warned_at = Time.get_ticks_msec()
	var rec: Dictionary = building.pieces[key]
	var p: Vector3 = rec.node.global_position
	var deg := fposmod(rad_to_deg(atan2(p.x, -p.z)), 360.0)
	var side: String = Hud.DIRS[int(round(deg / 45.0)) % 8]
	hud.show_banner("Mutants are breaking in! (%s side of the base)" % side)


## Back at the base flag with your items.
func respawn() -> void:
	survival.respawn()
	player.position = player.spawn_point
	player.velocity = Vector3.ZERO
	player.stamina = player.STAMINA_MAX
	death_screen.close()


func select_hotbar(i: int) -> void:
	inventory.selected = i
	hud.refresh_hotbar()


## On the sand a step in front of the player.
func _drop_spot() -> Vector3:
	var fwd := -player.global_transform.basis.z
	var p := player.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 1.1
	p.y = terrain.surface_height(p.x, p.z)
	return p


# --- Save / load ---------------------------------------------------------------

func collect_save_data() -> Dictionary:
	return {
		"player": {
			"position": [player.position.x, player.position.y, player.position.z],
			"yaw": player.rotation.y,
			"pitch": player.head.rotation.x,
			"stamina": player.stamina,
		},
		"world": {
			"day": day_night.day,
			"hour": day_night.hour,
		},
		"loot": loot.save_data(),
		"inventory": inventory.save_data(),
		"survival": survival.save_data(),
		"map": {"discovered": discovered.keys()},
		"buildings": building.save_data(),
		"mutants": mutants.save_data(),
		"waves": waves.save_data(),
		"guns": guns.save_data(),
	}


func apply_save_data(data: Dictionary) -> void:
	var w: Dictionary = data.get("world", {})
	day_night.restore(int(w.get("day", 1)), float(w.get("hour", 9.0)))
	loot.load_data(data.get("loot", {}))
	survival.load_data(data.get("survival", {}))
	building.load_data(data.get("buildings", []))
	waves.load_data(data.get("waves", {"wave": maxi(day_night.day - 1, 0)}))
	guns.load_data(data.get("guns", {}))
	if waves.active and not day_night.is_night():
		waves.active = false  # never carry a wave into the day
	if data.has("mutants"):
		mutants.load_data(data.mutants)  # older saves keep the freshly spawned walkers
	discovered = {}
	for key in data.get("map", {}).get("discovered", []):
		discovered[str(key)] = true
	if data.has("inventory"):
		inventory.load_data(data.inventory)
		if inventory.count_of("hammer") == 0:
			inventory.add("hammer", 1)  # saves from before v0.10
		if inventory.count_of("pipe") + inventory.count_of("machete") == 0:
			inventory.add("pipe", 1)  # saves from before v0.12
	else:
		# v0.4 saves kept items as a plain {item: count} list.
		inventory.load_data({})
		var old: Dictionary = data.get("loot", {}).get("inventory", {})
		for item in old:
			if Items.ITEMS.has(item):
				inventory.add(item, int(old[item]))
	var p: Dictionary = data.get("player", {})
	var pos: Array = p.get("position", [])
	if pos.size() == 3:
		player.position = Vector3(pos[0], pos[1], pos[2])
		# Never restore inside the ground.
		player.position.y = maxf(player.position.y, terrain.surface_height(player.position.x, player.position.z))
	player.rotation.y = float(p.get("yaw", 0.0))
	player.head.rotation.x = float(p.get("pitch", 0.0))
	player.stamina = float(p.get("stamina", player.STAMINA_MAX))
	player.velocity = Vector3.ZERO


func _setup_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)

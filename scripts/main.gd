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
const Shop = preload("res://scripts/shop.gd")
const ShopUI = preload("res://scripts/shop_ui.gd")
const Market = preload("res://scripts/market.gd")
const Drone = preload("res://scripts/drone.gd")
const Hints = preload("res://scripts/hints.gd")
const LowPoly = preload("res://scripts/lowpoly.gd")
const Caches = preload("res://scripts/caches.gd")
const HordeStand = preload("res://scripts/horde_stand.gd")
const Nav = preload("res://scripts/nav.gd")
const Water = preload("res://scripts/water.gd")
const Farming = preload("res://scripts/farming.gd")
const Animals = preload("res://scripts/animals.gd")
const Raids = preload("res://scripts/raids.gd")
const Livable = preload("res://scripts/livable.gd")
const Oases = preload("res://scripts/oases.gd")
const Weather = preload("res://scripts/weather.gd")
const Goals = preload("res://scripts/goals.gd")
const EndingUI = preload("res://scripts/ending_ui.gd")
const Throwables = preload("res://scripts/throwables.gd")
const Camp = preload("res://scripts/camp.gd")

## Testing aid (temporary): a green box by the spawn point that holds a full
## stack of every item and tops your cash up to $2000 each time you open it.
## Set to false to remove it from the game.
const TEST_BOX := true
const TEST_CASH := 2000

## How hard a mutant's blow shoves you (m/s, v2.0). A Brute also lifts you off your feet.
const PLAYER_SHOVE := {"walker": 1.5, "runner": 1.0, "brute": 7.5}
const DISCOVER_RANGE := 45.0
const REFILLS_PER_MORNING := 4
const SUPPLY_CHANCE := 0.5
const HAMMER_REACH := 3.5
const SHOVEL_REACH := 4.0
const SHOVEL_COOLDOWN := 0.45  # seconds between digs
const PICK_REACH := 3.0
## Stamina for hard work: a dig, a pickaxe hit, building a piece, a hammer job.
const STAMINA_DIG := 7.0
const STAMINA_PICK := 9.0
const STAMINA_BUILD := 6.0
const STAMINA_HAMMER := 5.0
const STAMINA_CHOP := 8.0
const AXE_REACH := 2.8
## Felled trees grow back after this many mornings; picked-up stones after PEBBLE_DAYS.
const TREE_REGROW_DAYS := 3
const PEBBLE_DAYS := 2
const AREA_R := 8.0  # hammer R / G: repair or upgrade everything this close
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
var nav: Nav
var water: Water
var farming: Farming
var animals: Animals
var raids: Raids
var livable: Livable
var oases: Oases
var weather: Weather
var throwables: Throwables
var camp: Camp  # v2.1: warmth round you, cooking, food going bad, heavy loads
var goals: Goals
var ending_ui: EndingUI
var waves: Waves
var guns: Guns
var traps: Traps
var power: Power
var turrets: Turrets
var shop: Shop
var shop_ui: ShopUI
var market: Market
var drone: Drone
var hints: Hints
var test_box: StaticBody3D
## The horde button stand by the spawn point.
var horde_stand: StaticBody3D
## Holding E at a blueprint keeps building it, one piece every SITE_STEP s.
const SITE_STEP := 0.3
var _site_hold := 0.0
var test_storage: Inventory
## Wrecks and ruins: {"key": "w3", "kind": "wreck", "pos": Vector3}.
var places: Array = []
## Keys of places you have been near.
var discovered := {}
var _shovel_ready_at := 0
## Cable in hand: the piece a cable is being run from ("" when none).
var cable_from := ""
## Rocks broken with the pickaxe (id -> true) and hits left on started ones.
var broken_rocks := {}
var rock_hits := {}
## Trees felled with the axe (id -> day felled), chops left on started ones,
## and loose stones picked up (id -> day).
var felled_trees := {}
var tree_hits := {}
var taken_pebbles := {}
var caches: Caches
var _beep: AudioStreamPlayer
var _beep_t := 0.0
var _dig_marker: MeshInstance3D
var _dig_marker_key := []
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

	# Nothing digs out the ground under the flag, rocks or wrecks.
	for c in props.get_children():
		if c is Node3D:
			terrain.add_no_dig(c.position, 2.0)

	for i in props.wreck_positions.size():
		places.append({"key": "w%d" % i, "kind": "wreck", "pos": props.wreck_positions[i]})
	for i in props.ruin_positions.size():
		places.append({"key": "r%d" % i, "kind": "ruin", "pos": props.ruin_positions[i]})

	building = Building.new()
	building.name = "Building"
	building.terrain = terrain
	add_child(building)

	water = Water.new()
	water.name = "Water"
	water.terrain = terrain
	water.building = building
	water.piece_at_crosshair = piece_under_crosshair
	add_child(water)
	terrain.add_no_dig(water.well.position, 2.0)
	farming = Farming.new()
	farming.name = "Farming"
	farming.terrain = terrain
	farming.water = water
	add_child(farming)
	water.morning_tally.connect(farming.on_tally)  # before the day's litres are cleared

	base_zone = BaseZone.new()
	base_zone.name = "BaseZone"
	base_zone.terrain = terrain
	add_child(base_zone)

	shop = Shop.new()
	shop.name = "ShopTerminal"
	shop.position = Vector3(-2.2, terrain.surface_height(-2.2, 1.6), 1.6)
	shop.rotation.y = PI + 0.5  # screen towards the spawn point
	add_child(shop)

	if TEST_BOX:
		_make_test_box()
		terrain.add_no_dig(test_box.position, 1.3)
	terrain.add_no_dig(shop.position, 1.3)
	if not menu_mode:
		horde_stand = HordeStand.new()
		horde_stand.name = "HordeStand"
		horde_stand.position = Vector3(-3.6, terrain.surface_height(-3.6, 8.6), 8.6)
		horde_stand.rotation.y = 1.46  # button and sign face the spawn point
		add_child(horde_stand)
		terrain.add_no_dig(horde_stand.position, 1.0)

	drone = Drone.new()
	drone.name = "Drone"
	drone.building = building
	add_child(drone)
	shop.drone = drone

	dummy = Dummy.new()
	dummy.name = "TrainingDummy"
	dummy.position = Vector3(-3.0, terrain.surface_height(-3.0, 4.0), 4.0)
	dummy.rotation.y = 0.5
	add_child(dummy)
	terrain.add_no_dig(dummy.position, 1.3)

	loot = Loot.new()
	loot.name = "Loot"
	loot.world_seed = world_seed
	loot.terrain = terrain
	for c in props.containers:
		loot.register(c.id, c.kind, c.lid)
	add_child(loot)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, moon, env, sky_mat)
	_apply_quality()
	Settings.changed.connect(_apply_quality)

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
	player.ladder_check = building.on_ladder
	add_child(player)
	_apply_quality()

	ambience = Ambience.new()
	ambience.name = "Ambience"
	ambience.player = player
	ambience.day_night = day_night
	add_child(ambience)

	nav = Nav.new()
	nav.name = "Nav"
	nav.terrain = terrain
	nav.building = building
	nav.player = player
	nav.player_dead = func(): return survival == null or survival.dead
	add_child(nav)
	nav.rebuild_map()

	mutants = Mutants.new()
	mutants.name = "Mutants"
	mutants.nav = nav
	mutants.terrain = terrain
	mutants.building = building
	mutants.player = player
	mutants.world_seed = world_seed
	mutants.player_dead = func(): return survival == null or survival.dead
	add_child(mutants)
	mutants.health_mult = Game.diff("health")
	mutants.peaceful = Game.is_peaceful()
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
	power.player = player
	add_child(power)

	waves = Waves.new()
	waves.name = "Waves"
	waves.mutants = mutants
	waves.world_seed = world_seed
	waves.size_mult = Game.diff("waves")
	waves.cash_mult = Game.diff("cash")
	waves.peaceful = Game.is_peaceful()
	add_child(waves)
	power.waves = waves
	if horde_stand:
		horde_stand.wave_active = func() -> bool: return waves.active
	day_night.dusk_started.connect(waves.on_dusk)
	day_night.night_started.connect(func(_d): waves.start_wave())
	day_night.day_started.connect(waves.on_dawn)
	mutants.mutant_killed.connect(waves.note_kill)
	building.piece_destroyed.connect(func(_k, _t): waves.note_lost())
	building.piece_collapsed.connect(func(_k, _t): waves.note_lost())

	inventory = Inventory.new()
	inventory.changed.connect(func():
		player.overloaded = inventory.overloaded()
		player.load_mult = Camp.load_factor(inventory.weight(), Inventory.MAX_WEIGHT))
	inventory.add("hammer", 1)  # everyone starts with a hammer
	inventory.add("pipe", 1)    # and a rusty pipe
	water.player = player
	water.inventory = inventory
	farming.player = player
	farming.inventory = inventory

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
	build_mode.shop = shop
	build_mode.pay_stamina = func() -> bool: return use_stamina(STAMINA_BUILD)
	add_child(build_mode)

	survival = Survival.new()
	survival.name = "Survival"
	add_child(survival)
	player.landed.connect(survival.fall)
	survival.need_mult = Game.diff("needs")

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

	market = Market.new()
	market.world_seed = world_seed
	market.day = day_night.day
	day_night.day_started.connect(market.on_morning)
	shop_ui = ShopUI.new()
	shop_ui.name = "ShopUI"
	shop_ui.shop = shop
	shop_ui.market = market
	shop_ui.inventory = inventory
	shop_ui.bought.connect(func(i, left):
		hud.show_pickup(["Bought " + Shop.CATALOG[i].name.to_lower()])
		if not left.is_empty():
			loot.spawn_drop(left, _drop_spot())
			hud.show_banner("Inventory full: the rest is in a bag at your feet"))
	shop_ui.upgrade_bought.connect(func(id): hud.show_pickup(["Base upgrade: " + Shop.UPGRADES[id].name.to_lower()]))
	shop_ui.ordered.connect(func(i): hud.show_pickup(["Ordered " + Shop.DRONE[i].name.to_lower() + " by drone"]))
	shop_ui.market_sold.connect(func(item, n, got): hud.show_pickup(["Sold %d %s for $%d" % [n, Items.display_name(item).to_lower(), got]]))
	shop_ui.market_bought.connect(func(item): hud.show_pickup(["Bought 1 " + Items.display_name(item).to_lower()]))
	add_child(shop_ui)
	drone.delivered.connect(_on_delivery)

	death_screen = DeathScreen.new()
	death_screen.name = "DeathScreen"
	death_screen.respawn_pressed.connect(respawn)
	add_child(death_screen)
	map_ui = MapUI.new()
	map_ui.name = "MapUI"
	map_ui.main = self
	add_child(map_ui)

	survival.died.connect(_on_died)
	terrain.ground_changed.connect(_on_ground_changed)
	caches = Caches.new()
	caches.name = "Caches"
	caches.terrain = terrain
	caches.world_seed = world_seed
	add_child(caches)
	caches.setup()
	caches.found.connect(func(pos, items):
		loot.spawn_drop(items, pos)
		hud.show_banner("You dug up a buried cache! It is in a bag in the hole."))
	day_night.day_started.connect(caches.on_morning)
	_beep = AudioStreamPlayer.new()
	_beep.stream = _beep_sound()
	_beep.volume_db = -10.0
	add_child(_beep)
	_dig_marker = MeshInstance3D.new()
	_dig_marker.name = "DigMarker"
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.35)
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dig_marker.material_override = marker_mat
	_dig_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dig_marker.visible = false
	add_child(_dig_marker)
	hints = Hints.new()
	hints.name = "Hints"
	hints.hud = hud
	add_child(hints)
	_connect_hints()
	survival.died.connect(waves.note_death)
	waves.wave_started.connect(func(n, size):
		if waves.called:
			hud.show_banner("The horde is coming: %s. Here they come!" % Waves.mix_text(waves.queue))
		elif shop.upgrades.radio > 0:
			hud.show_banner("Wave %d is coming: %s. Defend the base!" % [n, Waves.mix_text(waves.queue)])
		else:
			hud.show_banner("Wave %d: %d mutants are coming. Defend the base!" % [n, size]))
	waves.wave_ended.connect(func(s):
		shop.add_cash(int(s.get("cash", 0)))
		hud.show_summary(Waves.summary_lines(s)))
	waves.wave_started.connect(func(_n, _size): waves.stats.pieces = building.pieces.size())
	hud.shop = shop
	waves.siren.connect(func():
		if shop.upgrades.radio > 0:
			hud.show_banner("Radio: wave %d tonight, %s.%s" % [waves.wave + 1, Waves.mix_text(waves.preview_next()),
				" Your water and green land draw %d of them." % waves.lure if waves.lure > 0 else ""])
		else:
			hud.show_banner("Siren! Mutants come at nightfall. Get back to the base."))
	shop.upgraded.connect(func(_id): apply_upgrades())
	mutants.player_hit.connect(_on_player_hit)
	mutants.piece_hit.connect(_on_piece_attacked)
	traps.player_hurt.connect(_on_blast_hurt)
	building.piece_destroyed.connect(func(_k, t): hud.show_pickup(["%s was destroyed!" % Building.PIECES[t].name]))
	building.piece_collapsed.connect(func(_k, t): hud.show_pickup(["%s collapsed" % Building.PIECES[t].name]))
	melee.hit_landed.connect(hud.show_hitmarker)
	guns.hit_landed.connect(hud.show_hitmarker)
	guns.fired.connect(mutants.alert)
	hud.guns = guns
	survival.warning.connect(hud.show_banner)
	water.message.connect(hud.show_banner)
	water.pickup.connect(hud.show_pickup)
	farming.message.connect(hud.show_banner)
	farming.pickup.connect(hud.show_pickup)
	farming.spilled.connect(loot.spawn_drop)
	day_night.hour_changed.connect(farming.on_hour)
	_setup_life()
	_setup_oases()

	day_night.day_started.connect(_on_morning)
	day_night.day_started.connect(water.on_morning)
	day_night.day_started.connect(mutants.top_up)
	_setup_goals()  # after water.on_morning: the rain falls on the new day
	_setup_throwables()
	_setup_camp()
	# Autosave every morning (after the morning loot is in place).
	day_night.day_started.connect(func(_d): Game.save_game("auto", _screenshot()))
	Game.saved.connect(func(slot): hud.show_banner("Game saved (%s)" % Game.slot_label(slot)))
	Game.world_ready(self)


func _unhandled_input(event: InputEvent) -> void:
	if menu_mode or get_tree().paused:
		return
	if event.is_action_pressed("quick_save"):
		Game.save_game("quick", _screenshot())
	elif inventory_ui.is_open() or shop_ui.is_open():
		return
	elif event.is_action_pressed("build"):
		build_mode.toggle()
		hud.show_pickup(["Build mode on" if build_mode.active else "Build mode off"])
	elif build_mode.active and _build_input(event):
		get_viewport().set_input_as_handled()
	elif holding_hammer() and _hammer_input(event):
		get_viewport().set_input_as_handled()
	elif dig_tool() != "" and _shovel_input(event):
		get_viewport().set_input_as_handled()
	elif holding("cable") and _cable_input(event):
		get_viewport().set_input_as_handled()
	elif holding("axe") and _axe_input(event):
		get_viewport().set_input_as_handled()
	elif (holding("watering_can") or holding("water_pipe")) and water.handle_input(event, inventory.selected_stack().item):
		get_viewport().set_input_as_handled()
	elif Farming.crop_of_seed(inventory.selected_stack().get("item", "")) != "" and farming.handle_input(event, inventory.selected_stack().item):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate") and lock_door(player.interact_target()):
		get_viewport().set_input_as_handled()
	elif guns.item != "" and _gun_input(event):
		get_viewport().set_input_as_handled()
	elif holding_throwable() and throwables.handle_input(event, inventory.selected_stack().item):
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
			if camp:
				camp.sense()
		survival.tick(delta, day_night.hour, player.sprinting, in_shade)
		mutants.night = day_night.is_night()
		water.tick(delta, not day_night.is_night())
		animals.tick(delta, day_night.hour)
	if hud and not get_tree().paused:
		var text := ""
		if not inventory_ui.is_open() and not shop_ui.is_open():
			text = _prompt_for(player.interact_target())
			if text == "" and holding_hammer():
				text = hammer_prompt(piece_under_crosshair())
			elif text == "" and dig_tool() != "":
				text = shovel_prompt()
			elif text == "" and holding("metal_detector"):
				text = detector_text()
			elif text == "" and holding("cable"):
				text = cable_prompt(piece_under_crosshair())
			elif text == "" and holding("axe"):
				text = axe_prompt()
			elif text == "" and (holding("watering_can") or holding("water_pipe")):
				text = water.held_prompt(inventory.selected_stack().item)
			elif text == "" and Farming.crop_of_seed(inventory.selected_stack().get("item", "")) != "":
				text = farming.seed_prompt(inventory.selected_stack().item)
			elif text == "" and holding_throwable():
				text = throwables.held_prompt(inventory.selected_stack().item)
			if text == "" and player.interact_target() == "":
				text = farming.look_prompt()  # a plant under the crosshair
		hud.set_prompt(text)
		_hold_site(delta)
		_update_dig_marker()
		for i in Inventory.HOTBAR:
			if Input.is_action_just_pressed("hotbar_%d" % (i + 1)) and not inventory_ui.is_open():
				if build_mode.active:
					build_mode.select(i)
				else:
					select_hotbar(i)
		hud.build_label.text = build_mode.status_text() if build_mode.active else ""
		base_zone.set_highlight(build_mode.active)
		oases.set_highlight(build_mode.active)
		var held: Dictionary = inventory.selected_stack()
		var hand: String = "" if build_mode.active or survival.dead or held.is_empty() else held.item
		if build_mode.active:
			hints.show_hint("build")
		elif hand == "hammer":
			hints.show_hint("hammer")
		elif hand == "shovel":
			hints.show_hint("shovel")
		elif hand == "metal_detector":
			hints.show_hint("detector")
		elif Guns.is_gun(hand):
			hints.show_hint("gun")
		elif Throwables.is_throwable(hand):
			hints.show_hint("throw")
		melee.set_item(hand)
		throwables.set_held(hand if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not inventory_ui.is_open() else "")
		_detector_beep(delta, hand == "metal_detector")
		guns.set_item(hand)
		if inventory_ui.is_open() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			guns.set_ads(false)
		_check_station_reach()
	if _orbit_camera:
		_orbit_angle += delta * 0.04
		var target := Vector3(0, terrain.BASE_HEIGHT + 3.0, 0)
		_orbit_camera.position = target + Vector3(cos(_orbit_angle) * 48.0, 16.0, sin(_orbit_angle) * 48.0)
		_orbit_camera.look_at(target)


## Holding E at a blueprint keeps building it.
func _hold_site(delta: float) -> void:
	if not Input.is_action_pressed("interact"):
		_site_hold = 0.0
		return
	_site_hold -= delta
	if _site_hold > 0.0:
		return
	_site_hold = SITE_STEP
	var target := player.interact_target()
	if target.begins_with("site:") and not inventory_ui.is_open():
		build_site_step(int(target.trim_prefix("site:")))


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


func holding_shovel() -> bool:
	return dig_tool() == "shovel"


## "shovel" or "pickaxe" when one is in your hands, otherwise "".
func dig_tool() -> String:
	var s := inventory.selected_stack()
	if s.is_empty() or build_mode.active or survival.dead or not s.item in ["shovel", "pickaxe"]:
		return ""
	return s.item


func holding_throwable() -> bool:
	var s := inventory.selected_stack()
	return not s.is_empty() and Throwables.is_throwable(s.item) and not build_mode.active and not survival.dead


func holding(item: String) -> bool:
	var s := inventory.selected_stack()
	return not s.is_empty() and s.item == item and not build_mode.active and not survival.dead


## Where a digging tool would dig: a point on the ground under the crosshair, or null.
func dig_point() -> Variant:
	# Looking down into a hole reaches further (about the same distance out).
	var reach := minf(SHOVEL_REACH / maxf(cos(player.head.rotation.x), 0.01), SHOVEL_REACH * 1.6)
	var hit := player.look_hit(reach)
	if hit.is_empty() or hit.collider != terrain:
		return null
	return hit.position


## Id of the rock under the crosshair (within reach), or -1.
func rock_under_crosshair() -> int:
	var hit := player.look_hit(PICK_REACH)
	if hit.is_empty() or not hit.collider.has_meta("rock_id"):
		return -1
	return int(hit.collider.get_meta("rock_id"))


## "Clay, dug 1.75 m deep\n[LMB] Dig   [RMB] Fill (3 sand)", or why you can't.
func shovel_prompt() -> String:
	var tool := dig_tool()
	if tool == "pickaxe":
		var r := rock_under_crosshair()
		if r >= 0:
			return "Rock\n[LMB] Break it for stone (%d hits)" % rock_hits_left(r)
	var p = dig_point()
	if p == null:
		return ""
	return ground_prompt(p, tool)


## What a digging tool would do to the ground at p.
func ground_prompt(p: Vector3, tool: String) -> String:
	var why := terrain.dig_blocked(p.x, p.z)
	if why != "":
		return why
	var depth := terrain.cell_depth(terrain.dig_cell(p.x, p.z))
	var layer := terrain.next_layer(p.x, p.z)
	var text: String = layer.capitalize() if layer != "" else "Bedrock"
	if depth > 0.05:
		text += ", dug %.2f m deep" % depth
	elif depth < -0.05:
		text += ", piled %.2f m high" % -depth
	if layer == "":
		text += "\n[LMB] Can't dig deeper"
	elif layer == "stone" and tool != "pickaxe":
		text += "\n[LMB] Too hard: you need a pickaxe"
	else:
		text += "\n[LMB] Dig"
	if tool == "shovel":
		text += "   [RMB] Fill (%d sand)" % inventory.count_of("sand")
	return text


## Digs (or fills) the cell at p: a dig gives a bag of what comes up (sand, clay
## or stone, deeper down), a fill uses a bag of sand. Solid stone needs the pickaxe.
## Returns "" if the ground moved, or the reason it didn't.
func dig_at(p: Vector3, filling := false, tool := "shovel") -> String:
	var why := terrain.dig_blocked(p.x, p.z)
	if why != "":
		return why
	if filling:
		if inventory.count_of("sand") <= 0:
			return "You have no sand. Dig some up first (left click)."
		if not terrain.fill(p.x, p.z):
			return "You can't pile the sand any higher here"
		inventory.remove("sand", 1)
		return ""
	var layer := terrain.next_layer(p.x, p.z)
	if layer == "":
		return "Bedrock: you can't dig any deeper here"
	if layer == "stone" and tool != "pickaxe":
		return "Solid stone: you need a pickaxe to dig deeper"
	if inventory.add(layer, 1) > 0:
		return "No room in your bag for the %s" % layer
	if not terrain.dig(p.x, p.z):
		inventory.remove(layer, 1)
		return "Bedrock: you can't dig any deeper here"
	return ""


## Pickaxe hits left before a rock breaks.
func rock_hits_left(id: int) -> int:
	return int(rock_hits.get(id, props.rocks[id].hits))


## One pickaxe hit on a rock: a stone each hit, and it breaks after its last.
## Returns how much stone it gave (0 if your bag is full or the rock is gone).
func mine_rock(id: int) -> int:
	if id < 0 or id >= props.rocks.size() or broken_rocks.has(id):
		return 0
	if inventory.add("stone", 1) > 0:
		hud.show_banner("No room in your bag for the stone")
		return 0
	var left := rock_hits_left(id) - 1
	if left <= 0:
		rock_hits.erase(id)
		broken_rocks[id] = true
		props.set_rock_broken(id, true)
		hud.show_pickup(["The rock breaks apart"])
	else:
		rock_hits[id] = left
	return 1


# --- Trees, loose stones and machines (v1.11) ---------------------------------

## Id of the standing tree under the crosshair (within axe reach), or -1.
func tree_under_crosshair() -> int:
	var hit := player.look_hit(AXE_REACH)
	if hit.is_empty() or not hit.collider.has_meta("tree_id"):
		return -1
	var id := int(hit.collider.get_meta("tree_id"))
	return -1 if felled_trees.has(id) else id


func tree_hits_left(id: int) -> int:
	return int(tree_hits.get(id, props.trees[id].hits))


func axe_prompt() -> String:
	var id := tree_under_crosshair()
	if id < 0:
		return ""
	var t: Dictionary = props.trees[id]
	return "%s\n[LMB] Chop (%d hits left, about %d logs)" % ["Date palm" if t.kind == "palm" else "Acacia", tree_hits_left(id), t.logs]


## One axe blow on a tree. On the last one it falls and its logs go in your
## bag (what doesn't fit drops in a bag beside you). Returns the logs it gave.
func chop_tree(id: int) -> int:
	if id < 0 or id >= props.trees.size() or felled_trees.has(id):
		return 0
	var left := tree_hits_left(id) - 1
	if left > 0:
		tree_hits[id] = left
		return 0
	tree_hits.erase(id)
	felled_trees[id] = day_night.day
	var t: Dictionary = props.trees[id]
	var logs: int = t.logs
	var over := inventory.add("log", logs)
	if over > 0:
		loot.spawn_drop({"log": over}, _drop_spot())
		hud.show_banner("Your bag is full: the rest of the logs are in a bag on the ground")
	hud.show_pickup(["Timber! +%d Log" % logs])
	# It topples away from you, then it is gone (no collision on the way down).
	var body: StaticBody3D = t.node
	body.collision_layer = 0
	var away: Vector3 = (body.global_position - player.global_position)
	away.y = 0
	var tw := create_tween()
	var target_rot := Vector3(-away.normalized().z * 1.5, body.rotation.y, away.normalized().x * -1.5) if away.length() > 0.01 else Vector3(1.5, body.rotation.y, 0)
	tw.tween_property(body, "rotation", target_rot, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if felled_trees.has(id):
			props.set_tree_felled(id, true))
	return logs


## Axe: left click on a tree chops it; anywhere else it swings like a weapon.
func _axe_input(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	var id := tree_under_crosshair()
	if id < 0:
		return false
	if melee.swing_time >= 0.0 and melee.swing_time < 0.6:
		return true
	if not use_stamina(STAMINA_CHOP * camp.load_mult()):
		return true
	melee.play_swing(0.6)
	chop_tree(id)
	return true


## E on a loose stone.
func pick_pebble(id: int) -> bool:
	if id < 0 or id >= props.pebbles.size() or taken_pebbles.has(id):
		return false
	if inventory.add("stone", 1) > 0:
		hud.show_banner("No room in your bag for the stone")
		return false
	taken_pebbles[id] = day_night.day
	props.set_pebble_taken(id, true)
	hud.show_pickup(["+1 Stone"])
	return true


## E on a machine: loads what it takes from your pockets and takes what it made.
## Returns [loaded, taken].
func use_machine(key: String) -> Array:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty():
		return [0, 0]
	var m: Dictionary = Building.MACHINES[rec.type]
	var load_n := mini(inventory.count_of(m.in), Building.MACHINE_IN_MAX - int(rec.input))
	if load_n > 0:
		inventory.remove(m.in, load_n)
		rec.input += load_n
	var take := int(rec.output)
	if take > 0:
		var over := inventory.add(m.out, take)
		take -= over
		rec.output = over
	var lines: Array = []
	if load_n > 0:
		lines.append("Loaded %d %s" % [load_n, Items.display_name(m.in).to_lower()])
	if take > 0:
		lines.append("+%d %s" % [take, Items.display_name(m.out)])
	if lines.is_empty():
		hud.show_banner("Bring %s to feed it" % Items.display_name(m.in).to_lower() if int(rec.output) == 0 else "No room in your bag")
	else:
		hud.show_pickup(lines)
	return [load_n, take]


## Morning: felled trees grow back after a few days, loose stones turn up again.
func _regrow(d: int) -> void:
	for id in felled_trees.keys():
		if d - int(felled_trees[id]) >= TREE_REGROW_DAYS:
			felled_trees.erase(id)
			props.set_tree_felled(id, false)
	for id in taken_pebbles.keys():
		if d - int(taken_pebbles[id]) >= PEBBLE_DAYS:
			taken_pebbles.erase(id)
			props.set_pebble_taken(id, false)


## Shovel: left click digs, right click fills. Pickaxe: left click breaks rocks or digs.
func _shovel_input(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	var tool := dig_tool()
	if event.button_index != MOUSE_BUTTON_LEFT and not (event.button_index == MOUSE_BUTTON_RIGHT and tool == "shovel"):
		return false
	var rock := rock_under_crosshair() if tool == "pickaxe" else -1
	var p = dig_point()
	if p == null and rock < 0:
		return false
	if Time.get_ticks_msec() < _shovel_ready_at:
		return true
	var cool := SHOVEL_COOLDOWN * (1.4 if tool == "pickaxe" else 1.0)
	_shovel_ready_at = Time.get_ticks_msec() + int(cool * 1000.0)
	var filling: bool = event.button_index == MOUSE_BUTTON_RIGHT
	if not use_stamina((STAMINA_PICK if tool == "pickaxe" else (STAMINA_DIG * 0.5 if filling else STAMINA_DIG)) * camp.load_mult()):
		return true
	melee.play_swing(cool)
	if rock >= 0:
		if mine_rock(rock) > 0:
			hud.show_pickup(["+1 Stone"])
		return true
	var why := dig_at(p, filling, tool)
	if why != "":
		hud.show_banner(why)
	return true


## A see-through square on the cell the shovel would dig.
func _update_dig_marker() -> void:
	var p = dig_point() if dig_tool() != "" else null
	if p == null or terrain.dig_blocked(p.x, p.z) != "":
		_dig_marker.visible = false
		return
	var c: Vector2i = terrain.dig_cell(p.x, p.z)
	var h: Array = terrain.cell_corners(c)
	_dig_marker.visible = true
	if _dig_marker_key == [c, h]:
		return
	_dig_marker_key = [c, h]
	var x0: float = c.x - terrain.DIG_HALF
	var z0: float = c.y - terrain.DIG_HALF
	var lift := 0.04
	var v := PackedVector3Array([
		Vector3(x0, h[0] + lift, z0), Vector3(x0 + 1, h[1] + lift, z0), Vector3(x0 + 1, h[3] + lift, z0 + 1),
		Vector3(x0, h[0] + lift, z0), Vector3(x0 + 1, h[3] + lift, z0 + 1), Vector3(x0, h[2] + lift, z0 + 1)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_dig_marker.mesh = m


## Metal detector: how close the nearest buried cache is, in beeps.
func detector_text() -> String:
	var d := caches.nearest(player.global_position)
	if d > Caches.RANGE:
		return "Metal detector: no signal (caches are buried near the base)"
	if d > 12.0:
		return "Metal detector: a faint beep now and then"
	if d > 6.0:
		return "Metal detector: beep... beep... (getting closer)"
	if d > 2.0:
		return "Metal detector: fast beeping (very close)"
	return "Metal detector: a steady tone. Dig right here, 1 m down!"


## Beeps faster the closer the nearest cache is.
func _detector_beep(delta: float, on: bool) -> void:
	if not on:
		_beep_t = 0.0
		return
	var d := caches.nearest(player.global_position)
	if d > Caches.RANGE:
		return
	_beep_t -= delta
	if _beep_t <= 0.0:
		_beep_t = clampf(d / 10.0, 0.12, 2.0)
		_beep.pitch_scale = 1.0 + clampf((Caches.RANGE - d) / Caches.RANGE, 0.0, 1.0) * 0.5
		_beep.play()


func _beep_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.07)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := minf(t / 0.005, 1.0) * minf((0.07 - t) / 0.01, 1.0)
		data.encode_s16(i * 2, int(sin(TAU * 1250.0 * t) * env * 12000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


## The ground was dug or filled: pieces settle or fall, and nobody ends up inside the sand.
func _on_ground_changed(area: Rect2) -> void:
	building.settle(area)
	caches.check(area)
	water.on_ground_changed(area)
	farming.on_ground_changed(area)
	var near := area.grow(0.6)
	var bodies: Array = [player]
	bodies.append_array(mutants.get_children())
	for b in bodies:
		if b is CharacterBody3D and near.has_point(Vector2(b.position.x, b.position.z)):
			var g := terrain.surface_height(b.position.x, b.position.z)
			if b.position.y < g:
				b.position.y = g
	loot.ground_changed(near)
	var r := building.zone_radius
	var d := area.get_center().length()
	if d > r - 4.0 and d < r + 4.0:
		base_zone.rebuild()


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
	if rec.slot.level > 0:
		text += "   support %d%%" % int(building.support.get(key, 0.0))
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
		var problem := building.upgrade_problem(key)
		if problem != "":
			hud.show_banner(problem)
			return
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
	if event.is_action_pressed("rotate"):
		var n := area_repair(player.global_position)
		hud.show_pickup(["Repaired %d pieces" % n] if n > 0 else ["Nothing nearby needs repairing (or you lack materials)"])
		return true
	if event.is_action_pressed("move_piece"):
		var key := piece_under_crosshair()
		if key == "":
			hud.show_banner("Look at a piece: G upgrades everything like it nearby")
			return true
		var n := area_upgrade(key)
		hud.show_pickup(["Upgraded %d pieces" % n] if n > 0 else ["Nothing nearby to upgrade (or you lack materials)"])
		return true
	if not (event is InputEventMouseButton and event.pressed) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return false
	var key := piece_under_crosshair()
	if key == "":
		return false
	if event.button_index == MOUSE_BUTTON_LEFT:
		var rec: Dictionary = building.pieces[key]
		if not building.repair_cost(rec).is_empty() or not building.upgrade_cost(rec).is_empty():
			if not use_stamina(STAMINA_HAMMER):
				return true
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
	if id == "shop":
		return "[E] Use the shop terminal   ($%d)" % shop.cash
	if id == "testbox":
		return "[E] Open the TEST box (every item, cash to $%d)" % TEST_CASH
	if id.begins_with("testbox:"):
		return "[E] Open TEST box %d (the newer items)" % (int(id.trim_prefix("testbox:")) + 1)
	if id == "horde":
		return horde_prompt()
	if id == "mainwell":
		return water.well_prompt(inventory.count_of("watering_can") > 0)
	if id.begins_with("sprinkler:"):
		return water.sprinkler_prompt(id.trim_prefix("sprinkler:"))
	if id.begins_with("site:"):
		return building.site_prompt(int(id.trim_prefix("site:")), _cost_text, player.global_position)
	if id.begins_with("pebble:"):
		return "[E] Pick up stone"
	if id.begins_with("animal:"):
		return animals.prompt(id)
	if id.begins_with("oasis:"):
		return oases.prompt(id)
	if id.begins_with("weather:"):
		return weather.prompt(id.trim_prefix("weather:"))
	if id.begins_with("fire:"):
		return building.prompt(id) + camp.cook_prompt(building.pieces.get(id.trim_prefix("fire:"), {}))
	if id.begins_with("machine:"):
		var mk := id.trim_prefix("machine:")
		var mrec: Dictionary = building.pieces.get(mk, {})
		if mrec.is_empty():
			return ""
		return building.machine_prompt(mk, inventory.count_of(Building.MACHINES[mrec.type].in))
	for prefix in ["gate:", "hatch:", "chest:", "bench:", "gen:", "fire:", "turret:", "well:", "switch:"]:
		if id.begins_with(prefix):
			return building.prompt(id)
	return loot.prompt(id)


## "[E] Press the red button: call the horde (8 mutants)"
func horde_prompt() -> String:
	if waves.peaceful:
		return "Horde button   (peaceful mode: no mutants come)"
	if waves.active:
		return "Horde button   (a wave is already out: %d left)" % waves.remaining()
	var n := maxi(waves.wave, 1)
	var rng := RandomNumberGenerator.new()
	return "[E] Press the red button: call the horde now (about %d mutants, like night %d)" % [Waves.wave_mix(n, rng, waves.size_mult).size(), n]


## E at the horde stand: a wave comes for you straight away.
func press_horde_button() -> bool:
	horde_stand.press()
	if waves.peaceful:
		hud.show_banner("Peaceful mode: no mutants come.")
		return false
	if not waves.call_horde(horde_stand.global_position):
		hud.show_banner("A wave is already out. Finish it first.")
		return false
	return true


## Builds the next piece of a blueprint, paid from your pockets and the chests
## in reach. Returns the new piece's key, or "".
func build_site_step(id: int) -> String:
	var nxt: Dictionary = building.site_next(id, player.global_position)
	if not nxt.has("i"):
		hud.show_banner(str(nxt.get("reason", "Nothing to build")))
		return ""
	var cost: Dictionary = Building.PIECES[nxt.type].cost
	if not has_near(cost):
		hud.show_banner("Not enough for the next %s: %s" % [Building.PIECES[nxt.type].name.to_lower(), _cost_text(cost)])
		return ""
	if not use_stamina(STAMINA_BUILD):
		return ""
	pay_near(cost)
	var key := building.build_site_piece(id, nxt)
	if not building.sites.has(id):
		hud.show_pickup(["Finished building!"])
	return key


## Mouse and R while building. Returns true if the event was used.
func _build_input(event: InputEvent) -> bool:
	if event.is_action_pressed("rotate"):
		build_mode.rotate_piece()
		return true
	if event.is_action_pressed("turn_left") or event.is_action_pressed("turn_right"):
		build_mode.fine_turn(-1 if event.is_action_pressed("turn_left") else 1)
		return true
	if event.is_action_pressed("build_menu"):
		build_mode.toggle_prefabs()
		hud.show_pickup(["Ready-made buildings" if build_mode.prefab_mode else "Single pieces"])
		return true
	if build_mode.prefab_mode and event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if build_mode.place_prefab() > 0:
				hud.show_pickup(["Blueprint laid: " + build_mode.Prefabs.display_name(build_mode.current_prefab()), "Press E at it to build"])
			elif build_mode.reason != "":
				hud.show_banner(build_mode.reason)
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var target := player.interact_target()
			if target.begins_with("site:"):
				building.remove_site(int(target.trim_prefix("site:")))
				hud.show_pickup(["Blueprint scrapped"])
			return true
	if build_mode.prefab_mode and event.is_action_pressed("move_piece"):
		return true
	if build_mode.prefab_mode and event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return true
	if event.is_action_pressed("move_piece"):
		if not build_mode.carrying.is_empty():
			build_mode.cancel_carry()
			hud.show_pickup(["Put it back"])
		else:
			var why: String = build_mode.pick_up(build_mode.piece_under_crosshair())
			if why != "":
				hud.show_banner(why)
			else:
				hud.show_pickup(["Picked up " + Building.PIECES[build_mode.carrying.type].name.to_lower()])
		return true
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var n: int = build_mode.end_drag()
		if n > 1:
			hud.show_pickup(["Built %d pieces" % n])
		return true
	if not (event is InputEventMouseButton and event.pressed) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			build_mode.begin_drag()
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
		farming.use_look()  # harvest the plant under the crosshair, if any
		return
	if id == "shop":
		shop_ui.open()
		return
	if id == "testbox" or id.begins_with("testbox:"):
		open_test_box(int(id.trim_prefix("testbox:")) if id != "testbox" else 0)
		return
	if id == "horde":
		press_horde_button()
		return
	if id == "mainwell":
		water.use_well()
		return
	if id.begins_with("sprinkler:"):
		water.toggle_sprinkler(id.trim_prefix("sprinkler:"))
		return
	if id.begins_with("pebble:"):
		pick_pebble(int(id.trim_prefix("pebble:")))
		return
	if id.begins_with("animal:"):
		animals.butcher(id)
		return
	if id.begins_with("oasis:"):
		oases.interact(id)
		return
	if id.begins_with("weather:"):
		return  # nothing to do with them; the prompt says what they do
	if id.begins_with("machine:"):
		use_machine(id.trim_prefix("machine:"))
		return
	if id.begins_with("site:"):
		build_site_step(int(id.trim_prefix("site:")))
		_site_hold = SITE_STEP + 0.15
		return
	if id.begins_with("gate:") or id.begins_with("hatch:"):
		var gk := id.substr(id.find(":") + 1)
		if building.pieces.get(gk, {}).get("locked", false):
			hud.show_banner("The door is locked (R unlocks it)")
		building.toggle_gate(gk)
		return
	if id.begins_with("switch:"):
		building.toggle_switch(id.trim_prefix("switch:"))
		power.tick(0.0)
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
	if id.begins_with("well:"):
		var n := take_water(id.trim_prefix("well:"))
		if n > 0:
			hud.show_pickup(["+%d Water bottle" % n])
		else:
			var w: Dictionary = building.pieces.get(id.trim_prefix("well:"), {})
			hud.show_banner("No room in your bag" if w.get("water", 0.0) >= 1.0 else "The well is still filling")
		return
	if id.begins_with("fire:"):
		if camp.cook(building.pieces.get(id.trim_prefix("fire:"), {})) > 0:
			return
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


## The drone lowered a parcel: blueprints are learned on the spot, the rest is in a bag on the pad.
func _on_delivery(items: Dictionary, pos: Vector3) -> void:
	var learned: Array = shop.learn_blueprints(items)
	for t in learned:
		hud.show_pickup(["Blueprint learned: " + Building.PIECES[t].name])
	if not items.is_empty():
		loot.spawn_drop(items, pos)
	hud.show_banner("Drone delivery on the landing pad" + (": new builds unlocked" if not learned.is_empty() else ""))


## Makes the bought base upgrades take effect: zone size, chest size, bench tier.
func apply_upgrades() -> void:
	building.zone_radius = shop.upgrade_value("zone", Building.ZONE_RADIUS)
	base_zone.set_radius(building.zone_radius)
	water.set_capacity(shop.upgrade_value("well", Water.STORE_BASE))
	water.set_pump(shop.upgrades.pump > 0)
	building.set_chest_slots(shop.upgrade_value("storage", Building.CHEST_SLOTS))
	inventory_ui.bench_tier = shop.upgrade_value("bench", 1)
	inventory_ui.refresh()


## R on a metal door: lock or unlock it. Returns true if the key was used.
func lock_door(id: String) -> bool:
	if not id.begins_with("gate:"):
		return false
	var key := id.trim_prefix("gate:")
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty() or rec.type != "metal_door":
		return false
	if building.toggle_lock(key):
		hud.show_pickup(["Locked the metal door" if rec.locked else "Unlocked the metal door"])
	else:
		hud.show_banner("Close the door first")
	return true


## What the cable does on the piece under the crosshair.
func cable_prompt(key: String) -> String:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty() or not rec.type in Building.WIRED:
		return "Cable: look at a generator, switch, floodlight, fence or turret" if cable_from != "" else ""
	var name: String = Building.PIECES[rec.type].name
	var n := building.cables_of(key).size()
	var take := ("   [RMB] Take up its %d cable%s" % [n, "" if n == 1 else "s"]) if n > 0 else ""
	if cable_from == "" or not building.pieces.has(cable_from):
		return "%s
[LMB] Start a cable here (%d cable)%s" % [name, inventory.count_of("cable"), take]
	if cable_from == key:
		return "%s
[LMB] Cancel this cable" % name
	var why := building.cable_problem(cable_from, key)
	if why != "":
		return "%s
%s" % [name, why]
	return "%s
[LMB] Connect (%d cable of your %d)%s" % [name, building.cable_cost(cable_from, key), inventory.count_of("cable"), take]


## Cable in hand: left click a piece to start a cable, then another to connect
## (paid in cable); right click takes up a piece's cables. Returns "" or why not.
func cable_click(key: String, take_up := false) -> String:
	if not building.pieces.has(key) or not building.pieces[key].type in Building.WIRED:
		return "Cables join generators, switches, floodlights, electric fences and turrets"
	if take_up:
		var back := building.disconnect_all(key)
		inventory.add("cable", back)
		return ""
	if cable_from == "" or not building.pieces.has(cable_from) or cable_from == key:
		cable_from = "" if cable_from == key else key
		return ""
	var why := building.cable_problem(cable_from, key)
	if why != "":
		return why
	var cost := building.cable_cost(cable_from, key)
	if inventory.count_of("cable") < cost:
		return "Not enough cable: this needs %d" % cost
	inventory.remove("cable", cost)
	building.connect_cable(cable_from, key)
	cable_from = ""
	power.tick(0.0)
	return ""


func _cable_input(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return false
	var key := piece_under_crosshair()
	if key == "":
		return false
	var why := cable_click(key, event.button_index == MOUSE_BUTTON_RIGHT)
	if why != "":
		hud.show_banner(why)
	return true


## Storage of every chest within reach (hammer work can be paid from them).
func _nearby_storages() -> Array:
	var out: Array = []
	for key in building.keys_of(["chest"]):
		var rec: Dictionary = building.pieces[key]
		if rec.node.global_position.distance_to(player.global_position) <= CHEST_REACH + 2.0:
			out.append(rec.storage)
	return out


## True if your pockets and the chests within reach hold all of cost.
func has_near(cost: Dictionary) -> bool:
	var stores: Array = [inventory] + _nearby_storages()
	for item in cost:
		var n := 0
		for st in stores:
			n += st.count_of(item)
		if n < cost[item]:
			return false
	return true


## Takes cost from your pockets first, then from the chests within reach.
func pay_near(cost: Dictionary) -> bool:
	if not has_near(cost):
		return false
	var stores: Array = [inventory] + _nearby_storages()
	for item in cost:
		var left: int = cost[item]
		for st in stores:
			left -= st.remove(item, left)
			if left <= 0:
				break
	return true


## Pieces within AREA_R of a point, nearest first.
func _pieces_near(center: Vector3) -> Array:
	var keys: Array = building.pieces.keys().filter(func(k): return building.pieces[k].node.global_position.distance_to(center) <= AREA_R)
	keys.sort_custom(func(a, b): return building.pieces[a].node.global_position.distance_to(center) < building.pieces[b].node.global_position.distance_to(center))
	return keys


## Hammer R: repairs every damaged piece nearby, nearest first, until the
## materials (pockets and chests in reach) or your stamina run out. Returns how many.
func area_repair(center: Vector3) -> int:
	var n := 0
	for key in _pieces_near(center):
		var cost := building.repair_cost(building.pieces[key])
		if cost.is_empty() or not has_near(cost):
			continue
		if not use_stamina(STAMINA_HAMMER):
			break
		pay_near(cost)
		building.repair(key)
		n += 1
	if n > 0:
		melee.play_swing(0.45)
	return n


## Hammer G: upgrades every piece near the one you look at that has its tier,
## nearest first, while you can pay. Returns how many.
func area_upgrade(key: String) -> int:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty():
		return 0
	var tier: int = rec.tier
	var n := 0
	for k in _pieces_near(rec.node.global_position):
		var r: Dictionary = building.pieces[k]
		var cost := building.upgrade_cost(r)
		if r.tier != tier or cost.is_empty() or not building.repair_cost(r).is_empty() or building.upgrade_problem(k) != "" or not has_near(cost):
			continue
		if not use_stamina(STAMINA_HAMMER):
			break
		pay_near(cost)
		building.upgrade(k)
		n += 1
	if n > 0:
		melee.play_swing(0.45)
	return n


## Takes the full bottles out of a well. Returns how many you got.
func take_water(key: String) -> int:
	var rec: Dictionary = building.pieces.get(key, {})
	if rec.is_empty() or not rec.has("water"):
		return 0
	var full := int(floor(rec.water))
	if full <= 0:
		return 0
	var n := full - inventory.add("water", full)
	rec.water -= n
	return n


## Pays stamina for hard work. Too tired: says so and returns false.
func use_stamina(cost: float) -> bool:
	if player.stamina < cost:
		hud.show_banner("Too tired: catch your breath")
		return false
	player.stamina -= cost
	return true


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
	if s.is_empty():
		return
	# Tossed from the hand a step ahead: it falls, rolls and settles (v2.0).
	var b := player.camera.global_transform.basis
	var from := player.camera.global_position - b.z * 0.6 - Vector3(0, 0.35, 0)
	if player.look_hit(0.9).is_empty():
		var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
		loot.toss_drop({s.item: s.count}, from, fwd * 2.2 + Vector3(0, 1.2, 0) + player.velocity * 0.5)
	else:
		loot.spawn_drop({s.item: s.count}, _drop_spot())  # facing a wall: at your feet


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
	_regrow(d)
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
	if shop_ui.is_open():
		shop_ui.close()
	death_screen.open(cause)


## v1.16: animals drawn in by day (animals.gd) and the night side of water:
## waves drawn to the main well and the fields (raids.gd).
func _setup_life() -> void:
	raids = Raids.new()
	raids.name = "Raids"
	raids.water = water
	raids.farming = farming
	raids.mutants = mutants
	raids.waves = waves
	add_child(raids)
	mutants.raid = raids.raid_point
	waves.lure_source = raids.lure
	waves.night_goal = Raids.well_goal()
	waves.goal_source = raids.goal_for
	raids.message.connect(hud.show_banner)
	day_night.night_started.connect(raids.on_night)
	animals = Animals.new()
	animals.name = "Animals"
	animals.terrain = terrain
	animals.water = water
	animals.inventory = inventory
	animals.player = player
	animals.player_dead = func(): return survival == null or survival.dead
	animals.world_seed = world_seed
	animals.day = day_night.day
	add_child(animals)
	animals.pickup.connect(hud.show_pickup)
	animals.message.connect(hud.show_banner)
	animals.spilled.connect(loot.spawn_drop)
	animals.attacked.connect(func(dmg, from, _kind):
		if survival.dead:
			return
		survival.damage(dmg * Game.diff("damage"), "A jackal got you.")
		survival.wound(dmg * Game.diff("damage"))
		var local: Vector3 = player.global_transform.basis.inverse() * (from - player.global_position)
		hud.show_damage(atan2(local.x, -local.z)))
	guns.fired.connect(animals.alert)
	day_night.dusk_started.connect(animals.on_dusk)
	day_night.night_started.connect(animals.on_night)
	day_night.day_started.connect(animals.on_morning)
	livable = Livable.new()
	livable.name = "Livable"
	livable.water = water
	livable.farming = farming
	livable.building = building
	livable.survival = survival
	livable.player = player
	livable.day_night = day_night
	livable.world_seed = world_seed
	add_child(livable)
	hud.livable = livable
	livable.message.connect(hud.show_banner)
	water.morning_tally.connect(livable.on_tally)  # after the farming tally
	day_night.day_started.connect(livable.on_morning)


## v1.18: hidden oases out in the desert, claimed as outposts (oases.gd).
func _setup_oases() -> void:
	oases = Oases.new()
	oases.name = "Oases"
	oases.terrain = terrain
	oases.water = water
	oases.building = building
	oases.mutants = mutants
	oases.inventory = inventory
	oases.survival = survival
	oases.player = player
	oases.player_dead = func(): return survival == null or survival.dead
	oases.pay = pay_near
	oases.has_cost = has_near
	oases.world_seed = world_seed
	oases.peaceful = Game.is_peaceful()
	add_child(oases)
	var avoid: Array = []
	for c in props.get_children():  # once per world: every prop (a few hundred)
		if c is Node3D:
			avoid.append(c.position)
	for p in props.pebbles:
		avoid.append(p.pos)
	oases.setup(avoid)
	oases.green_new_world()
	oases.message.connect(hud.show_banner)
	oases.pickup.connect(hud.show_pickup)
	oases.spilled.connect(loot.spawn_drop)
	water.morning_tally.connect(oases.on_tally)
	raids.wild_green = oases.wild_green


## Hurt by a blast or a fire (mines, pipe bombs, molotovs): damage and a red mark
## on the side it came from.
func _on_blast_hurt(dmg: float, from: Vector3, cause: String) -> void:
	if survival.dead:
		return
	survival.damage(dmg, cause)
	var local: Vector3 = player.global_transform.basis.inverse() * (from - player.global_position)
	hud.show_damage(atan2(local.x, -local.z))


## v2.0: stones, molotovs and pipe bombs thrown from the hand (throwables.gd).
func _setup_throwables() -> void:
	throwables = Throwables.new()
	throwables.name = "Throwables"
	throwables.inventory = inventory
	throwables.player = player
	throwables.melee = melee
	throwables.mutants = mutants
	throwables.traps = traps
	throwables.oases = oases
	throwables.loot = loot
	throwables.terrain = terrain
	add_child(throwables)
	throwables.player_hurt.connect(_on_blast_hurt)
	throwables.hit_landed.connect(hud.show_hitmarker)


## v2.1: warmth from fires and shelter, cooking, food going bad, heavy loads.
func _setup_camp() -> void:
	camp = Camp.new()
	camp.name = "Camp"
	camp.building = building
	camp.inventory = inventory
	camp.survival = survival
	camp.player = player
	camp.world_seed = world_seed
	add_child(camp)
	camp.pickup.connect(hud.show_pickup)
	camp.spilled.connect(loot.spawn_drop)
	# After the "Day N" banner and the morning loot news.
	camp.message.connect(func(t): get_tree().create_timer(9.0).timeout.connect(func(): hud.show_banner(t)))
	day_night.day_started.connect(camp.on_morning)


## Green milestones, the weather (dew, rain) and the ending (v1.19).
func _setup_goals() -> void:
	weather = Weather.new()
	weather.name = "Weather"
	weather.water = water
	weather.building = building
	weather.player = player
	weather.day_night = day_night
	weather.world_seed = world_seed
	add_child(weather)
	weather.message.connect(hud.show_banner)
	day_night.day_started.connect(weather.on_morning)
	goals = Goals.new()
	goals.name = "Goals"
	goals.livable = livable
	goals.shop = shop
	goals.weather = weather
	goals.day_night = day_night
	add_child(goals)
	goals.message.connect(hud.show_banner)
	ending_ui = EndingUI.new()
	ending_ui.name = "EndingUI"
	add_child(ending_ui)
	goals.ended.connect(func(): ending_ui.open(ending_lines()))
	goals.load_data({})


## A few lines about the game for the ending screen.
func ending_lines() -> Array:
	var mins := int(Game.playtime / 60.0)
	return ["Day %d, %d nights survived" % [day_night.day, waves.wave],
		"Green: %s of the desert   Livable base: %d" % [livable.percent_text(), livable.score],
		"Played for %d h %02d min" % [mins / 60, mins % 60]]


## A mutant clawed you: lose health, red flash on the side it came from.
func _on_player_hit(dmg: float, from: Vector3, kind := "walker") -> void:
	if survival.dead:
		return
	var who: String = Mutants.Mutant.TYPES.get(kind, {}).get("name", "mutant").to_lower()
	dmg *= Game.diff("damage")
	survival.damage(dmg, ("Acid from a spitter got you." if kind == "spitter" and dmg > 10.0 else "A %s got you." % who))
	if kind in BLEED_KINDS:
		survival.wound(dmg)  # claws (not acid or a brute's fist)
	waves.note_damage(dmg)
	var to: Vector3 = from - player.global_position
	var local: Vector3 = player.global_transform.basis.inverse() * to
	hud.show_damage(atan2(local.x, -local.z))
	# A claw shoves you a little, a Brute's fist sends you flying (acid doesn't).
	var shove: float = PLAYER_SHOVE.get(kind, 0.0)
	if shove > 0.0:
		var away := Vector3(-to.x, 0, -to.z).normalized()
		player.push(away * shove + Vector3(0, shove * 0.35 if kind == "brute" else 0.0, 0))


var _attack_warned_at := -100000
## v2.1: mutants whose claws open bleeding wounds (a brute's fist and acid don't).
const BLEED_KINDS := ["walker", "runner"]

## Items each test box holds (a chest's 40 slots); newer items spill into a second box.
const TEST_SLOTS := 40

## Every item the test boxes hand out, in order (blueprints are bought, not given).
static func test_items() -> Array:
	return Items.ITEMS.keys().filter(func(i): return not i.begins_with("bp_"))


## The temporary test boxes: green crates with a white cross on the lid. The
## first holds the first 40 items; each further box (beside it) the next 40.
func _make_test_box() -> void:
	var boxes := ceili(test_items().size() / float(TEST_SLOTS))
	for i in boxes:
		var box := StaticBody3D.new()
		box.name = "TestBox" if i == 0 else "TestBox%d" % (i + 1)
		box.set_meta("interact_id", "testbox" if i == 0 else "testbox:%d" % i)
		var x := 3.0 + 1.3 * i
		box.position = Vector3(x, terrain.surface_height(x, 7.0), 7.0)
		add_child(box)
		if i == 0:
			test_box = box
		else:
			terrain.add_no_dig(box.position, 1.3)
		for b in [[Vector3(1.0, 0.7, 0.7), Vector3(0, 0.35, 0), Color(0.2, 0.55, 0.25) if i == 0 else Color(0.3, 0.6, 0.2)],
				[Vector3(0.7, 0.02, 0.15), Vector3(0, 0.71, 0), Color(0.95, 0.95, 0.9)],
				[Vector3(0.15, 0.02, 0.5), Vector3(0, 0.71, 0), Color(0.95, 0.95, 0.9)]]:
			var mi := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = b[0]
			mi.mesh = m
			mi.position = b[1]
			mi.material_override = LowPoly.material(b[2])
			box.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 0.72, 0.7)
		col.shape = shape
		col.position.y = 0.36
		box.add_child(col)
	test_storage = Inventory.new(TEST_SLOTS)


## Refills test box `page` with a full stack of each of its items and opens it like a chest.
func open_test_box(page := 0) -> void:
	test_storage.load_data({})
	var all := test_items()
	for k in range(page * TEST_SLOTS, mini((page + 1) * TEST_SLOTS, all.size())):
		test_storage.add(all[k], int(Items.ITEMS[all[k]].stack))
	if shop.cash < TEST_CASH:
		shop.add_cash(TEST_CASH - shop.cash)
	inventory_ui.open_chest("", test_storage)


## When each first-time hint shows.
func _connect_hints() -> void:
	inventory.changed.connect(func():
		if inventory.weight() > 2.6:  # more than the starting tools
			hints.show_hint("loot"))
	day_night.dusk_started.connect(func(_d): hints.show_hint("dusk"))
	waves.wave_ended.connect(func(_s): hints.show_hint("cash"))
	survival.warning.connect(func(_t): hints.show_hint("hurt"))
	for m in mutants.get_children():
		if m.has_signal("spotted"):
			m.spotted.connect(func(_m): hints.show_hint("mutant"))
	mutants.child_entered_tree.connect(func(m):
		if m.has_signal("spotted"):
			m.spotted.connect(func(_m): hints.show_hint("mutant")))
	if Game.fresh_game:
		get_tree().create_timer(2.0).timeout.connect(func(): hints.show_hint("welcome"))


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
	build_mode.cancel_carry()  # a piece being moved goes back in its place first
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
		"loot": _loot_save(),
		"inventory": inventory.save_data(),
		"survival": survival.save_data(),
		"map": {"discovered": discovered.keys()},
		"buildings": building.save_data(),
		"mutants": mutants.save_data(),
		"waves": waves.save_data(),
		"guns": guns.save_data(),
		"shop": shop.save_data(),
		"market": market.save_data(),
		"drone": drone.save_data(),
		"terrain": terrain.save_data(),
		"caches": caches.save_data(),
		"mining": {"broken": broken_rocks.keys(), "hits": rock_hits.keys().map(func(k): return [k, rock_hits[k]])},
		"tiers": Building.TIER_NAMES.size(),
		"cables": building.cables.duplicate(true),
		"sites": building.sites_save_data(),
		"nature": {"felled": felled_trees.keys().map(func(k): return [k, felled_trees[k]]),
			"hits": tree_hits.keys().map(func(k): return [k, tree_hits[k]]),
			"pebbles": taken_pebbles.keys().map(func(k): return [k, taken_pebbles[k]])},
		"water": water.save_data(),
		"farming": farming.save_data(),
		"animals": animals.save_data(),
		"livable": livable.save_data(),
		"oases": oases.save_data(),
		"weather": weather.save_data(),
		"goals": goals.save_data(),
	}


## Thrown stones still in the air land first, so saving never loses one.
func _loot_save() -> Dictionary:
	throwables.land_stones()
	return loot.save_data()


func apply_save_data(data: Dictionary) -> void:
	throwables.clear()  # fires go out, bombs in the air are gone
	# Dug ground first, so everything else is restored on top of it. Older saves: flat.
	terrain.load_data(data.get("terrain", {}))
	base_zone.rebuild()
	caches.load_data(data.get("caches", {}))
	for id in broken_rocks:
		props.set_rock_broken(id, false)
	broken_rocks = {}
	rock_hits = {}
	var mining: Dictionary = data.get("mining", {})
	for id in mining.get("broken", []):
		broken_rocks[int(id)] = true
		props.set_rock_broken(int(id), true)
	for e in mining.get("hits", []):
		rock_hits[int(e[0])] = int(e[1])
	for id in felled_trees:
		props.set_tree_felled(id, false)
	for id in taken_pebbles:
		props.set_pebble_taken(id, false)
	felled_trees = {}
	tree_hits = {}
	taken_pebbles = {}
	var nature: Dictionary = data.get("nature", {})
	for e in nature.get("felled", []):
		felled_trees[int(e[0])] = int(e[1])
		props.set_tree_felled(int(e[0]), true)
	for e in nature.get("hits", []):
		tree_hits[int(e[0])] = int(e[1])
	for e in nature.get("pebbles", []):
		taken_pebbles[int(e[0])] = int(e[1])
		props.set_pebble_taken(int(e[0]), true)
	var w: Dictionary = data.get("world", {})
	day_night.restore(int(w.get("day", 1)), float(w.get("hour", 9.0)))
	# Upgrades first: chests must be big enough before their contents load.
	shop.load_data(data.get("shop", {}))
	var md = data.get("market", {})
	market.load_data(md if md is Dictionary else {}, day_night.day)
	building.chest_slots = Building.CHEST_SLOTS
	apply_upgrades()
	loot.load_data(data.get("loot", {}))
	survival.load_data(data.get("survival", {}))
	# Saves from before the stone tier (3 tiers): concrete was tier 2, now 3.
	building.load_data(data.get("buildings", []), int(data.get("tiers", 3)) < 4)
	building.cables = []
	if data.has("cables"):
		for c in data.cables:
			if c is Array and c.size() == 2 and building.pieces.has(str(c[0])) and building.pieces.has(str(c[1])):
				building.cables.append([str(c[0]), str(c[1])])
		building._rebuild_cables()
	else:
		building.auto_wire(power.POWER_RANGE)  # older saves: power reached 18 m without cables
	building.sites_load_data(data.get("sites", []))
	var wd = data.get("water", {})
	water.load_data(wd if wd is Dictionary else {})  # after the sprinklers it pipes to
	var od = data.get("oases", {})
	oases.load_data(od if od is Dictionary else {})  # after the water (older saves: green round the wild springs)
	var fd = data.get("farming", {})
	farming.load_data(fd if fd is Dictionary else {})
	var ad = data.get("animals", {})
	animals.load_data(ad if ad is Dictionary else {}, day_night.day)
	waves.load_data(data.get("waves", {"wave": maxi(day_night.day - 1, 0)}))
	guns.load_data(data.get("guns", {}))
	# Older saves: a little starting cash plus pay for the nights already survived.
	if not data.has("shop"):
		shop.cash = Shop.START_CASH + 40 * waves.wave
	if not data.get("shop", {}).has("unlocked"):
		# Saves from before blueprints keep every build they had.
		for t in Building.PIECES:
			if Building.PIECES[t].get("blueprint", false):
				shop.unlocked[t] = true
	drone.load_data(data.get("drone", {}))
	if waves.active and not day_night.is_night() and not waves.called:
		waves.active = false  # never carry a night wave into the day
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
	nav.rebuild_map()  # the mutants' path map, worked out now rather than when the first one arrives
	var lv = data.get("livable", {})
	livable.load_data(lv if lv is Dictionary else {})  # last: scores what was loaded
	var wd2 = data.get("weather", {})
	weather.load_data(wd2 if wd2 is Dictionary else {})
	var gd = data.get("goals", {})
	goals.load_data(gd if gd is Dictionary else {})  # after livable: needs the green %


## Graphics quality: sun shadows and how far you can see.
func _apply_quality() -> void:
	var q: Dictionary = Settings.QUALITY[Settings.quality]
	sun.shadow_enabled = q.shadows
	sun.directional_shadow_max_distance = maxf(q.shadow_dist, 1.0)
	if player:
		player.camera.far = q.far


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

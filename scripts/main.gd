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

const DISCOVER_RANGE := 45.0
const REFILLS_PER_MORNING := 4
const SUPPLY_CHANCE := 0.5

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
## Wrecks and ruins: {"key": "w3", "kind": "wreck", "pos": Vector3}.
var places: Array = []
## Keys of places you have been near.
var discovered := {}
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

	inventory = Inventory.new()
	inventory.changed.connect(func(): player.overloaded = inventory.overloaded())

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
	add_child(hud)

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	# Added after the pause menu so it sees Esc first while open.
	inventory_ui = InventoryUI.new()
	inventory_ui.name = "InventoryUI"
	inventory_ui.inventory = inventory
	inventory_ui.drop_requested.connect(drop_slot)
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
	survival.warning.connect(hud.show_banner)

	day_night.day_started.connect(_on_morning)
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
	if hud and not get_tree().paused:
		hud.set_prompt("" if inventory_ui.is_open() else loot.prompt(player.interact_target()))
		for i in Inventory.HOTBAR:
			if Input.is_action_just_pressed("hotbar_%d" % (i + 1)) and not inventory_ui.is_open():
				select_hotbar(i)
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


## E on a container or a dropped bag: put what fits in the inventory.
func interact(id: String) -> void:
	if id == "":
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
	hud.show_pickup(["%s %s" % ["Drank" if s.item == "water" else "Ate", Items.display_name(s.item).to_lower()]])
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
	if survival.water <= 0.0:
		cause = "You died of thirst."
	elif survival.food <= 0.0:
		cause = "You starved."
	if inventory_ui.is_open():
		inventory_ui.close()
	death_screen.open(cause)


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
	}


func apply_save_data(data: Dictionary) -> void:
	var w: Dictionary = data.get("world", {})
	day_night.restore(int(w.get("day", 1)), float(w.get("hour", 9.0)))
	loot.load_data(data.get("loot", {}))
	survival.load_data(data.get("survival", {}))
	discovered = {}
	for key in data.get("map", {}).get("discovered", []):
		discovered[str(key)] = true
	if data.has("inventory"):
		inventory.load_data(data.inventory)
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

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

	hud = Hud.new()
	hud.name = "HUD"
	hud.player = player
	hud.day_night = day_night
	add_child(hud)

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	# Autosave every morning.
	day_night.day_started.connect(func(_d): Game.save_game("auto", _screenshot()))
	Game.saved.connect(func(slot): hud.show_banner("Game saved (%s)" % Game.slot_label(slot)))
	Game.world_ready(self)


func _unhandled_input(event: InputEvent) -> void:
	if menu_mode or get_tree().paused:
		return
	if event.is_action_pressed("quick_save"):
		Game.save_game("quick", _screenshot())
	elif event.is_action_pressed("quick_load"):
		if not Game.load_game("quick"):
			hud.show_banner("No quicksave yet (F5 to quicksave)")


func _process(delta: float) -> void:
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
	}


func apply_save_data(data: Dictionary) -> void:
	var w: Dictionary = data.get("world", {})
	day_night.restore(int(w.get("day", 1)), float(w.get("hour", 9.0)))
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

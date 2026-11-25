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

const WORLD_SEED := 1337

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
	_setup_environment()

	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.generate(WORLD_SEED)

	props = Props.new()
	props.name = "Props"
	add_child(props)
	props.populate(terrain, WORLD_SEED)

	player = Player.new()
	player.name = "Player"
	var spawn := Vector3(0, terrain.surface_height(0, 9) + 1.0, 9)
	player.position = spawn
	player.spawn_point = spawn
	player.play_radius = terrain.PLAY_RADIUS
	add_child(player)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, moon, env, sky_mat)

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

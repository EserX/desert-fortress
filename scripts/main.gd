extends Node3D
## Builds the world at startup: sky, sun, terrain, props, player and HUD.

const Terrain = preload("res://scripts/terrain.gd")
const Props = preload("res://scripts/props.gd")
const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")

const WORLD_SEED := 1337

var terrain: Terrain
var props: Props
var player: Player
var hud: Hud


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
	var spawn := Vector3(0, terrain.height_at(0, 9) + 1.0, 9)
	player.position = spawn
	player.spawn_point = spawn
	player.play_radius = terrain.PLAY_RADIUS
	add_child(player)

	hud = Hud.new()
	hud.name = "HUD"
	hud.player = player
	add_child(hud)


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.92, 0.80, 0.66)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.55, 0.40, 0.27)
	sky_mat.ground_horizon_color = Color(0.92, 0.80, 0.66)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.90, 0.78, 0.62)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)

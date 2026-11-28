extends Node3D
## Desert ambience made entirely in code (no audio files): gusting wind,
## footsteps in sand, a landing thump and drifting dust around the player.

const MIX_RATE := 22050.0

var player  # Player (untyped to avoid a circular preload)
var day_night  # DayNight
## v2.3: a sandstorm's strength (0..1, set by events.gd): the wind howls.
var storm := 0.0

var _wind_player: AudioStreamPlayer
var _wind: AudioStreamGeneratorPlayback
var _step_player: AudioStreamPlayer
var _land_player: AudioStreamPlayer
var _step_sounds: Array[AudioStreamWAV] = []
var _rng := RandomNumberGenerator.new()
var _dust: CPUParticles3D

# Wind synthesis state.
var _lp1 := 0.0
var _lp2 := 0.0
var _gust := 0.5
var _gust_target := 0.5
var _gust_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	_setup_wind()
	_setup_steps()
	_setup_dust()
	if player:
		player.footstep.connect(_on_footstep)
		player.landed.connect(_on_landed)


# --- Wind -------------------------------------------------------------------

func _setup_wind() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.3
	_wind_player = AudioStreamPlayer.new()
	_wind_player.stream = gen
	_wind_player.volume_db = -8.0
	add_child(_wind_player)
	_wind_player.play()
	_wind = _wind_player.get_stream_playback()


func _process(delta: float) -> void:
	_fill_wind(delta)
	if _dust and player:
		_dust.global_position = player.global_position + Vector3(0, 2.0, 0)


func _fill_wind(delta: float) -> void:
	if _wind == null:
		return
	# New gust strength every few seconds; the wind eases towards it.
	_gust_timer -= delta
	if _gust_timer <= 0.0:
		_gust_timer = _rng.randf_range(2.0, 6.0)
		_gust_target = _rng.randf_range(0.25 + storm * 0.6, 1.0 + storm * 0.6)
	var night := 1.0
	if day_night and day_night.is_night():
		night = 0.6  # calmer at night
	var frames := _wind.get_frames_available()
	for i in frames:
		_gust = lerpf(_gust, _gust_target, 0.00004)
		var white := _rng.randf_range(-1.0, 1.0)
		# Two one-pole low-pass filters; stronger gusts let more hiss through.
		var cutoff := 0.015 + _gust * 0.05
		_lp1 += (white - _lp1) * cutoff
		_lp2 += (_lp1 - _lp2) * cutoff
		var s := _lp2 * (2.5 + _gust * 5.0) * night * (1.0 + storm * 1.6)
		_wind.push_frame(Vector2(s, s))


# --- Footsteps --------------------------------------------------------------

func _setup_steps() -> void:
	for v in 4:
		_step_sounds.append(_make_crunch(0.16, 0.35 + v * 0.08, 900.0 + v * 150.0))
	_step_player = AudioStreamPlayer.new()
	_step_player.volume_db = -10.0
	add_child(_step_player)
	_land_player = AudioStreamPlayer.new()
	_land_player.stream = _make_crunch(0.3, 0.2, 500.0)
	add_child(_land_player)


## Short burst of filtered noise with a fast attack and decay: a step in sand.
func _make_crunch(length: float, brightness: float, grain_hz: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var grain := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var env := minf(t / 0.008, 1.0) * exp(-t * 22.0)
		# Grainy crackle: noise gated by a fast random on/off pattern.
		if _rng.randf() < grain_hz / MIX_RATE * 8.0:
			grain = _rng.randf_range(0.3, 1.0)
		grain *= 0.995
		lp += (_rng.randf_range(-1, 1) - lp) * brightness
		var s := clampf(lp * env * (0.5 + grain) * 1.6, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.stereo = false
	wav.data = data
	return wav


func _on_footstep(sprinting: bool) -> void:
	_step_player.stream = _step_sounds[_rng.randi() % _step_sounds.size()]
	_step_player.pitch_scale = _rng.randf_range(0.85, 1.15) * (1.1 if sprinting else 1.0)
	_step_player.volume_db = -7.0 if sprinting else -10.0
	_step_player.play()


func _on_landed(fall_speed: float) -> void:
	if fall_speed < 3.0:
		return
	_land_player.volume_db = lerpf(-14.0, -2.0, clampf((fall_speed - 3.0) / 8.0, 0.0, 1.0))
	_land_player.pitch_scale = _rng.randf_range(0.8, 1.0)
	_land_player.play()


# --- Dust -------------------------------------------------------------------

func _setup_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.name = "Dust"
	_dust.amount = 220
	_dust.lifetime = 7.0
	_dust.preprocess = 7.0
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(28, 3, 28)
	_dust.direction = Vector3(1, 0.05, 0.3)
	_dust.spread = 25.0
	_dust.gravity = Vector3(0, -0.05, 0)
	_dust.initial_velocity_min = 1.5
	_dust.initial_velocity_max = 4.0
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	# Lit by the sun/moon so it doesn't glow at night; fades out near the camera.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 1.0
	mat.distance_fade_max_distance = 4.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.95, 0.85, 0.65, 0.55)
	quad.material = mat
	_dust.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	_dust.color_ramp = fade
	add_child(_dust)
	_dust.emitting = true

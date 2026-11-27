extends Node
## Night waves. A siren wails at dusk; when night falls a wave of mutants comes
## in from the edge of the map in small groups and heads for the base. The wave
## ends when every one of them is dead or at dawn (the sun finishes the rest).
## Then a short summary shows how the night went.

const MIX_RATE := 22050.0
const SPAWN_RADIUS := 205.0
## A horde called with the button comes from this far out, round where you are.
const CALL_RADIUS := 60.0
const GROUP_GAP := 9.0      # seconds between groups
const MAX_SIZE := 30
## Cash for each mutant of the wave you kill.
const BOUNTY := {"walker": 10, "runner": 12, "spitter": 15, "brute": 40}

signal wave_started(n: int, size: int)
signal wave_ended(summary: Dictionary)
signal siren

var mutants  # Mutants
var size_mult := 1.0        # difficulty: wave size
var cash_mult := 1.0        # difficulty: pay
var world_seed := 1337
var wave := 0               # number of the last wave that started
var active := false
var to_spawn := 0
var queue: Array = []       # types still to come, in order
var spawn_timer := 0.0
## The wave was called with the horde button (not a night wave): it comes
## from CALL_RADIUS round call_at and pays only the bounty.
var called := false
var call_at := Vector3.ZERO
var stats := {}             # this wave: kills, damage, lost, deaths
var _rng := RandomNumberGenerator.new()
var _siren: AudioStreamPlayer


func _ready() -> void:
	_siren = AudioStreamPlayer.new()
	_siren.stream = _make_siren()
	_siren.volume_db = -8.0
	add_child(_siren)


## How many mutants night n brings.
static func wave_size(n: int) -> int:
	return mini(4 + (n - 1) * 2, MAX_SIZE)


## The mutant types of night n, in arrival order. Night 1 is all walkers;
## runners join on night 2, spitters on night 3 and brutes on night 4,
## and their share grows each night.
static func wave_mix(n: int, rng: RandomNumberGenerator, mult := 1.0) -> Array:
	var size := maxi(2, int(round(wave_size(n) * mult)))
	var weights := {"walker": 1.0}
	if n >= 2:
		weights.runner = minf(0.25 + 0.05 * n, 0.8)
	if n >= 3:
		weights.spitter = minf(0.15 + 0.03 * n, 0.5)
	if n >= 4:
		weights.brute = minf(0.08 + 0.02 * n, 0.35)
	var total := 0.0
	for k in weights:
		total += weights[k]
	var out: Array = []
	for i in size:
		var r := rng.randf() * total
		var pick := "walker"
		for k in weights:
			r -= weights[k]
			if r <= 0.0:
				pick = k
				break
		out.append(pick)
	# Each new type shows up at least once on the night it is introduced.
	var intro := {2: "runner", 3: "spitter", 4: "brute"}
	if intro.has(n) and not out.has(intro[n]):
		out[size - 1] = intro[n]
	return out


## The lineup the next wave will bring (the same roll start_wave() will make).
func preview_next() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wave:%d:%d" % [world_seed, wave + 1])
	return wave_mix(wave + 1, rng, size_mult)


## "6 walkers, 2 runners, 1 brute"
static func mix_text(types: Array) -> String:
	var counts := {}
	for t in types:
		counts[t] = counts.get(t, 0) + 1
	var parts: Array = []
	for t in ["walker", "runner", "spitter", "brute"]:
		if counts.has(t):
			parts.append("%d %s%s" % [counts[t], t, "s" if counts[t] > 1 else ""])
	return ", ".join(parts)


func on_dusk(_day: int) -> void:
	_siren.play()
	siren.emit()


func start_wave() -> void:
	wave += 1
	active = true
	called = false
	_rng.seed = hash("wave:%d:%d" % [world_seed, wave])
	queue = wave_mix(wave, _rng, size_mult)
	to_spawn = queue.size()
	spawn_timer = 1.0
	stats = {"kills": 0, "damage": 0.0, "lost": 0, "deaths": 0, "size": to_spawn, "bounty": 0, "pieces": 0}
	wave_started.emit(wave, to_spawn)


## The horde button: a wave as big as the last night's (at least night 1's)
## comes for `at` straight away, day or night. It doesn't count as a night.
## Returns false if a wave is already out.
func call_horde(at: Vector3) -> bool:
	if active:
		return false
	active = true
	called = true
	call_at = Vector3(at.x, 0, at.z)
	var n := maxi(wave, 1)
	_rng.seed = hash("horde:%d:%d:%d" % [world_seed, wave, Time.get_ticks_msec()])
	queue = wave_mix(n, _rng, size_mult)
	to_spawn = queue.size()
	spawn_timer = 1.0
	stats = {"kills": 0, "damage": 0.0, "lost": 0, "deaths": 0, "size": to_spawn, "bounty": 0, "pieces": 0, "called": true}
	siren.emit()
	_siren.play()
	wave_started.emit(n, to_spawn)
	return true


## Mutants of this wave still to come or still alive.
func remaining() -> int:
	return to_spawn + hunters().size()


func hunters() -> Array:
	return mutants.alive().filter(func(m): return m.hunter)


func _process(delta: float) -> void:
	if not active:
		return
	if to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = GROUP_GAP
			_spawn_group()
	elif hunters().is_empty():
		end_wave(true)


## Two or three mutants side by side at a random spot on the edge.
func _spawn_group() -> void:
	var n := mini(_rng.randi_range(2, 3), to_spawn)
	var a := _rng.randf() * TAU
	var out := Vector3(cos(a), 0, sin(a))
	var side := out.cross(Vector3.UP)
	var center := call_at if called else Vector3.ZERO
	var radius := CALL_RADIUS if called else SPAWN_RADIUS
	for i in n:
		var p := center + out * (radius + _rng.randf_range(-4, 4)) + side * (i - (n - 1) * 0.5) * 2.5
		p = p.limit_length(SPAWN_RADIUS)
		var kind: String = queue.pop_front() if not queue.is_empty() else "walker"
		var m = mutants.spawn(kind, p)
		m.make_hunter(center)
	to_spawn -= n


## cleared: every mutant was killed (otherwise dawn came first).
func end_wave(cleared: bool) -> void:
	if not active:
		return
	active = false
	to_spawn = 0
	queue = []
	if not cleared:
		for m in hunters():
			m.crumble()
	var s := stats.duplicate()
	s.wave = wave
	s.cleared = cleared
	s.merge(cash_for(s), true)
	s.cash = int(round(s.cash * cash_mult))
	wave_ended.emit(s)


func on_dawn(_day: int) -> void:
	end_wave(false)


func note_kill(m: Node) -> void:
	if active:
		stats.kills = int(stats.get("kills", 0)) + 1
		stats.bounty = int(stats.get("bounty", 0)) + int(BOUNTY.get(m.type, 10))


## Cash for a night: the bounty on kills, a payment for surviving it, and a
## bonus for how much of the base is still standing; a quarter more if you
## killed the whole wave. Returns {"cash", "cash_kills", "cash_night", "cash_base"}.
static func cash_for(s: Dictionary) -> Dictionary:
	var kills: int = int(s.get("bounty", 0))
	var night: int = 0 if s.get("called", false) else 25 + 10 * int(s.get("wave", 1))
	var base := 0
	var pieces: int = int(s.get("pieces", 0))
	if pieces > 0 and not s.get("called", false):
		base = int(round(60.0 * clampf(1.0 - float(s.get("lost", 0)) / pieces, 0.0, 1.0)))
	var total := kills + night + base
	if s.get("cleared", false):
		total = int(round(total * 1.25))
	return {"cash": total, "cash_kills": kills, "cash_night": night, "cash_base": base}


func note_damage(amount: float) -> void:
	if active:
		stats.damage = float(stats.get("damage", 0.0)) + amount


func note_lost() -> void:
	if active:
		stats.lost = int(stats.get("lost", 0)) + 1


func note_death() -> void:
	if active:
		stats.deaths = int(stats.get("deaths", 0)) + 1


## Lines for the end-of-wave summary.
static func summary_lines(s: Dictionary) -> Array:
	var lines: Array = []
	if s.get("called", false):
		lines.append("Horde wiped out!" if s.get("cleared", false) else "The horde is gone")
	else:
		lines.append(("Wave %d cleared!" if s.get("cleared", false) else "Dawn: you survived night %d") % int(s.get("wave", 0)))
	lines.append("Mutants killed: %d" % int(s.get("kills", 0)))
	lines.append("Damage taken: %d" % int(s.get("damage", 0)))
	if int(s.get("lost", 0)) > 0:
		lines.append("Building pieces lost: %d" % int(s.lost))
	if int(s.get("deaths", 0)) > 0:
		lines.append("Times you died: %d" % int(s.deaths))
	if s.has("cash"):
		lines.append("Cash earned: $%d" % s.cash)
	return lines


func save_data() -> Dictionary:
	return {"wave": wave, "active": active, "to_spawn": to_spawn, "queue": queue, "stats": stats,
		"called": called, "call_at": [call_at.x, call_at.z]}


func load_data(data: Dictionary) -> void:
	wave = int(data.get("wave", 0))
	active = bool(data.get("active", false))
	to_spawn = int(data.get("to_spawn", 0))
	queue = []
	for t in data.get("queue", []):
		queue.append(str(t))
	while queue.size() < to_spawn:
		queue.append("walker")  # saves from v0.14
	called = bool(data.get("called", false))
	var ca: Array = data.get("call_at", [0.0, 0.0])
	call_at = Vector3(float(ca[0]), 0, float(ca[1])) if ca.size() == 2 else Vector3.ZERO
	stats = data.get("stats", {})
	for k in ["kills", "lost", "deaths", "size", "bounty", "pieces"]:
		stats[k] = int(stats.get(k, 0))
	stats.damage = float(stats.get("damage", 0.0))
	spawn_timer = 2.0
	_rng.seed = hash("wave:%d:%d:%d" % [world_seed, wave, to_spawn])


## A wailing air-raid siren: the pitch climbs and falls twice.
func _make_siren() -> AudioStreamWAV:
	var length := 7.0
	var n := int(MIX_RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var u := fposmod(t / 3.5, 1.0)
		var f := lerpf(260.0, 720.0, sin(PI * u) ** 0.7)
		phase += f / MIX_RATE
		var p := fposmod(phase, 1.0)
		# Rounded square wave, like a mechanical siren's rotor.
		var s := clampf(sin(TAU * p) * 2.5, -1.0, 1.0) * 0.5 + sin(TAU * p * 2.0) * 0.15
		var env := minf(t / 0.6, 1.0) * minf((length - t) / 1.2, 1.0)
		data.encode_s16(i * 2, int(s * env * 24000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.data = data
	return wav

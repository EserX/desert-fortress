extends Node
## v2.1 survival depth round the camp: what keeps you warm (a burning fire pit
## close by, a roof and walls round you), cooking at the fire pit, food that
## goes bad overnight, and how a heavy load makes hard work and climbing harder.
## The body side (warmth, wounds) lives in survival.gd; this script senses the
## world for it and handles the food.

const Inventory = preload("res://scripts/inventory.gd")
const Items = preload("res://scripts/items.gd")

signal pickup(lines: Array)
signal message(text: String)
signal spilled(items: Dictionary, pos: Vector3)

const FIRE_REACH := 5.0      # a burning fire pit warms you this close (m)
const ROOF_RAY := 8.0        # something this close above your head is a roof
const WALL_RAY := 4.0        # walls (or dunes, rocks) this close round you keep the wind off
const WALL_RAYS := 8
## Cooking at a burning fire pit: each batch burns COOK_EACH seconds of fire.
## E cooks up to COOK_MAX batches of everything you carry, in this order.
const COOK_EACH := 10.0
const COOK_MAX := 5
const COOKING := [
	{"in": {"raw_meat": 1}, "out": {"cooked_meat": 1}, "name": "raw meat"},
	{"in": {"millet": 2, "water": 1}, "out": {"flatbread": 2}, "name": "flatbread"},
	{"in": {"cooked_meat": 1, "melon": 1}, "out": {"stew": 2}, "name": "stew"},
]
## Food that goes bad: the chance each piece rots overnight (each morning).
## In a storage chest the chance is halved. Canned food, millet, dates, olives
## and flatbread keep.
const PERISHABLE := {
	"raw_meat": 0.5,
	"cooked_meat": 0.2,
	"stew": 0.2,
	"melon": 0.12,
	"dragon_fruit": 0.12,
	"prickly_pear": 0.08,
}
const CHEST_KEEP := 0.5
## Carried weight: above LOAD_EASY of the limit, hard work (digging, mining,
## chopping) costs more stamina and climbing is slower, up to LOAD_FULL times
## at the limit and LOAD_OVER when overloaded.
const LOAD_EASY := 0.5
const LOAD_FULL := 1.5
const LOAD_OVER := 2.0

var building  # Building
var inventory  # Inventory (your pockets)
var survival  # Survival
var player: Node3D
var world_seed := 0


## How much harder a load of this weight makes work and climbing (1 = no effect).
static func load_factor(weight: float, max_weight: float) -> float:
	var r := weight / maxf(max_weight, 0.001)
	if r > 1.0:
		return LOAD_OVER
	if r <= LOAD_EASY:
		return 1.0
	return lerpf(1.0, LOAD_FULL, (r - LOAD_EASY) / (1.0 - LOAD_EASY))


func load_mult() -> float:
	return load_factor(inventory.weight(), Inventory.MAX_WEIGHT) if inventory else 1.0


## Checks the fire and the shelter round you for survival (every 0.5 s).
func sense() -> void:
	if survival == null or player == null:
		return
	survival.near_fire = fire_near(player.global_position)
	survival.shelter = shelter_at(player)


## True when a burning fire pit is within FIRE_REACH.
func fire_near(pos: Vector3) -> bool:
	if building == null:
		return false
	# Every piece, twice a second from sense(): a base has a few hundred at most.
	for rec in building.pieces.values():
		if rec.type == "fire_pit" and float(rec.get("burn", 0.0)) > 0.0 \
				and rec.node.global_position.distance_to(pos) <= FIRE_REACH:
			return true
	return false


## 0 (open sand) to 1 (indoors): a roof overhead counts for 0.4 and walls all
## round for the rest; walls without a roof keep off at most 0.3.
func shelter_at(body: Node3D) -> float:
	var space := body.get_world_3d().direct_space_state
	var exclude := [body.get_rid()] if body is CollisionObject3D else []
	var head := body.global_position + Vector3(0, 1.4, 0)
	var q := PhysicsRayQueryParameters3D.create(head, head + Vector3.UP * ROOF_RAY, 1, exclude)
	var roof := not space.intersect_ray(q).is_empty()
	var chest := body.global_position + Vector3(0, 1.0, 0)
	var hits := 0
	for i in WALL_RAYS:
		var a := TAU * i / WALL_RAYS
		q = PhysicsRayQueryParameters3D.create(chest, chest + Vector3(cos(a), 0, sin(a)) * WALL_RAY, 1, exclude)
		if not space.intersect_ray(q).is_empty():
			hits += 1
	var walls := hits / float(WALL_RAYS)
	return 0.4 + 0.6 * walls if roof else 0.3 * walls


## How many batches of each cooking recipe your pockets have the makings for
## (at most COOK_MAX in all): [[recipe index, batches], ...].
func cook_plan() -> Array:
	var have: Dictionary = inventory.contents() if inventory else {}
	var plan := []
	var left := COOK_MAX
	for i in COOKING.size():
		var r: Dictionary = COOKING[i]
		var n := left
		for item in r.in:
			n = mini(n, int(have.get(item, 0)) / int(r.in[item]))
		if n <= 0:
			continue
		plan.append([i, n])
		left -= n
		for item in r.in:
			have[item] = int(have[item]) - n * int(r.in[item])
		if left <= 0:
			break
	return plan


## The line a fire pit adds when you carry something to cook ("" if you don't).
func cook_prompt(rec: Dictionary) -> String:
	var plan := cook_plan()
	if plan.is_empty():
		return ""
	if float(rec.get("burn", 0.0)) <= 0.0:
		return "\nLight the fire to cook"
	var parts: Array[String] = []
	for p in plan:
		var r: Dictionary = COOKING[p[0]]
		var out_n: int = int(r.out.values()[0]) * int(p[1])
		parts.append("%d %s" % [p[1] if r.in.size() == 1 else out_n, r.name])
	return "\n[E] Cook " + ", ".join(parts)


## E on a burning fire pit: cooks what cook_plan() finds, each batch burning
## COOK_EACH seconds of the fire. Returns how many batches were cooked.
func cook(rec: Dictionary) -> int:
	if inventory == null or float(rec.get("burn", 0.0)) <= 0.0:
		return 0
	var total := 0
	var made := {}
	for p in cook_plan():
		var r: Dictionary = COOKING[p[0]]
		var n: int = p[1]
		for item in r.in:
			inventory.remove(item, n * int(r.in[item]))
		for item in r.out:
			made[item] = int(made.get(item, 0)) + n * int(r.out[item])
		total += n
	if total <= 0:
		return 0
	var left: Dictionary = inventory.add_all(made)
	if not left.is_empty():
		spilled.emit(left, rec.node.global_position + Vector3(0, 0.5, 1.0))
	rec.burn = maxf(float(rec.burn) - COOK_EACH * total, 0.0)
	var lines := []
	for item in made:
		lines.append("Cooked %d %s" % [made[item], Items.display_name(item).to_lower()])
	pickup.emit(lines)
	return total


## Each morning some fresh food rots, in your pockets and (half as often) in
## chests. Seeded by the world, the day and the container, so it's repeatable.
## Returns how many pieces went bad.
func on_morning(d: int) -> int:
	var n := spoil(inventory, 1.0, "pockets", d)
	if building:
		# Every piece once a morning: only chests have storage.
		for key in building.pieces.keys():
			var store = building.storage_of(key)
			if store:
				n += spoil(store, CHEST_KEEP, str(key), d)
	if n > 0:
		message.emit("%d food went bad overnight. Cook it, eat it or keep it in a chest." % n)
	return n


## Rots fresh food in one inventory: each perishable piece goes bad with its
## chance times mult and becomes rotten food (if there's room).
func spoil(inv, mult: float, tag: String, d: int) -> int:
	if inv == null:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("spoil:%d:%d:%s" % [world_seed, d, tag])
	var have: Dictionary = inv.contents()
	var total := 0
	for item in PERISHABLE.keys():  # fixed order, so the rolls repeat
		var count: int = int(have.get(item, 0))
		var bad := 0
		for i in count:
			if rng.randf() < PERISHABLE[item] * mult:
				bad += 1
		if bad > 0:
			inv.remove(item, bad)
			inv.add("rotten_food", bad)
			total += bad
	return total

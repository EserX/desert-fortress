extends StaticBody3D
## The shop terminal at the base: a rugged screen on a post next to the flag.
## Holds your cash (earned for each night survived) and the catalogue of
## things you can buy with it. E on the terminal opens the shop screen.

const LowPoly = preload("res://scripts/lowpoly.gd")

## Everything for sale, grouped by category, in the order shown.
const CATALOG := [
	{"cat": "Materials", "name": "10 wood", "price": 20, "items": {"wood": 10}},
	{"cat": "Materials", "name": "10 scrap metal", "price": 30, "items": {"scrap": 10}},
	{"cat": "Materials", "name": "25 nails", "price": 15, "items": {"nails": 25}},
	{"cat": "Materials", "name": "5 cloth", "price": 10, "items": {"cloth": 5}},
	{"cat": "Materials", "name": "3 cement bags", "price": 30, "items": {"cement": 3}},
	{"cat": "Materials", "name": "2 fuel cans", "price": 25, "items": {"fuel": 2}},
	{"cat": "Supplies", "name": "3 canned food", "price": 15, "items": {"canned_food": 3}},
	{"cat": "Supplies", "name": "3 water bottles", "price": 15, "items": {"water": 3}},
	{"cat": "Supplies", "name": "3 bandages", "price": 20, "items": {"bandage": 3}},
	{"cat": "Weapons", "name": "Machete", "price": 50, "items": {"machete": 1}},
	{"cat": "Weapons", "name": "Pistol", "price": 120, "items": {"pistol": 1}},
	{"cat": "Weapons", "name": "Shotgun", "price": 260, "items": {"shotgun": 1}},
	{"cat": "Weapons", "name": "Hunting rifle", "price": 380, "items": {"rifle": 1}},
	{"cat": "Ammo", "name": "24 9mm rounds", "price": 20, "items": {"ammo_9mm": 24}},
	{"cat": "Ammo", "name": "12 shotgun shells", "price": 25, "items": {"shells": 12}},
	{"cat": "Ammo", "name": "10 7.62 rounds", "price": 30, "items": {"ammo_762": 10}},
	{"cat": "Traps", "name": "Spike barricade", "price": 25, "items": {"spike_barricade": 1}},
	{"cat": "Traps", "name": "Spike strip parts", "price": 20, "items": {"wood": 2, "nails": 8}},
	{"cat": "Traps", "name": "Barbed wire parts", "price": 20, "items": {"scrap": 3, "nails": 4}},
	{"cat": "Traps", "name": "Landmine parts", "price": 30, "items": {"scrap": 4, "nails": 4, "cloth": 1}},
]
## Bigger orders and blueprints, flown in by the drone to a landing pad.
const DRONE := [
	{"name": "40 wood", "price": 60, "items": {"wood": 40}},
	{"name": "40 scrap metal", "price": 90, "items": {"scrap": 40}},
	{"name": "100 nails", "price": 45, "items": {"nails": 100}},
	{"name": "10 cement bags", "price": 80, "items": {"cement": 10}},
	{"name": "120 9mm rounds", "price": 80, "items": {"ammo_9mm": 120}},
	{"name": "6 fuel cans", "price": 60, "items": {"fuel": 6}},
	{"name": "Blueprint: Auto-turret", "price": 150, "items": {"bp_turret": 1}},
	{"name": "Blueprint: Electric fence", "price": 120, "items": {"bp_fence": 1}},
	{"name": "Blueprint: Sandbag wall", "price": 60, "items": {"bp_sandbags": 1}},
]
## Blueprint item -> the build piece it unlocks.
const BLUEPRINTS := {"bp_turret": "turret", "bp_fence": "electric_fence", "bp_sandbags": "sandbags"}
## Base upgrades: each level's price and what it gives.
const UPGRADES := {
	"zone": {"name": "Bigger build zone", "levels": [{"price": 200, "value": 34.0, "text": "34 m"}, {"price": 400, "value": 42.0, "text": "42 m"}]},
	"storage": {"name": "More chest storage", "levels": [{"price": 150, "value": 30, "text": "30 slots"}, {"price": 300, "value": 40, "text": "40 slots"}]},
	"bench": {"name": "Workbench tier", "levels": [{"price": 200, "value": 2, "text": "tier 2: shotgun, shells"}, {"price": 400, "value": 3, "text": "tier 3: rifle, 7.62, medkits"}]},
	"radio": {"name": "Radio", "levels": [{"price": 120, "value": 1, "text": "hear at dusk what is coming"}]},
}
const START_CASH := 50

signal cash_changed(cash: int)
signal upgraded(id: String)

var cash := START_CASH
## Build pieces unlocked by blueprints.
var unlocked := {}
var drone  # Drone
## Upgrade id -> how many levels bought.
var upgrades := {"zone": 0, "storage": 0, "bench": 0, "radio": 0}
var _radio: Node3D


func _ready() -> void:
	set_meta("interact_id", "shop")
	var metal := LowPoly.material(Color(0.3, 0.33, 0.3), 0.6)
	var dark := LowPoly.material(Color(0.12, 0.13, 0.12))
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.2, 0.9, 0.5)
	screen.emission_enabled = true
	screen.emission = Color(0.15, 0.8, 0.4)
	screen.emission_energy_multiplier = 1.2
	_box(Vector3(0.12, 1.1, 0.12), Vector3(0, 0.55, 0), metal)          # post
	_box(Vector3(0.7, 0.55, 0.22), Vector3(0, 1.3, 0), metal)           # housing
	_box(Vector3(0.58, 0.4, 0.02), Vector3(0, 1.32, -0.115), screen)    # screen
	_box(Vector3(0.78, 0.06, 0.32), Vector3(0, 1.6, -0.03), dark)       # sun hood
	_box(Vector3(0.5, 0.06, 0.18), Vector3(0, 1.0, -0.12), dark)        # keypad
	_box(Vector3(0.5, 0.06, 0.5), Vector3(0, 0.03, 0), dark)            # foot
	# A field radio on top, there once you buy the radio upgrade.
	_radio = Node3D.new()
	_radio.position = Vector3(0.18, 1.63, 0.02)
	_radio.visible = false
	add_child(_radio)
	var olive := LowPoly.material(Color(0.33, 0.36, 0.22))
	for b in [[Vector3(0.3, 0.16, 0.14), Vector3(0, 0.08, 0)], [Vector3(0.015, 0.5, 0.015), Vector3(0.11, 0.4, 0.03)]]:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = b[0]
		mi.mesh = m
		mi.position = b[1]
		mi.material_override = olive if b[0].y < 0.3 else dark
		_radio.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.75, 1.65, 0.4)
	col.shape = shape
	col.position.y = 0.82
	add_child(col)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	add_child(mi)


func add_cash(n: int) -> void:
	cash += n
	cash_changed.emit(cash)


func can_buy(i: int) -> bool:
	return cash >= int(CATALOG[i].price)


## Buys catalogue entry i into the inventory. Returns what did not fit
## ({} normally), or null if you can't afford it.
func buy(i: int, inventory) -> Variant:
	if not can_buy(i):
		return null
	cash -= int(CATALOG[i].price)
	cash_changed.emit(cash)
	return inventory.add_all(CATALOG[i].items)


## True if a build piece may be built (blueprint pieces need unlocking).
func is_unlocked(type: String, pieces: Dictionary) -> bool:
	return not pieces[type].get("blueprint", false) or unlocked.has(type)


## A blueprint already learned, or on its way.
func blueprint_owned(item: String) -> bool:
	if unlocked.has(BLUEPRINTS[item]):
		return true
	if drone:
		for o in drone.orders:
			if o.has(item):
				return true
		return drone.cargo.has(item)
	return false


func can_order(i: int) -> bool:
	if drone == null or drone.pad_position() == null or cash < int(DRONE[i].price):
		return false
	for item in DRONE[i].items:
		if BLUEPRINTS.has(item) and blueprint_owned(item):
			return false
	return true


## Sends a drone order. Returns false if it can't be ordered now.
func order(i: int) -> bool:
	if not can_order(i):
		return false
	cash -= int(DRONE[i].price)
	cash_changed.emit(cash)
	drone.order(DRONE[i].items)
	return true


## Takes the blueprints out of a delivery and learns them. Returns the piece names learned.
func learn_blueprints(items: Dictionary) -> Array:
	var learned: Array = []
	for item in items.keys():
		if BLUEPRINTS.has(item):
			unlocked[BLUEPRINTS[item]] = true
			learned.append(BLUEPRINTS[item])
			items.erase(item)
	return learned


## The next level of an upgrade ({} when it is maxed out).
func next_level(id: String) -> Dictionary:
	var levels: Array = UPGRADES[id].levels
	return levels[upgrades[id]] if upgrades[id] < levels.size() else {}


## What an upgrade gives right now (its last bought level), or base when none.
func upgrade_value(id: String, base):
	return UPGRADES[id].levels[upgrades[id] - 1].value if upgrades[id] > 0 else base


func can_upgrade(id: String) -> bool:
	var n := next_level(id)
	return not n.is_empty() and cash >= int(n.price)


func buy_upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	cash -= int(next_level(id).price)
	upgrades[id] += 1
	cash_changed.emit(cash)
	_radio.visible = upgrades.radio > 0
	upgraded.emit(id)
	return true


func save_data() -> Dictionary:
	return {"cash": cash, "unlocked": unlocked.keys(), "upgrades": upgrades}


func load_data(data: Dictionary) -> void:
	cash = maxi(int(data.get("cash", START_CASH)), 0)
	unlocked = {}
	for t in data.get("unlocked", []):
		unlocked[str(t)] = true
	# Saves from before workbench tiers keep every recipe.
	var up: Dictionary = data.get("upgrades", {"bench": 2})
	for id in upgrades:
		upgrades[id] = clampi(int(up.get(id, 0)), 0, UPGRADES[id].levels.size())
	_radio.visible = upgrades.radio > 0
	cash_changed.emit(cash)

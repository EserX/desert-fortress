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
const START_CASH := 50

signal cash_changed(cash: int)

var cash := START_CASH


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


func save_data() -> Dictionary:
	return {"cash": cash}


func load_data(data: Dictionary) -> void:
	cash = maxi(int(data.get("cash", START_CASH)), 0)
	cash_changed.emit(cash)

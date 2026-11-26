extends RefCounted
## Item definitions: display name, weight in kg (for the v0.5 weight limit)
## and how many fit in one stack.

const ITEMS := {
	"scrap": {"name": "Scrap metal", "weight": 1.5, "stack": 20},
	"wood": {"name": "Wood", "weight": 1.0, "stack": 20},
	"cloth": {"name": "Cloth", "weight": 0.2, "stack": 20},
	"nails": {"name": "Nails", "weight": 0.05, "stack": 50},
	"canned_food": {"name": "Canned food", "weight": 0.4, "stack": 10},
	"water": {"name": "Water bottle", "weight": 0.5, "stack": 10},
	"cement": {"name": "Cement bag", "weight": 2.0, "stack": 10},
	"hammer": {"name": "Hammer", "weight": 1.0, "stack": 1},
	"pipe": {"name": "Rusty pipe", "weight": 1.5, "stack": 1},
	"machete": {"name": "Machete", "weight": 0.8, "stack": 1},
	"bandage": {"name": "Bandage", "weight": 0.1, "stack": 10},
	"spike_barricade": {"name": "Spike barricade", "weight": 4.0, "stack": 5},
}

## What each kind of container can hold: item -> [min, max].
const LOOT_TABLES := {
	"glovebox": {"cloth": [0, 2], "nails": [0, 4], "canned_food": [0, 1], "water": [0, 1]},
	"trunk": {"scrap": [2, 5], "nails": [2, 6], "cloth": [0, 2], "water": [0, 1]},
	"crate": {"wood": [2, 5], "nails": [1, 4], "canned_food": [0, 2], "water": [0, 2], "cement": [0, 1]},
	"supply": {"wood": [4, 8], "scrap": [3, 7], "nails": [8, 16], "canned_food": [1, 3], "water": [2, 4], "cloth": [1, 3], "cement": [1, 3]},
}

## Workbench recipes, in the order shown: item -> {"count": made, "cost": {item: n}, "info": String}.
const RECIPES := {
	"hammer": {"count": 1, "cost": {"scrap": 2, "wood": 2}, "info": "Repairs, upgrades and demolishes"},
	"machete": {"count": 1, "cost": {"scrap": 3, "cloth": 1, "wood": 1}, "info": "Hits harder and faster than the pipe"},
	"bandage": {"count": 1, "cost": {"cloth": 2}, "info": "Heals 30 health (use it like food)"},
	"spike_barricade": {"count": 1, "cost": {"wood": 4, "nails": 4}, "info": "Build it in build mode, keeps mutants back"},
}

const CONTAINER_NAMES := {"glovebox": "glovebox", "trunk": "trunk", "crate": "crate", "supply": "supply crate"}


static func display_name(id: String) -> String:
	return ITEMS[id].name if ITEMS.has(id) else id


## Rolls the contents of a container. Never returns nothing.
static func roll(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	var table: Dictionary = LOOT_TABLES[kind]
	for item in table:
		var n := rng.randi_range(table[item][0], table[item][1])
		if n > 0:
			out[item] = n
	if out.is_empty():
		var first: String = table.keys()[0]
		out[first] = 1
	return out


## True if the inventory holds everything a recipe needs.
static func can_craft(id: String, inventory) -> bool:
	var cost: Dictionary = RECIPES[id].cost
	for item in cost:
		if inventory.count_of(item) < cost[item]:
			return false
	return true


## Crafts one batch: takes the materials and adds the result. Returns what did
## not fit in the inventory ({} normally), or null if materials are missing.
static func craft(id: String, inventory) -> Variant:
	if not can_craft(id, inventory):
		return null
	var r: Dictionary = RECIPES[id]
	for item in r.cost:
		inventory.remove(item, r.cost[item])
	return inventory.add_all({id: r.count})

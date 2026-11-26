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
	"pistol": {"name": "Pistol", "weight": 1.0, "stack": 1},
	"ammo_9mm": {"name": "9mm rounds", "weight": 0.012, "stack": 60},
	"shotgun": {"name": "Shotgun", "weight": 3.2, "stack": 1},
	"rifle": {"name": "Hunting rifle", "weight": 3.8, "stack": 1},
	"shells": {"name": "Shotgun shells", "weight": 0.04, "stack": 30},
	"ammo_762": {"name": "7.62 rounds", "weight": 0.025, "stack": 40},
	"fuel": {"name": "Fuel can", "weight": 1.2, "stack": 10},
	"bp_turret": {"name": "Blueprint: Auto-turret", "weight": 0.0, "stack": 1},
	"bp_fence": {"name": "Blueprint: Electric fence", "weight": 0.0, "stack": 1},
	"bp_sandbags": {"name": "Blueprint: Sandbag wall", "weight": 0.0, "stack": 1},
	"medkit": {"name": "Medkit", "weight": 0.4, "stack": 5},
	"shovel": {"name": "Shovel", "weight": 2.0, "stack": 1},
	"sand": {"name": "Sand", "weight": 1.0, "stack": 20},
	"pickaxe": {"name": "Pickaxe", "weight": 2.5, "stack": 1},
	"stone": {"name": "Stone", "weight": 1.5, "stack": 20},
	"clay": {"name": "Clay", "weight": 1.2, "stack": 20},
	"metal_detector": {"name": "Metal detector", "weight": 1.5, "stack": 1},
}

## What each kind of container can hold: item -> [min, max]. A negative min
## makes the item rarer (anything rolled below 1 means none).
const LOOT_TABLES := {
	"glovebox": {"cloth": [0, 2], "nails": [0, 4], "canned_food": [0, 1], "water": [0, 1]},
	"trunk": {"scrap": [2, 5], "nails": [2, 6], "cloth": [0, 2], "water": [0, 1], "ammo_9mm": [-6, 6], "shells": [-8, 4], "fuel": [-1, 2]},
	"crate": {"wood": [2, 5], "nails": [1, 4], "canned_food": [0, 2], "water": [0, 2], "cement": [0, 1]},
	"cache": {"scrap": [3, 8], "nails": [6, 14], "ammo_9mm": [6, 18], "cloth": [0, 3], "cement": [0, 2], "fuel": [0, 2], "shells": [-4, 6], "medkit": [-2, 1], "canned_food": [0, 2]},
	"supply": {"wood": [4, 8], "scrap": [3, 7], "nails": [8, 16], "canned_food": [1, 3], "water": [2, 4], "cloth": [1, 3], "cement": [1, 3], "ammo_9mm": [8, 20], "pistol": [-1, 1], "shells": [2, 8], "ammo_762": [-2, 6], "shotgun": [-3, 1], "rifle": [-4, 1], "fuel": [1, 4]},
}

## Workbench recipes, in the order shown: item -> {"count": made, "cost": {item: n}, "info": String}.
const RECIPES := {
	"hammer": {"count": 1, "cost": {"scrap": 2, "wood": 2}, "info": "repairs, upgrades, demolishes"},
	"machete": {"count": 1, "cost": {"scrap": 3, "cloth": 1, "wood": 1}, "info": "faster and harder than the pipe"},
	"bandage": {"count": 1, "cost": {"cloth": 2}, "info": "heals 30, use with F"},
	"shovel": {"count": 1, "cost": {"scrap": 3, "wood": 2}, "info": "LMB digs (gives sand), RMB fills"},
	"pickaxe": {"count": 1, "cost": {"scrap": 4, "wood": 2}, "info": "breaks rocks for stone, digs through stone"},
	"metal_detector": {"count": 1, "cost": {"scrap": 6, "nails": 4, "cloth": 2}, "info": "finds caches buried near the base"},
	"spike_barricade": {"count": 1, "cost": {"wood": 4, "nails": 4}, "info": "build it in build mode"},
	"pistol": {"count": 1, "cost": {"scrap": 10, "wood": 2, "nails": 6}, "info": "12 rounds. RMB aims, R reloads"},
	"ammo_9mm": {"count": 8, "cost": {"scrap": 2, "nails": 3}, "info": "for the pistol"},
	"shotgun": {"count": 1, "cost": {"scrap": 14, "wood": 4, "nails": 8}, "info": "6 shells, deadly up close", "tier": 2},
	"shells": {"count": 6, "cost": {"scrap": 2, "nails": 4, "cloth": 1}, "info": "for the shotgun", "tier": 2},
	"rifle": {"count": 1, "cost": {"scrap": 16, "wood": 5, "nails": 10, "cloth": 2}, "info": "Scoped, 5 rounds, long range", "tier": 3},
	"ammo_762": {"count": 5, "cost": {"scrap": 3, "nails": 4}, "info": "for the rifle", "tier": 3},
	"medkit": {"count": 1, "cost": {"bandage": 2, "cloth": 2, "water": 1}, "info": "heals 70, use with F", "tier": 3},
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


## Workbench tier a recipe needs (base upgrades raise the bench's tier).
static func recipe_tier(id: String) -> int:
	return int(RECIPES[id].get("tier", 1))


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

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
	"cable": {"name": "Cable", "weight": 0.1, "stack": 50},
	"axe": {"name": "Axe", "weight": 1.8, "stack": 1},
	"log": {"name": "Log", "weight": 3.0, "stack": 10},
	"kit_sawmill": {"name": "Sawmill (crate)", "weight": 12.0, "stack": 1},
	"kit_crusher": {"name": "Rock crusher (crate)", "weight": 15.0, "stack": 1},
	"kit_press": {"name": "Nail press (crate)", "weight": 12.0, "stack": 1},
	"watering_can": {"name": "Watering can", "weight": 1.0, "stack": 1},
	"water_pipe": {"name": "Water pipe", "weight": 0.3, "stack": 50},
	# v1.14 farming: seeds (by drone) and what the crops give.
	"seed_millet": {"name": "Millet seeds", "weight": 0.02, "stack": 30},
	"seed_melon": {"name": "Melon seeds", "weight": 0.02, "stack": 30},
	"seed_cotton": {"name": "Cotton seeds", "weight": 0.02, "stack": 30},
	"seed_agave": {"name": "Agave pups", "weight": 0.3, "stack": 10},
	"seed_acacia": {"name": "Fast acacia seedlings", "weight": 0.3, "stack": 10},
	"seed_marigold": {"name": "Desert marigold seeds", "weight": 0.02, "stack": 30},
	"seed_date_palm": {"name": "Date palm sapling", "weight": 2.0, "stack": 5},
	"seed_saffron": {"name": "Saffron bulbs", "weight": 0.05, "stack": 20},
	"seed_dragon_fruit": {"name": "Dragon fruit cuttings", "weight": 0.3, "stack": 10},
	"millet": {"name": "Millet", "weight": 0.2, "stack": 30},
	"melon": {"name": "Melon", "weight": 1.5, "stack": 10},
	"cotton": {"name": "Cotton", "weight": 0.1, "stack": 30},
	"fibre": {"name": "Agave fibre", "weight": 0.1, "stack": 30},
	"rope": {"name": "Rope", "weight": 0.3, "stack": 20},
	"flowers": {"name": "Marigolds", "weight": 0.05, "stack": 30},
	"dates": {"name": "Dates", "weight": 0.2, "stack": 30},
	"saffron": {"name": "Saffron", "weight": 0.01, "stack": 50},
	"dragon_fruit": {"name": "Dragon fruit", "weight": 0.4, "stack": 20},
	# v1.16 hunting: animals give raw meat, cooked at a burning fire pit.
	"raw_meat": {"name": "Raw meat", "weight": 0.5, "stack": 10},
	"cooked_meat": {"name": "Cooked meat", "weight": 0.4, "stack": 10},
	# v1.18 oases: reeds cut at the pond (clay is dug from the bank there too).
	"reeds": {"name": "Reeds", "weight": 0.2, "stack": 30},
	# v1.19 goals: seeds unlocked by the first green milestone, and machines.
	"seed_olive": {"name": "Olive sapling", "weight": 2.0, "stack": 5},
	"seed_prickly_pear": {"name": "Prickly pear pads", "weight": 0.4, "stack": 10},
	"olives": {"name": "Olives", "weight": 0.1, "stack": 40},
	"prickly_pear": {"name": "Prickly pears", "weight": 0.3, "stack": 20},
	"kit_dew": {"name": "Dew collector (crate)", "weight": 8.0, "stack": 1},
	"kit_purifier": {"name": "Water purifier (crate)", "weight": 10.0, "stack": 1},
	"kit_weather": {"name": "Weather station (crate)", "weight": 14.0, "stack": 1},
	# v2.0 throwables (a stone can be thrown too).
	"molotov": {"name": "Molotov", "weight": 0.8, "stack": 5},
	"pipe_bomb": {"name": "Pipe bomb", "weight": 1.0, "stack": 5},
	# v2.1 cooking and spoiling food.
	"flatbread": {"name": "Flatbread", "weight": 0.2, "stack": 20},
	"stew": {"name": "Stew", "weight": 0.6, "stack": 10},
	"rotten_food": {"name": "Rotten food", "weight": 0.3, "stack": 30},
	# v2.2 crafting chain: what the furnace smelts, parts and better tools.
	"metal_plate": {"name": "Metal plate", "weight": 1.2, "stack": 20},
	"glass": {"name": "Glass", "weight": 0.6, "stack": 20},
	"brick": {"name": "Bricks", "weight": 1.0, "stack": 30},
	"glass_pane": {"name": "Glass pane", "weight": 1.5, "stack": 5},
	"steel_shovel": {"name": "Steel shovel", "weight": 2.2, "stack": 1},
	"sledgehammer": {"name": "Sledgehammer", "weight": 4.0, "stack": 1},
}

## What each kind of container can hold: item -> [min, max]. A negative min
## makes the item rarer (anything rolled below 1 means none).
const LOOT_TABLES := {
	"glovebox": {"cloth": [0, 2], "nails": [0, 4], "canned_food": [0, 1], "water": [0, 1]},
	"trunk": {"scrap": [2, 5], "nails": [2, 6], "cloth": [0, 2], "water": [0, 1], "ammo_9mm": [-6, 6], "shells": [-8, 4], "fuel": [-1, 2]},
	"crate": {"wood": [2, 5], "nails": [1, 4], "canned_food": [0, 2], "water": [0, 2], "cement": [0, 1]},
	"cache": {"scrap": [3, 8], "nails": [6, 14], "ammo_9mm": [6, 18], "cloth": [0, 3], "cement": [0, 2], "fuel": [0, 2], "shells": [-4, 6], "medkit": [-2, 1], "canned_food": [0, 2]},
	"oasis": {"seed_saffron": [2, 4], "seed_dragon_fruit": [1, 3], "seed_date_palm": [0, 2], "water": [1, 2]},
	"supply": {"wood": [4, 8], "scrap": [3, 7], "nails": [8, 16], "canned_food": [1, 3], "water": [2, 4], "cloth": [1, 3], "cement": [1, 3], "ammo_9mm": [8, 20], "pistol": [-1, 1], "shells": [2, 8], "ammo_762": [-2, 6], "shotgun": [-3, 1], "rifle": [-4, 1], "fuel": [1, 4]},
}

## Workbench recipes, in the order shown: item -> {"count": made, "cost": {item: n}, "info": String}.
const RECIPES := {
	"hammer": {"count": 1, "cost": {"scrap": 2, "wood": 2}, "info": "repairs, upgrades, demolishes"},
	"machete": {"count": 1, "cost": {"scrap": 3, "cloth": 1, "wood": 1}, "info": "faster and harder than the pipe"},
	"bandage": {"count": 1, "cost": {"cloth": 2}, "info": "heals 30, use with F"},
	"shovel": {"count": 1, "cost": {"scrap": 3, "wood": 2}, "info": "LMB digs (gives sand), RMB fills"},
	"pickaxe": {"count": 1, "cost": {"scrap": 4, "wood": 2}, "info": "breaks rocks for stone, digs through stone"},
	"axe": {"count": 1, "cost": {"scrap": 3, "wood": 2}, "info": "fells trees for logs; a decent weapon too"},
	"wood": {"count": 2, "cost": {"log": 1}, "info": "split a log by hand (a sawmill gets 5)"},
	"cable": {"count": 6, "cost": {"scrap": 1, "cloth": 1}, "info": "hold it: click a generator, then a light, fence, switch or turret"},
	"watering_can": {"count": 1, "cost": {"scrap": 2, "nails": 2}, "info": "fill it at the main well, LMB pours water on the sand"},
	"water_pipe": {"count": 4, "cost": {"scrap": 2, "nails": 1}, "info": "hold it: click the main well, then a sprinkler or water purifier (needs the hand pump)"},
	"cloth": {"count": 2, "cost": {"cotton": 3}, "info": "spin cotton from your fields into cloth"},
	"fibre": {"count": 2, "cost": {"reeds": 3}, "info": "strip oasis reeds for fibre"},
	"rope": {"count": 1, "cost": {"fibre": 3}, "info": "twist agave fibre into rope (sells well at the market)"},
	"glass_pane": {"count": 1, "cost": {"glass": 2, "wood": 1}, "info": "a framed pane: builds the brick wall with a glass window"},
	"steel_shovel": {"count": 1, "cost": {"metal_plate": 3, "wood": 2}, "info": "digs twice as fast for less stamina (metal plates come from a furnace)"},
	"sledgehammer": {"count": 1, "cost": {"metal_plate": 4, "wood": 3, "cloth": 1}, "info": "LMB knocks a building piece down in one blow, breaks rocks fast, a heavy weapon"},
	"metal_detector": {"count": 1, "cost": {"scrap": 6, "nails": 4, "cloth": 2}, "info": "finds caches buried near the base"},
	"spike_barricade": {"count": 1, "cost": {"wood": 4, "nails": 4}, "info": "build it in build mode"},
	"molotov": {"count": 2, "cost": {"fuel": 1, "cloth": 1, "water": 2}, "info": "LMB throws (hold to throw further): a pool of fire, burns nests"},
	"pipe_bomb": {"count": 1, "cost": {"scrap": 2, "nails": 4, "fuel": 1}, "info": "LMB throws (hold to throw further): bounces, blows up after 2.5 s", "tier": 2},
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

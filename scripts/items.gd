extends RefCounted
## Item definitions and loot tables. Weights (kg) are for the inventory limit
## that arrives in v0.5.

const ITEMS := {
	"scrap": {"name": "Scrap metal", "weight": 1.0, "color": Color(0.70, 0.66, 0.62)},
	"wood": {"name": "Wood", "weight": 0.8, "color": Color(0.78, 0.56, 0.32)},
	"cloth": {"name": "Cloth", "weight": 0.2, "color": Color(0.86, 0.80, 0.68)},
	"nails": {"name": "Nails", "weight": 0.05, "color": Color(0.75, 0.78, 0.82)},
	"canned_food": {"name": "Canned food", "weight": 0.4, "color": Color(0.95, 0.62, 0.35)},
	"water": {"name": "Water bottle", "weight": 0.5, "color": Color(0.55, 0.80, 1.0)},
}

## How many of an item one lucky roll gives: [min, max].
const AMOUNTS := {
	"scrap": [1, 3], "wood": [1, 3], "cloth": [1, 2],
	"nails": [2, 6], "canned_food": [1, 1], "water": [1, 1],
}

## Per container kind: rolls [min, max], chance of finding nothing, and
## item weights (higher = more common).
const TABLES := {
	"glovebox": {"rolls": [1, 2], "empty": 0.15,
		"items": {"cloth": 3, "nails": 3, "canned_food": 2, "water": 2}},
	"trunk": {"rolls": [2, 3], "empty": 0.05,
		"items": {"scrap": 5, "cloth": 2, "nails": 2, "water": 2, "wood": 1}},
	"crate": {"rolls": [2, 4], "empty": 0.0,
		"items": {"wood": 5, "nails": 3, "scrap": 2, "canned_food": 2, "water": 2, "cloth": 1}},
}


static func display_name(id: String) -> String:
	return ITEMS[id].name if ITEMS.has(id) else id


## Rolls the contents of one container: {item_id: count}. The same seed
## always gives the same loot, so a world's containers are fixed per save.
static func roll(kind: String, seed_value: int) -> Dictionary:
	var table: Dictionary = TABLES.get(kind, TABLES.crate)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := {}
	if rng.randf() < float(table.empty):
		return out
	var total := 0
	for w in table.items.values():
		total += int(w)
	for r in rng.randi_range(table.rolls[0], table.rolls[1]):
		var pick := rng.randi_range(1, total)
		for id in table.items:
			pick -= int(table.items[id])
			if pick <= 0:
				var amt: Array = AMOUNTS[id]
				out[id] = int(out.get(id, 0)) + rng.randi_range(amt[0], amt[1])
				break
	return out

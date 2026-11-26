extends Node
## What the player carries: item id -> count. The grid, hotbar and weight
## limit arrive in v0.5; for now this is a simple tally that is saved.

const Items = preload("res://scripts/items.gd")

signal changed

var items := {}


func add(id: String, amount: int) -> void:
	if amount <= 0:
		return
	items[id] = count(id) + amount
	changed.emit()


func count(id: String) -> int:
	return int(items.get(id, 0))


func total_weight() -> float:
	var w := 0.0
	for id in items:
		if Items.ITEMS.has(id):
			w += float(Items.ITEMS[id].weight) * count(id)
	return w


func to_save() -> Dictionary:
	return items.duplicate()


func from_save(data: Dictionary) -> void:
	items = {}
	for id in data:
		if Items.ITEMS.has(id) and int(data[id]) > 0:
			items[id] = int(data[id])
	changed.emit()

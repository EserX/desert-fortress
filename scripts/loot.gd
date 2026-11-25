extends Node
## Searchable containers (wreck gloveboxes and trunks, ruin crates) and what
## the player has picked up. Containers are found by their stable ids, so
## which ones are opened can be saved.

const Items = preload("res://scripts/items.gd")

signal picked_up(items: Dictionary)

var world_seed := 0
## id -> {"kind": String, "opened": bool, "lid": Node3D or null}
var containers := {}
## item id -> count. Grows into the full inventory in v0.5.
var inventory := {}


func register(id: String, kind: String, lid: Node3D = null) -> void:
	containers[id] = {"kind": kind, "opened": false, "lid": lid}


func is_opened(id: String) -> bool:
	return containers.has(id) and containers[id].opened


## Text for the on-screen prompt, e.g. "[E] Search trunk".
func prompt(id: String) -> String:
	if not containers.has(id):
		return ""
	var c: Dictionary = containers[id]
	var name: String = Items.CONTAINER_NAMES[c.kind]
	if c.opened:
		return "%s (empty)" % name.capitalize()
	return "[E] Search %s" % name


## Opens a container, adds its loot to the inventory and returns it.
## Returns an empty dictionary if it was already searched.
func open(id: String) -> Dictionary:
	if not containers.has(id) or containers[id].opened:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [world_seed, id])
	var got := Items.roll(containers[id].kind, rng)
	for item in got:
		inventory[item] = int(inventory.get(item, 0)) + got[item]
	_mark_opened(id)
	picked_up.emit(got)
	return got


func _mark_opened(id: String) -> void:
	var c: Dictionary = containers[id]
	c.opened = true
	var lid: Node3D = c.lid
	if lid:
		# Lid knocked off and lying next to the crate.
		lid.position += Vector3(0.55, -0.35, 0.2)
		lid.rotation = Vector3(0.3, 0.6, 1.2)


func save_data() -> Dictionary:
	var opened: Array = []
	for id in containers:
		if containers[id].opened:
			opened.append(id)
	return {"opened": opened, "inventory": inventory.duplicate()}


func load_data(data: Dictionary) -> void:
	for id in data.get("opened", []):
		if containers.has(id) and not containers[id].opened:
			_mark_opened(id)
	inventory = {}
	var inv: Dictionary = data.get("inventory", {})
	for item in inv:
		inventory[item] = int(inv[item])

extends RefCounted
## v2.7: machines that feed a chest. A sawmill, rock crusher, nail press or
## furnace with a storage chest on a square next to it (sides or corners, same
## storey) puts what it makes straight into that chest, so it keeps working
## while you are away and doesn't stop when its own tray fills up. If the
## chest is full, what's made waits in the machine as before.
## It only ever puts things in: machines never take from the chest, so stone or
## scrap kept there for building is safe.
## power.gd (machines) and furnace.gd call feed() after each work step; the
## prompts call chest_for() to say where the goods go.

## Furthest a chest's middle may be from the machine's: a neighbouring square,
## diagonals too (2 m squares, so 2.83 m), but not two squares away.
const RANGE := 3.0
## Most a chest may be above or below the machine (the same storey).
const RISE := 1.2


## Key of the nearest chest next to the machine piece `rec`, or "".
## Runs four times a second per machine, over the chests (a few dozen at most).
static func chest_for(building, rec: Dictionary) -> String:
	if rec.is_empty() or not is_instance_valid(rec.get("node")):
		return ""
	var at: Vector3 = rec.node.global_position
	var best := ""
	var best_d := INF
	for key in building.keys_of(["chest"]):
		var c: Dictionary = building.pieces[key]
		if not is_instance_valid(c.get("node")) or c.get("storage") == null:
			continue
		var p: Vector3 = c.node.global_position
		if absf(p.y - at.y) > RISE:
			continue
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d <= RANGE and d < best_d:
			best_d = d
			best = key
	return best


## Moves what the machine or furnace `rec` has made into the chest next to it.
## Returns {item: count} of what went in (empty when nothing moved).
static func feed(building, rec: Dictionary) -> Dictionary:
	var moved := {}
	var ready := _ready_goods(building, rec)
	if ready.is_empty():
		return moved
	var key := chest_for(building, rec)
	if key == "":
		return moved
	var store = building.pieces[key].storage
	for item in ready:
		var n: int = ready[item]
		var left: int = store.add(item, n)
		if n - left > 0:
			moved[item] = n - left
			_take(building, rec, item, n - left)
	return moved


## What `rec` has ready to hand over: {item: count}.
static func _ready_goods(building, rec: Dictionary) -> Dictionary:
	if rec.get("type", "") == "furnace":
		return (rec.get("made", {}) as Dictionary).duplicate()
	if building.MACHINES.has(rec.get("type", "")) and int(rec.get("output", 0)) > 0:
		return {building.MACHINES[rec.type].out: int(rec.output)}
	return {}


static func _take(building, rec: Dictionary, item: String, n: int) -> void:
	if rec.type == "furnace":
		var left := int(rec.made.get(item, 0)) - n
		if left > 0:
			rec.made[item] = left
		else:
			rec.made.erase(item)
	elif building.MACHINES.has(rec.type):
		rec.output = maxi(int(rec.output) - n, 0)

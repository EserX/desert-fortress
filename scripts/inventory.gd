extends RefCounted
## The player's pockets: a fixed grid of slots holding stacks. The first
## HOTBAR slots are the hotbar (keys 1–9). Carrying more than MAX_WEIGHT kg
## means no sprinting.

const Items = preload("res://scripts/items.gd")

signal changed

const SIZE := 30
const HOTBAR := 9
const MAX_WEIGHT := 50.0

## Each slot is {} (empty) or {"item": String, "count": int}.
var slots: Array = []
var selected := 0  # selected hotbar slot


## size: how many slots (chests use fewer than your pockets).
func _init(size := SIZE) -> void:
	slots.resize(size)
	for i in size:
		slots[i] = {}


## Grows to n slots (never shrinks, so nothing is lost).
func resize(n: int) -> void:
	while slots.size() < n:
		slots.append({})
	changed.emit()


## Adds items, topping up stacks first, then empty slots (hotbar first).
## Returns how many did not fit.
func add(item: String, count: int) -> int:
	var max_stack: int = Items.ITEMS[item].stack
	for s in slots:
		if count <= 0:
			break
		if not s.is_empty() and s.item == item and s.count < max_stack:
			var n := mini(count, max_stack - s.count)
			s.count += n
			count -= n
	for i in slots.size():
		if count <= 0:
			break
		if slots[i].is_empty():
			var n := mini(count, max_stack)
			slots[i] = {"item": item, "count": n}
			count -= n
	changed.emit()
	return count


## Adds a whole {item: count} dictionary. Returns what did not fit, in the same form.
func add_all(items: Dictionary) -> Dictionary:
	var left := {}
	for item in items:
		var n := add(item, int(items[item]))
		if n > 0:
			left[item] = n
	return left


func count_of(item: String) -> int:
	var n := 0
	for s in slots:
		if not s.is_empty() and s.item == item:
			n += s.count
	return n


## Removes up to count of an item. Returns how many were removed.
func remove(item: String, count: int) -> int:
	var removed := 0
	for i in range(slots.size() - 1, -1, -1):
		var s: Dictionary = slots[i]
		if removed >= count:
			break
		if not s.is_empty() and s.item == item:
			var n := mini(count - removed, s.count)
			s.count -= n
			removed += n
			if s.count <= 0:
				slots[i] = {}
	changed.emit()
	return removed


## Takes the whole stack out of a slot and returns it ({} if empty).
## Uses up one item from a slot.
func take_one(i: int) -> void:
	var s: Dictionary = slots[i]
	if s.is_empty():
		return
	s.count -= 1
	if s.count <= 0:
		slots[i] = {}
	changed.emit()


func take_slot(i: int) -> Dictionary:
	var s: Dictionary = slots[i]
	slots[i] = {}
	changed.emit()
	return s


## Moves slot a onto slot b: merges equal items, otherwise swaps.
func move(a: int, b: int) -> void:
	if a == b or slots[a].is_empty():
		return
	var sa: Dictionary = slots[a]
	var sb: Dictionary = slots[b]
	if not sb.is_empty() and sb.item == sa.item:
		var max_stack: int = Items.ITEMS[sa.item].stack
		var n := mini(sa.count, max_stack - sb.count)
		sb.count += n
		sa.count -= n
		if sa.count <= 0:
			slots[a] = {}
	else:
		slots[a] = sb
		slots[b] = sa
	changed.emit()


## Moves slot a of this inventory onto slot b of another (or the same) one:
## merges equal items, otherwise swaps.
func move_to(a: int, other, b: int) -> void:
	if other == self:
		move(a, b)
		return
	if slots[a].is_empty():
		return
	var sa: Dictionary = slots[a]
	var sb: Dictionary = other.slots[b]
	if not sb.is_empty() and sb.item == sa.item:
		var n := mini(sa.count, int(Items.ITEMS[sa.item].stack) - sb.count)
		sb.count += n
		sa.count -= n
		if sa.count <= 0:
			slots[a] = {}
	else:
		slots[a] = sb
		other.slots[b] = sa
	changed.emit()
	other.changed.emit()


## Moves a whole stack into another inventory wherever it fits. Returns true if all of it went.
func transfer(a: int, other) -> bool:
	var s: Dictionary = slots[a]
	if s.is_empty():
		return true
	var left: int = other.add(s.item, s.count)
	if left <= 0:
		slots[a] = {}
	else:
		s.count = left
	changed.emit()
	return left <= 0


## Everything in here as {item: count}.
func contents() -> Dictionary:
	var out := {}
	for s in slots:
		if not s.is_empty():
			out[s.item] = int(out.get(s.item, 0)) + s.count
	return out


func weight() -> float:
	var w := 0.0
	for s in slots:
		if not s.is_empty():
			w += Items.ITEMS[s.item].weight * s.count
	return w


func overloaded() -> bool:
	return weight() > MAX_WEIGHT


func selected_stack() -> Dictionary:
	return slots[selected]


func save_data() -> Dictionary:
	return {"slots": slots.duplicate(true), "selected": selected}


func load_data(data: Dictionary) -> void:
	for i in slots.size():
		slots[i] = {}
	var saved: Array = data.get("slots", [])
	for i in mini(saved.size(), slots.size()):
		var s = saved[i]
		if s is Dictionary and Items.ITEMS.has(s.get("item", "")):
			slots[i] = {"item": s.item, "count": int(s.count)}
	selected = clampi(int(data.get("selected", 0)), 0, HOTBAR - 1)
	changed.emit()

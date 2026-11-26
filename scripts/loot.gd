extends Node
## Searchable containers (wreck gloveboxes and trunks, ruin crates) and bags
## of items dropped on the ground. Containers are found by their stable ids,
## so which ones are opened can be saved.

const Items = preload("res://scripts/items.gd")
const LowPoly = preload("res://scripts/lowpoly.gd")

var world_seed := 0
## id -> {"kind": String, "opened": bool, "lid": Node3D or null}
var containers := {}
## id -> {"items": Dictionary, "node": Node3D}
var drops := {}
var _next_drop := 0
var _bag_mesh: Mesh
var _bag_mat: Material


func register(id: String, kind: String, lid: Node3D = null) -> void:
	containers[id] = {"kind": kind, "opened": false, "lid": lid}


func is_opened(id: String) -> bool:
	return containers.has(id) and containers[id].opened


## Text for the on-screen prompt, e.g. "[E] Search trunk".
func prompt(id: String) -> String:
	if drops.has(id):
		return "[E] Pick up bag (%s)" % _describe(drops[id].items)
	if not containers.has(id):
		return ""
	var c: Dictionary = containers[id]
	var name: String = Items.CONTAINER_NAMES[c.kind]
	if c.opened:
		return "%s (empty)" % name.capitalize()
	return "[E] Search %s" % name


## Opens a container and returns its loot ({} if it was already searched).
func open(id: String) -> Dictionary:
	if not containers.has(id) or containers[id].opened:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [world_seed, id])
	var got := Items.roll(containers[id].kind, rng)
	_mark_opened(id)
	return got


func _mark_opened(id: String) -> void:
	var c: Dictionary = containers[id]
	c.opened = true
	var lid: Node3D = c.lid
	if lid:
		# Lid knocked off and lying next to the crate.
		lid.position += Vector3(0.55, -0.35, 0.2)
		lid.rotation = Vector3(0.3, 0.6, 1.2)


# --- Dropped bags --------------------------------------------------------------

## Puts a bag holding items on the ground at pos. Returns its id.
func spawn_drop(items: Dictionary, pos: Vector3, id := "") -> String:
	if id == "":
		id = "drop_%d" % _next_drop
	_next_drop = maxi(_next_drop, int(id.trim_prefix("drop_")) + 1)
	if _bag_mesh == null:
		var s := SphereMesh.new()
		s.radial_segments = 6
		s.rings = 3
		_bag_mesh = LowPoly.flat(s)
		_bag_mat = LowPoly.material(Color(0.55, 0.47, 0.32))
	var body := Node3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = _bag_mesh
	mi.material_override = _bag_mat
	mi.scale = Vector3(0.5, 0.4, 0.45)
	mi.position.y = 0.16
	body.add_child(mi)
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.set_meta("interact_id", id)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.7, 0.8)
	col.shape = shape
	col.position.y = 0.3
	area.add_child(col)
	body.add_child(area)
	add_child(body)
	drops[id] = {"items": items.duplicate(), "node": body}
	return id


## Sets what is left in a bag; an empty bag disappears.
func set_drop_items(id: String, items: Dictionary) -> void:
	if not drops.has(id):
		return
	if items.is_empty():
		drops[id].node.queue_free()
		drops.erase(id)
	else:
		drops[id].items = items.duplicate()


func _describe(items: Dictionary) -> String:
	var parts: Array = []
	for item in items:
		parts.append("%d %s" % [items[item], Items.display_name(item)])
	return ", ".join(parts)


func save_data() -> Dictionary:
	var opened: Array = []
	for id in containers:
		if containers[id].opened:
			opened.append(id)
	var bags: Array = []
	for id in drops:
		var p: Vector3 = drops[id].node.position
		bags.append({"id": id, "pos": [p.x, p.y, p.z], "items": drops[id].items})
	return {"opened": opened, "drops": bags}


func load_data(data: Dictionary) -> void:
	for id in data.get("opened", []):
		if containers.has(id) and not containers[id].opened:
			_mark_opened(id)
	for id in drops.keys():
		set_drop_items(id, {})
	for b in data.get("drops", []):
		var items := {}
		for item in b.get("items", {}):
			if Items.ITEMS.has(item):
				items[item] = int(b.items[item])
		var pos: Array = b.get("pos", [0, 0, 0])
		if not items.is_empty():
			spawn_drop(items, Vector3(pos[0], pos[1], pos[2]), str(b.get("id", "")))

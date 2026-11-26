extends Node3D
## Build mode (B): a see-through preview of the selected piece snaps to the
## grid where you look. Green means it can be built, red means it can't.
## Left click builds (costs materials), right click takes a piece down
## (full refund for now), R turns the piece, the wheel or 1–8 picks a piece.
## Aiming higher up a wall or at an upper floor builds on the next level.

const Building = preload("res://scripts/building.gd")
const Items = preload("res://scripts/items.gd")

var building: Building
var inventory  # Inventory
var player  # Player
var active := false
var type_index := 0
var dir := 0
## What the preview shows right now.
var slot := {}
var base_y := 0.0
var can_build := false
var reason := ""
var looking_at_piece := ""

var _ghost: Node3D
var _ghost_type := ""
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D


func _ready() -> void:
	_ok_mat = _ghost_mat(Color(0.3, 1.0, 0.35, 0.38))
	_bad_mat = _ghost_mat(Color(1.0, 0.25, 0.2, 0.38))
	_ghost = Node3D.new()
	_ghost.visible = false
	add_child(_ghost)


func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	return m


func current_type() -> String:
	return Building.ORDER[type_index]


func toggle() -> void:
	active = not active
	_ghost.visible = false


func select(i: int) -> void:
	if i >= 0 and i < Building.ORDER.size():
		type_index = i


func cycle(step: int) -> void:
	type_index = posmod(type_index + step, Building.ORDER.size())


func rotate_piece() -> void:
	dir = (dir + 1) % 4


func _process(_d: float) -> void:
	if not active:
		return
	update_preview()


## Works out the slot under the crosshair and whether the piece fits there.
func update_preview() -> void:
	var type := current_type()
	if _ghost_type != type:
		_rebuild_ghost(type)
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * Building.REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	looking_at_piece = ""
	if hit.is_empty():
		_ghost.visible = false
		can_build = false
		reason = "Look at the ground nearby"
		slot = {}
		return
	if hit.collider.has_meta("piece_key"):
		looking_at_piece = hit.collider.get_meta("piece_key")
	# Nudge the point back towards the camera so aiming at a wall face picks this side.
	var p: Vector3 = hit.position + hit.normal * 0.05
	slot = Building.slot_for(type, p, dir)
	slot.level = building.level_for(type, slot, p.y)
	var ev := building.evaluate(type, slot)
	base_y = ev.y
	reason = ev.reason
	can_build = ev.ok
	if can_build and (not building.space_free(type, slot, base_y) or building.blocks_person(type, slot, base_y, player.global_position)):
		can_build = false
		reason = "Something is in the way"
	if can_build and not has_materials(type):
		can_build = false
		reason = "Not enough materials"
	_ghost.transform = Building.piece_transform(type, slot, base_y)
	_ghost.visible = true
	for mi in _ghost.get_children():
		mi.material_override = _ok_mat if can_build else _bad_mat


func _rebuild_ghost(type: String) -> void:
	_ghost_type = type
	for c in _ghost.get_children():
		c.queue_free()
	for b in Building.piece_boxes(type):
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = b[0] + Vector3(0.02, 0.02, 0.02)
		mi.mesh = mesh
		mi.position = b[1]
		if b.size() > 3:
			mi.rotation.x = b[3]
		if b.size() > 4:
			mi.position += Basis(Vector3.RIGHT, b[3]) * b[4]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost.add_child(mi)


func has_materials(type: String) -> bool:
	var cost: Dictionary = Building.PIECES[type].cost
	for item in cost:
		if inventory.count_of(item) < cost[item]:
			return false
	return true


## Builds the previewed piece. Returns true on success.
func try_place() -> bool:
	if not active or slot.is_empty() or not can_build:
		return false
	var type := current_type()
	var cost: Dictionary = Building.PIECES[type].cost
	for item in cost:
		inventory.remove(item, cost[item])
	building.place(type, slot, base_y)
	return true


## Takes down the piece under the crosshair and refunds it. Returns its type or "".
func try_remove() -> String:
	if not active or looking_at_piece == "":
		return ""
	var type := building.remove(looking_at_piece)
	if type != "":
		var left: Dictionary = inventory.add_all(Building.PIECES[type].cost)
		if not left.is_empty():
			# Pockets full: nothing is lost, it goes into a bag.
			get_parent().loot.spawn_drop(left, player.global_position)
	looking_at_piece = ""
	return type


## One line for the HUD.
func status_text() -> String:
	var type := current_type()
	var info: Dictionary = Building.PIECES[type]
	var parts: Array = []
	for item in info.cost:
		parts.append("%d %s (%d)" % [info.cost[item], Items.display_name(item).to_lower(), inventory.count_of(item)])
	var line := "BUILD: %s   %s" % [info.name, ", ".join(parts)]
	if not can_build and reason != "":
		line += "\n" + reason
	return line

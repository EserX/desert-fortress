extends Area3D
## A searchable spot (glovebox, trunk, crate). The player's interaction ray
## finds it on collision layer 2. Contents are rolled when it is opened.

const Items = preload("res://scripts/items.gd")
const LAYER := 2

var container_id := ""        # stable id for saving, e.g. "wreck3_trunk"
var kind := "crate"           # loot table name in items.gd
var label := "crate"          # shown in the prompt: "[E] Search <label>"
var search_time := 1.0        # seconds of rummaging
var opened := false
var lid: Node3D               # optional part that swings open
var lid_open_rotation := Vector3.ZERO


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


## Adds a box-shaped hit area (local to this node).
func add_box(size: Vector3, pos := Vector3.ZERO) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	add_child(col)


## Marks it searched and returns the loot. `world_seed` makes loot per world.
func open(world_seed: int, animate := true) -> Dictionary:
	if opened:
		return {}
	opened = true
	_show_open(animate)
	return Items.roll(kind, hash("%d:%s" % [world_seed, container_id]))


## Restores the opened look without giving loot (used when loading a save).
func set_opened() -> void:
	opened = true
	_show_open(false)


func _show_open(animate: bool) -> void:
	if lid == null:
		return
	if animate and is_inside_tree():
		create_tween().tween_property(lid, "rotation", lid_open_rotation, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lid.rotation = lid_open_rotation

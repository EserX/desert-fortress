extends Node
## Looks where the player is looking (a short ray from the camera) for
## something to use. Press E on a container to search it: a short rummage,
## then its loot goes into the inventory. Walking off or looking away cancels.

const LootContainer = preload("res://scripts/loot_container.gd")

signal focus_changed(target: Node)
signal search_progress(fraction: float)
signal looted(target: Node, loot: Dictionary)

const REACH := 2.6

var player  # Player
var inventory  # Inventory
var world_seed := 0
var focus: Node = null       # container under the crosshair, or null
var searching: Node = null   # container being searched
var search_elapsed := 0.0


func _physics_process(_delta: float) -> void:
	var hit := _ray_target()
	if hit != focus:
		focus = hit
		focus_changed.emit(focus)


func _process(delta: float) -> void:
	if searching == null:
		return
	if focus != searching or get_tree().paused:
		cancel_search()
		return
	search_elapsed += delta
	search_progress.emit(clampf(search_elapsed / searching.search_time, 0.0, 1.0))
	if search_elapsed >= searching.search_time:
		_finish_search()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not get_tree().paused:
		start_search()


## Starts searching whatever is in focus. Returns false if there is nothing to search.
func start_search() -> bool:
	if focus == null or focus.opened or searching != null:
		return false
	searching = focus
	search_elapsed = 0.0
	search_progress.emit(0.0)
	return true


func cancel_search() -> void:
	searching = null
	search_elapsed = 0.0
	search_progress.emit(-1.0)


func _finish_search() -> void:
	var target := searching
	searching = null
	search_elapsed = 0.0
	search_progress.emit(-1.0)
	var loot: Dictionary = target.open(world_seed)
	for id in loot:
		inventory.add(id, loot[id])
	looted.emit(target, loot)
	focus_changed.emit(focus)  # prompt now says "empty"


func _ray_target() -> Node:
	if player == null or not player.is_inside_tree():
		return null
	var cam: Camera3D = player.camera
	var from: Vector3 = cam.global_position
	var to := from - cam.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | LootContainer.LAYER, [player.get_rid()])
	q.collide_with_areas = true
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(q)
	if hit and hit.collider is LootContainer:
		return hit.collider
	return null

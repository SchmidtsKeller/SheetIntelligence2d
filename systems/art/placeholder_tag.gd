class_name PlaceholderTag
extends Node2D
## Says "Placeholder" on a thing in the world whose art is still a stand-in
## (#69). It is a child of what it marks, so it moves, fades and hides with
## it: an entity the vision system hides takes its tag along (no tell, GDD
## §3.2). The word stays upright and keeps its size however its host turns or
## is scaled.
##
## Most tags are added by [PlaceholderWatcher]; an entity built of several
## placeholder layers (the sheep) tags the node above them itself, once.

const NODE_NAME: StringName = &"PlaceholderTag"
const FONT_SIZE: int = 12
## A host larger than this is tagged once per tile of this size.
const TILE: float = 512.0

## Where the host's art is, in the host's coordinates. Empty: at its origin.
var area: Rect2 = Rect2()


func _init(tag_area: Rect2 = Rect2()) -> void:
	name = NODE_NAME
	area = tag_area
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


## Tags [param host], whose art covers [param host_area]. Returns the tag; a
## host that has one already keeps it.
static func attach(host: Node2D, host_area: Rect2 = Rect2()) -> PlaceholderTag:
	var existing: PlaceholderTag = of(host)
	if existing != null:
		return existing
	var tag: PlaceholderTag = PlaceholderTag.new(host_area)
	host.add_child(tag)
	return tag


## The tag of [param host], or [code]null[/code].
static func of(host: Node) -> PlaceholderTag:
	return host.get_node_or_null(NodePath(NODE_NAME)) as PlaceholderTag


## Whether [param node] or one of its ancestors is tagged already.
static func is_covered(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if of(current) != null:
			return true
		current = current.get_parent()
	return false


## Where the word is drawn, in the host's coordinates: the middle of the
## area, or one point per tile of a large area.
func get_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	if not area.has_area():
		centers.append(area.position)
		return centers
	var columns: int = maxi(floori(area.size.x / TILE), 1)
	var rows: int = maxi(floori(area.size.y / TILE), 1)
	var step: Vector2 = area.size / Vector2(columns, rows)
	for row: int in rows:
		for column: int in columns:
			centers.append(area.position + step * Vector2(column + 0.5, row + 0.5))
	return centers


func _draw() -> void:
	var host_scale: Vector2 = global_transform.get_scale().abs()
	var upright_scale: Vector2 = Vector2(
		1.0 / maxf(host_scale.x, 0.001), 1.0 / maxf(host_scale.y, 0.001)
	)
	for center: Vector2 in get_centers():
		draw_set_transform(center, -global_rotation, upright_scale)
		PlaceholderArt.draw_word(get_canvas_item(), Vector2.ZERO, FONT_SIZE)
	draw_set_transform(Vector2.ZERO)

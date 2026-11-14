class_name ArenaDebugOverlay
extends Node2D
## Draws what the arena is made of: the play area, the borders, every obstacle
## footprint (movement and sight), every light occluder and the spawn areas.
## Toggled through [member Arena.debug_overlay_visible].

const FOOTPRINT_COLOR: Color = Color(0.9, 0.2, 0.2, 0.35)
const OCCLUDER_COLOR: Color = Color(1.0, 0.85, 0.2)
const BORDER_COLOR: Color = Color(0.2, 0.4, 1.0, 0.35)
const PLAY_AREA_COLOR: Color = Color(1.0, 1.0, 1.0)
const SHEEPHERDER_SPAWN_COLOR: Color = Color(0.2, 0.9, 1.0)
const FLOCK_SPAWN_COLOR: Color = Color(1.0, 0.3, 0.9)
## A negative width draws lines one pixel wide at any zoom, so they stay
## visible when the whole arena is on screen.
const OUTLINE_WIDTH: float = -1.0

## The arena to show.
var arena: Arena:
	set(value):
		arena = value
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if arena == null:
		return
	var to_local: Transform2D = get_global_transform().affine_inverse()
	for band: Rect2 in _border_bands(arena.get_bounds(), arena.get_play_area()):
		draw_rect(to_local * band, BORDER_COLOR)
	draw_rect(to_local * arena.get_play_area(), PLAY_AREA_COLOR, false, OUTLINE_WIDTH)
	for obstacle: ArenaObstacle in arena.get_obstacles():
		draw_colored_polygon(to_local * obstacle.get_world_footprint(), FOOTPRINT_COLOR)
		var occluder: LightOccluder2D = obstacle.get_occluder()
		if occluder != null:
			var outline: PackedVector2Array = occluder.global_transform * occluder.occluder.polygon
			outline.append(outline[0])
			draw_polyline(to_local * outline, OCCLUDER_COLOR, OUTLINE_WIDTH)
	var herder_area: Rect2 = to_local * arena.get_sheepherder_spawn_area()
	draw_rect(herder_area, SHEEPHERDER_SPAWN_COLOR, false, OUTLINE_WIDTH)
	draw_rect(to_local * arena.get_flock_spawn_area(), FLOCK_SPAWN_COLOR, false, OUTLINE_WIDTH)


## The parts of [param bounds] outside [param inner], as up to four rectangles.
static func _border_bands(bounds: Rect2, inner: Rect2) -> Array[Rect2]:
	return [
		Rect2(bounds.position, Vector2(bounds.size.x, inner.position.y - bounds.position.y)),
		Rect2(
			Vector2(bounds.position.x, inner.end.y),
			Vector2(bounds.size.x, bounds.end.y - inner.end.y)
		),
		Rect2(
			Vector2(bounds.position.x, inner.position.y),
			Vector2(inner.position.x - bounds.position.x, inner.size.y)
		),
		Rect2(
			Vector2(inner.end.x, inner.position.y),
			Vector2(bounds.end.x - inner.end.x, inner.size.y)
		),
	]

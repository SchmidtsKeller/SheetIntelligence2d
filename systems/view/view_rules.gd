@abstract
class_name ViewRules
extends RefCounted
## The view-fairness rule: how much of the world a player may see.
##
## The project stretches with aspect [code]expand[/code], so the UI can use the
## whole screen on any device. Without a rule, a wider screen would simply show
## more of the world, which matters because the Monster sees everything in
## view. Every gameplay camera therefore zooms so that the visible world never
## exceeds [method GameConfig.get_view_max_world_size] on either axis: a 16:9
## screen sees exactly that area, any other shape sees less along one axis and
## never more.


## The camera zoom for a viewport of [param viewport_size] (in canvas units)
## so that the visible world fits inside [param max_world_size].
static func camera_zoom(viewport_size: Vector2, max_world_size: Vector2) -> float:
	if max_world_size.x <= 0.0 or max_world_size.y <= 0.0:
		push_error("ViewRules: the maximum world view must be positive, got %s." % max_world_size)
		return 1.0
	return maxf(viewport_size.x / max_world_size.x, viewport_size.y / max_world_size.y)


## The world area visible in a viewport of [param viewport_size] under the rule.
static func visible_world_size(viewport_size: Vector2, max_world_size: Vector2) -> Vector2:
	return viewport_size / camera_zoom(viewport_size, max_world_size)

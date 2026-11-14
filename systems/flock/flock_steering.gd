@abstract class_name FlockSteering
extends RefCounted
## The steering forces of the flock (boids): keep apart, stay together, head
## the same way, and keep clear of obstacles and borders.
##
## Each function returns a push as a vector; the agent adds them up. All of
## them are pure functions of positions, so they can be tested without a
## scene.


## Away from neighbours that are closer than [param radius]. The closer a
## neighbour, the stronger the push; at touching distance it is 1 per
## neighbour.
static func separation(position: Vector2, neighbours: PackedVector2Array, radius: float) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for neighbour: Vector2 in neighbours:
		var away: Vector2 = position - neighbour
		var distance: float = away.length()
		if distance >= radius:
			continue
		if distance < 0.001:
			# Exactly on top of each other: any direction will do, as long as
			# the two do not pick the same one.
			away = Vector2.from_angle(position.x * 12.9898 + position.y * 78.233)
			distance = 0.001
		push += away / distance * (1.0 - distance / radius)
	return push


## Toward the center of the flock, once the sheep is farther from it than
## [param radius]. Grows from 0 at the radius to 1 at twice the radius.
static func cohesion(position: Vector2, center: Vector2, radius: float) -> Vector2:
	var to_center: Vector2 = center - position
	var distance: float = to_center.length()
	if distance <= radius or radius <= 0.0:
		return Vector2.ZERO
	return to_center / distance * clampf((distance - radius) / radius, 0.0, 1.0)


## Away from every obstacle footprint that is closer than [param margin].
## [param footprints] are convex polygons in world coordinates.
static func obstacle_avoidance(
	position: Vector2, footprints: Array[PackedVector2Array], margin: float
) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for footprint: PackedVector2Array in footprints:
		var nearest: Vector2 = nearest_point_on_outline(position, footprint)
		var away: Vector2 = position - nearest
		var distance: float = away.length()
		if Geometry2D.is_point_in_polygon(position, footprint):
			# Inside (it should never get there): straight out through the
			# nearest edge, at full strength.
			push += (nearest - position).normalized() if distance > 0.001 else Vector2.UP
		elif distance < margin and distance > 0.001:
			push += away / distance * (1.0 - distance / margin)
	return push


## Back into [param area] when closer than [param margin] to one of its edges.
static func border_avoidance(position: Vector2, area: Rect2, margin: float) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	push.x += _edge_push(position.x - area.position.x, margin)
	push.x -= _edge_push(area.end.x - position.x, margin)
	push.y += _edge_push(position.y - area.position.y, margin)
	push.y -= _edge_push(area.end.y - position.y, margin)
	return push


## The point on the outline of [param polygon] that is closest to [param point].
static func nearest_point_on_outline(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	var nearest: Vector2 = polygon[0]
	var nearest_distance: float = INF
	for index: int in polygon.size():
		var candidate: Vector2 = Geometry2D.get_closest_point_to_segment(
			point, polygon[index], polygon[(index + 1) % polygon.size()]
		)
		var distance: float = point.distance_squared_to(candidate)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


## How hard an edge pushes at [param distance] from it: 0 at the margin, 1 at
## the edge, more beyond it.
static func _edge_push(distance: float, margin: float) -> float:
	if distance >= margin or margin <= 0.0:
		return 0.0
	return 1.0 - distance / margin

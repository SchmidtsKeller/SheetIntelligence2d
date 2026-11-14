@abstract class_name WorldQueries
extends RefCounted
## Line of sight and raycasts against the solid world: obstacles and the arena's
## borders (GDD §6).
##
## Everything that must agree on what blocks sight and bullets uses these: the
## flashlight cone, the Monster's view, the Shepherd Dog and the firearm.
## Characters, sheep and companions never block sight. Pass the [World2D] of
## any node in the world, e.g. [code]get_world_2d()[/code].


## Whether nothing solid lies between [param from] and [param to].
static func has_line_of_sight(world: World2D, from: Vector2, to: Vector2) -> bool:
	return _first_hit(world, from, to) == null


## The first solid thing along [param direction] from [param origin], at most
## [param max_distance] away, or [code]null[/code] if there is none.
static func raycast(
	world: World2D, origin: Vector2, direction: Vector2, max_distance: float
) -> WorldHit:
	return _first_hit(world, origin, origin + direction.normalized() * max_distance)


static func _first_hit(world: World2D, from: Vector2, to: Vector2) -> WorldHit:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		from, to, PhysicsLayers.WORLD
	)
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return WorldHit.new(result["position"], result["normal"], result["collider"])

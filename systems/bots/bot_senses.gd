class_name BotSenses
extends RefCounted
## What a bot may know about the round: only what its player could see or hear.
##
## The Sheepherder sees what their flashlight lights (GDD §3.1), decided the
## same way as the [VisionSystem] decides it for a player. Neither bot ever
## asks which sheep is the Monster.


## Whether [param point] is in the light of [param herder]: inside the cone and
## not in the shadow of an obstacle. Nothing is lit by a dead Sheepherder.
static func is_lit(herder: Sheepherder, point: Vector2) -> bool:
	if not is_instance_valid(herder) or not herder.is_alive() or not herder.is_inside_tree():
		return false
	var cone: FlashlightCone = herder.get_flashlight_cone()
	if not cone.contains(point):
		return false
	return WorldQueries.has_line_of_sight(herder.get_world_2d(), cone.origin, point)


## Whether [param herder] sees [param body]: some part of it is lit, and it is
## not cloaked. Like the vision system, this looks at where the body is drawn.
static func herder_sees(herder: Sheepherder, body: Node2D) -> bool:
	var target: VisionTarget = body.get_node_or_null(^"VisionTarget") as VisionTarget
	if target == null:
		return is_lit(herder, body.global_position)
	if target.cloaked:
		return false
	for point: Vector2 in target.get_sample_points():
		if is_lit(herder, point):
			return true
	return false


## Every living sheep-like body in [param tree]: the flock and the Monster's
## disguise, which look alike.
static func living_sheep_like(tree: SceneTree) -> Array[SheepBody]:
	var bodies: Array[SheepBody] = []
	for node: Node in tree.get_nodes_in_group(Groups.SHEEP_LIKE):
		var body: SheepBody = node as SheepBody
		if body != null and body.is_alive() and body.is_inside_tree():
			bodies.append(body)
	return bodies

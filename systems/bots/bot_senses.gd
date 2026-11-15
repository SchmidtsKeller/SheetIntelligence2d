class_name BotSenses
extends RefCounted
## What a bot may know about the round: only what its player could see or hear.
##
## The Sheepherder sees what light falls on, their flashlight's or a lit
## torch's (GDD §3.1), by the same [LightRules] the [VisionSystem] uses for a
## player. Neither bot ever asks which sheep is the Monster.


## The light level at [param point] as [param herder] sees it: their flashlight
## and the lit torches, not through obstacles. A dead Sheepherder sees nothing.
static func light_level(herder: Sheepherder, point: Vector2) -> float:
	if not is_instance_valid(herder) or not herder.is_alive() or not herder.is_inside_tree():
		return 0.0
	return LightRules.level_at(
		herder.get_world_2d(),
		point,
		herder.get_flashlight_cone(),
		LightRules.lit_torches(herder.get_tree())
	)


## Whether [param point] is lit enough for [param herder] to see what is there.
static func is_lit(herder: Sheepherder, point: Vector2) -> bool:
	return light_level(herder, point) >= LightRules.SEEN_LEVEL


## Whether [param herder] sees [param body]: some part of it is lit enough, and
## it is not cloaked. Like the vision system, this looks at where the body is
## drawn.
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

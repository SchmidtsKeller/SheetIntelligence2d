class_name LightRules
extends RefCounted
## How much light falls on a point of the world (GDD §3.1): the one rule for
## what the Sheepherder sees, used by the [VisionSystem] for the player and by
## [BotSenses] for the bots, and the shape the lights are drawn with.
##
## A light level runs from 0 (dark) to 1 (fully lit). It is the brightest of
## the lights that reach the point with a free line of sight:
## [br]- the flashlight: fully lit inside its cone, fading out beyond the cone's
## end (over [code]flashlight_fade_length_share[/code] of its length) and beside
## it (over [code]flashlight_fade_angle_deg[/code] on each side);
## [br]- every lit [Torch]: fully lit within [code]torch_light_radius[/code],
## fading out over [code]torch_fade_length[/code] beyond.
## [br]The fades are smooth, so the light ends softly instead of at an edge.
##
## Light depends on the position only, never on what stands there: an NPC
## sheep and the Monster in the same place are lit alike.

## A target counts as seen when it is at least this much lit: shown at least
## half (see [constant VisionTarget.SEEN_SHOWN]).
const SEEN_LEVEL: float = VisionTarget.SEEN_SHOWN


## The light level at [param point]: the brightest of the flashlight
## [param cone] (may be [code]null[/code]) and the lit [param torches], each
## only where no obstacle of [param world] stands in between.
static func level_at(
	world: World2D, point: Vector2, cone: FlashlightCone, torches: Array[Torch]
) -> float:
	var best: float = 0.0
	if cone != null:
		var level: float = flashlight_level(cone, point)
		if level > best and WorldQueries.has_line_of_sight(world, cone.origin, point):
			best = level
	for torch: Torch in torches:
		if best >= 1.0:
			break
		var level: float = torch_level(torch.global_position, point)
		if level > best and WorldQueries.has_line_of_sight(world, torch.global_position, point):
			best = level
	return best


## The flashlight's light at [param point], obstacles not considered.
static func flashlight_level(cone: FlashlightCone, point: Vector2) -> float:
	var perks: PerkService = Services.perks
	var offset: Vector2 = (point - cone.origin).rotated(-cone.direction.angle())
	return cone_falloff(
		offset,
		deg_to_rad(cone.angle_deg) / 2.0,
		cone.length,
		perks.get_stat(StatIds.FLASHLIGHT_FADE_LENGTH_SHARE),
		deg_to_rad(perks.get_stat(StatIds.FLASHLIGHT_FADE_ANGLE_DEG))
	)


## A lit torch's light at [param point] when the torch stands at
## [param torch_position], obstacles not considered.
static func torch_level(torch_position: Vector2, point: Vector2) -> float:
	var perks: PerkService = Services.perks
	return fade(
		torch_position.distance_to(point),
		perks.get_stat(StatIds.TORCH_LIGHT_RADIUS),
		perks.get_stat(StatIds.TORCH_FADE_LENGTH)
	)


## The farthest a lit torch's light reaches.
static func torch_reach() -> float:
	var perks: PerkService = Services.perks
	return perks.get_stat(StatIds.TORCH_LIGHT_RADIUS) + perks.get_stat(StatIds.TORCH_FADE_LENGTH)


## The light of a cone pointing along +x from the origin, at [param offset]:
## [param half_angle] and [param length] are fully lit; the light fades out
## over [param fade_share] of the length beyond its end and over
## [param fade_angle] beside it (angles in radians).
static func cone_falloff(
	offset: Vector2, half_angle: float, length: float, fade_share: float, fade_angle: float
) -> float:
	var radial: float = fade(offset.length(), length, length * fade_share)
	if radial <= 0.0 or offset.is_zero_approx():
		return radial
	# angle() is the signed angle to +x, so directions around ±180° work.
	return radial * fade(absf(offset.angle()), half_angle, fade_angle)


## 1 up to [param full], falling smoothly to 0 over [param fade_width] beyond.
static func fade(value: float, full: float, fade_width: float) -> float:
	if value <= full:
		return 1.0
	if value >= full + fade_width:
		return 0.0
	return 1.0 - smoothstep(full, full + fade_width, value)


## The lit torches in [param tree].
static func lit_torches(tree: SceneTree) -> Array[Torch]:
	var torches: Array[Torch] = []
	if tree == null:
		return torches
	for node: Node in tree.get_nodes_in_group(Groups.TORCHES):
		var torch: Torch = node as Torch
		if torch != null and torch.is_lit() and torch.is_inside_tree():
			torches.append(torch)
	return torches

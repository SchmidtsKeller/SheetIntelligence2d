class_name BloodShape
extends RefCounted
## The shape of a blood mark on the ground (#91): an irregular pool, a few
## droplets and splatter around it, generated from a seed instead of an image.
##
## The seed comes from the mark's position ([method for_position]), so both
## devices show the same mark, and every mark looks different. Only numbers
## are generated here, with [SeededRandom] in integer arithmetic; the
## [code]blood.gdshader[/code] of [BloodDecal] draws them.
##
## The shape is a set of [i]elements[/i], each a stroke from [code]a[/code]
## to [code]b[/code] whose radius runs from one end's to the other's; a round
## blob has [code]a == b[/code]. Their soft fields add up, so overlapping
## blobs flow into one pool, and the sum is how thick the blood is there.

## Most elements a shape has; the shader's arrays hold this many.
const MAX_ELEMENTS: int = 16
## How far an element's field reaches, in its radius: the shader's
## [code]FIELD_REACH[/code]. The blood ends at about one radius.
const FIELD_REACH: float = 1.7
## How far the shader shifts the outline to make it irregular, in pixels: its
## [code]warp_amount[/code] plus [code]edge_roughness[/code].
const OUTLINE_WARP: float = 3.0
## Radius of the pool's central blob, in pixels.
const CORE_RADIUS_MIN: float = 7.5
const CORE_RADIUS_MAX: float = 10.0
## Lobes around the core that make the pool irregular.
const LOBES_MIN: int = 3
const LOBES_MAX: int = 6
## Droplets flung away from the pool, mostly towards the side it was hit from.
const DROPLETS_MIN: int = 4
const DROPLETS_MAX: int = 6
## Elongated splatter, thin where it leaves the pool and round where it lands.
const STREAKS_MIN: int = 1
const STREAKS_MAX: int = 3

## The turn of the whole mark, in radians.
var rotation: float = 0.0
## Per element: its ends [code](a.x, a.y, b.x, b.y)[/code], in pixels around
## the center.
var segments: PackedVector4Array = PackedVector4Array()
## Per element: the radius at [code]a[/code] and at [code]b[/code], and how
## thick the blood is at most there (1 for the pool, less for droplets).
var params: PackedVector4Array = PackedVector4Array()
## Where the shader's noise is read for this mark, so the outline, the thick
## and thin parts and the clotting differ from mark to mark.
var noise_offset: Vector2 = Vector2.ZERO
## Half the side of a square around the center that holds the whole mark.
var extent: float = 0.0


## The mark left at [param at]. The same position always gives the same mark.
static func for_position(at: Vector2) -> BloodShape:
	return generate(seed_for(at))


## The seed of the mark at [param at]: whole pixels only, so both devices agree
## even if the position differs in the last bits.
static func seed_for(at: Vector2) -> int:
	return roundi(at.x) * 7919 + roundi(at.y)


## The mark of [param initial_seed].
static func generate(initial_seed: int) -> BloodShape:
	var random: SeededRandom = SeededRandom.new(initial_seed)
	var shape: BloodShape = BloodShape.new()
	shape.rotation = deg_to_rad(random.next_int(360))
	shape.noise_offset = Vector2(_between(random, 0.0, 97.0), _between(random, 0.0, 97.0))

	# The pool: a core and lobes that flow into it. It runs out a little
	# towards the side the blood was flung to, which is +x before the turn.
	var core: float = _between(random, CORE_RADIUS_MIN, CORE_RADIUS_MAX)
	var flow: Vector2 = Vector2(_between(random, 2.0, 6.0), 0.0)
	shape._add(Vector2.ZERO, flow, core, core * _between(random, 0.75, 0.95), 1.0)
	var lobes: int = random.next_int_range(LOBES_MIN, LOBES_MAX)
	for index: int in lobes:
		var angle: float = TAU * (index + _between(random, -0.3, 0.3)) / lobes
		var distance: float = core * _between(random, 0.6, 1.1)
		var radius: float = core * _between(random, 0.4, 0.75)
		var at: Vector2 = Vector2.from_angle(angle) * distance
		shape._add(at, at, radius, radius, _between(random, 0.75, 1.0))

	# Droplets, most of them on the side the blood was flung to.
	for _droplet: int in random.next_int_range(DROPLETS_MIN, DROPLETS_MAX):
		var spread: float = 1.2 if random.next_int(4) > 0 else PI
		var angle: float = _between(random, -spread, spread)
		var distance: float = core * _between(random, 1.5, 2.6)
		var radius: float = _between(random, 1.0, 2.3)
		var at: Vector2 = Vector2.from_angle(angle) * distance
		shape._add(at, at, radius, radius, _between(random, 0.55, 0.8))

	# Splatter: a thin streak leaving the pool that ends in a drop.
	for _streak: int in random.next_int_range(STREAKS_MIN, STREAKS_MAX):
		var direction: Vector2 = Vector2.from_angle(_between(random, -0.9, 0.9))
		var start: Vector2 = direction * core * _between(random, 1.0, 1.3)
		var end: Vector2 = direction * core * _between(random, 1.7, 2.3)
		var drop: float = _between(random, 1.3, 2.2)
		shape._add(start, end, drop * 0.45, drop, _between(random, 0.55, 0.75))

	for index: int in shape.segments.size():
		var segment: Vector4 = shape.segments[index]
		var reach: float = maxf(shape.params[index].x, shape.params[index].y) * FIELD_REACH
		var a: Vector2 = Vector2(segment.x, segment.y)
		var b: Vector2 = Vector2(segment.z, segment.w)
		var far: float = maxf(a.length(), b.length())
		shape.extent = maxf(shape.extent, far + reach + OUTLINE_WARP)
	shape.extent = ceilf(shape.extent)
	return shape


## Whether [param other] is the same mark.
func equals(other: BloodShape) -> bool:
	return (
		other != null
		and rotation == other.rotation
		and noise_offset == other.noise_offset
		and segments == other.segments
		and params == other.params
	)


## How many elements the shape has.
func size() -> int:
	return segments.size()


func _add(a: Vector2, b: Vector2, radius_a: float, radius_b: float, thickness: float) -> void:
	if segments.size() >= MAX_ELEMENTS:
		return
	segments.append(Vector4(a.x, a.y, b.x, b.y))
	params.append(Vector4(radius_a, radius_b, thickness, 0.0))


## A number from [param from] to [param to], in steps of a thousandth.
static func _between(random: SeededRandom, from: float, to: float) -> float:
	return from + (to - from) * random.next_int(1001) / 1000.0

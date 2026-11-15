class_name FlashlightLight
extends PointLight2D
## The light of the Sheepherder's flashlight: a cone whose light fades out
## softly beyond its end and beside it, with shadows behind the obstacles'
## occluders (GDD §3.1).
##
## It is drawn with the falloff of [LightRules], from the effective cone angle
## and length of the stat lookup, so perks and the bat change the light as
## well as the visibility, and what looks lit is what counts as lit. It shines
## on every device: the Monster sees it too.
##
## Presentation only, never part of the rules: the light sways by about a
## degree and breathes slightly while the Sheepherder walks, and dust drifts
## in the beam.

## Pixels of the generated cone texture; the light is scaled up from it.
const TEXTURE_SIZE: int = 128
## Brightness at the end of the fully lit cone, relative to its start, so the
## light looks brightest near the lamp.
const END_BRIGHTNESS: float = 0.75
## Largest sway while walking at full speed, in degrees. Far smaller than the
## soft edge, so it never shows what the rules would not.
const SWAY_DEG: float = 1.0
## Sway cycles per pixel walked: one step left and right per stride.
const SWAY_PER_PIXEL: float = 0.035
## How much the brightness breathes while walking.
const BREATH_ENERGY: float = 0.04
## Walking speed at which the sway is strongest, in pixels per second.
const FULL_SWAY_SPEED: float = 180.0
## Dust motes in the beam at once.
const DUST_AMOUNT: int = 28
## Points the dust is emitted from, spread over the lit cone.
const DUST_POINTS: int = 48

## Cone textures by opening angle and fade, shared by all flashlights.
static var _textures: Dictionary[String, Texture2D] = {}

var _angle_deg: float = -1.0
var _length: float = -1.0
var _fade_share: float = -1.0
var _fade_angle_deg: float = -1.0
var _base_energy: float = 1.0
var _sway_phase: float = 0.0
var _sway_strength: float = 0.0
var _last_position: Vector2
var _dust: CPUParticles2D


func _ready() -> void:
	shadow_enabled = true
	shadow_filter = Light2D.SHADOW_FILTER_PCF5
	shadow_filter_smooth = 1.5
	_base_energy = energy
	_dust = _build_dust()
	add_child(_dust)
	_last_position = global_position
	refresh()


func _process(delta: float) -> void:
	refresh()
	_sway(delta)


## Takes the current cone angle, length and fade from the stat lookup.
func refresh() -> void:
	var perks: PerkService = Services.perks
	var angle: float = perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG)
	var length: float = perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH)
	var fade_share: float = perks.get_stat(StatIds.FLASHLIGHT_FADE_LENGTH_SHARE)
	var fade_angle: float = perks.get_stat(StatIds.FLASHLIGHT_FADE_ANGLE_DEG)
	if angle != _angle_deg or fade_share != _fade_share or fade_angle != _fade_angle_deg:
		_angle_deg = angle
		_fade_share = fade_share
		_fade_angle_deg = fade_angle
		texture = cone_texture(angle, fade_share, fade_angle)
		_length = -1.0
	if length != _length:
		_length = length
		texture_scale = length * (1.0 + fade_share) / (TEXTURE_SIZE / 2.0)
		_dust.emission_points = _dust_points()


## The light's own movement while the Sheepherder walks: a small sway with
## each stride and a slight breathing of the brightness.
func _sway(delta: float) -> void:
	var moved: float = global_position.distance_to(_last_position)
	_last_position = global_position
	var speed: float = moved / maxf(delta, 0.0001)
	var target: float = clampf(speed / FULL_SWAY_SPEED, 0.0, 1.0)
	_sway_strength = move_toward(_sway_strength, target, 4.0 * delta)
	_sway_phase = fmod(_sway_phase + moved * SWAY_PER_PIXEL * TAU, TAU)
	rotation = deg_to_rad(SWAY_DEG) * _sway_strength * sin(_sway_phase)
	energy = _base_energy * (1.0 + BREATH_ENERGY * _sway_strength * sin(2.0 * _sway_phase + 0.8))


func _build_dust() -> CPUParticles2D:
	var dust: CPUParticles2D = CPUParticles2D.new()
	dust.name = "Dust"
	dust.amount = DUST_AMOUNT
	dust.lifetime = 3.5
	dust.preprocess = 3.5
	# The motes stay where they are in the world while the beam moves on; the
	# darkness hides them outside the light.
	dust.local_coords = false
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	dust.direction = Vector2.RIGHT
	dust.spread = 180.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 9.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.8, 0.0))
	ramp.set_color(1, Color(1.0, 0.95, 0.8, 0.0))
	ramp.add_point(0.3, Color(1.0, 0.95, 0.8, 0.35))
	ramp.add_point(0.7, Color(1.0, 0.95, 0.8, 0.3))
	dust.color_ramp = ramp
	return dust


## Points spread evenly over the fully lit cone, in the light's coordinates.
func _dust_points() -> PackedVector2Array:
	var points: PackedVector2Array = []
	var half_angle: float = deg_to_rad(_angle_deg) / 2.0
	var random: SeededRandom = SeededRandom.new(DUST_POINTS)
	for _i: int in DUST_POINTS:
		# The square root spreads the points evenly over the area, not the length.
		var along: float = sqrt(random.next_int_range(4, 100) / 100.0) * _length
		var side: float = (random.next_int_range(-100, 100) / 100.0) * half_angle
		points.append(Vector2.from_angle(side) * along)
	return points


## A cone of [param angle_deg] pointing to +x from the center of a square
## texture, fully lit up to [code]1 / (1 + fade_share)[/code] of the radius and
## fading out like [method LightRules.cone_falloff] up to the edge. Generated
## once per angle and fade.
static func cone_texture(angle_deg: float, fade_share: float, fade_angle_deg: float) -> Texture2D:
	var key: String = "%d/%d/%d" % [
		roundi(angle_deg * 10.0), roundi(fade_share * 1000.0), roundi(fade_angle_deg * 10.0)
	]
	if _textures.has(key):
		return _textures[key]
	var half_angle: float = deg_to_rad(angle_deg) / 2.0
	var fade_angle: float = deg_to_rad(fade_angle_deg)
	var center: Vector2 = Vector2.ONE * (TEXTURE_SIZE / 2.0)
	# The texture's radius is the whole reach; the full cone is 1 / (1 + share).
	var length: float = 1.0 / (1.0 + fade_share)
	var image: Image = Image.create_empty(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y: int in TEXTURE_SIZE:
		for x: int in TEXTURE_SIZE:
			var offset: Vector2 = (Vector2(x + 0.5, y + 0.5) - center) / (TEXTURE_SIZE / 2.0)
			var level: float = LightRules.cone_falloff(
				offset, half_angle, length, fade_share, fade_angle
			)
			var brightness: float = lerpf(1.0, END_BRIGHTNESS, minf(offset.length() / length, 1.0))
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, level * brightness))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture

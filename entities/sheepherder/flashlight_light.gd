class_name FlashlightLight
extends PointLight2D
## The light of the Sheepherder's flashlight: a cone with soft edges whose
## shadows fall behind the obstacles' occluders (GDD §3.1).
##
## It follows the effective cone angle and length from the stat lookup, so
## perks and the bat change the light as well as the visibility. It shines on
## every device: the Monster sees it too.

## Pixels of the generated cone texture; the light is scaled up from it.
const TEXTURE_SIZE: int = 128
## Width of the soft edge at each side of the cone, in degrees at most.
const EDGE_SOFTNESS_DEG: float = 6.0
## Where the light starts to fade toward the end of the cone (share of length).
const FADE_START: float = 0.7

## Cone textures by opening angle, shared by all flashlights.
static var _textures: Dictionary[int, Texture2D] = {}

var _angle_deg: float = -1.0
var _length: float = -1.0


func _ready() -> void:
	shadow_enabled = true
	shadow_filter = Light2D.SHADOW_FILTER_PCF5
	shadow_filter_smooth = 1.5
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Takes the current cone angle and length from the stat lookup.
func refresh() -> void:
	var perks: PerkService = Services.perks
	var angle: float = perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG)
	var length: float = perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH)
	if angle != _angle_deg:
		_angle_deg = angle
		texture = cone_texture(angle)
	if length != _length:
		_length = length
		texture_scale = length / (TEXTURE_SIZE / 2.0)


## A cone of [param angle_deg] pointing to +x from the center of a square
## texture, reaching its edge. Generated once per angle (to a tenth of a degree).
static func cone_texture(angle_deg: float) -> Texture2D:
	var key: int = roundi(angle_deg * 10.0)
	if _textures.has(key):
		return _textures[key]
	var half_angle: float = deg_to_rad(angle_deg) / 2.0
	var softness: float = minf(deg_to_rad(EDGE_SOFTNESS_DEG), half_angle * 0.5)
	var center: Vector2 = Vector2.ONE * (TEXTURE_SIZE / 2.0)
	var radius: float = TEXTURE_SIZE / 2.0
	var image: Image = Image.create_empty(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y: int in TEXTURE_SIZE:
		for x: int in TEXTURE_SIZE:
			var offset: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			var along: float = offset.length() / radius
			var side: float = absf(offset.angle())
			var strength: float = (
				clampf((half_angle - side) / softness, 0.0, 1.0)
				* clampf((1.0 - along) / (1.0 - FADE_START), 0.0, 1.0)
			)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, strength))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture

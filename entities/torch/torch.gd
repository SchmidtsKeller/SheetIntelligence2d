class_name Torch
extends Node2D
## A torch on a post in the arena (#63). The Sheepherder lights it by walking
## up to it: the [Arena] checks on the host and announces it, and both devices
## light it on that word. A lit torch burns for the rest of the round.
##
## Its light falls on everything around it on every device, blocked by the
## obstacles. For the Sheepherder it counts like the flashlight: what it lights
## is seen (see [LightRules]). The torch itself is scenery: it blocks nothing,
## stays faintly visible in the dark and looks the same to both players.
##
## The flicker and the embers are presentation only; the rules use the
## steady radius from the config.

## The torch was lit. Emitted on both devices.
signal lit

## Pixels of the generated light texture; the light is scaled up from it.
const TEXTURE_SIZE: int = 128
const LIGHT_COLOR: Color = Color(1.0, 0.68, 0.38)
const LIGHT_ENERGY: float = 1.05
## How much the flicker changes the brightness and the size of the light.
const FLICKER_ENERGY: float = 0.1
const FLICKER_SCALE: float = 0.015
## Base speed of the flicker, in radians per second.
const FLICKER_SPEED: float = 9.0
## Brightness at the edge of the fully lit circle, relative to the middle, so
## the light looks brightest at the flame.
const EDGE_BRIGHTNESS: float = 0.7
## Height of the flame above the ground, in pixels: the painted ground (#76)
## shows its relief by the angle the light comes from.
const FLAME_HEIGHT: float = 90.0

## Light textures by the share of the fade in the reach, shared by all torches.
static var _textures: Dictionary[int, Texture2D] = {}

var _lit: bool = false
var _time: float = 0.0
var _flicker_phase: float = 0.0
var _light: PointLight2D
var _flame: Node2D
var _embers: CPUParticles2D
var _crackle: int = -1


func _ready() -> void:
	add_to_group(Groups.TORCHES)
	add_to_group(Groups.STATIC_SCENERY)
	# Torches do not flicker in step: the phase comes from where it stands.
	_flicker_phase = fposmod(global_position.x * 0.013 + global_position.y * 0.007, TAU)
	_light = PointLight2D.new()
	_light.name = "Light"
	_light.color = LIGHT_COLOR
	_light.height = FLAME_HEIGHT
	_light.shadow_enabled = true
	_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_light.shadow_filter_smooth = 1.5
	add_child(_light)
	_flame = Node2D.new()
	_flame.name = "Flame"
	_flame.material = _unshaded()
	_flame.draw.connect(_draw_flame)
	add_child(_flame)
	_embers = _build_embers()
	add_child(_embers)
	_crackle = Services.audio.start_emitter(AudioEvents.TORCH_BURN, self)
	_apply()


func _process(delta: float) -> void:
	_time += delta
	var wave: float = (
		0.5 * sin(_time * FLICKER_SPEED + _flicker_phase)
		+ 0.3 * sin(_time * FLICKER_SPEED * 2.3 + 1.7 * _flicker_phase)
		+ 0.2 * sin(_time * FLICKER_SPEED * 0.6 + 0.5)
	)
	_light.energy = LIGHT_ENERGY * (1.0 + FLICKER_ENERGY * wave)
	_light.texture_scale = _base_scale() * (1.0 + FLICKER_SCALE * wave)
	_flame.scale = Vector2.ONE * (1.0 + 0.12 * wave)


## Whether the torch burns.
func is_lit() -> bool:
	return _lit


## Lights the torch on this device. Called by the [Arena] when the host says so.
func light() -> void:
	if _lit:
		return
	_lit = true
	_apply()
	Services.audio.play_event(AudioEvents.TORCH_IGNITE, global_position)
	lit.emit()


func _apply() -> void:
	if _light == null:
		return
	var reach: float = LightRules.torch_reach()
	var fade_length: float = Services.perks.get_stat(StatIds.TORCH_FADE_LENGTH)
	_light.texture = light_texture(fade_length / maxf(reach, 1.0))
	_light.texture_scale = _base_scale()
	_light.energy = LIGHT_ENERGY
	_light.enabled = _lit
	_flame.visible = _lit
	_embers.emitting = _lit
	Services.audio.set_emitter_playing(_crackle, _lit)
	set_process(_lit)


func _base_scale() -> float:
	return LightRules.torch_reach() / (TEXTURE_SIZE / 2.0)


func _draw_flame() -> void:
	_flame.draw_circle(Vector2.ZERO, 8.0, Color(0.85, 0.35, 0.1, 0.55))
	_flame.draw_circle(Vector2(0.5, -0.5), 5.5, Color(1.0, 0.62, 0.22, 0.85))
	_flame.draw_circle(Vector2(0.5, -1.0), 3.0, Color(1.0, 0.9, 0.62, 1.0))


func _build_embers() -> CPUParticles2D:
	var embers: CPUParticles2D = CPUParticles2D.new()
	embers.name = "Embers"
	embers.material = _unshaded()
	embers.emitting = false
	embers.amount = 10
	embers.lifetime = 1.6
	embers.local_coords = false
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 4.0
	embers.direction = Vector2(0.3, -1.0)
	embers.spread = 70.0
	embers.gravity = Vector2(4.0, -6.0)
	embers.initial_velocity_min = 6.0
	embers.initial_velocity_max = 20.0
	embers.damping_min = 2.0
	embers.damping_max = 6.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.2
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.82, 0.45, 1.0))
	ramp.set_color(1, Color(0.35, 0.1, 0.04, 0.0))
	ramp.add_point(0.4, Color(0.95, 0.42, 0.12, 0.85))
	embers.color_ramp = ramp
	return embers


## The flame and the embers glow by themselves: the darkness does not dim them.
static func _unshaded() -> CanvasItemMaterial:
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return material


## A round light reaching the edge of a square texture, fully lit up to
## [code]1 - fade_share[/code] of its radius and fading out like
## [method LightRules.fade] beyond. Generated once per share (to a thousandth).
static func light_texture(fade_share: float) -> Texture2D:
	var key: int = roundi(fade_share * 1000.0)
	if _textures.has(key):
		return _textures[key]
	var center: Vector2 = Vector2.ONE * (TEXTURE_SIZE / 2.0)
	var radius: float = TEXTURE_SIZE / 2.0
	var full: float = 1.0 - clampf(fade_share, 0.0, 1.0)
	var image: Image = Image.create_empty(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y: int in TEXTURE_SIZE:
		for x: int in TEXTURE_SIZE:
			var along: float = (Vector2(x + 0.5, y + 0.5) - center).length() / radius
			var falloff: float = LightRules.fade(along, full, 1.0 - full)
			var strength: float = falloff * lerpf(1.0, EDGE_BRIGHTNESS, minf(along, 1.0))
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, strength))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture

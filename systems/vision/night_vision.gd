class_name NightVision
extends CanvasLayer
## The Monster's night vision (#90): a dark-red vignette, strongest at the
## edges of the screen, and a subtle filter over the world: less saturated,
## shifted toward red and amber, a little grain, the shadows slightly lifted.
## In spider form the same look is a little stronger.
##
## It is a look only. What the Monster sees is decided by the [VisionSystem],
## which shows this layer while the local player is the Monster and hides it
## otherwise. Nothing of it is sent to the other device.
##
## It filters what is drawn below it, the world, and nothing above it: the
## round screen's banners, the HUD and the touch controls are drawn on higher
## layers. Every parameter of the look is here, tunable in
## [code]night_vision.tscn[/code]; the shader only draws it.

## Drawn above the world (layer 0) and below everything on top of it: the
## round screen's status and banners, the HUD (40) and the touch controls (50).
const LAYER: int = 10
const SHADER: Shader = preload("res://systems/vision/night_vision.gdshader")

@export_group("Strength")
## How strong the look is in the sheep disguise: 0 is off, 1 the look below.
@export_range(0.0, 2.0, 0.05) var intensity: float = 1.0
## How strong the look is in spider form: a little stronger than as a sheep.
@export_range(0.0, 2.0, 0.05) var spider_intensity: float = 1.3
## How fast the look moves between the two strengths, in strength per second.
@export var blend_speed: float = 0.6

@export_group("Filter")
## How much colour is taken out of the world: 0 keeps it, 1 leaves grey.
@export_range(0.0, 1.0, 0.05) var desaturation: float = 0.3:
	set(value):
		desaturation = value
		_apply()
## The hue the world shifts toward, at its own brightness: a dim amber-red.
@export var tint: Color = Color(1.0, 0.66, 0.45):
	set(value):
		tint = value
		_apply()
## How far the world shifts toward [member tint].
@export_range(0.0, 1.0, 0.05) var tint_strength: float = 0.22:
	set(value):
		tint_strength = value
		_apply()
## How much the shadows are lifted, in the tint, so the dark stays readable.
@export_range(0.0, 0.3, 0.01) var shadow_lift: float = 0.05:
	set(value):
		shadow_lift = value
		_apply()
## How strong the film grain is: the most a pixel's brightness changes.
@export_range(0.0, 0.2, 0.005) var grain: float = 0.025:
	set(value):
		grain = value
		_apply()
## How often the grain changes, per second.
@export var grain_fps: float = 24.0:
	set(value):
		grain_fps = value
		_apply()

@export_group("Vignette")
## The vignette's colour: a dark, oxidized crimson (art style), not bright red.
@export var vignette_color: Color = Color(0.36, 0.07, 0.05):
	set(value):
		vignette_color = value
		_apply()
## How much of the world the vignette covers at the edges: 1 covers it all.
@export_range(0.0, 1.0, 0.05) var vignette_strength: float = 0.7:
	set(value):
		vignette_strength = value
		_apply()
## Where the vignette begins: 0 is the middle of the screen, 1 the middle of
## an edge. The middle stays untouched by it.
@export_range(0.0, 1.5, 0.05) var vignette_start: float = 0.55:
	set(value):
		vignette_start = value
		_apply()
## Where the vignette is at its full strength: past the edges, in the corners.
@export_range(0.0, 2.0, 0.05) var vignette_end: float = 1.25:
	set(value):
		vignette_end = value
		_apply()
## How far the vignette breathes in and out, as a share of its reach. 0 keeps
## it still.
@export_range(0.0, 0.3, 0.01) var pulse: float = 0.06:
	set(value):
		pulse = value
		_apply()
## How long one breath of the vignette takes, in seconds.
@export var pulse_period: float = 4.0:
	set(value):
		pulse_period = value
		_apply()

## Whether the Monster is in spider form: the look moves toward
## [member spider_intensity].
var spider: bool = false

var _material: ShaderMaterial = ShaderMaterial.new()
var _strength: float = -1.0


func _init() -> void:
	layer = LAYER
	_material.shader = SHADER
	var screen: ColorRect = ColorRect.new()
	screen.name = "Filter"
	screen.material = _material
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# It only draws; touches go through to whatever is below.
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	visibility_changed.connect(_on_visibility_changed)


func _ready() -> void:
	_apply()
	_strength = get_target_strength()
	_material.set_shader_parameter(&"intensity", _strength)


func _process(delta: float) -> void:
	var target: float = get_target_strength()
	if is_equal_approx(_strength, target):
		return
	_strength = move_toward(_strength, target, blend_speed * delta)
	_material.set_shader_parameter(&"intensity", _strength)


## The strength the look is moving toward: the spider's or the sheep's.
func get_target_strength() -> float:
	return spider_intensity if spider else intensity


## The strength the look has right now.
func get_strength() -> float:
	return _strength


## The material that draws the look.
func get_filter_material() -> ShaderMaterial:
	return _material


func _apply() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"desaturation", desaturation)
	_material.set_shader_parameter(&"tint", tint)
	_material.set_shader_parameter(&"tint_strength", tint_strength)
	_material.set_shader_parameter(&"shadow_lift", shadow_lift)
	_material.set_shader_parameter(&"grain", grain)
	_material.set_shader_parameter(&"grain_fps", grain_fps)
	_material.set_shader_parameter(&"vignette_color", vignette_color)
	_material.set_shader_parameter(&"vignette_strength", vignette_strength)
	_material.set_shader_parameter(&"vignette_start", vignette_start)
	_material.set_shader_parameter(&"vignette_end", vignette_end)
	_material.set_shader_parameter(&"pulse", pulse)
	_material.set_shader_parameter(&"pulse_period", pulse_period)


# Hidden, it neither draws nor blends; shown again, it starts at its target.
func _on_visibility_changed() -> void:
	set_process(visible)
	if visible and is_node_ready():
		_strength = get_target_strength()
		_material.set_shader_parameter(&"intensity", _strength)

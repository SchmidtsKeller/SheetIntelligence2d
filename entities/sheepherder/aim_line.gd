class_name AimLine
extends Node2D
## Where the Sheepherder's shot will go, for their own player only (#81): a
## thin red line from the rifle along the aim, with a dot at the first
## obstacle or the arena's edge.
##
## It passes through sheep and the Monster, so it never shows where a sheep
## hidden in the dark stands (GDD §3.1); a shot can still stop earlier, at a
## sheep. Faint while no shot is possible (reloading, before the round),
## gone once the magazine is empty or the Sheepherder is dead. A child of the
## Sheepherder, which turns with the aim, so the line runs along its x axis.
## Placeholder look until the art pass (#22).

const COLOR: Color = Color(1.0, 0.12, 0.08)
const WIDTH: float = 2.0
## Opacity of the line at the rifle, and how faint it gets over FADE_LENGTH.
const NEAR_ALPHA: float = 0.55
const FAR_ALPHA: float = 0.12
const FADE_LENGTH: float = 700.0
const DOT_RADIUS: float = 4.0
## Muted and see-through, so it marks the spot without glaring (#87).
const DOT_COLOR: Color = Color(0.7, 0.18, 0.15)
const DOT_ALPHA: float = 0.45
## Strength while no shot is possible.
const DIM: float = 0.3
## Longer than any arena: its edge stops the line first.
const MAX_LENGTH: float = 100000.0

var _herder: Sheepherder
var _length: float = 0.0
var _strength: float = 0.0


func _ready() -> void:
	_herder = get_parent() as Sheepherder
	# Above the world, like the rest of the player's interface, and not dimmed
	# by the night.
	z_index = 1
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded


func _physics_process(_delta: float) -> void:
	_strength = _current_strength()
	var direction: Vector2 = Vector2.from_angle(global_rotation)
	var hit: WorldHit = WorldQueries.raycast(get_world_2d(), global_position, direction, MAX_LENGTH)
	_length = global_position.distance_to(hit.position) if hit != null else MAX_LENGTH
	queue_redraw()


## How far the line reaches from the Sheepherder, in pixels.
func get_length() -> float:
	return _length


## 1 when a shot is possible, [constant DIM] while not, 0 when it is hidden.
func get_strength() -> float:
	return _strength


func _current_strength() -> float:
	var combat: CombatService = Services.combat
	if _herder == null or not _herder.is_alive() or combat.is_ammo_depleted():
		return 0.0
	return 1.0 if combat.can_shoot() else DIM


func _draw() -> void:
	var start: float = ShotEffect.MUZZLE_DISTANCE
	if _strength <= 0.0 or _length <= start:
		return
	var fade_end: float = minf(_length, start + FADE_LENGTH)
	var fade_alpha: float = lerpf(NEAR_ALPHA, FAR_ALPHA, (fade_end - start) / FADE_LENGTH)
	var points: PackedVector2Array = [Vector2(start, 0.0), Vector2(fade_end, 0.0)]
	var colors: PackedColorArray = [_color(NEAR_ALPHA), _color(fade_alpha)]
	if _length > fade_end:
		points.append(Vector2(_length, 0.0))
		colors.append(_color(FAR_ALPHA))
	draw_polyline_colors(points, colors, WIDTH, true)
	draw_circle(Vector2(_length, 0.0), DOT_RADIUS, _color(DOT_ALPHA, DOT_COLOR))


func _color(alpha: float, base: Color = COLOR) -> Color:
	return Color(base, alpha * _strength)

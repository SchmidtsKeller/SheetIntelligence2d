class_name HudGauge
extends Control
## One element of the in-game HUD: a bar, a row of pips or a round icon, with
## a caption. Placeholder looks, like the touch controls: each says
## "Placeholder" until the art pass (#70) paints them; the colours come from
## [UiPalette].

enum Style {
	## A horizontal bar filled to [member value], with [member marks].
	BAR,
	## One pip per entry of [member pips], filled where it is true.
	PIPS,
	## A round icon with [member caption] in it; [member cooldown] darkens a
	## slice of it, [member value] is a ring around it.
	ICON,
}

const BACKGROUND: Color = UiPalette.HUD_BACKGROUND
const FILL: Color = UiPalette.HUD_FILL
const EMPTY: Color = UiPalette.HUD_EMPTY
const COOLDOWN: Color = UiPalette.HUD_COOLDOWN
const ACTIVE: Color = UiPalette.HUD_ACTIVE
const MARK: Color = UiPalette.HUD_MARK
const FONT_SIZE: int = 18
const SMALL_FONT_SIZE: int = 14

var style: Style = Style.BAR
## The text on or under the element.
var caption: String = "":
	set(text):
		if text != caption:
			caption = text
			queue_redraw()
## The key that triggers it, shown in a corner on PC; empty for none.
var hint: String = "":
	set(text):
		if text != hint:
			hint = text
			queue_redraw()
## How full the bar or the ring is, from 0 to 1.
var value: float = 0.0:
	set(amount):
		amount = clampf(amount, 0.0, 1.0)
		if not is_equal_approx(amount, value):
			value = amount
			queue_redraw()
## How much of a cooldown is left, from 1 to 0 (icons only).
var cooldown: float = 0.0:
	set(amount):
		amount = clampf(amount, 0.0, 1.0)
		if not is_equal_approx(amount, cooldown):
			cooldown = amount
			queue_redraw()
## Whether it is happening right now: drawn in the active colour.
var active: bool = false:
	set(on):
		if on != active:
			active = on
			queue_redraw()
## Whether it can be used at all; dimmed when not.
var available: bool = true:
	set(on):
		if on != available:
			available = on
			modulate.a = 1.0 if on else 0.45
## Positions on the bar, from 0 to 1, that are marked (milestones).
var marks: Array[float] = []:
	set(positions):
		marks = positions
		queue_redraw()
## The pips of a [constant Style.PIPS] gauge.
var pips: Array[bool] = []:
	set(entries):
		if entries != pips:
			pips = entries
			queue_redraw()


func _init(gauge_name: String, gauge_style: Style, gauge_size: Vector2) -> void:
	name = gauge_name
	style = gauge_style
	custom_minimum_size = gauge_size
	size = gauge_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	match style:
		Style.BAR:
			_draw_bar()
		Style.PIPS:
			_draw_pips()
		Style.ICON:
			_draw_icon()
	_draw_placeholder()


func _draw_bar() -> void:
	var bar: Rect2 = Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.45))
	draw_rect(bar, BACKGROUND)
	var filled: Rect2 = Rect2(bar.position, Vector2(bar.size.x * value, bar.size.y))
	draw_rect(filled, ACTIVE if active else FILL)
	for mark: float in marks:
		var x: float = bar.size.x * mark
		draw_line(Vector2(x, -3.0), Vector2(x, bar.size.y + 3.0), MARK, 3.0)
	_draw_text(caption, Vector2(0.0, size.y - 2.0), SMALL_FONT_SIZE)


func _draw_pips() -> void:
	var diameter: float = size.y * 0.6
	var radius: float = diameter / 2.0
	for index: int in pips.size():
		var center: Vector2 = Vector2(radius + index * (diameter + 6.0), radius)
		draw_circle(center, radius, FILL if pips[index] else EMPTY)
	_draw_text(caption, Vector2(0.0, size.y - 2.0), SMALL_FONT_SIZE)


func _draw_icon() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - 4.0
	draw_circle(center, radius, BACKGROUND)
	if cooldown > 0.0:
		_draw_slice(center, radius, cooldown)
	if value > 0.0:
		draw_arc(center, radius + 1.0, -PI / 2.0, -PI / 2.0 + TAU * value, 48, FILL, 4.0, true)
	draw_arc(center, radius, 0.0, TAU, 48, ACTIVE if active else EMPTY, 2.0, true)
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	_draw_text(caption, center + Vector2(-text_size.x / 2.0, text_size.y / 4.0), FONT_SIZE)
	if not hint.is_empty():
		_draw_text(hint, Vector2(2.0, SMALL_FONT_SIZE), SMALL_FONT_SIZE)


## A dark slice from twelve o'clock, as big as what is left of the cooldown.
func _draw_slice(center: Vector2, radius: float, share: float) -> void:
	var points: PackedVector2Array = [center]
	var steps: int = maxi(ceili(32.0 * share), 2)
	for step: int in steps + 1:
		var angle: float = -PI / 2.0 + TAU * share * step / steps
		points.append(center + Vector2.from_angle(angle) * radius)
	draw_colored_polygon(points, COOLDOWN)


func _draw_text(text: String, baseline: Vector2, font_size: int) -> void:
	if text.is_empty():
		return
	var font: Font = get_theme_default_font()
	draw_string_outline(
		font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, BACKGROUND
	)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


## Until the art pass, every gauge says that it is a stand-in.
func _draw_placeholder() -> void:
	match style:
		Style.BAR, Style.PIPS:
			PlaceholderArt.draw_word_in_corner(get_canvas_item(), Rect2(Vector2.ZERO, size), 10)
		Style.ICON:
			var font_size: int = PlaceholderArt.font_size_for(size.x * 0.75, 10)
			PlaceholderArt.draw_word(
				get_canvas_item(), Vector2(size.x / 2.0, size.y * 0.78), font_size
			)

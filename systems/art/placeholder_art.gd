class_name PlaceholderArt
extends RefCounted
## What marks art that is still a stand-in (#69): the word "Placeholder",
## drawn on every texture or shape that a painted image will replace. The
## images still to be made are listed in [code]toBeCreatedAsImage.txt[/code]
## in the repository root.
##
## Textures under an [code]assets/**/placeholder/[/code] folder are
## placeholders by definition: once the real image lives elsewhere, the word
## disappears by itself.

const WORD: String = "Placeholder"
## Part of the path of every placeholder texture.
const FOLDER: String = "/placeholder/"
## Loud on purpose, so a placeholder is never mistaken for final art.
const COLOR: Color = Color(1.0, 0.62, 1.0, 0.9)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.75)
const OUTLINE_SIZE: int = 3
const MIN_FONT_SIZE: int = 7
const MAX_FONT_SIZE: int = 14


## Whether [param texture] is placeholder art.
static func is_placeholder(texture: Texture2D) -> bool:
	return texture != null and texture.resource_path.contains(FOLDER)


## The largest font size, up to [param largest], at which the word fits into
## [param width].
static func font_size_for(width: float, largest: int = MAX_FONT_SIZE) -> int:
	var font: Font = ThemeDB.fallback_font
	var reference: float = (
		font.get_string_size(WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, MAX_FONT_SIZE).x
	)
	var fitting: int = floori(width / reference * MAX_FONT_SIZE) if reference > 0.0 else 0
	return clampi(fitting, MIN_FONT_SIZE, maxi(largest, MIN_FONT_SIZE))


## Draws the word centered on [param center] into [param canvas_item]. Call it
## from a [method CanvasItem._draw] or a [method StyleBox._draw].
static func draw_word(canvas_item: RID, center: Vector2, font_size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline: Vector2 = Vector2(
		center.x - text_size.x / 2.0, center.y - text_size.y / 2.0 + font.get_ascent(font_size)
	)
	font.draw_string_outline(
		canvas_item,
		baseline,
		WORD,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		OUTLINE_SIZE,
		OUTLINE_COLOR
	)
	font.draw_string(canvas_item, baseline, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR)


## Draws the word in [param corner] of [param rect], small enough to leave
## room for whatever else is in it.
static func draw_word_in_corner(
	canvas_item: RID, rect: Rect2, font_size: int = 11, corner: Corner = CORNER_TOP_RIGHT
) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var half: Vector2 = text_size / 2.0 + Vector2(4.0, 4.0)
	var right: bool = corner == CORNER_TOP_RIGHT or corner == CORNER_BOTTOM_RIGHT
	var bottom: bool = corner == CORNER_BOTTOM_LEFT or corner == CORNER_BOTTOM_RIGHT
	var center: Vector2 = Vector2(
		rect.end.x - half.x if right else rect.position.x + half.x,
		rect.end.y - half.y if bottom else rect.position.y + half.y
	)
	draw_word(canvas_item, center, font_size)

class_name PlaceholderBadge
extends Control
## Says "Placeholder" on a control whose image is still missing (#69): the
## title logo, a perk icon, a joystick. Laid over the control as a child; it
## never takes clicks or touches.

enum Placement {
	## Over the whole parent, the word small in its top-right corner.
	CORNER,
	## The word in the middle, as large as fits.
	CENTER,
}

const FRAME_WIDTH: float = 2.0

var placement: Placement = Placement.CORNER
## Whether a frame shows where the image goes (an icon slot).
var framed: bool = false
## The image that will replace it, as listed in toBeCreatedAsImage.txt.
var image_id: String = ""


func _init(
	image: String = "", badge_placement: Placement = Placement.CORNER, with_frame: bool = false
) -> void:
	name = "PlaceholderBadge"
	image_id = image
	placement = badge_placement
	framed = with_frame
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lays a badge over all of [param parent], the word in its corner.
static func over(parent: Control, image: String) -> PlaceholderBadge:
	var badge: PlaceholderBadge = PlaceholderBadge.new(image, Placement.CORNER)
	parent.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return badge


## A framed slot of [param side] pixels for an icon that does not exist yet.
static func icon_slot(image: String, side: float) -> PlaceholderBadge:
	var badge: PlaceholderBadge = PlaceholderBadge.new(image, Placement.CENTER, true)
	badge.custom_minimum_size = Vector2(side, side)
	badge.size = badge.custom_minimum_size
	return badge


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if not PlaceholderArt.marks_shown:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if framed:
		draw_rect(rect, UiPalette.HUD_BACKGROUND)
		draw_rect(rect, UiPalette.BUTTON_BORDER, false, FRAME_WIDTH)
	match placement:
		Placement.CORNER:
			PlaceholderArt.draw_word_in_corner(get_canvas_item(), rect)
		Placement.CENTER:
			var font_size: int = PlaceholderArt.font_size_for(size.x - 2.0 * FRAME_WIDTH)
			PlaceholderArt.draw_word(get_canvas_item(), size / 2.0, font_size)

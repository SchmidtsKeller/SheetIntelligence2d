class_name PlaceholderStyleBox
extends StyleBox
## A flat box with a border that stands in for a painted texture (#69): a
## button, a board, the menu backdrop. It says "Placeholder" in its top-right
## corner until the art pass (#70) puts a [StyleBoxTexture] in its place in
## [GameTheme].

var fill: Color = Color.BLACK
var border: Color = Color.TRANSPARENT
var border_width: float = 0.0
## Whether the word is drawn. Off for boxes drawn on top of another one, such
## as the focus frame, so the word does not appear twice.
var marked: bool = true
## Where the word is drawn.
var word_corner: Corner = CORNER_TOP_RIGHT
## The image that will replace it, as listed in toBeCreatedAsImage.txt.
var image_id: String = ""


func _init(
	fill_color: Color = Color.BLACK,
	border_color: Color = Color.TRANSPARENT,
	border_size: float = 0.0,
	image: String = ""
) -> void:
	fill = fill_color
	border = border_color
	border_width = border_size
	image_id = image


## The same box with [param margin_x] and [param margin_y] around the content.
func with_margins(margin_x: float, margin_y: float) -> PlaceholderStyleBox:
	content_margin_left = margin_x
	content_margin_right = margin_x
	content_margin_top = margin_y
	content_margin_bottom = margin_y
	return self


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if fill.a > 0.0:
		RenderingServer.canvas_item_add_rect(to_canvas_item, rect, fill)
	if border_width > 0.0 and border.a > 0.0:
		var width: float = border_width
		var top: Rect2 = Rect2(rect.position, Vector2(rect.size.x, width))
		var bottom: Rect2 = Rect2(rect.position.x, rect.end.y - width, rect.size.x, width)
		var left: Rect2 = Rect2(rect.position, Vector2(width, rect.size.y))
		var right: Rect2 = Rect2(rect.end.x - width, rect.position.y, width, rect.size.y)
		for side: Rect2 in [top, bottom, left, right]:
			RenderingServer.canvas_item_add_rect(to_canvas_item, side, border)
	if marked and rect.size.x >= 80.0 and rect.size.y >= 20.0:
		PlaceholderArt.draw_word_in_corner(to_canvas_item, rect, 11, word_corner)

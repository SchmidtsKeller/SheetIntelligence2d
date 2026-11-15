class_name TwoColumns
extends RefCounted
## The layout of the screens around a round (#20): what happened on the left,
## what comes next (the perk choice) on the right, side by side so that a phone
## held sideways shows both without scrolling. On a screen too small for that,
## the whole page scrolls.


## Fills [param screen] with the two columns and returns them:
## [code][left, right][/code].
static func build(screen: Control) -> Array[VBoxContainer]:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	screen.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Columns"
	row.add_theme_constant_override(&"separation", 48)
	center.add_child(row)
	var columns: Array[VBoxContainer] = []
	for column_name: String in ["Left", "Right"]:
		var column: VBoxContainer = VBoxContainer.new()
		column.name = column_name
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override(&"separation", 12)
		row.add_child(column)
		columns.append(column)
	return columns

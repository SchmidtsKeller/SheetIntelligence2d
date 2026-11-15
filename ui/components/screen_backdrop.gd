class_name ScreenBackdrop
extends Panel
## What lies behind a whole menu screen (#69): a painted night pasture once it
## exists (see [GameTheme]). It fills its parent and lets clicks through.


## A backdrop filling [param screen], behind everything else in it.
static func fill(screen: Control) -> ScreenBackdrop:
	var backdrop: ScreenBackdrop = ScreenBackdrop.new()
	backdrop.name = "Backdrop"
	backdrop.theme_type_variation = GameTheme.BACKDROP_PANEL
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(backdrop)
	screen.move_child(backdrop, 0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return backdrop

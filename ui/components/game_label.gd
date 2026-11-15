class_name GameLabel
extends Label
## A text of the game's menus and HUD (#69), in one of the styles of
## [GameTheme] ([constant GameTheme.TITLE], [constant GameTheme.BODY], …),
## centered.

## Tall enough for the title and the "Placeholder" word above it.
const LOGO_HEIGHT: float = 76.0


## A label in [param style] saying [param label_text], named
## [param label_name] when one is given.
static func create(
	style: StringName, label_text: String = "", label_name: String = ""
) -> GameLabel:
	var label: GameLabel = GameLabel.new()
	label.theme_type_variation = style
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not label_name.is_empty():
		label.name = label_name
	return label


## Makes [param label] the stand-in for the game's logo: the title text, with
## room above it for the "Placeholder" word until the logo is painted.
static func mark_as_logo(label: Label) -> void:
	label.theme_type_variation = GameTheme.TITLE
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.custom_minimum_size.y = LOGO_HEIGHT
	PlaceholderBadge.over(label, "ui_logo")


## Wraps long lines at word boundaries, at least [param min_width] wide.
## Returns the label.
func wrapped(min_width: float = 0.0) -> GameLabel:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	custom_minimum_size.x = min_width
	return self

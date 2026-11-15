class_name GameTheme
extends RefCounted
## The one [Theme] of the menus, the HUD and the touch controls (#69): font
## sizes, label styles, buttons, boards and the menu backdrop. Screens apply it
## to their root with [method apply] and pick a style by its type variation
## (the constants below); none of them styles a control of its own. The art
## pass (#70) swaps the [PlaceholderStyleBox]es here for painted
## [StyleBoxTexture]s and the fallback font for the game's fonts.

## The game's name in large letters, until the logo exists.
const TITLE: StringName = &"TitleLabel"
## How a round ended.
const HEADLINE: StringName = &"HeadlineLabel"
const HEADING: StringName = &"HeadingLabel"
const BODY: StringName = &"BodyLabel"
const SMALL: StringName = &"SmallLabel"
## A problem or a hint that needs attention.
const WARNING: StringName = &"WarningLabel"
## HUD texts, outlined so they read on the dark and on the lit ground: a
## banner across the round (countdown, result), the timer, short messages.
const HUD_TITLE: StringName = &"HudTitleLabel"
const HUD_TIMER: StringName = &"HudTimerLabel"
const HUD_MESSAGE: StringName = &"HudMessageLabel"
const HUD_TEXT: StringName = &"HudLabel"
## A wide toggle button with an icon, such as a perk.
const CHOICE_BUTTON: StringName = &"ChoiceButton"
## A board behind a group of texts and buttons.
const BOARD_PANEL: StringName = &"BoardPanel"
## Behind a whole menu screen.
const BACKDROP_PANEL: StringName = &"BackdropPanel"

const DEFAULT_FONT_SIZE: int = 20
const LABEL_SIZES: Dictionary[StringName, int] = {
	TITLE: 40,
	HEADLINE: 32,
	HEADING: 26,
	BODY: 20,
	SMALL: 16,
	WARNING: 20,
	HUD_TITLE: 40,
	HUD_TIMER: 34,
	HUD_MESSAGE: 24,
	HUD_TEXT: 18,
}
const HUD_OUTLINES: Dictionary[StringName, int] = {
	HUD_TITLE: 6,
	HUD_TIMER: 6,
	HUD_MESSAGE: 6,
	HUD_TEXT: 4,
}
## Room on the left of a choice button for its icon.
const CHOICE_ICON_SPACE: float = 68.0

static var _theme: Theme


## The shared theme, built once.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


## Gives [param control] and everything below it the shared theme.
static func apply(control: Control) -> void:
	control.theme = get_theme()


## A new theme with every style of the game.
static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = DEFAULT_FONT_SIZE
	_add_labels(theme)
	_add_buttons(theme)
	_add_panels(theme)
	return theme


static func _add_labels(theme: Theme) -> void:
	theme.set_color(&"font_color", &"Label", UiPalette.TEXT)
	for variation: StringName in LABEL_SIZES:
		theme.set_type_variation(variation, &"Label")
		theme.set_font_size(&"font_size", variation, LABEL_SIZES[variation])
	theme.set_color(&"font_color", TITLE, UiPalette.HIGHLIGHT)
	theme.set_color(&"font_color", WARNING, UiPalette.WARNING)
	for variation: StringName in HUD_OUTLINES:
		theme.set_constant(&"outline_size", variation, HUD_OUTLINES[variation])
		theme.set_color(&"font_outline_color", variation, UiPalette.HUD_BACKGROUND)


static func _add_buttons(theme: Theme) -> void:
	_set_button_styles(theme, &"Button", 16.0)
	theme.set_type_variation(CHOICE_BUTTON, &"Button")
	_set_button_styles(theme, CHOICE_BUTTON, 12.0)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var box: StyleBox = theme.get_stylebox(state, CHOICE_BUTTON)
		box.content_margin_left = CHOICE_ICON_SPACE
	theme.set_font_size(&"font_size", CHOICE_BUTTON, 17)
	var chosen: PlaceholderStyleBox = theme.get_stylebox(&"pressed", CHOICE_BUTTON)
	chosen.border = UiPalette.HIGHLIGHT


static func _set_button_styles(theme: Theme, type: StringName, margin_x: float) -> void:
	var image: String = "ui_button" if type == &"Button" else "ui_choice_button"
	var normal: PlaceholderStyleBox = _box(UiPalette.BUTTON, UiPalette.BUTTON_BORDER, image)
	var hover: PlaceholderStyleBox = _box(UiPalette.BUTTON_HOVER, UiPalette.HIGHLIGHT, image)
	var pressed: PlaceholderStyleBox = _box(
		UiPalette.BUTTON_PRESSED, UiPalette.BUTTON_BORDER, image
	)
	var hover_pressed: PlaceholderStyleBox = _box(
		UiPalette.BUTTON_PRESSED, UiPalette.HIGHLIGHT, image
	)
	var disabled: PlaceholderStyleBox = _box(
		UiPalette.BUTTON_DISABLED, UiPalette.BOARD_BORDER, image
	)
	var focus: PlaceholderStyleBox = _box(Color.TRANSPARENT, UiPalette.HIGHLIGHT, image)
	focus.marked = false
	var styles: Dictionary[StringName, PlaceholderStyleBox] = {
		&"normal": normal,
		&"hover": hover,
		&"pressed": pressed,
		&"hover_pressed": hover_pressed,
		&"disabled": disabled,
		&"focus": focus,
	}
	for state: StringName in styles:
		theme.set_stylebox(state, type, styles[state].with_margins(margin_x, 8.0))
	theme.set_color(&"font_color", type, UiPalette.TEXT)
	theme.set_color(&"font_hover_color", type, UiPalette.TEXT)
	theme.set_color(&"font_focus_color", type, UiPalette.TEXT)
	theme.set_color(&"font_pressed_color", type, UiPalette.HIGHLIGHT)
	theme.set_color(&"font_hover_pressed_color", type, UiPalette.HIGHLIGHT)
	theme.set_color(&"font_disabled_color", type, UiPalette.TEXT_DISABLED)


static func _add_panels(theme: Theme) -> void:
	theme.set_type_variation(BOARD_PANEL, &"PanelContainer")
	var board: PlaceholderStyleBox = _box(UiPalette.BOARD, UiPalette.BOARD_BORDER, "ui_board")
	theme.set_stylebox(&"panel", BOARD_PANEL, board.with_margins(22.0, 16.0))
	theme.set_type_variation(BACKDROP_PANEL, &"Panel")
	var backdrop: PlaceholderStyleBox = _box(UiPalette.BACKDROP, Color.TRANSPARENT, "ui_backdrop")
	backdrop.border_width = 0.0
	# Bottom left, where the boards in front of it leave it visible.
	backdrop.word_corner = CORNER_BOTTOM_LEFT
	theme.set_stylebox(&"panel", BACKDROP_PANEL, backdrop)


static func _box(fill: Color, border: Color, image: String) -> PlaceholderStyleBox:
	return PlaceholderStyleBox.new(fill, border, 2.0, image)

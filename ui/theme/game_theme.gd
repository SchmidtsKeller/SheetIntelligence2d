class_name GameTheme
extends RefCounted
## The one [Theme] of the menus, the HUD and the touch controls (#69): font
## sizes, label styles, buttons, boards and the menu backdrop. Screens apply it
## to their root with [method apply] and pick a style by its type variation
## (the constants below); none of them styles a control of its own.
##
## Buttons, choice buttons, boards and the touch joysticks are painted
## ([PaintedUi], #83, #96). The menu backdrop has no painting yet: a plain
## dark [PlaceholderStyleBox]. All text is set in IM Fell English (#86), old print with worn
## ink; it is also the project's default font, so nothing falls back to
## another face. Its digits are old-style figures, so the small HUD texts are
## a little larger than they would be in a modern face.

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

## The game's typeface: IM Fell English (SIL Open Font License,
## assets/fonts/OFL.txt).
const FONT: FontFile = preload("res://assets/fonts/IMFellEnglish-Regular.ttf")

const DEFAULT_FONT_SIZE: int = 20
const LABEL_SIZES: Dictionary[StringName, int] = {
	TITLE: 40,
	HEADLINE: 32,
	HEADING: 26,
	BODY: 20,
	SMALL: 18,
	WARNING: 20,
	HUD_TITLE: 40,
	HUD_TIMER: 34,
	HUD_MESSAGE: 24,
	HUD_TEXT: 20,
}
const HUD_OUTLINES: Dictionary[StringName, int] = {
	HUD_TITLE: 6,
	HUD_TIMER: 6,
	HUD_MESSAGE: 6,
	HUD_TEXT: 4,
}
## Room on the left of a choice button that has an icon (see
## [method GameButton.set_choice_icon]).
const CHOICE_ICON_SPACE: float = 68.0

static var _theme: Theme
static var _board_theme: Theme


## The shared theme, built once.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


## Gives [param control] and everything below it the shared theme.
static func apply(control: Control) -> void:
	control.theme = get_theme()


## Makes [constant FONT] the font of everything that has no theme font: text
## outside [GameTheme], and code that draws with [member ThemeDB.fallback_font].
## Done at start-up by the [code]SceneFlow[/code] autoload, not through the
## project setting [code]gui/theme/custom_font[/code]: that one is loaded before
## a fresh checkout has imported the font, which fails the import (#96).
static func use_font_everywhere() -> void:
	ThemeDB.fallback_font = FONT


## The theme for what stands on a painted board: the same styles, with text in
## dark ink, because the board is light parchment.
static func get_board_theme() -> Theme:
	if _board_theme == null:
		_board_theme = build()
		_ink_labels(_board_theme)
	return _board_theme


## A new theme with every style of the game.
static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = DEFAULT_FONT_SIZE
	_add_labels(theme)
	_add_buttons(theme)
	_add_panels(theme)
	_add_joysticks(theme)
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
	# Menu buttons are wooden planks, with pale text.
	_set_button_styles(theme, &"Button", "ui_button", 16.0)
	theme.set_color(&"font_color", &"Button", UiPalette.TEXT)
	theme.set_color(&"font_hover_color", &"Button", UiPalette.HIGHLIGHT)
	theme.set_color(&"font_focus_color", &"Button", UiPalette.TEXT)
	theme.set_color(&"font_pressed_color", &"Button", UiPalette.TEXT)
	theme.set_color(&"font_hover_pressed_color", &"Button", UiPalette.TEXT)
	theme.set_color(&"font_disabled_color", &"Button", UiPalette.TEXT_DISABLED)
	theme.set_constant(&"outline_size", &"Button", 4)
	theme.set_color(&"font_outline_color", &"Button", UiPalette.HUD_BACKGROUND)
	# Choices (a perk) are parchment on wood, with ink.
	theme.set_type_variation(CHOICE_BUTTON, &"Button")
	_set_button_styles(theme, CHOICE_BUTTON, "ui_choice_button", 24.0)
	theme.set_font_size(&"font_size", CHOICE_BUTTON, 17)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var box: StyleBox = theme.get_stylebox(state, CHOICE_BUTTON)
		box.content_margin_top = 13.0
		box.content_margin_bottom = 13.0
	theme.set_color(&"font_color", CHOICE_BUTTON, PaintedUi.INK)
	theme.set_color(&"font_hover_color", CHOICE_BUTTON, PaintedUi.INK)
	theme.set_color(&"font_focus_color", CHOICE_BUTTON, PaintedUi.INK)
	theme.set_color(&"font_pressed_color", CHOICE_BUTTON, PaintedUi.INK)
	theme.set_color(&"font_hover_pressed_color", CHOICE_BUTTON, PaintedUi.INK)
	theme.set_color(&"font_disabled_color", CHOICE_BUTTON, UiPalette.TEXT)
	theme.set_constant(&"outline_size", CHOICE_BUTTON, 0)


## The painted states of [param piece] for buttons of [param type], with
## [param margin_x] around the text.
static func _set_button_styles(
	theme: Theme, type: StringName, piece: String, margin_x: float
) -> void:
	var styles: Dictionary[StringName, String] = {
		&"normal": "normal",
		&"hover": "hover",
		&"pressed": "pressed",
		&"hover_pressed": "pressed",
		&"disabled": "disabled",
		&"focus": "focus",
	}
	for state: StringName in styles:
		var box: StyleBoxTexture = PaintedUi.box("%s_%s" % [piece, styles[state]], piece)
		box.content_margin_left = margin_x
		box.content_margin_right = margin_x
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
		theme.set_stylebox(state, type, box)


static func _add_panels(theme: Theme) -> void:
	theme.set_type_variation(BOARD_PANEL, &"PanelContainer")
	var board: StyleBoxTexture = PaintedUi.box("ui_board_large", "ui_board_large")
	board.content_margin_left = 24.0
	board.content_margin_right = 24.0
	board.content_margin_top = 26.0
	board.content_margin_bottom = 26.0
	theme.set_stylebox(&"panel", BOARD_PANEL, board)
	theme.set_type_variation(BACKDROP_PANEL, &"Panel")
	var backdrop: PlaceholderStyleBox = _box(UiPalette.BACKDROP, Color.TRANSPARENT, "ui_backdrop")
	backdrop.border_width = 0.0
	# Bottom left, where the boards in front of it leave it visible.
	backdrop.word_corner = CORNER_BOTTOM_LEFT
	theme.set_stylebox(&"panel", BACKDROP_PANEL, backdrop)


## The touch sticks: the painted ring and knob, a little brighter while held.
static func _add_joysticks(theme: Theme) -> void:
	var held: Color = Color(1.25, 1.2, 1.1)
	for part: String in ["joystick", "tip"]:
		var piece: String = "touch_joystick_base" if part == "joystick" else "touch_joystick_tip"
		var normal: StyleBoxTexture = PaintedUi.round_box(piece)
		var pressed: StyleBoxTexture = PaintedUi.round_box(piece)
		pressed.modulate_color = held
		theme.set_stylebox(StringName("normal_" + part), &"VirtualJoystick", normal)
		theme.set_stylebox(StringName("pressed_" + part), &"VirtualJoystick", pressed)


## Dark ink for every label style, for text on the parchment board.
static func _ink_labels(theme: Theme) -> void:
	theme.set_color(&"font_color", &"Label", PaintedUi.INK)
	for variation: StringName in LABEL_SIZES:
		if not HUD_OUTLINES.has(variation):
			theme.set_color(&"font_color", variation, PaintedUi.INK)
	theme.set_color(&"font_color", TITLE, PaintedUi.INK_TITLE)
	theme.set_color(&"font_color", WARNING, PaintedUi.INK_WARNING)
	theme.set_color(&"font_color", SMALL, PaintedUi.INK_SOFT)


static func _box(fill: Color, border: Color, image: String) -> PlaceholderStyleBox:
	return PlaceholderStyleBox.new(fill, border, 2.0, image)

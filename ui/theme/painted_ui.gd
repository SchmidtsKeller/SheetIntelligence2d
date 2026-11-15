class_name PaintedUi
extends RefCounted
## The painted UI pieces (#83): buttons, choice buttons, the board and the
## touch controls, cut from resources/art_sources/uiElements.webp by
## tools/cut_art_sheets.gd. [GameTheme] and the touch controls build their
## styles from here.
##
## The pieces are small (the sheet is 1024 px wide), so the boxes that grow
## with their content keep their painted frame and stretch only the middle
## (nine-slice).

const FOLDER: String = "res://assets/ui/painted/"

## The states of a button, in the names of the pieces.
const STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]

## How much of each piece's edge is frame that must not stretch, in pixels of
## the piece: [code][left and right, top and bottom][/code].
const FRAMES: Dictionary[String, Vector2] = {
	"ui_button": Vector2(16.0, 12.0),
	"ui_choice_button": Vector2(22.0, 18.0),
	"ui_board": Vector2(26.0, 26.0),
}

## Ink on the parchment of the board and the choice buttons: dark enough to
## read on a phone.
const INK: Color = Color(0.16, 0.115, 0.07)
const INK_SOFT: Color = Color(0.3, 0.24, 0.17)
const INK_TITLE: Color = Color(0.36, 0.17, 0.07)
const INK_WARNING: Color = Color(0.5, 0.1, 0.06)


## The texture of the piece [param piece_name], e.g. "ui_button_hover".
static func texture(piece_name: String) -> Texture2D:
	return load(FOLDER + piece_name + ".png") as Texture2D


## A nine-slice box of [param piece_name], whose frame is that of
## [param kind] (see [constant FRAMES]).
static func box(piece_name: String, kind: String) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture(piece_name)
	var frame: Vector2 = FRAMES[kind]
	style.texture_margin_left = frame.x
	style.texture_margin_right = frame.x
	style.texture_margin_top = frame.y
	style.texture_margin_bottom = frame.y
	return style


## A round touch control piece drawn at the size of its control.
static func round_box(piece_name: String) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture(piece_name)
	return style

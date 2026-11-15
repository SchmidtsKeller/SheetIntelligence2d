class_name GameButton
extends Button
## A button of the game's menus (#69). Its looks come from [GameTheme]; this
## gives every button the same size, place and touch target.
##
## [codeblock lang=text]
## MENU:    an action such as "Host a game" or "Ready"
## CHOICE:  a wide toggle with an icon on the left, such as a perk
## [/codeblock]

enum Kind { MENU, CHOICE }

## Large enough for a thumb on a phone held sideways.
const MENU_SIZE: Vector2 = Vector2(300.0, 56.0)
const CHOICE_SIZE: Vector2 = Vector2(460.0, 64.0)
const ICON_SIDE: float = 44.0
## Where the icon sits, from the button's left edge.
const ICON_INSET: float = 12.0

var kind: Kind = Kind.MENU
var _icon_slot: Control


func _init() -> void:
	pressed.connect(_on_pressed)


## A button saying [param label] that calls [param action] when pressed.
static func create(
	label: String, action: Callable = Callable(), button_kind: Kind = Kind.MENU
) -> GameButton:
	var button: GameButton = GameButton.new()
	button.kind = button_kind
	button.text = label
	if action.is_valid():
		button.pressed.connect(action)
	match button_kind:
		Kind.MENU:
			button.custom_minimum_size = MENU_SIZE
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		Kind.CHOICE:
			button.theme_type_variation = GameTheme.CHOICE_BUTTON
			button.custom_minimum_size = CHOICE_SIZE
			button.toggle_mode = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button


func _on_pressed() -> void:
	Services.audio.play_ui(AudioEvents.UI_CLICK)


## Shows [param texture] as the choice's icon, or a placeholder slot naming
## [param image_id] while there is none.
func set_choice_icon(texture: Texture2D, image_id: String) -> void:
	if _icon_slot != null:
		_icon_slot.queue_free()
	if texture != null:
		var picture: TextureRect = TextureRect.new()
		picture.name = "Icon"
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_slot = picture
	else:
		_icon_slot = PlaceholderBadge.icon_slot(image_id, ICON_SIDE)
	_icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_slot)
	_icon_slot.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_icon_slot.offset_left = ICON_INSET
	_icon_slot.offset_right = ICON_INSET + ICON_SIDE
	_icon_slot.offset_top = -ICON_SIDE / 2.0
	_icon_slot.offset_bottom = ICON_SIDE / 2.0

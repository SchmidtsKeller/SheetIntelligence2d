extends TestCase
## The shared theme, the UI components and the "Placeholder" marking (#69).

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const TREE_SCENE: PackedScene = preload("res://entities/obstacles/tree.tscn")
const PLACEHOLDER_TEXTURE: Texture2D = preload("res://assets/arena/placeholder/bush.svg")
const BUTTON_STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled"]


func after_each() -> void:
	# Tests of the marking switch it on for themselves.
	PlaceholderArt.marks_shown = false


# --- Theme -----------------------------------------------------------------------


func test_the_theme_is_built_once_and_shared() -> void:
	assert_eq(GameTheme.get_theme(), GameTheme.get_theme())
	var control: Control = autofree(Control.new())
	GameTheme.apply(control)
	assert_eq(control.theme, GameTheme.get_theme())


func test_the_text_is_set_in_the_games_font() -> void:
	var theme: Theme = GameTheme.build()

	assert_eq(theme.default_font, GameTheme.FONT)
	assert_eq(GameTheme.FONT.resource_path, "res://assets/fonts/IMFellEnglish-Regular.ttf")
	assert_eq(theme.get_font(&"font", GameTheme.HEADING), GameTheme.FONT)
	assert_eq(theme.get_font(&"font", GameTheme.HUD_TEXT), GameTheme.FONT, "the HUD too")
	assert_eq(ThemeDB.fallback_font, GameTheme.FONT, "and everything outside the theme")


func test_every_label_style_has_its_font_size() -> void:
	var theme: Theme = GameTheme.build()
	for style: StringName in GameTheme.LABEL_SIZES:
		assert_eq(theme.get_type_variation_base(style), &"Label", "%s is a label" % style)
		assert_eq(theme.get_font_size(&"font_size", style), GameTheme.LABEL_SIZES[style])


func test_buttons_and_boards_are_painted() -> void:
	var theme: Theme = GameTheme.build()
	var pieces: Dictionary[StringName, String] = {
		&"Button": "ui_button", GameTheme.CHOICE_BUTTON: "ui_choice_button"
	}
	for type: StringName in pieces:
		for state: StringName in BUTTON_STATES + ([&"focus"] as Array[StringName]):
			var box: StyleBoxTexture = theme.get_stylebox(state, type) as StyleBoxTexture
			assert_not_null(box, "%s %s is painted" % [type, state])
			var expected: String = "%s%s_%s.png" % [PaintedUi.FOLDER, pieces[type], state]
			assert_eq(box.texture.resource_path, expected)
		var held: StyleBoxTexture = theme.get_stylebox(&"hover_pressed", type)
		assert_eq(held.texture, (theme.get_stylebox(&"pressed", type) as StyleBoxTexture).texture)
	var board: StyleBoxTexture = theme.get_stylebox(&"panel", GameTheme.BOARD_PANEL)
	assert_eq(board.texture.resource_path, PaintedUi.FOLDER + "ui_board_large.png")
	assert_gt(board.texture_margin_left, 0.0, "the frame does not stretch")


func test_the_backdrop_is_still_a_placeholder_that_says_so() -> void:
	var theme: Theme = GameTheme.build()
	var box: PlaceholderStyleBox = theme.get_stylebox(&"panel", GameTheme.BACKDROP_PANEL)

	assert_true(box.marked)
	assert_eq(box.image_id, "ui_backdrop")


func test_text_on_the_parchment_board_is_dark_ink() -> void:
	var board: Theme = GameTheme.get_board_theme()

	assert_eq(board.get_color(&"font_color", GameTheme.BODY), PaintedUi.INK)
	assert_eq(board.get_color(&"font_color", GameTheme.HEADING), PaintedUi.INK)
	assert_ne(GameTheme.get_theme().get_color(&"font_color", GameTheme.BODY), PaintedUi.INK)
	var panel: GamePanel = autofree(GamePanel.create("Board", Control.new()))
	assert_eq(panel.theme, board)


func test_the_touch_sticks_are_painted() -> void:
	var theme: Theme = GameTheme.build()
	var items: Array[StringName] = [
		&"normal_joystick", &"pressed_joystick", &"normal_tip", &"pressed_tip"
	]
	for item: StringName in items:
		var box: StyleBoxTexture = theme.get_stylebox(item, &"VirtualJoystick") as StyleBoxTexture
		assert_not_null(box, "%s is painted" % item)
		assert_true(box.texture.resource_path.begins_with(PaintedUi.FOLDER + "touch_joystick_"))


# --- Components ------------------------------------------------------------------


func test_a_menu_button_is_large_enough_for_a_thumb() -> void:
	var pressed: Array[bool] = [false]
	var button: GameButton = autofree(GameButton.create("Go", func() -> void: pressed[0] = true))

	assert_eq(button.text, "Go")
	assert_gte(button.custom_minimum_size.y, 48.0)
	assert_eq(button.size_flags_horizontal, Control.SIZE_SHRINK_CENTER)
	button.pressed.emit()
	assert_true(pressed[0], "the action runs")


func test_a_choice_button_without_an_icon_shows_no_slot_and_keeps_no_room() -> void:
	var button: GameButton = add_child_autofree(
		GameButton.create("Perk", Callable(), GameButton.Kind.CHOICE)
	)
	var plain_margin: float = button.get_theme_stylebox(&"normal").content_margin_left

	button.set_choice_icon(null, "perk_icon_test")

	assert_eq(_children(button, PlaceholderBadge).size(), 0, "no placeholder slot")
	assert_eq(button.get_theme_stylebox(&"normal").content_margin_left, plain_margin)

	button.set_choice_icon(PLACEHOLDER_TEXTURE, "perk_icon_test")

	assert_eq(button.find_children("*", "TextureRect", false, false).size(), 1)
	var with_icon: float = button.get_theme_stylebox(&"normal").content_margin_left
	assert_eq(with_icon, GameTheme.CHOICE_ICON_SPACE, "room for the icon")


func test_with_marks_a_choice_button_shows_a_placeholder_icon_until_there_is_one() -> void:
	PlaceholderArt.marks_shown = true
	var button: GameButton = add_child_autofree(
		GameButton.create("Perk", Callable(), GameButton.Kind.CHOICE)
	)
	button.set_choice_icon(null, "perk_icon_test")

	assert_true(button.toggle_mode)
	assert_eq(button.theme_type_variation, GameTheme.CHOICE_BUTTON)
	var badges: Array[Node] = _children(button, PlaceholderBadge)
	assert_eq(badges.size(), 1)
	assert_eq((badges[0] as PlaceholderBadge).image_id, "perk_icon_test")

	button.set_choice_icon(PLACEHOLDER_TEXTURE, "perk_icon_test")
	await wait_frames(1)
	assert_eq(_children(button, PlaceholderBadge).size(), 0)
	assert_eq(button.find_children("*", "TextureRect", false, false).size(), 1)


func test_a_label_takes_a_style_and_a_name() -> void:
	var label: GameLabel = autofree(GameLabel.create(GameTheme.HEADING, "Hello", "Greeting"))

	assert_eq(label.theme_type_variation, GameTheme.HEADING)
	assert_eq(label.text, "Hello")
	assert_eq(String(label.name), "Greeting")
	assert_eq(label.wrapped(200.0), label)
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(label.custom_minimum_size.x, 200.0)


func test_the_two_columns_stand_on_boards_over_a_backdrop() -> void:
	var screen: Control = add_child_autofree(Control.new())
	var columns: Array[VBoxContainer] = TwoColumns.build(screen)

	assert_eq(screen.theme, GameTheme.get_theme())
	assert_is(screen.get_child(0), ScreenBackdrop, "the backdrop is behind everything")
	assert_eq(columns.size(), 2)
	for column: VBoxContainer in columns:
		assert_is(TwoColumns.board_of(column), GamePanel)


func test_the_lobby_uses_only_game_buttons() -> void:
	var lobby: Control = add_child_autofree(
		(load("res://ui/screens/lobby_screen.tscn") as PackedScene).instantiate()
	)
	await wait_frames(1)

	var buttons: Array[Node] = lobby.find_children("*", "Button", true, false)
	assert_gt(buttons.size(), 0)
	for button: Node in buttons:
		assert_is(button, GameButton, "%s is a game button" % button.name)
	assert_not_null(lobby.find_child("PlaceholderBadge", true, false), "the logo is a stand-in")


# --- Placeholder art in the world ------------------------------------------------


func test_placeholder_textures_are_told_by_their_folder() -> void:
	assert_true(PlaceholderArt.is_placeholder(PLACEHOLDER_TEXTURE))
	assert_false(PlaceholderArt.is_placeholder(ImageTexture.new()))
	assert_false(PlaceholderArt.is_placeholder(null))


func test_by_default_nothing_says_placeholder() -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = PLACEHOLDER_TEXTURE
	add_child_autofree(sprite)
	await wait_frames(2)

	assert_false(PlaceholderArt.marks_shown)
	assert_null(PlaceholderTag.of(sprite), "no tag on placeholder art")


func test_a_sprite_with_placeholder_art_is_tagged() -> void:
	PlaceholderArt.marks_shown = true
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = PLACEHOLDER_TEXTURE
	add_child_autofree(sprite)
	await wait_frames(1)

	var tag: PlaceholderTag = PlaceholderTag.of(sprite)
	assert_not_null(tag)
	assert_eq(tag.get_centers(), [sprite.get_rect().get_center()] as Array[Vector2])


func test_a_sprite_with_final_art_is_not_tagged_until_it_gets_placeholder_art() -> void:
	PlaceholderArt.marks_shown = true
	var sprite: Sprite2D = Sprite2D.new()
	var image: Image = Image.create_empty(8, 8, false, Image.FORMAT_L8)
	sprite.texture = ImageTexture.create_from_image(image)
	add_child_autofree(sprite)
	await wait_frames(1)
	assert_null(PlaceholderTag.of(sprite))

	sprite.texture = PLACEHOLDER_TEXTURE
	await wait_frames(1)
	assert_not_null(PlaceholderTag.of(sprite))


func test_a_large_area_is_tagged_once_per_tile() -> void:
	var tag: PlaceholderTag = autofree(
		PlaceholderTag.new(Rect2(0.0, 0.0, PlaceholderTag.TILE * 3.0, PlaceholderTag.TILE))
	)
	assert_eq(tag.get_centers().size(), 3)


func test_a_painted_obstacle_is_not_tagged() -> void:
	var tree: Node2D = add_child_autofree(TREE_SCENE.instantiate())
	await wait_frames(1)

	assert_null(PlaceholderTag.of(tree.get_node(^"Art")), "the tree is painted (#83)")


func test_an_obstacle_with_placeholder_art_is_tagged_on_its_art() -> void:
	PlaceholderArt.marks_shown = true
	var tree: Node2D = TREE_SCENE.instantiate()
	(tree.get_node(^"Art") as Sprite2D).texture = PLACEHOLDER_TEXTURE
	add_child_autofree(tree)
	await wait_frames(1)

	assert_not_null(PlaceholderTag.of(tree.get_node(^"Art")))


func test_a_sheep_is_tagged_once_on_what_the_vision_system_fades() -> void:
	# The shipped sheep is painted (#74); two placeholder layers stand in for
	# art still to come.
	var placeholder: Texture2D = PLACEHOLDER_TEXTURE
	var catalog: SheepAppearanceCatalog = SheepAppearanceCatalog.new()
	for slot_id: StringName in [&"first", &"second"]:
		var part: SheepAppearancePart = SheepAppearancePart.new()
		part.texture = placeholder
		var slot: SheepAppearanceSlot = SheepAppearanceSlot.new()
		slot.id = slot_id
		slot.parts = [part]
		catalog.slots.append(slot)
	var sheep: SheepBody = SHEEP_SCENE.instantiate()
	sheep.catalog = catalog
	add_child_autofree(sheep)
	await wait_frames(1)

	var tags: Array[Node] = _descendants(sheep, PlaceholderTag)
	assert_eq(tags.size(), 1, "one word for all the layers")
	if tags.is_empty():
		return
	var faded: CanvasItem = VisionTarget.of(sheep).visual
	assert_eq(tags[0].get_parent(), faded, "hidden and faded with the sheep")


func test_the_painted_sheep_is_not_tagged() -> void:
	var sheep: SheepBody = add_child_autofree(SHEEP_SCENE.instantiate())
	await wait_frames(1)

	assert_eq(_descendants(sheep, PlaceholderTag).size(), 0)


func _children(node: Node, type: Script) -> Array[Node]:
	return node.get_children().filter(func(child: Node) -> bool: return is_instance_of(child, type))


func _descendants(node: Node, type: Script) -> Array[Node]:
	return node.find_children("*", "", true, false).filter(
		func(child: Node) -> bool: return is_instance_of(child, type)
	)

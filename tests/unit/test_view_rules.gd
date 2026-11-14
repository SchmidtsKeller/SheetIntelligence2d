extends TestCase
## The view-fairness rule: no screen shape ever shows more than the maximum
## world area.

const MAX_VIEW: Vector2 = Vector2(1600.0, 900.0)


func test_a_16_to_9_screen_sees_exactly_the_maximum() -> void:
	var viewport: Vector2 = Vector2(1280.0, 720.0)

	assert_almost_eq(ViewRules.camera_zoom(viewport, MAX_VIEW), 0.8)
	assert_almost_eq(ViewRules.visible_world_size(viewport, MAX_VIEW), MAX_VIEW, 0.01)


func test_an_ultrawide_screen_sees_no_wider_and_less_high() -> void:
	# With aspect "expand", a 21:9 window gives a 1680 × 720 canvas.
	var visible: Vector2 = ViewRules.visible_world_size(Vector2(1680.0, 720.0), MAX_VIEW)

	assert_almost_eq(visible.x, 1600.0, 0.01)
	assert_lt(visible.y, 900.0)


func test_a_4_to_3_screen_sees_no_higher_and_less_wide() -> void:
	# With aspect "expand", a 4:3 window gives a 1280 × 960 canvas.
	var visible: Vector2 = ViewRules.visible_world_size(Vector2(1280.0, 960.0), MAX_VIEW)

	assert_almost_eq(visible.y, 900.0, 0.01)
	assert_lt(visible.x, 1600.0)


func test_no_screen_shape_sees_more_than_the_maximum() -> void:
	var shapes: Array[Vector2] = [
		Vector2(1280.0, 720.0),  # 16:9
		Vector2(1680.0, 720.0),  # 21:9
		Vector2(1560.0, 720.0),  # 19.5:9 phone, landscape
		Vector2(1280.0, 960.0),  # 4:3 tablet
		Vector2(1280.0, 2770.0),  # phone held upright
		Vector2(3840.0, 2160.0),  # a larger canvas
	]

	for viewport: Vector2 in shapes:
		var visible: Vector2 = ViewRules.visible_world_size(viewport, MAX_VIEW)
		assert_lte(visible.x, MAX_VIEW.x + 0.01, "width seen on %s" % viewport)
		assert_lte(visible.y, MAX_VIEW.y + 0.01, "height seen on %s" % viewport)
		var touches_limit: bool = (
			is_equal_approx(visible.x, MAX_VIEW.x) or is_equal_approx(visible.y, MAX_VIEW.y)
		)
		assert_true(touches_limit, "%s uses the full view along one axis" % viewport)


func test_the_maximum_comes_from_the_config() -> void:
	var config: GameConfig = GameConfig.new()

	assert_eq(
		config.get_view_max_world_size(),
		Vector2(config.view_max_world_width, config.view_max_world_height)
	)


func test_the_whole_flashlight_cone_fits_on_a_16_to_9_screen() -> void:
	var config: GameConfig = GameConfig.new()
	var half_view: Vector2 = config.get_view_max_world_size() / 2.0

	assert_lt(
		config.perk_long_flashlight_length, half_view.y, "even the long cone, pointing straight up"
	)


func test_an_invalid_maximum_fails_loudly() -> void:
	expect_error("maximum world view must be positive")

	assert_eq(ViewRules.camera_zoom(Vector2(1280.0, 720.0), Vector2.ZERO), 1.0)

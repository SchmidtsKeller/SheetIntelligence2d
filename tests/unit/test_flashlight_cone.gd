extends TestCase
## Which points the flashlight cone covers (GDD §3.1, §5).


func test_points_along_the_direction_are_inside_up_to_the_length() -> void:
	var cone: FlashlightCone = FlashlightCone.new(Vector2(10.0, 20.0), Vector2.RIGHT, 60.0, 350.0)

	assert_true(cone.contains(Vector2(10.0, 20.0)), "the origin itself")
	assert_true(cone.contains(Vector2(200.0, 20.0)))
	assert_true(cone.contains(Vector2(360.0, 20.0)), "exactly at the length")
	assert_false(cone.contains(Vector2(361.0, 20.0)), "just beyond it")
	assert_false(cone.contains(Vector2(-100.0, 20.0)), "behind the Sheepherder")


func test_the_edges_of_the_angle() -> void:
	var cone: FlashlightCone = FlashlightCone.new(Vector2.ZERO, Vector2.RIGHT, 60.0, 350.0)

	assert_true(cone.contains(Vector2.from_angle(deg_to_rad(29.9)) * 100.0))
	assert_true(cone.contains(Vector2.from_angle(deg_to_rad(-29.9)) * 100.0))
	assert_false(cone.contains(Vector2.from_angle(deg_to_rad(30.1)) * 100.0))
	assert_false(cone.contains(Vector2.from_angle(deg_to_rad(-30.1)) * 100.0))


func test_a_cone_pointing_left_covers_both_sides_of_180_degrees() -> void:
	var cone: FlashlightCone = FlashlightCone.new(Vector2.ZERO, Vector2.LEFT, 60.0, 350.0)

	assert_true(cone.contains(Vector2.from_angle(deg_to_rad(175.0)) * 100.0))
	assert_true(cone.contains(Vector2.from_angle(deg_to_rad(-175.0)) * 100.0))
	assert_false(cone.contains(Vector2.from_angle(deg_to_rad(140.0)) * 100.0))
	assert_false(cone.contains(Vector2.RIGHT * 100.0))


func test_a_wider_or_longer_cone_covers_more() -> void:
	var point: Vector2 = Vector2.from_angle(deg_to_rad(40.0)) * 400.0

	assert_false(FlashlightCone.new(Vector2.ZERO, Vector2.RIGHT, 60.0, 350.0).contains(point))
	assert_false(FlashlightCone.new(Vector2.ZERO, Vector2.RIGHT, 90.0, 350.0).contains(point))
	assert_true(FlashlightCone.new(Vector2.ZERO, Vector2.RIGHT, 90.0, 429.0).contains(point))


func test_the_direction_is_normalized() -> void:
	var cone: FlashlightCone = FlashlightCone.new(Vector2.ZERO, Vector2(0.0, 5.0), 60.0, 350.0)

	assert_almost_eq(cone.direction, Vector2.DOWN)
	assert_true(cone.contains(Vector2(0.0, 300.0)))

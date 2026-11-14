extends TestCase
## The steering forces of the flock.

const SQUARE: PackedVector2Array = [
	Vector2(100.0, 100.0), Vector2(200.0, 100.0), Vector2(200.0, 200.0), Vector2(100.0, 200.0)
]
const AREA: Rect2 = Rect2(0.0, 0.0, 1000.0, 800.0)


func test_separation_pushes_away_from_a_close_neighbour() -> void:
	var push: Vector2 = FlockSteering.separation(Vector2(0.0, 0.0), [Vector2(30.0, 0.0)], 70.0)

	assert_lt(push.x, 0.0, "away from the neighbour on the right")
	assert_almost_eq(push.y, 0.0)


func test_separation_ignores_neighbours_beyond_the_radius() -> void:
	var push: Vector2 = FlockSteering.separation(Vector2.ZERO, [Vector2(80.0, 0.0)], 70.0)

	assert_eq(push, Vector2.ZERO)


func test_separation_grows_as_the_neighbour_comes_closer() -> void:
	var far: Vector2 = FlockSteering.separation(Vector2.ZERO, [Vector2(60.0, 0.0)], 70.0)
	var near: Vector2 = FlockSteering.separation(Vector2.ZERO, [Vector2(10.0, 0.0)], 70.0)

	assert_gt(near.length(), far.length())
	assert_lte(near.length(), 1.0)


func test_separation_cancels_out_between_two_equal_neighbours() -> void:
	var push: Vector2 = FlockSteering.separation(
		Vector2.ZERO, [Vector2(40.0, 0.0), Vector2(-40.0, 0.0)], 70.0
	)

	assert_almost_eq(push, Vector2.ZERO)


func test_separation_resolves_two_sheep_on_the_same_spot() -> void:
	var push: Vector2 = FlockSteering.separation(Vector2(5.0, 5.0), [Vector2(5.0, 5.0)], 70.0)

	assert_gt(push.length(), 0.5, "some direction, at nearly full strength")


func test_cohesion_is_silent_near_the_flock() -> void:
	assert_eq(FlockSteering.cohesion(Vector2(100.0, 0.0), Vector2.ZERO, 280.0), Vector2.ZERO)


func test_cohesion_pulls_a_stray_sheep_back() -> void:
	var pull: Vector2 = FlockSteering.cohesion(Vector2(420.0, 0.0), Vector2.ZERO, 280.0)

	assert_lt(pull.x, 0.0, "toward the center")
	assert_almost_eq(pull.length(), 0.5, 0.001, "halfway between one and two radii")


func test_cohesion_is_never_stronger_than_one() -> void:
	var pull: Vector2 = FlockSteering.cohesion(Vector2(5000.0, 0.0), Vector2.ZERO, 280.0)

	assert_almost_eq(pull.length(), 1.0)


func test_obstacle_avoidance_pushes_away_from_a_near_obstacle() -> void:
	var push: Vector2 = FlockSteering.obstacle_avoidance(Vector2(70.0, 150.0), [SQUARE], 60.0)

	assert_lt(push.x, 0.0, "away from the square on the right")
	assert_almost_eq(push.y, 0.0)


func test_obstacle_avoidance_ignores_far_obstacles() -> void:
	assert_eq(FlockSteering.obstacle_avoidance(Vector2(0.0, 150.0), [SQUARE], 60.0), Vector2.ZERO)


func test_obstacle_avoidance_pushes_out_of_an_obstacle() -> void:
	# Inside, close to the left edge: the way out is to the left.
	var push: Vector2 = FlockSteering.obstacle_avoidance(Vector2(110.0, 150.0), [SQUARE], 60.0)

	assert_almost_eq(push, Vector2.LEFT, 0.001)


func test_obstacle_avoidance_adds_up_over_obstacles() -> void:
	var other: PackedVector2Array = [
		Vector2(-100.0, 100.0), Vector2(0.0, 100.0), Vector2(0.0, 200.0), Vector2(-100.0, 200.0)
	]

	# Exactly between two squares: their pushes cancel.
	var push: Vector2 = FlockSteering.obstacle_avoidance(Vector2(50.0, 150.0), [SQUARE, other], 60.0)

	assert_almost_eq(push, Vector2.ZERO)


func test_border_avoidance_is_silent_in_the_open() -> void:
	assert_eq(FlockSteering.border_avoidance(Vector2(500.0, 400.0), AREA, 70.0), Vector2.ZERO)


func test_border_avoidance_pushes_back_from_each_edge() -> void:
	assert_gt(FlockSteering.border_avoidance(Vector2(20.0, 400.0), AREA, 70.0).x, 0.0, "left")
	assert_lt(FlockSteering.border_avoidance(Vector2(980.0, 400.0), AREA, 70.0).x, 0.0, "right")
	assert_gt(FlockSteering.border_avoidance(Vector2(500.0, 20.0), AREA, 70.0).y, 0.0, "top")
	assert_lt(FlockSteering.border_avoidance(Vector2(500.0, 780.0), AREA, 70.0).y, 0.0, "bottom")


func test_border_avoidance_is_strongest_beyond_the_edge() -> void:
	var inside: Vector2 = FlockSteering.border_avoidance(Vector2(35.0, 400.0), AREA, 70.0)
	var outside: Vector2 = FlockSteering.border_avoidance(Vector2(-35.0, 400.0), AREA, 70.0)

	assert_almost_eq(inside.x, 0.5)
	assert_gt(outside.x, 1.0)


func test_nearest_point_on_an_outline() -> void:
	assert_almost_eq(
		FlockSteering.nearest_point_on_outline(Vector2(50.0, 150.0), SQUARE), Vector2(100.0, 150.0)
	)
	assert_almost_eq(
		FlockSteering.nearest_point_on_outline(Vector2(300.0, 300.0), SQUARE), Vector2(200.0, 200.0)
	)

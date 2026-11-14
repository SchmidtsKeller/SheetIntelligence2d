extends TestCase
## The shared sheep motion model: limited acceleration and turn rate.

const STEP: float = 1.0 / 60.0
const MAX_SPEED: float = 180.0
const ACCELERATION: float = 900.0
const TURN_RATE: float = PI * 3.0


func test_a_sheep_reaches_full_speed_after_max_speed_over_acceleration() -> void:
	var motion: SheepMotion = SheepMotion.new()
	var steps: int = roundi(MAX_SPEED / ACCELERATION / STEP)

	for _i: int in steps - 1:
		motion.step(Vector2.RIGHT, MAX_SPEED, ACCELERATION, TURN_RATE, STEP)
	assert_lt(motion.speed, MAX_SPEED)
	motion.step(Vector2.RIGHT, MAX_SPEED, ACCELERATION, TURN_RATE, STEP)
	assert_almost_eq(motion.speed, MAX_SPEED)


func test_speed_never_exceeds_the_maximum() -> void:
	var motion: SheepMotion = SheepMotion.new()

	for _i: int in 120:
		var velocity: Vector2 = motion.step(Vector2(5.0, 3.0), MAX_SPEED, ACCELERATION, TURN_RATE, STEP)
		assert_lte(velocity.length(), MAX_SPEED + 0.001)


func test_a_partial_wish_walks_at_partial_speed() -> void:
	var motion: SheepMotion = SheepMotion.new()

	for _i: int in 60:
		motion.step(Vector2(0.5, 0.0), MAX_SPEED, ACCELERATION, TURN_RATE, STEP)

	assert_almost_eq(motion.speed, MAX_SPEED * 0.5)


func test_a_stopping_sheep_slows_down_and_keeps_its_heading() -> void:
	var motion: SheepMotion = SheepMotion.new()
	for _i: int in 60:
		motion.step(Vector2.DOWN, MAX_SPEED, ACCELERATION, TURN_RATE, STEP)
	var heading: float = motion.heading

	motion.step(Vector2.ZERO, MAX_SPEED, ACCELERATION, TURN_RATE, STEP)
	assert_almost_eq(motion.speed, MAX_SPEED - ACCELERATION * STEP)
	for _i: int in 60:
		motion.step(Vector2.ZERO, MAX_SPEED, ACCELERATION, TURN_RATE, STEP)

	assert_eq(motion.speed, 0.0)
	assert_almost_eq(motion.heading, heading)


func test_turning_is_limited_by_the_turn_rate() -> void:
	var motion: SheepMotion = SheepMotion.new()

	motion.step(Vector2.LEFT, MAX_SPEED, ACCELERATION, TURN_RATE, STEP)

	assert_almost_eq(absf(motion.heading), TURN_RATE * STEP)


func test_a_sheep_ends_up_facing_where_it_wants_to_go() -> void:
	var motion: SheepMotion = SheepMotion.new()

	for _i: int in 60:
		motion.step(Vector2.UP, MAX_SPEED, ACCELERATION, TURN_RATE, STEP)

	assert_almost_eq(motion.heading, Vector2.UP.angle())
	assert_almost_eq(motion.get_velocity(), Vector2.UP * MAX_SPEED, 0.01)

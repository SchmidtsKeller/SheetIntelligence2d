extends TestCase
## The interpolation buffer shows entities smoothly between received states.

var _buffer: InterpolationBuffer


func before_each() -> void:
	_buffer = InterpolationBuffer.new()


func test_empty_buffer_has_nothing_to_show() -> void:
	assert_true(_buffer.is_empty())
	assert_eq(_buffer.sample_position(1.0), Vector2.ZERO)
	assert_eq(_buffer.sample_rotation(1.0), 0.0)


func test_position_between_two_samples_is_interpolated() -> void:
	_buffer.push(1.0, Vector2(0.0, 0.0), 0.0)
	_buffer.push(2.0, Vector2(100.0, 40.0), 0.0)

	assert_almost_eq(_buffer.sample_position(1.5), Vector2(50.0, 20.0))
	assert_almost_eq(_buffer.sample_position(1.25), Vector2(25.0, 10.0))


func test_sample_times_hit_the_samples_exactly() -> void:
	_buffer.push(1.0, Vector2(10.0, 0.0), 0.0)
	_buffer.push(2.0, Vector2(20.0, 0.0), 0.0)
	_buffer.push(3.0, Vector2(40.0, 0.0), 0.0)

	assert_almost_eq(_buffer.sample_position(1.0), Vector2(10.0, 0.0))
	assert_almost_eq(_buffer.sample_position(2.0), Vector2(20.0, 0.0))
	assert_almost_eq(_buffer.sample_position(2.5), Vector2(30.0, 0.0))


func test_before_the_first_sample_the_first_position_is_held() -> void:
	_buffer.push(5.0, Vector2(7.0, 8.0), 1.0)
	_buffer.push(6.0, Vector2(9.0, 8.0), 2.0)

	assert_eq(_buffer.sample_position(0.0), Vector2(7.0, 8.0))
	assert_eq(_buffer.sample_rotation(0.0), 1.0)


func test_after_the_last_sample_the_course_is_kept_for_a_moment() -> void:
	_buffer.max_extrapolation = 0.1
	_buffer.push(1.0, Vector2(0.0, 0.0), 0.0)
	_buffer.push(1.05, Vector2(10.0, 0.0), 0.0)

	# 200 px/s for 0.05 s.
	assert_almost_eq(_buffer.sample_position(1.1), Vector2(20.0, 0.0), 0.001)


func test_extrapolation_stops_at_its_limit() -> void:
	_buffer.max_extrapolation = 0.1
	_buffer.push(1.0, Vector2(0.0, 0.0), 0.0)
	_buffer.push(1.05, Vector2(10.0, 0.0), 0.0)

	var at_limit: Vector2 = _buffer.sample_position(1.15)
	assert_almost_eq(at_limit, Vector2(30.0, 0.0), 0.001)
	assert_almost_eq(_buffer.sample_position(5.0), at_limit, 0.001, "no packets: the entity stops")


func test_extrapolation_can_be_switched_off() -> void:
	_buffer.max_extrapolation = 0.0
	_buffer.push(1.0, Vector2(0.0, 0.0), 0.0)
	_buffer.push(1.05, Vector2(10.0, 0.0), 0.0)

	assert_eq(_buffer.sample_position(2.0), Vector2(10.0, 0.0))


func test_a_single_sample_is_simply_held() -> void:
	_buffer.push(1.0, Vector2(3.0, 4.0), 0.5)

	assert_eq(_buffer.sample_position(9.0), Vector2(3.0, 4.0))
	assert_eq(_buffer.sample_rotation(9.0), 0.5)


func test_rotation_takes_the_shorter_way_around() -> void:
	_buffer.push(1.0, Vector2.ZERO, deg_to_rad(170.0))
	_buffer.push(2.0, Vector2.ZERO, deg_to_rad(-170.0))

	var halfway: float = wrapf(rad_to_deg(_buffer.sample_rotation(1.5)), 0.0, 360.0)
	assert_almost_eq(halfway, 180.0, 0.01, "through 180°, not back through 0°")


func test_rotation_is_not_extrapolated() -> void:
	_buffer.push(1.0, Vector2.ZERO, 0.0)
	_buffer.push(1.05, Vector2.ZERO, 1.0)

	assert_eq(_buffer.sample_rotation(1.1), 1.0)


func test_late_and_duplicate_samples_are_ignored() -> void:
	_buffer.push(2.0, Vector2(20.0, 0.0), 0.0)
	_buffer.push(1.0, Vector2(999.0, 0.0), 0.0)
	_buffer.push(2.0, Vector2(999.0, 0.0), 0.0)

	assert_eq(_buffer.size(), 1)
	assert_eq(_buffer.sample_position(2.0), Vector2(20.0, 0.0))


func test_a_teleport_jumps_instead_of_sliding() -> void:
	_buffer.teleport_distance = 400.0
	_buffer.push(1.0, Vector2(0.0, 0.0), 0.0)
	_buffer.push(2.0, Vector2(2000.0, 0.0), 0.0)

	assert_eq(_buffer.sample_position(1.5), Vector2(0.0, 0.0), "stays until the new sample is due")
	assert_eq(_buffer.sample_position(2.0), Vector2(2000.0, 0.0))
	assert_eq(_buffer.sample_position(2.05), Vector2(2000.0, 0.0), "and does not fly on afterwards")


func test_old_samples_are_dropped() -> void:
	for index: int in InterpolationBuffer.MAX_SAMPLES + 10:
		_buffer.push(float(index), Vector2(index, 0.0), 0.0)

	assert_eq(_buffer.size(), InterpolationBuffer.MAX_SAMPLES)
	assert_eq(_buffer.get_latest_time(), float(InterpolationBuffer.MAX_SAMPLES + 9))
	assert_eq(_buffer.sample_position(0.0), Vector2(10.0, 0.0), "the oldest kept sample")


func test_clear_empties_the_buffer() -> void:
	_buffer.push(1.0, Vector2.ONE, 0.0)

	_buffer.clear()

	assert_true(_buffer.is_empty())
	assert_eq(_buffer.get_latest_time(), 0.0)


func test_motion_is_smooth_when_packets_arrive_unevenly() -> void:
	# An entity moving at a steady 200 px/s, sampled 20 times per second.
	# Rendering 0.1 s in the past must show steady motion as well.
	for tick: int in 20:
		var time: float = tick * 0.05
		_buffer.push(time, Vector2(200.0 * time, 0.0), 0.0)

	var previous: float = _buffer.sample_position(0.3).x
	for step: int in range(1, 30):
		var x: float = _buffer.sample_position(0.3 + step / 60.0).x
		assert_almost_eq(x - previous, 200.0 / 60.0, 0.001, "frame %d" % step)
		previous = x

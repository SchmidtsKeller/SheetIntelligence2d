extends TestCase
## The guest's estimate of the host's clock, which the round timer rests on.

var _sync: ClockSync


func before_each() -> void:
	_sync = ClockSync.new()


func after_each() -> void:
	_sync = null


func test_without_an_answer_the_clocks_are_taken_as_equal() -> void:
	assert_false(_sync.has_samples())
	assert_eq(_sync.get_offset(), 0.0)
	assert_eq(_sync.get_round_trip(), 0.0)


func test_a_symmetric_round_trip_gives_the_exact_offset() -> void:
	# The host's clock is 100 s ahead; each way takes 40 ms.
	_sync.add_sample(10.0, 110.04, 10.08)

	assert_true(_sync.has_samples())
	assert_almost_eq(_sync.get_offset(), 100.0, 0.000001)
	assert_almost_eq(_sync.get_round_trip(), 0.08, 0.000001)


func test_a_clock_that_is_behind_gives_a_negative_offset() -> void:
	_sync.add_sample(500.0, 20.01, 500.02)

	assert_almost_eq(_sync.get_offset(), -480.0, 0.000001)


func test_the_fastest_round_trip_counts() -> void:
	# Offset 100 s. The slow answers were held up on one way only.
	_sync.add_sample(10.0, 110.04, 10.30)
	_sync.add_sample(11.0, 111.02, 11.04)
	_sync.add_sample(12.0, 112.25, 12.27)

	assert_almost_eq(_sync.get_offset(), 100.0, 0.000001)
	assert_almost_eq(_sync.get_round_trip(), 0.04, 0.000001)


func test_the_error_is_at_most_half_the_round_trip() -> void:
	# Offset 100 s, 80 ms there and nothing back: the worst case.
	_sync.add_sample(10.0, 110.08, 10.08)

	assert_almost_eq(_sync.get_offset(), 100.0, 0.04 + 0.000001)


func test_old_answers_are_forgotten() -> void:
	_sync.add_sample(0.0, 100.0, 0.01)
	for index: int in ClockSync.WINDOW:
		var sent_at: float = 1.0 + index
		# The clocks have drifted: the offset is 101 s now.
		_sync.add_sample(sent_at, sent_at + 101.05, sent_at + 0.1)

	assert_almost_eq(_sync.get_offset(), 101.0, 0.000001)


func test_an_answer_from_the_future_is_ignored() -> void:
	_sync.add_sample(10.0, 50.0, 9.0)

	assert_false(_sync.has_samples())


func test_reset_forgets_everything() -> void:
	_sync.add_sample(10.0, 110.04, 10.08)

	_sync.reset()

	assert_false(_sync.has_samples())
	assert_eq(_sync.get_offset(), 0.0)


func test_large_clock_values_keep_their_precision() -> void:
	# Three days of uptime on one device, seconds on the other.
	var sent_at: float = 259200.123456
	_sync.add_sample(sent_at, 12.5, sent_at + 0.05)

	assert_almost_eq(sent_at + 0.05 + _sync.get_offset(), 12.525, 0.000001)

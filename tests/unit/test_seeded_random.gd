extends TestCase
## SeededRandom yields the same numbers for the same seed on every device.

## Reference sequences, computed independently of Godot (Python, same algorithm).
const REFERENCE: Dictionary[int, Array] = {
	0: [2462723854, 1020716019, 454327756, 1275600319, 1215922603],
	42: [939911724, 3948730756, 321366731, 3317318717, 527392959],
	-1: [920564995, 4230986166, 697614773, 1778835764, 280495159],
	123456789: [1573771921, 319883699, 2742014374, 1324369493, 2217150806],
}


func test_sequences_match_the_reference() -> void:
	for initial_seed: int in REFERENCE:
		var random: SeededRandom = SeededRandom.new(initial_seed)
		for expected: int in REFERENCE[initial_seed]:
			assert_eq(random.next_u32(), expected, "seed %d" % initial_seed)


func test_only_the_low_32_bits_of_the_seed_count() -> void:
	var low: SeededRandom = SeededRandom.new(7)
	var high: SeededRandom = SeededRandom.new((1 << 40) + 7)

	assert_eq(high.next_u32(), low.next_u32())


func test_generators_do_not_share_state() -> void:
	var first: SeededRandom = SeededRandom.new(42)
	var second: SeededRandom = SeededRandom.new(42)

	first.next_u32()
	first.next_u32()

	assert_eq(second.next_u32(), REFERENCE[42][0])
	assert_eq(first.next_u32(), REFERENCE[42][2])


func test_numbers_stay_within_32_bits() -> void:
	var random: SeededRandom = SeededRandom.new(-12345)

	for _i: int in 1000:
		var value: int = random.next_u32()
		assert_true(value >= 0 and value <= 0xFFFFFFFF, "%d is a 32-bit number" % value)


func test_next_int_stays_below_the_bound_and_reaches_every_value() -> void:
	var random: SeededRandom = SeededRandom.new(3)
	var seen: Dictionary[int, bool] = {}

	for _i: int in 600:
		var value: int = random.next_int(6)
		assert_true(value >= 0 and value < 6, "%d is in 0..5" % value)
		seen[value] = true

	assert_eq(seen.size(), 6)


func test_next_int_range_includes_both_ends() -> void:
	var random: SeededRandom = SeededRandom.new(5)
	var seen: Dictionary[int, bool] = {}

	for _i: int in 400:
		var value: int = random.next_int_range(-2, 2)
		assert_true(value >= -2 and value <= 2, "%d is in -2..2" % value)
		seen[value] = true

	assert_eq(seen.size(), 5)


func test_a_bound_below_one_fails_loudly() -> void:
	var random: SeededRandom = SeededRandom.new(1)
	expect_error("bound must be at least 1")

	assert_eq(random.next_int(0), 0)

extends TestCase
## Which slot of a round belongs to the Monster, and the seeds of the others.

const SLOTS: int = 11


func test_monster_slot_is_one_of_the_slots() -> void:
	for round_seed: int in 200:
		var slot: int = RoundCast.monster_slot(round_seed, SLOTS)
		assert_gte(slot, 0)
		assert_lt(slot, SLOTS)


func test_monster_slot_follows_from_the_round_seed_alone() -> void:
	for round_seed: int in [0, 1, 7, 123456, -5]:
		assert_eq(
			RoundCast.monster_slot(round_seed, SLOTS), RoundCast.monster_slot(round_seed, SLOTS)
		)


func test_monster_takes_every_slot_about_equally_often() -> void:
	var counts: PackedInt32Array = []
	counts.resize(SLOTS)
	for round_seed: int in 2200:
		counts[RoundCast.monster_slot(round_seed, SLOTS)] += 1

	# 200 expected per slot; nowhere near never or always.
	for slot: int in SLOTS:
		assert_gt(counts[slot], 130, "slot %d" % slot)
		assert_lt(counts[slot], 270, "slot %d" % slot)


func test_monster_slot_does_not_follow_the_seed_in_step() -> void:
	# Neighbouring round seeds must not simply give neighbouring slots.
	var in_step: int = 0
	for round_seed: int in 100:
		var here: int = RoundCast.monster_slot(round_seed, SLOTS)
		var next: int = RoundCast.monster_slot(round_seed + 1, SLOTS)
		in_step += int(next == (here + 1) % SLOTS)

	assert_lt(in_step, 30)


func test_every_slot_gets_a_visual_seed() -> void:
	var seeds: PackedInt64Array = RoundCast.visual_seeds(42, SLOTS)

	assert_eq(seeds.size(), SLOTS)
	assert_eq(seeds, RoundCast.visual_seeds(42, SLOTS), "the same round looks the same")
	assert_ne(seeds, RoundCast.visual_seeds(43, SLOTS), "another round looks different")


func test_behaviour_seeds_differ_between_slots_and_rounds() -> void:
	var seen: Dictionary[int, bool] = {}
	for slot: int in SLOTS:
		seen[RoundCast.behaviour_seed(42, slot)] = true

	assert_eq(seen.size(), SLOTS, "every sheep has a mind of its own")
	assert_eq(RoundCast.behaviour_seed(42, 3), RoundCast.behaviour_seed(42, 3))
	assert_ne(RoundCast.behaviour_seed(42, 3), RoundCast.behaviour_seed(43, 3))

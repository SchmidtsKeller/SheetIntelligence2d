extends TestCase
## Sheep looks: deterministic per seed, and no near-twins within a round
## (GDD §3.3, §9.4).

const CATALOG_PATH: String = "res://entities/sheep/appearance/sheep_appearance_catalog.tres"

## Fingerprints for the fixture catalog, computed independently of Godot
## (Python, same algorithm). Equal results here and in the Web build mean both
## devices see the same sheep.
const FIXTURE_FINGERPRINTS: Dictionary[int, String] = {
	0: "0.0,1.1,0.1|1024x972",
	1: "1.-1,-1.-1,0.1|983x1083",
	42: "0.1,-1.-1,0.1|977x921",
	4000000000: "0.2,-1.-1,0.1|996x1100",
}
const FIXTURE_ROUND_7_SEEDS: Array[int] = [588686121, 2372217166, 2898530240, 1278588126]

var _catalog: SheepAppearanceCatalog


func before_all() -> void:
	_catalog = load(CATALOG_PATH) as SheepAppearanceCatalog


# --- Determinism -------------------------------------------------------------------

func test_fingerprints_match_the_reference() -> void:
	var fixture: SheepAppearanceCatalog = _fixture_catalog()

	for visual_seed: int in FIXTURE_FINGERPRINTS:
		var appearance: SheepAppearance = SheepAppearanceGenerator.generate(visual_seed, fixture)
		assert_eq(appearance.fingerprint(), FIXTURE_FINGERPRINTS[visual_seed], "seed %d" % visual_seed)


func test_round_seeds_match_the_reference() -> void:
	var seeds: PackedInt64Array = SheepAppearanceGenerator.generate_round_seeds(7, 4, _fixture_catalog())

	assert_eq(Array(seeds), FIXTURE_ROUND_7_SEEDS)


func test_the_same_seed_gives_the_same_look() -> void:
	for visual_seed: int in [0, 1, 99, 123456789, 4294967295]:
		var first: SheepAppearance = SheepAppearanceGenerator.generate(visual_seed, _catalog)
		var second: SheepAppearance = SheepAppearanceGenerator.generate(visual_seed, _catalog)
		assert_eq(first.fingerprint(), second.fingerprint())
		assert_eq(first.visual_seed, visual_seed)


func test_the_same_round_seed_gives_the_same_sheep() -> void:
	var first: PackedInt64Array = SheepAppearanceGenerator.generate_round_seeds(2024, 11, _catalog)
	var second: PackedInt64Array = SheepAppearanceGenerator.generate_round_seeds(2024, 11, _catalog)

	assert_eq(first, second)
	assert_eq(first.size(), 11)


func test_the_monster_seed_is_drawn_like_any_other() -> void:
	# Drawing one more seed only appends to the sequence, so the last of 11
	# seeds (the Monster's, if the round gives it that one) is no special case.
	var flock: PackedInt64Array = SheepAppearanceGenerator.generate_round_seeds(55, 10, _catalog)
	var with_monster: PackedInt64Array = SheepAppearanceGenerator.generate_round_seeds(55, 11, _catalog)

	assert_eq(with_monster.slice(0, 10), flock)


# --- Distinctness ------------------------------------------------------------------

func test_no_two_sheep_of_a_round_look_alike() -> void:
	var count: int = Services.config.flock_size + 1

	for round_seed: int in 300:
		var appearances: Array[SheepAppearance] = _round(round_seed, count)
		for i: int in count:
			for j: int in range(i + 1, count):
				var difference: int = appearances[i].difference(appearances[j])
				if difference < _catalog.min_difference:
					fail_test("round %d: sheep %d and %d differ in only %d layers" % [round_seed, i, j, difference])
					return
	pass_test()


func test_a_catalog_too_small_for_distinct_sheep_fails_loudly() -> void:
	var tiny: SheepAppearanceCatalog = SheepAppearanceCatalog.new()
	tiny.slots.append(_slot(0, [_part(1)]))
	expect_error("cannot make 3 sheep that differ")

	var seeds: PackedInt64Array = SheepAppearanceGenerator.generate_round_seeds(1, 3, tiny)

	assert_eq(seeds.size(), 3)


func test_difference_counts_layers_with_another_part_or_tint() -> void:
	var a: SheepAppearance = _appearance([0, 1, -1], [2, -1, -1])
	var same_part_other_tint: SheepAppearance = _appearance([0, 1, -1], [1, -1, -1])
	var two_changes: SheepAppearance = _appearance([1, 1, 0], [-1, -1, -1])

	assert_eq(a.difference(a), 0)
	assert_eq(a.difference(same_part_other_tint), 1)
	assert_eq(a.difference(two_changes), 2)
	assert_eq(two_changes.difference(a), 2)


func test_proportions_do_not_count_as_a_difference() -> void:
	var a: SheepAppearance = _appearance([0], [0])
	var b: SheepAppearance = _appearance([0], [0])
	b.length_permille = 1080

	assert_eq(a.difference(b), 0)
	assert_ne(a.fingerprint(), b.fingerprint())


# --- Shipped catalog ---------------------------------------------------------------

func test_shipped_catalog_is_complete() -> void:
	if not assert_not_null(_catalog, "the shipped catalog loads"):
		return
	assert_gt(_catalog.slots.size(), 0)
	for slot: SheepAppearanceSlot in _catalog.slots:
		assert_gt(slot.parts.size(), 0, "slot '%s' has parts" % slot.id)
		for part: SheepAppearancePart in slot.parts:
			assert_not_null(part.texture, "part '%s' has a texture" % part.id)
	assert_lte(_catalog.min_length_permille, _catalog.max_length_permille)
	assert_lte(_catalog.min_width_permille, _catalog.max_width_permille)


func test_generated_looks_stay_inside_the_catalog() -> void:
	for visual_seed: int in 500:
		var appearance: SheepAppearance = SheepAppearanceGenerator.generate(visual_seed * 7919, _catalog)
		for slot_index: int in _catalog.slots.size():
			var slot: SheepAppearanceSlot = _catalog.slots[slot_index]
			var part_index: int = appearance.part_indices[slot_index]
			if part_index == SheepAppearance.NONE:
				assert_gt(slot.empty_chance_percent, 0, "only optional layers stay empty")
				continue
			assert_lt(part_index, slot.parts.size())
			var tint_index: int = appearance.tint_indices[slot_index]
			assert_lt(tint_index, slot.parts[part_index].tints.size())
		assert_true(appearance.length_permille >= _catalog.min_length_permille and appearance.length_permille <= _catalog.max_length_permille)
		assert_true(appearance.width_permille >= _catalog.min_width_permille and appearance.width_permille <= _catalog.max_width_permille)


# --- Helpers -----------------------------------------------------------------------

func _round(round_seed: int, count: int) -> Array[SheepAppearance]:
	var appearances: Array[SheepAppearance] = []
	for visual_seed: int in SheepAppearanceGenerator.generate_round_seeds(round_seed, count, _catalog):
		appearances.append(SheepAppearanceGenerator.generate(visual_seed, _catalog))
	return appearances


## Three layers: a required one with a tinted and an untinted part, an
## optional one, and a required head layer with two tints.
static func _fixture_catalog() -> SheepAppearanceCatalog:
	var catalog: SheepAppearanceCatalog = SheepAppearanceCatalog.new()
	catalog.slots.append(_slot(0, [_part(3), _part(0)]))
	catalog.slots.append(_slot(50, [_part(0), _part(2)]))
	var head: SheepAppearanceSlot = _slot(0, [_part(2)])
	head.anchor = SheepAppearanceSlot.Anchor.HEAD
	catalog.slots.append(head)
	catalog.min_length_permille = 950
	catalog.max_length_permille = 1050
	catalog.min_width_permille = 900
	catalog.max_width_permille = 1100
	catalog.min_difference = 2
	return catalog


static func _slot(empty_chance: int, parts: Array[SheepAppearancePart]) -> SheepAppearanceSlot:
	var slot: SheepAppearanceSlot = SheepAppearanceSlot.new()
	slot.empty_chance_percent = empty_chance
	slot.parts = parts
	return slot


static func _part(tint_count: int) -> SheepAppearancePart:
	var part: SheepAppearancePart = SheepAppearancePart.new()
	for i: int in tint_count:
		part.tints.append(Color(float(i) / maxf(tint_count, 1), 0.5, 0.5))
	return part


static func _appearance(parts: Array[int], tints: Array[int]) -> SheepAppearance:
	var appearance: SheepAppearance = SheepAppearance.new()
	appearance.part_indices = PackedInt32Array(parts)
	appearance.tint_indices = PackedInt32Array(tints)
	return appearance

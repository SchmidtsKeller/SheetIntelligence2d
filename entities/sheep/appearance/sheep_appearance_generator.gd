@abstract
class_name SheepAppearanceGenerator
extends RefCounted
## Turns seeds into sheep looks (GDD §3.3, §9.4).
##
## Both devices derive the same looks from the same seeds, because only
## [SeededRandom] and integer arithmetic are involved. The Monster's seed is
## one of the seeds of a round like any other (GDD §3.2), so nothing in its
## look sets it apart.

## Candidates tried per sheep before [method generate_round_seeds] gives up on
## the minimum difference.
const MAX_ATTEMPTS_PER_SHEEP: int = 1000


## The look for [param visual_seed] in [param catalog].
static func generate(visual_seed: int, catalog: SheepAppearanceCatalog) -> SheepAppearance:
	var random: SeededRandom = SeededRandom.new(visual_seed)
	var appearance: SheepAppearance = SheepAppearance.new()
	appearance.visual_seed = visual_seed
	for slot: SheepAppearanceSlot in catalog.slots:
		var part_index: int = SheepAppearance.NONE
		var tint_index: int = SheepAppearance.NONE
		var empty: bool = slot.empty_chance_percent > 0 and random.next_int(100) < slot.empty_chance_percent
		if not empty and not slot.parts.is_empty():
			part_index = random.next_int(slot.parts.size())
			var tints: Array[Color] = slot.parts[part_index].tints
			if not tints.is_empty():
				tint_index = random.next_int(tints.size())
		appearance.part_indices.append(part_index)
		appearance.tint_indices.append(tint_index)
	appearance.length_permille = random.next_int_range(catalog.min_length_permille, catalog.max_length_permille)
	appearance.width_permille = random.next_int_range(catalog.min_width_permille, catalog.max_width_permille)
	return appearance


## The visual seeds for the [param count] sheep-like entities of one round
## (the NPC sheep and the Monster), derived from [param round_seed]. Any two of
## them differ in at least [member SheepAppearanceCatalog.min_difference]
## layers. A catalog too small for that fails loudly and still returns
## [param count] seeds.
static func generate_round_seeds(round_seed: int, count: int, catalog: SheepAppearanceCatalog) -> PackedInt64Array:
	var random: SeededRandom = SeededRandom.new(round_seed)
	var seeds: PackedInt64Array = []
	var chosen: Array[SheepAppearance] = []
	var attempts: int = 0
	while seeds.size() < count:
		var candidate: int = random.next_u32()
		var appearance: SheepAppearance = generate(candidate, catalog)
		attempts += 1
		var distinct: bool = _differs_from_all(appearance, chosen, catalog.min_difference)
		if not distinct and attempts < MAX_ATTEMPTS_PER_SHEEP:
			continue
		if not distinct:
			push_error(
				"SheepAppearanceGenerator: the catalog cannot make %d sheep that differ in %d layers."
				% [count, catalog.min_difference]
			)
		seeds.append(candidate)
		chosen.append(appearance)
		attempts = 0
	return seeds


static func _differs_from_all(appearance: SheepAppearance, others: Array[SheepAppearance], min_difference: int) -> bool:
	for other: SheepAppearance in others:
		if appearance.difference(other) < min_difference:
			return false
	return true

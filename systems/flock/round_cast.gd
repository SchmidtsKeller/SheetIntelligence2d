@abstract class_name RoundCast
extends RefCounted
## Who stands where when a round starts: the sheep-like entities of a round
## and which of them is the Monster.
##
## A round has [code]flock_size + 1[/code] sheep-like entities: the NPC sheep
## and the Monster. The arena gives that many start positions and the
## appearance generator that many visual seeds, all drawn alike (GDD §3.2:
## the Monster gets its own seed, generated the same way). One of these slots
## belongs to the Monster. Which one follows from the round seed alone, so
## the flock (which leaves the slot free) and the Monster (which takes it)
## agree without talking to each other.

const SHEEP_CATALOG: SheepAppearanceCatalog = preload(
	"res://entities/sheep/appearance/sheep_appearance_catalog.tres"
)
## Mixed into the round seed, so the Monster's slot is independent of the
## other numbers the same seed gives.
const MONSTER_SLOT_SALT: int = 0x4D0A_57E2
## Mixed into the round seed for the flock's behaviour.
const BEHAVIOUR_SALT: int = 0x0B3A_A11D


## The slot of the Monster among [param slot_count] sheep-like entities.
static func monster_slot(round_seed: int, slot_count: int) -> int:
	return SeededRandom.new(round_seed ^ MONSTER_SLOT_SALT).next_int(slot_count)


## The visual seed of every slot.
static func visual_seeds(round_seed: int, slot_count: int) -> PackedInt64Array:
	return SheepAppearanceGenerator.generate_round_seeds(round_seed, slot_count, SHEEP_CATALOG)


## The seed of the behaviour of the sheep in [param slot].
static func behaviour_seed(round_seed: int, slot: int) -> int:
	return SeededRandom.new((round_seed ^ BEHAVIOUR_SALT) + slot * 7919).next_u32()

@abstract
class_name PerkIds
extends RefCounted
## Identifiers of all perks (GDD §4). Each player picks exactly one per round.
##
## Ids are [StringName]s so the perk catalog can stay data-driven: a perk
## resource names its id, and nothing has to be recompiled to add one.

## No perk selected.
const NONE: StringName = &""

# --- Sheepherder pool (GDD §4.1) ---------------------------------------------
## Cone angle 60° → 90° at the normal length.
const WIDE_FLASHLIGHT: StringName = &"wide_flashlight"
## Cone length 350 px → 429 px at the normal angle.
const LONG_FLASHLIGHT: StringName = &"long_flashlight"
## Firearm reload 4.0 s → 2.0 s.
const FASTER_RELOAD: StringName = &"faster_reload"
## Companion: barks and points at the Monster while it is eating.
const SHEPHERD_DOG: StringName = &"shepherd_dog"
## A hidden 4th bullet.
const SPARE_BULLET: StringName = &"spare_bullet"

# --- Monster pool (GDD §4.2) -------------------------------------------------
## Eating animation 1.0 s → 0.5 s.
const FASTER_CONSUMPTION: StringName = &"faster_consumption"
## Active: invisible for up to 5 s.
const INVISIBILITY: StringName = &"invisibility"
## Companion / active: a bat shrinks the Sheepherder's flashlight cone.
const ALLIED_BAT: StringName = &"allied_bat"

const SHEEPHERDER_POOL: Array[StringName] = [
	WIDE_FLASHLIGHT,
	LONG_FLASHLIGHT,
	FASTER_RELOAD,
	SHEPHERD_DOG,
	SPARE_BULLET,
]

const MONSTER_POOL: Array[StringName] = [
	FASTER_CONSUMPTION,
	INVISIBILITY,
	ALLIED_BAT,
]


## The perks a player with [param role] may choose from.
static func pool_for(role: GameEnums.Role) -> Array[StringName]:
	match role:
		GameEnums.Role.SHEEPHERDER:
			return SHEEPHERDER_POOL
		GameEnums.Role.MONSTER:
			return MONSTER_POOL
		_:
			return []


## Whether [param perk_id] belongs to the pool of [param role].
static func is_valid_for(role: GameEnums.Role, perk_id: StringName) -> bool:
	return pool_for(role).has(perk_id)

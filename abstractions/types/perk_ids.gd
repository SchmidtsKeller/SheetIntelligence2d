@abstract class_name PerkIds
extends RefCounted
## Identifiers of all perks (GDD §4). Each player picks exactly one per round.
##
## Ids are [StringName]s so the perk catalog can stay data-driven: a perk
## resource names its id, and nothing has to be recompiled to add one. The
## catalog ([PerkCatalog]) also says which role's pool each perk is in; the
## constants here are for code that has to name a particular perk.

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

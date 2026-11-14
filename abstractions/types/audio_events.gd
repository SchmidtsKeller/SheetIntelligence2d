@abstract class_name AudioEvents
extends RefCounted
## Identifiers of all sound events (GDD §7.2).
##
## Gameplay code names an event and a world position; [AudioService] decides
## which sound plays and how far it carries. An event sounds the same whether
## an NPC sheep or the Monster causes it (GDD §3.2, "No Built-in Tell").

## A sheep bleats ("mähen").
const BLEAT: StringName = &"bleat"
## A sheep-like entity moves through grass.
const GRASS_MOVE: StringName = &"grass_move"
## A sheep-like entity eats grass.
const GRAZE: StringName = &"graze"
## The Sheepherder rings the bell.
const BELL: StringName = &"bell"
## The Sheepherder fires the firearm.
const GUNSHOT: StringName = &"gunshot"
## The firearm finished reloading.
const RELOAD_CLICK: StringName = &"reload_click"
## The Monster eats a sheep or the Sheepherder.
const EAT: StringName = &"eat"
## The Monster evolves into the spider.
const SPIDER_SCREECH: StringName = &"spider_screech"
## The Shepherd Dog barks at the eating Monster.
const DOG_BARK: StringName = &"dog_bark"
## The Allied Bat harasses the Sheepherder.
const BAT: StringName = &"bat"

const ALL: Array[StringName] = [
	BLEAT,
	GRASS_MOVE,
	GRAZE,
	BELL,
	GUNSHOT,
	RELOAD_CLICK,
	EAT,
	SPIDER_SCREECH,
	DOG_BARK,
	BAT,
]

## Hearing-range class per event. The GDD (§5) classifies grass movement as
## quiet, bleating / eating / barking as loud, and bell / gunshot as whole map.
## The other four are assumptions until the audio task (#10) settles them.
const RANGE_CLASS: Dictionary[StringName, GameEnums.HearingRange] = {
	BLEAT: GameEnums.HearingRange.LOUD,
	GRASS_MOVE: GameEnums.HearingRange.QUIET,
	GRAZE: GameEnums.HearingRange.QUIET,  # assumption
	BELL: GameEnums.HearingRange.WHOLE_MAP,
	GUNSHOT: GameEnums.HearingRange.WHOLE_MAP,
	RELOAD_CLICK: GameEnums.HearingRange.QUIET,  # assumption
	EAT: GameEnums.HearingRange.LOUD,
	SPIDER_SCREECH: GameEnums.HearingRange.WHOLE_MAP,  # assumption (see #16)
	DOG_BARK: GameEnums.HearingRange.LOUD,
	BAT: GameEnums.HearingRange.LOUD,  # assumption
}


## The hearing-range class of [param event_id]; quiet for unknown events.
static func range_class_of(event_id: StringName) -> GameEnums.HearingRange:
	return RANGE_CLASS.get(event_id, GameEnums.HearingRange.QUIET)

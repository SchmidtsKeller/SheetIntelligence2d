@abstract class_name AudioEvents
extends RefCounted
## Identifiers of all sound events (GDD §7.2).
##
## Gameplay code names an event and a world position; [AudioService] decides
## which sound plays and how far it carries. An event sounds the same whether
## an NPC sheep or the Monster causes it (GDD §3.2, "No Built-in Tell").
##
## [constant ALL] are sounds in the world, each with a hearing range.
## [constant CUES] are not placed in the world ([method AudioService.play_ui]):
## menus, the round's flow and messages for one player only.
## [constant AMBIENCE] are the layers of the night's background
## ([method AudioService.set_ambience]).

## A sheep bleats ("mähen").
const BLEAT: StringName = &"bleat"
## A sheep-like entity moves through grass.
const GRASS_MOVE: StringName = &"grass_move"
## A sheep-like entity moves through grass faster than a sheep can: the
## Monster sprinting. Louder than walking. The spider has [constant SPIDER_MOVE].
const GRASS_RUN: StringName = &"grass_run"
## A sheep-like entity eats grass.
const GRAZE: StringName = &"graze"
## The Sheepherder rings the bell.
const BELL: StringName = &"bell"
## The Sheepherder walks.
const HERDER_STEP: StringName = &"herder_step"
## The Sheepherder fires the firearm.
const GUNSHOT: StringName = &"gunshot"
## The firearm finished reloading. Only the Sheepherder's own player hears it:
## after the third shot it would tell the Monster about the Spare Bullet.
const RELOAD_CLICK: StringName = &"reload_click"
## Fire was pressed with no bullet left. Only the Sheepherder's own player
## hears it, for the same reason as the reload click.
const EMPTY_CLICK: StringName = &"empty_click"
## A bullet stops in an obstacle or the arena's fence (never in a creature).
const BULLET_IMPACT: StringName = &"bullet_impact"
## The Monster kills the Sheepherder.
const HERDER_DEATH: StringName = &"herder_death"
## The Monster eats a sheep or the Sheepherder.
const EAT: StringName = &"eat"
## The Monster evolves into the spider.
const SPIDER_SCREECH: StringName = &"spider_screech"
## The spider moves.
const SPIDER_MOVE: StringName = &"spider_move"
## The Sheepherder shoots the Monster.
const MONSTER_DEATH: StringName = &"monster_death"
## The Shepherd Dog barks at the eating Monster.
const DOG_BARK: StringName = &"dog_bark"
## The Allied Bat reaches the Sheepherder.
const BAT: StringName = &"bat"
## The Allied Bat's wings while it flies.
const BAT_WINGS: StringName = &"bat_wings"
## A torch is lit.
const TORCH_IGNITE: StringName = &"torch_ignite"
## A lit torch burns.
const TORCH_BURN: StringName = &"torch_burn"

const ALL: Array[StringName] = [
	BLEAT,
	GRASS_MOVE,
	GRASS_RUN,
	GRAZE,
	BELL,
	HERDER_STEP,
	GUNSHOT,
	RELOAD_CLICK,
	EMPTY_CLICK,
	BULLET_IMPACT,
	HERDER_DEATH,
	EAT,
	SPIDER_SCREECH,
	SPIDER_MOVE,
	MONSTER_DEATH,
	DOG_BARK,
	BAT,
	BAT_WINGS,
	TORCH_IGNITE,
	TORCH_BURN,
]

## Hearing-range class per event. The GDD (§5) classifies grass movement as
## quiet, bleating / eating / barking as loud, and bell / gunshot as whole map;
## the audio task (#10) and the sound pass (#23) decided the rest.
const RANGE_CLASS: Dictionary[StringName, GameEnums.HearingRange] = {
	BLEAT: GameEnums.HearingRange.LOUD,
	GRASS_MOVE: GameEnums.HearingRange.QUIET,
	GRASS_RUN: GameEnums.HearingRange.QUIET,
	GRAZE: GameEnums.HearingRange.QUIET,
	BELL: GameEnums.HearingRange.WHOLE_MAP,
	HERDER_STEP: GameEnums.HearingRange.QUIET,
	GUNSHOT: GameEnums.HearingRange.WHOLE_MAP,
	RELOAD_CLICK: GameEnums.HearingRange.QUIET,
	EMPTY_CLICK: GameEnums.HearingRange.QUIET,
	BULLET_IMPACT: GameEnums.HearingRange.QUIET,
	HERDER_DEATH: GameEnums.HearingRange.LOUD,
	EAT: GameEnums.HearingRange.LOUD,
	SPIDER_SCREECH: GameEnums.HearingRange.WHOLE_MAP,
	SPIDER_MOVE: GameEnums.HearingRange.QUIET,
	MONSTER_DEATH: GameEnums.HearingRange.LOUD,
	DOG_BARK: GameEnums.HearingRange.LOUD,
	BAT: GameEnums.HearingRange.LOUD,
	BAT_WINGS: GameEnums.HearingRange.LOUD,
	TORCH_IGNITE: GameEnums.HearingRange.QUIET,
	TORCH_BURN: GameEnums.HearingRange.QUIET,
}

# --- Cues: not in the world --------------------------------------------------------

## The Monster turns invisible (its own player only).
const INVISIBILITY_ON: StringName = &"invisibility_on"
## The Monster's invisibility ends (its own player only).
const INVISIBILITY_OFF: StringName = &"invisibility_off"
## The Monster sends the Allied Bat (its own player only).
const BAT_SENT: StringName = &"bat_sent"
## The Sheepherder's last bullet is gone (their own player only).
const ALERT_OUT_OF_BULLETS: StringName = &"alert_out_of_bullets"
## The Monster may kill the Sheepherder now (its own player only).
const ALERT_KILL_UNLOCKED: StringName = &"alert_kill_unlocked"
## The player's active perk is ready again.
const ALERT_PERK_READY: StringName = &"alert_perk_ready"
## A button of the menus is pressed.
const UI_CLICK: StringName = &"ui_click"
## The two devices are connected.
const PAIRED: StringName = &"paired"
## The other player left the session.
const PLAYER_LEFT: StringName = &"player_left"
## A player got ready in the lobby.
const READY: StringName = &"ready"
## One second of the countdown before a round.
const COUNTDOWN_TICK: StringName = &"countdown_tick"
## The round begins.
const ROUND_START: StringName = &"round_start"
## The round is decided, from this player's side.
const ROUND_WIN: StringName = &"round_win"
const ROUND_LOSE: StringName = &"round_lose"
const ROUND_DRAW: StringName = &"round_draw"
## The match is over.
const MATCH_END: StringName = &"match_end"

const CUES: Array[StringName] = [
	INVISIBILITY_ON,
	INVISIBILITY_OFF,
	BAT_SENT,
	ALERT_OUT_OF_BULLETS,
	ALERT_KILL_UNLOCKED,
	ALERT_PERK_READY,
	UI_CLICK,
	PAIRED,
	PLAYER_LEFT,
	READY,
	COUNTDOWN_TICK,
	ROUND_START,
	ROUND_WIN,
	ROUND_LOSE,
	ROUND_DRAW,
	MATCH_END,
]

# --- Ambience -----------------------------------------------------------------------

## Soft wind over the fields.
const AMBIENCE_WIND: StringName = &"ambience_wind"
## Night insects.
const AMBIENCE_CRICKETS: StringName = &"ambience_crickets"
## A distant owl now and then.
const AMBIENCE_OWL: StringName = &"ambience_owl"

const AMBIENCE: Array[StringName] = [AMBIENCE_WIND, AMBIENCE_CRICKETS, AMBIENCE_OWL]


## The hearing-range class of [param event_id]; quiet for unknown events.
static func range_class_of(event_id: StringName) -> GameEnums.HearingRange:
	return RANGE_CLASS.get(event_id, GameEnums.HearingRange.QUIET)

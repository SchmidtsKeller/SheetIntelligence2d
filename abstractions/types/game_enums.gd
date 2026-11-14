@abstract class_name GameEnums
extends RefCounted
## Shared enums of the game rules (GDD §2, §3).
##
## Everything that two systems have to agree on lives here, so no system
## depends on another system's script just to name a role or a death cause.
## Transport- or service-specific enums stay on their service contract.

## Which side a player plays in the current round (GDD §2.3: swapped every round).
enum Role {
	NONE,
	SHEEPHERDER,
	MONSTER,
}

## Who won a round (GDD §2.2). A draw gives neither player a round win.
enum RoundOutcome {
	UNDECIDED,
	SHEEPHERDER_WIN,
	MONSTER_WIN,
	DRAW,
}

## Why a round ended (GDD §2.2).
enum RoundEndReason {
	NONE,
	## The Sheepherder shot the Monster before its spider evolution.
	MONSTER_SHOT,
	## The Monster killed the Sheepherder (5+ sheep eaten, or as the spider).
	SHEEPHERDER_KILLED,
	## The round timer ran out; points decide.
	TIMEOUT,
	## The round was stopped from outside the rules, e.g. by a disconnect.
	ABORTED,
}

## Behaviour phases of a sheep (GDD §3.3). The Monster player imitates these.
enum SheepPhase {
	## Idle wandering with the flock.
	WANDER,
	## Standing still with the head lowered, eating grass.
	GRAZE,
	## Bleating ("mähen").
	BLEAT,
	## Walking toward the Sheepherder after the bell was rung.
	BELL,
}

## How an NPC sheep died. Only [constant EATEN] counts toward the Monster's
## evolution and score; [constant SHOT] costs the Sheepherder points (GDD §2.3).
enum DeathCause {
	SHOT,
	EATEN,
}

## The Monster's body (GDD §3.2): the sheep disguise or the unkillable spider.
enum MonsterForm {
	SHEEP,
	SPIDER,
}

## Hearing-range classes for sound events (GDD §5, Audio rows).
enum HearingRange {
	## Audible within [member GameConfig.hearing_range_quiet].
	QUIET,
	## Audible within [member GameConfig.hearing_range_loud].
	LOUD,
	## Audible everywhere on the map.
	WHOLE_MAP,
}


## The role the other player has. [constant Role.NONE] stays [constant Role.NONE].
static func opposite_role(role: Role) -> Role:
	match role:
		Role.SHEEPHERDER:
			return Role.MONSTER
		Role.MONSTER:
			return Role.SHEEPHERDER
		_:
			return Role.NONE


## Human-readable role name for UI and logs.
static func role_name(role: Role) -> String:
	match role:
		Role.SHEEPHERDER:
			return "Sheepherder"
		Role.MONSTER:
			return "Monster"
		_:
			return "None"

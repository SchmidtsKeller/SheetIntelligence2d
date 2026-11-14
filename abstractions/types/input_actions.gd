@abstract class_name InputActions
extends RefCounted
## Names of all input actions declared in the InputMap (`project.godot`).
##
## Keyboard, mouse, gamepad and the mobile touch controls all trigger these
## same actions (GDD §9.2). Only the [InputService] implementation reads them;
## character controllers consume vectors and action signals from the service.

# --- Movement (WASD / arrow keys / left stick / left virtual joystick) -------
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"

# --- Aim (right stick / right virtual joystick; the mouse aims on PC) --------
const AIM_LEFT: StringName = &"aim_left"
const AIM_RIGHT: StringName = &"aim_right"
const AIM_UP: StringName = &"aim_up"
const AIM_DOWN: StringName = &"aim_down"

# --- Sheepherder actions (GDD §3.1) ------------------------------------------
## Fire the firearm.
const SHOOT: StringName = &"shoot"
## Ring the bell.
const BELL: StringName = &"bell"

# --- Monster actions (GDD §3.2) ----------------------------------------------
## Hold: lower the head and eat grass. No movement while held.
const GRAZE: StringName = &"graze"
## Press: bleat like an NPC sheep.
const BLEAT: StringName = &"bleat"
## Press: eat a sheep (or the Sheepherder) within melee range.
const EAT: StringName = &"eat"
## Hold: sprint while stamina lasts.
const SPRINT: StringName = &"sprint"
## Press: use the active perk.
const PERK: StringName = &"perk"

# --- Pseudo-actions ----------------------------------------------------------
# Not in the InputMap. They name movement and aim as a whole, e.g. as the
# target of [method InputService.add_lock].
const MOVE: StringName = &"move"
const AIM: StringName = &"aim"

const MOVEMENT: Array[StringName] = [MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN]
const AIMING: Array[StringName] = [AIM_LEFT, AIM_RIGHT, AIM_UP, AIM_DOWN]
const SHEEPHERDER_ACTIONS: Array[StringName] = [SHOOT, BELL]
const MONSTER_ACTIONS: Array[StringName] = [GRAZE, BLEAT, EAT, SPRINT, PERK]
## Actions that are meant to be held rather than tapped.
const HOLD_ACTIONS: Array[StringName] = [GRAZE, SPRINT]

## Every action that must exist in the InputMap.
const ALL: Array[StringName] = [
	MOVE_LEFT,
	MOVE_RIGHT,
	MOVE_UP,
	MOVE_DOWN,
	AIM_LEFT,
	AIM_RIGHT,
	AIM_UP,
	AIM_DOWN,
	SHOOT,
	BELL,
	GRAZE,
	BLEAT,
	EAT,
	SPRINT,
	PERK,
]


## The ability actions available to [param role]. Movement applies to both
## roles and aiming to the Sheepherder; neither is part of this list.
static func abilities_for(role: GameEnums.Role) -> Array[StringName]:
	match role:
		GameEnums.Role.SHEEPHERDER:
			return SHEEPHERDER_ACTIONS
		GameEnums.Role.MONSTER:
			return MONSTER_ACTIONS
		_:
			return []


## Whether [param role] aims (only the Sheepherder has a flashlight to point).
static func role_aims(role: GameEnums.Role) -> bool:
	return role == GameEnums.Role.SHEEPHERDER

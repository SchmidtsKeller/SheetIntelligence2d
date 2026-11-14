@abstract class_name PerkService
extends Node
## Contract for perks and the modifier-aware stat lookup (GDD §4, §5).
##
## Two jobs:
## [br]1. [b]Stat lookup.[/b] Gameplay code never reads a gameplay number from
## [GameConfig] directly. It asks [method get_stat] for the effective value,
## which is the configured base value with all active modifiers applied. That
## way perks and temporary effects (the bat) change behaviour without any
## change to the code that uses the number.
## [br]2. [b]Loadout.[/b] Each player selects exactly one perk per round from
## the pool of their role. The Sheepherder's choice must never reach the
## Monster player's screen (GDD §4).

## The effective value of [param stat] may have changed.
@warning_ignore("unused_signal")
signal stat_changed(stat: StringName)

## A player's perk selection changed. Presentation code must not show the
## Sheepherder's selection to the Monster player.
@warning_ignore("unused_signal")
signal perk_selected(role: GameEnums.Role, perk_id: StringName)

## The active perk of [param role] was triggered, ran out or became ready.
@warning_ignore("unused_signal")
signal active_perk_state_changed(role: GameEnums.Role)

## How a modifier changes a stat. Applied in this order: the last
## [constant OVERRIDE] replaces the base value, then all [constant ADD] values
## are added, then all [constant MULTIPLY] factors are applied.
enum ModifierOp {
	ADD,
	MULTIPLY,
	OVERRIDE,
}

# --- Stat lookup -------------------------------------------------------------

## The effective value of [param stat] (see [StatIds]): the base value from
## [GameConfig] with all active modifiers applied.
@abstract func get_stat(stat: StringName) -> float

## The configured value of [param stat] without any modifier.
@abstract func get_base_stat(stat: StringName) -> float


## [method get_stat] rounded to the nearest integer, for counts such as ammo.
func get_stat_int(stat: StringName) -> int:
	return roundi(get_stat(stat))


## Adds a modifier to [param stat] and returns a handle for
## [method remove_modifier]. [param source] names who added it (a perk id, an
## effect). With [param duration] > 0 the modifier removes itself after that
## many seconds; otherwise it stays until removed.
@abstract func add_modifier(
	stat: StringName,
	op: ModifierOp,
	value: float,
	source: StringName,
	duration: float = -1.0,
) -> int

## Removes the modifier with [param handle]. Unknown handles are ignored.
@abstract func remove_modifier(handle: int) -> void

## Removes every modifier added by [param source].
@abstract func remove_modifiers_from(source: StringName) -> void

# --- Loadout -----------------------------------------------------------------

## The perks a player with [param role] may choose from.
@abstract func get_available_perks(role: GameEnums.Role) -> Array[StringName]

## Selects [param perk_id] for the player with [param role], replacing an
## earlier choice. Returns [code]false[/code] if the perk is not in the role's
## pool or the selection is locked.
@abstract func select_perk(role: GameEnums.Role, perk_id: StringName) -> bool

## The perk selected for [param role], or [constant PerkIds.NONE].
@abstract func get_selected_perk(role: GameEnums.Role) -> StringName

## Locks both selections at round start and applies the perks' effects. Host
## only; the guest follows. Lock before [method CombatService.begin_round],
## which reads the magazine size.
@abstract func lock_selection() -> void

## Whether selections are locked for the running round.
@abstract func is_selection_locked() -> bool

## Removes both selections and all modifiers after a round. Host only.
@abstract func clear_selection() -> void

# --- Active perks ------------------------------------------------------------

## Triggers the active perk of [param role]. Returns [code]false[/code] if the
## role has no active perk, it is on cooldown, or it cannot be used right now.
@abstract func activate_perk(role: GameEnums.Role) -> bool

## Ends the running active perk of [param role] early, if the perk allows that
## (e.g. invisibility). Returns [code]false[/code] if nothing was ended.
@abstract func end_perk(role: GameEnums.Role) -> bool


## What the perk button does: ends the running active perk of [param role]
## early if it allows that, otherwise triggers it.
func use_perk(role: GameEnums.Role) -> bool:
	if is_perk_active(role):
		return end_perk(role)
	return activate_perk(role)


## Whether the active perk of [param role] is running (e.g. invisible right now).
@abstract func is_perk_active(role: GameEnums.Role) -> bool

## Seconds until the active perk of [param role] can be triggered again.
@abstract func get_perk_cooldown_remaining(role: GameEnums.Role) -> float

## What is left of the running effect, from 1 (full) to 0 (used up), e.g. the
## invisibility meter. 0 when the perk is not running.
@abstract func get_perk_charge(role: GameEnums.Role) -> float

## Tells the perk service which character plays [param role], so its active
## perk can act on it. Called on both devices by the character itself.
@abstract func register_character(role: GameEnums.Role, character: Node2D) -> void

## Forgets [param character] again, e.g. when it leaves the round.
@abstract func unregister_character(character: Node2D) -> void

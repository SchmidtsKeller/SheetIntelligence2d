@abstract class_name InputService
extends Node
## Contract for player input (GDD §9.2).
##
## Unifies keyboard/mouse and touch controls into normalized vectors and action
## triggers. Character controllers never read devices or the InputMap; they
## poll the vectors and connect to the action signals of this service.
##
## The service is role-aware: only the abilities of the current role are
## reported. Gameplay code can also lock single actions (e.g. no movement
## while eating); the service itself knows no gameplay rule.

## How the player currently controls the game. Drives which controls and
## hints the UI shows.
enum Scheme {
	KEYBOARD_MOUSE,
	TOUCH,
}

## An ability action of the current role went down. Not emitted while the
## action is locked or gameplay input is disabled.
@warning_ignore("unused_signal")
signal action_pressed(action: StringName)

## An ability action went up. Always emitted for an action that was reported
## as pressed, also when the finger slides off a button, the tab loses focus,
## the action gets locked or gameplay input is disabled.
@warning_ignore("unused_signal")
signal action_released(action: StringName)

## The role whose action set is active changed.
@warning_ignore("unused_signal")
signal role_changed(role: GameEnums.Role)

## Gameplay input was switched on or off (menus, round not active).
@warning_ignore("unused_signal")
signal gameplay_enabled_changed(enabled: bool)

## The control scheme changed (device switch or debug override).
@warning_ignore("unused_signal")
signal scheme_changed(scheme: Scheme)

## Movement input with a length of 0..1: analog on touch and gamepad, 8-way on
## the keyboard. [constant Vector2.ZERO] while movement is locked or gameplay
## input is disabled.
@abstract func get_move_vector() -> Vector2

## Unit vector the player aims along, in world space.
## [param aim_origin] is the world position of the controlled character: with
## the mouse, the aim points from there to the cursor. With a stick, the last
## direction is kept after the stick is released. Never zero.
@abstract func get_aim_direction(aim_origin: Vector2) -> Vector2

## Whether an ability action of the current role is currently held down.
## [code]false[/code] while the action is locked or gameplay input is disabled.
@abstract func is_action_held(action: StringName) -> bool

## Activates the action set of [param role] (see [method InputActions.abilities_for]).
## Actions of the other role are no longer reported; held ones are released.
@abstract func set_role(role: GameEnums.Role) -> void

## The role whose action set is active.
@abstract func get_role() -> GameEnums.Role

## Switches gameplay input on or off as a whole. While off, vectors are zero
## and no action is reported. Menus and UI input are not affected.
@abstract func set_gameplay_enabled(enabled: bool) -> void

## Whether gameplay input is switched on.
@abstract func is_gameplay_enabled() -> bool

## Blocks [param action] until [method remove_lock] is called with the same
## [param source]. [param action] is an ability action or one of the
## pseudo-actions [constant InputActions.MOVE] and [constant InputActions.AIM].
## Several sources can lock the same action; it stays blocked until the last
## lock is gone. A locked aim keeps its last direction.
@abstract func add_lock(action: StringName, source: StringName) -> void

## Removes the lock [param source] holds on [param action], if any.
@abstract func remove_lock(action: StringName, source: StringName) -> void

## Removes every lock held by [param source].
@abstract func clear_locks(source: StringName) -> void

## Whether at least one source currently locks [param action].
@abstract func is_locked(action: StringName) -> bool

## The control scheme in use.
@abstract func get_scheme() -> Scheme

## Forces [param scheme] regardless of the device (debugging touch controls on
## a desktop). Stays until [method clear_scheme_override] is called.
@abstract func set_scheme_override(scheme: Scheme) -> void

## Returns to automatic scheme detection.
@abstract func clear_scheme_override() -> void

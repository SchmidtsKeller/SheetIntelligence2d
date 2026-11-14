@abstract
class_name CombatService
extends Node
## Contract for everything lethal (GDD §2.2, §3.1, §3.2).
##
## Owns the firearm (ammo, reload, shot resolution), the Monster's melee attack
## (eating sheep, killing the Sheepherder) and the Monster's evolution. The
## host validates every request and decides the result; both devices receive
## the same events (GDD §9.4).
##
## This service reports what happened. Who wins because of it is decided by
## the round rules, which listen to these signals.

## What a shot did.
enum ShotResult {
	## The request was refused: reloading, empty, or the round is not running.
	REJECTED,
	## The bullet hit nothing before leaving the arena or reaching its range.
	MISSED,
	## The bullet was stopped by a solid obstacle.
	HIT_OBSTACLE,
	## The bullet killed an NPC sheep.
	HIT_SHEEP,
	## The bullet hit the Monster in its sheep form.
	HIT_MONSTER,
	## The bullet hit the Monster in its spider form and had no effect.
	HIT_SPIDER,
}

## What the Monster's melee attack is aimed at.
enum EatTarget {
	NONE,
	SHEEP,
	SHEEPHERDER,
}

# --- Firearm -----------------------------------------------------------------

## A shot was fired and resolved. The bullet travelled from [param origin] to
## [param end_position]. Emitted for every shot that used up a bullet.
@warning_ignore("unused_signal")
signal shot_fired(origin: Vector2, end_position: Vector2, result: ShotResult)

## The number of bullets left changed.
@warning_ignore("unused_signal")
signal ammo_changed(remaining: int, capacity: int)

## The automatic reload after a shot started and takes [param duration] seconds.
@warning_ignore("unused_signal")
signal reload_started(duration: float)

## The firearm is ready to fire again.
@warning_ignore("unused_signal")
signal reload_finished()

## The last bullet is gone: the firearm stays empty for the rest of the round
## and the Monster can no longer be killed (GDD §2.2).
@warning_ignore("unused_signal")
signal ammo_depleted()

# --- Deaths ------------------------------------------------------------------

## An NPC sheep was killed by a shot or by the Monster.
@warning_ignore("unused_signal")
signal sheep_killed(sheep_id: int, cause: GameEnums.DeathCause, position: Vector2)

## The Monster was shot in its sheep form.
@warning_ignore("unused_signal")
signal monster_shot(position: Vector2)

## The Monster's attack landed on the Sheepherder, who dies instantly.
@warning_ignore("unused_signal")
signal sheepherder_killed(position: Vector2)

# --- Monster -----------------------------------------------------------------

## The Monster started eating. It can neither move nor abort for
## [param duration] seconds. [param target_id] is the sheep id, or -1 when the
## target is the Sheepherder.
@warning_ignore("unused_signal")
signal eat_started(target: EatTarget, target_id: int, duration: float)

## The eating animation ended and the cooldown of [param cooldown] seconds began.
@warning_ignore("unused_signal")
signal eat_finished(target: EatTarget, target_id: int, cooldown: float)

## Blood appeared on the ground where a sheep was eaten. It stays for the
## whole round (GDD §3.2).
@warning_ignore("unused_signal")
signal blood_spilled(position: Vector2)

## The number of sheep the Monster has eaten changed.
@warning_ignore("unused_signal")
signal eaten_count_changed(eaten: int)

## The Monster may now kill the Sheepherder (5 sheep eaten, GDD §2.1).
@warning_ignore("unused_signal")
signal sheepherder_kill_unlocked()

## The Monster changed form (10 sheep eaten: spider, GDD §2.1).
@warning_ignore("unused_signal")
signal monster_form_changed(form: GameEnums.MonsterForm)


# --- Round lifecycle ---------------------------------------------------------

## Resets ammo, reload, cooldowns, counters and the Monster's form for a new
## round, and remembers the two characters to resolve attacks against.
@abstract
func begin_round(sheepherder: Node2D, monster: Node2D) -> void


## Stops all combat. Requests are rejected until the next [method begin_round].
@abstract
func end_round() -> void


# --- Firearm -----------------------------------------------------------------

## Asks to fire from [param origin] along [param direction]. Returns whether
## the request was accepted locally; the result arrives as [signal shot_fired].
## A shot ends at the first sheep-like entity or obstacle (no piercing), and a
## miss still uses up the bullet.
@abstract
func request_shot(origin: Vector2, direction: Vector2) -> bool


## Whether a shot would be accepted right now (loaded and not reloading).
@abstract
func can_shoot() -> bool


## Bullets left this round.
@abstract
func get_ammo() -> int


## Bullets the firearm started the round with (3, or 4 with Spare Bullet).
@abstract
func get_ammo_capacity() -> int


## Whether the automatic reload is running.
@abstract
func is_reloading() -> bool


## Reload progress from 0 (just fired) to 1 (ready).
@abstract
func get_reload_progress() -> float


## Whether all bullets are used up.
@abstract
func is_ammo_depleted() -> bool


## How many NPC sheep the Sheepherder has shot this round.
@abstract
func get_shot_sheep_count() -> int


# --- Monster -----------------------------------------------------------------

## Asks to attack what is in melee range of the Monster: the Sheepherder if
## the kill is unlocked, otherwise the nearest living sheep. Returns whether
## the request was accepted locally; the result arrives as [signal eat_started].
@abstract
func request_eat() -> bool


## Whether an attack would be accepted right now: something is in range, the
## cooldown is over and nothing blocks eating.
@abstract
func can_eat() -> bool


## Whether the Monster is in the middle of its eating animation.
@abstract
func is_eating() -> bool


## Seconds until the Monster may attack again; 0 when ready.
@abstract
func get_eat_cooldown_remaining() -> float


## Forbids eating until [method remove_eat_blocker] is called with the same
## [param source] (e.g. while the Monster is invisible).
@abstract
func add_eat_blocker(source: StringName) -> void


## Removes a blocker added with [method add_eat_blocker].
@abstract
func remove_eat_blocker(source: StringName) -> void


## How many sheep the Monster has eaten this round. Shot sheep never count.
@abstract
func get_eaten_count() -> int


## The Monster's current form.
@abstract
func get_monster_form() -> GameEnums.MonsterForm


## Whether the Monster's attack can kill the Sheepherder.
@abstract
func can_kill_sheepherder() -> bool


## Whether a bullet can still kill the Monster: not in spider form and the
## firearm is not permanently empty.
@abstract
func is_monster_killable() -> bool

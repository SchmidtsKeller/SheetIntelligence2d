@abstract class_name PerkEffect
extends RefCounted
## What an active perk does while it runs (GDD §4), e.g. the Monster's
## invisibility.
##
## The perk service creates one per round and player and decides, on the host,
## when it starts and ends; both devices then call [method start] and
## [method stop]. The fields below are kept by the perk service.

## The role whose perk this is.
var role: GameEnums.Role = GameEnums.Role.NONE
## The character of that role, as registered with the perk service; may be
## [code]null[/code] for a moment on the device that has not spawned it yet.
var character: Node2D
## The stat lookup of this device.
var perks: PerkService
## Whether the effect is running.
var running: bool = false
## What is left of the running effect, from 1 to 0.
var charge: float = 0.0
## Seconds until the perk can be triggered again.
var cooldown_left: float = 0.0


## Whether the perk may be triggered right now, apart from its cooldown.
func can_start() -> bool:
	return true


## Whether its player may end it before it runs out.
func can_end_early() -> bool:
	return false


## The effect begins, on both devices.
@abstract func start() -> void

## The effect is over, on both devices: it ran out, was ended early, or the
## round is over.
@abstract func stop() -> void

## Moves the running effect forward by [param delta] seconds and returns what
## is left of it, from 1 to 0. At 0 the host ends it.
@abstract func advance(delta: float) -> float

## Seconds after the effect ends before the perk can be triggered again.
@abstract func get_cooldown() -> float

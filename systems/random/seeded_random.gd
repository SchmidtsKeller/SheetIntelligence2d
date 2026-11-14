class_name SeededRandom
extends RefCounted
## A small random number generator for everything both devices must derive
## identically from a seed, such as the look of a sheep (GDD §9.4).
##
## A 32-bit Weyl sequence mixed with the MurmurHash3 finalizer, in integer
## arithmetic only, so a seed yields the same numbers on every platform and in
## every browser. Godot's [RandomNumberGenerator] is not used for this: its
## documentation calls the algorithm an implementation detail.

const _MASK_32: int = 0xFFFFFFFF
const _WEYL_STEP: int = 0x9E3779B9
const _MIX_1: int = 0x85EBCA6B
const _MIX_2: int = 0xC2B2AE35

var _state: int


## Starts the sequence of [param initial_seed]. Only its low 32 bits are used.
func _init(initial_seed: int = 0) -> void:
	_state = initial_seed & _MASK_32


## The next number, from 0 to 2^32 - 1.
func next_u32() -> int:
	_state = (_state + _WEYL_STEP) & _MASK_32
	var z: int = _state
	# int wraps around on overflow, so the masked product is exact.
	z = ((z ^ (z >> 16)) * _MIX_1) & _MASK_32
	z = ((z ^ (z >> 13)) * _MIX_2) & _MASK_32
	return z ^ (z >> 16)


## The next number from 0 to [param bound] - 1. Fails loudly for a bound below 1.
func next_int(bound: int) -> int:
	if bound < 1:
		push_error("SeededRandom: the bound must be at least 1, got %d." % bound)
		return 0
	return next_u32() % bound


## The next number from [param from] to [param to], both included.
func next_int_range(from: int, to: int) -> int:
	return from + next_int(to - from + 1)

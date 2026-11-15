class_name HudReadout
extends RefCounted
## The arithmetic of the in-game HUD (#21): from the game's state to what is
## shown. No scene, no services, no gameplay rules: the HUD only displays what
## the combat service, the perk service, the match flow and the characters
## expose (GDD §8.2).


## [param seconds] as minutes and seconds, rounded up: the timer shows 0:00
## only when the time is over.
static func format_time(seconds: float) -> String:
	var whole: int = maxi(ceili(seconds), 0)
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]


## How much of a cooldown is left, from 1 (just started) to 0 (ready).
## 0 when [param total] is not positive.
static func cooldown_ratio(remaining: float, total: float) -> float:
	if total <= 0.0:
		return 0.0
	return clampf(remaining / total, 0.0, 1.0)


## One entry per bullet the magazine holds: [code]true[/code] for a bullet
## that is still there.
static func bullets(ammo: int, capacity: int) -> Array[bool]:
	var pips: Array[bool] = []
	for index: int in maxi(capacity, 0):
		pips.append(index < ammo)
	return pips


## How far the Monster is on its way to the spider, from 0 to 1.
static func evolution_progress(eaten: int, spider_at: int) -> float:
	if spider_at <= 0:
		return 1.0
	return clampf(float(eaten) / spider_at, 0.0, 1.0)


## Where on the evolution bar a milestone of [param at] eaten sheep sits.
static func milestone_position(at: int, spider_at: int) -> float:
	return evolution_progress(at, spider_at)


## Sheep the Monster can still eat: the living ones and the bodies of shot
## ones it has not eaten yet (GDD §2.3: those count toward the evolution).
static func sheep_left_to_eat(
	living: int, shot: int, eaten: int, eaten_alive: int
) -> int:
	var bodies_eaten: int = maxi(eaten - eaten_alive, 0)
	return living + maxi(shot - bodies_eaten, 0)


## Whether the spider can still be reached: enough sheep are left to eat.
static func spider_reachable(eaten: int, left_to_eat: int, spider_at: int) -> bool:
	return eaten + left_to_eat >= spider_at


## The short line under the evolution bar.
static func evolution_text(eaten: int, kill_at: int, spider_at: int, reachable: bool) -> String:
	if eaten >= spider_at:
		return "The spider"
	if not reachable:
		if eaten >= kill_at:
			return "%d eaten · kill unlocked · the spider is out of reach" % eaten
		return "%d eaten · the spider is out of reach" % eaten
	if eaten >= kill_at:
		return "%d eaten · kill unlocked · spider at %d" % [eaten, spider_at]
	return "%d eaten · kill at %d · spider at %d" % [eaten, kill_at, spider_at]


## Tracks how long a cooldown was when it started, for services that tell only
## what is left of it: the ratio is the remaining time over the longest
## remaining time seen since the cooldown last ran out.
class CooldownTracker:
	extends RefCounted

	var _peak: float = 0.0

	## The ratio for [param remaining] seconds left.
	func ratio(remaining: float) -> float:
		if remaining <= 0.0:
			_peak = 0.0
			return 0.0
		_peak = maxf(_peak, remaining)
		return HudReadout.cooldown_ratio(remaining, _peak)

class_name FlockAgent
extends RefCounted
## The mind of one NPC sheep (GDD §3.3).
##
## A sheep alternates between short walks, pauses and grazing, bleats now and
## then, and comes when the bell rings. Where it walks is decided when a walk
## starts: somewhere nearby, leaning toward where the others are heading and
## back toward the flock when it has strayed. While it walks it keeps apart
## from the others and clear of obstacles and borders.
##
## The behaviour is made of plain segments on purpose: walk, stand, graze.
## That is what the Monster player has to imitate with a stick and two
## buttons, so there is nothing here a human hand could not do.
##
## The agent only decides. It knows positions, not nodes, and returns a
## movement input; the swarm service passes that on to the sheep's body.

## What the sheep is doing right now.
enum Activity {
	PAUSE,
	WALK,
	GRAZE,
	BELL,
}

## Close enough to a walk's target to call it reached.
const ARRIVE_DISTANCE: float = 20.0
## A walking sheep that is slower than this for [constant STUCK_TIME] gives up
## its walk: something is in the way.
const STUCK_SPEED: float = 20.0
const STUCK_TIME: float = 0.6
## Attempts to find a free target for a walk before pausing instead.
const TARGET_ATTEMPTS: int = 12
## Distance between the points checked along the way to a target.
const PATH_CHECK_STEP: float = 40.0

var activity: Activity = Activity.PAUSE
## Where the current walk leads, or where the bell rang.
var target: Vector2 = Vector2.ZERO
## Seconds left of the current activity.
var time_left: float = 0.0
## The movement input of the last update, for the debug overlay.
var steering: Vector2 = Vector2.ZERO

var _settings: FlockSettings
var _random: SeededRandom
var _bleat_in: float = 0.0
var _bleat_pending: bool = false
var _stuck_for: float = 0.0


func _init(agent_seed: int, settings: FlockSettings) -> void:
	_settings = settings
	_random = SeededRandom.new(agent_seed)
	# Not all sheep start to move at the same moment.
	time_left = _between(0.0, settings.pause_time_max)
	_bleat_in = _between(0.0, settings.bleat_interval_max)


## Decides what the sheep does during the next [param delta] seconds and
## returns its movement input (zero to stand, length 1 to walk).
## [param speed] is how fast the sheep is actually moving.
func update(delta: float, position: Vector2, speed: float, world: FlockWorld) -> Vector2:
	_bleat_in -= delta
	if _bleat_in <= 0.0:
		_bleat_pending = true
		_bleat_in = _between(_settings.bleat_interval_min, _settings.bleat_interval_max)

	time_left -= delta
	steering = Vector2.ZERO
	match activity:
		Activity.PAUSE:
			if time_left <= 0.0:
				_start_walk(position, world)
		Activity.GRAZE:
			if time_left <= 0.0:
				_start_pause()
		Activity.WALK:
			_stuck_for = _stuck_for + delta if speed < STUCK_SPEED else 0.0
			var arrived: bool = position.distance_to(target) <= ARRIVE_DISTANCE
			if arrived or time_left <= 0.0 or _stuck_for >= STUCK_TIME:
				_finish_walk()
			else:
				steering = _steer(position, world)
		Activity.BELL:
			if time_left <= 0.0:
				_start_pause()
			elif position.distance_to(target) > _settings.bell_stop_distance:
				steering = _steer(position, world)
	return steering


## The behaviour phase this activity belongs to.
func get_phase() -> GameEnums.SheepPhase:
	match activity:
		Activity.GRAZE:
			return GameEnums.SheepPhase.GRAZE
		Activity.BELL:
			return GameEnums.SheepPhase.BELL
		_:
			return GameEnums.SheepPhase.WANDER


func is_grazing() -> bool:
	return activity == Activity.GRAZE


## Whether the sheep wants to bleat. Asking clears the wish.
func take_bleat() -> bool:
	var pending: bool = _bleat_pending
	_bleat_pending = false
	return pending


## The bell rang at [param origin]: drop everything and go there, for at most
## [member FlockSettings.bell_follow_time] seconds.
func start_bell(origin: Vector2) -> void:
	activity = Activity.BELL
	target = origin
	time_left = _settings.bell_follow_time
	_stuck_for = 0.0


func _start_pause() -> void:
	activity = Activity.PAUSE
	time_left = _between(_settings.pause_time_min, _settings.pause_time_max)


func _start_graze() -> void:
	activity = Activity.GRAZE
	time_left = _between(_settings.graze_time_min, _settings.graze_time_max)


func _finish_walk() -> void:
	if _chance(_settings.graze_chance):
		_start_graze()
	else:
		_start_pause()


func _start_walk(position: Vector2, world: FlockWorld) -> void:
	for attempt: int in TARGET_ATTEMPTS:
		var direction: Vector2 = Vector2.from_angle(_between(0.0, TAU))
		direction += world.heading * _settings.alignment_weight
		direction += (
			FlockSteering.cohesion(position, world.center, _settings.cohesion_radius)
			* _settings.cohesion_weight
		)
		if direction.is_zero_approx():
			continue
		var distance: float = _between(_settings.wander_distance_min, _settings.wander_distance_max)
		var candidate: Vector2 = position + direction.normalized() * distance
		if _is_way_free(position, candidate, world):
			activity = Activity.WALK
			target = candidate
			time_left = _between(_settings.walk_time_min, _settings.walk_time_max)
			_stuck_for = 0.0
			return
	_start_pause()


## Whether the straight way from [param from] to [param to] is free.
func _is_way_free(from: Vector2, to: Vector2, world: FlockWorld) -> bool:
	var steps: int = maxi(ceili(from.distance_to(to) / PATH_CHECK_STEP), 1)
	for step: int in range(1, steps + 1):
		if not world.is_free.call(from.lerp(to, float(step) / steps)):
			return false
	return true


## Toward the target, but apart from the others and clear of what is solid.
## Sheep have one walking speed, so the result has length 1 or 0.
func _steer(position: Vector2, world: FlockWorld) -> Vector2:
	var wish: Vector2 = position.direction_to(target)
	wish += (
		FlockSteering.separation(position, world.neighbours, _settings.separation_radius)
		* _settings.separation_weight
	)
	wish += (
		FlockSteering.obstacle_avoidance(position, world.footprints, _settings.obstacle_margin)
		* _settings.obstacle_weight
	)
	wish += (
		FlockSteering.border_avoidance(position, world.play_area, _settings.border_margin)
		* _settings.border_weight
	)
	return wish.normalized() if wish.length() > 0.05 else Vector2.ZERO


## A random number from [param from] to [param to].
func _between(from: float, to: float) -> float:
	return lerpf(from, to, _random.next_u32() / 4294967296.0)


func _chance(probability: float) -> bool:
	return _random.next_u32() / 4294967296.0 < probability

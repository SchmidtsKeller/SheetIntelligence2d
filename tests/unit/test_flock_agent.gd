extends TestCase
## The mind of one sheep: walks, pauses, grazing, bleats and the bell.

# An alias for an enum type, so it is named like a type.
# gdlint: ignore=constant-name
const Activity = FlockAgent.Activity

const STEP: float = 1.0 / 60.0
const AREA: Rect2 = Rect2(0.0, 0.0, 2000.0, 1500.0)
const START: Vector2 = Vector2(1000.0, 750.0)

var _settings: FlockSettings
var _world: FlockWorld


func before_each() -> void:
	_settings = FlockSettings.new()
	_world = FlockWorld.new()
	_world.play_area = AREA
	_world.center = START
	_world.is_free = func(point: Vector2) -> bool: return AREA.grow(-30.0).has_point(point)


func test_sheep_starts_with_a_pause() -> void:
	var agent: FlockAgent = FlockAgent.new(1, _settings)

	assert_eq(agent.activity, Activity.PAUSE)
	assert_lte(agent.time_left, _settings.pause_time_max)
	assert_eq(agent.get_phase(), GameEnums.SheepPhase.WANDER)


func test_sheep_do_not_all_start_moving_at_once() -> void:
	var starts: Dictionary[int, bool] = {}

	for agent_seed: int in 10:
		starts[roundi(FlockAgent.new(agent_seed, _settings).time_left * 10.0)] = true

	assert_gt(starts.size(), 5, "different sheep, different first pauses")


func test_same_seed_gives_the_same_behaviour() -> void:
	var first: Array = _record_activities(FlockAgent.new(42, _settings), 20.0)
	var second: Array = _record_activities(FlockAgent.new(42, _settings), 20.0)
	var other: Array = _record_activities(FlockAgent.new(43, _settings), 20.0)

	assert_eq(first, second)
	assert_ne(first, other)


func test_a_pause_ends_in_a_walk() -> void:
	var agent: FlockAgent = FlockAgent.new(3, _settings)

	_run_until(agent, func() -> bool: return agent.activity == Activity.WALK, 5.0)

	assert_eq(agent.activity, Activity.WALK)
	var distance: float = START.distance_to(agent.target)
	assert_gte(distance, _settings.wander_distance_min - 0.01)
	assert_lte(distance, _settings.wander_distance_max + 0.01)
	assert_gte(agent.time_left, _settings.walk_time_min - STEP)
	assert_lte(agent.time_left, _settings.walk_time_max)


func test_walking_sheep_walks_at_full_speed_toward_its_target() -> void:
	var agent: FlockAgent = FlockAgent.new(3, _settings)
	_run_until(agent, func() -> bool: return agent.activity == Activity.WALK, 5.0)

	var input: Vector2 = agent.update(STEP, START, 180.0, _world)

	assert_almost_eq(input.length(), 1.0, 0.001, "sheep have one walking speed")
	assert_gt(input.dot(START.direction_to(agent.target)), 0.9)


func test_standing_sheep_gives_no_movement_input() -> void:
	var agent: FlockAgent = FlockAgent.new(3, _settings)

	assert_eq(agent.update(STEP, START, 0.0, _world), Vector2.ZERO)


func test_walk_ends_when_the_target_is_reached() -> void:
	var agent: FlockAgent = FlockAgent.new(3, _settings)
	_run_until(agent, func() -> bool: return agent.activity == Activity.WALK, 5.0)

	agent.update(STEP, agent.target + Vector2(3.0, 0.0), 180.0, _world)

	assert_ne(agent.activity, Activity.WALK)


func test_walk_ends_after_its_time_even_without_arriving() -> void:
	var agent: FlockAgent = FlockAgent.new(3, _settings)
	_run_until(agent, func() -> bool: return agent.activity == Activity.WALK, 5.0)

	for step: int in ceili(_settings.walk_time_max / STEP) + 2:
		agent.update(STEP, START, 180.0, _world)

	assert_ne(agent.activity, Activity.WALK)


func test_sheep_that_is_stuck_gives_up_its_walk() -> void:
	var agent: FlockAgent = FlockAgent.new(3, _settings)
	_run_until(agent, func() -> bool: return agent.activity == Activity.WALK, 5.0)
	agent.time_left = 100.0

	# It wants to walk but does not get anywhere.
	for step: int in ceili(FlockAgent.STUCK_TIME / STEP) + 2:
		agent.update(STEP, START, 0.0, _world)

	assert_ne(agent.activity, Activity.WALK)


func test_grazing_lasts_three_to_six_seconds() -> void:
	# GDD §5: graze duration 3.0–6.0 s, random per graze.
	var durations: Array[float] = []
	for agent_seed: int in 40:
		var agent: FlockAgent = FlockAgent.new(agent_seed, _settings)
		_run_until(agent, func() -> bool: return agent.activity == Activity.GRAZE, 120.0)
		if agent.activity == Activity.GRAZE:
			durations.append(agent.time_left)

	assert_gt(durations.size(), 30, "nearly every sheep grazes within two minutes")
	for duration: float in durations:
		assert_gte(duration, 3.0 - STEP)
		assert_lte(duration, 6.0)
	assert_gt(durations.max() - durations.min(), 1.0, "and not all equally long")


func test_grazing_sheep_stands_still_and_then_pauses() -> void:
	var agent: FlockAgent = FlockAgent.new(5, _settings)
	_run_until(agent, func() -> bool: return agent.activity == Activity.GRAZE, 120.0)

	assert_true(agent.is_grazing())
	assert_eq(agent.get_phase(), GameEnums.SheepPhase.GRAZE)
	assert_eq(agent.update(STEP, START, 0.0, _world), Vector2.ZERO)

	_run_until(agent, func() -> bool: return agent.activity != Activity.GRAZE, 7.0)
	assert_eq(agent.activity, Activity.PAUSE)


func test_about_half_the_walks_end_in_grazing() -> void:
	var grazes: int = 0
	var walks: int = 0
	var agent: FlockAgent = FlockAgent.new(9, _settings)
	var previous: FlockAgent.Activity = agent.activity

	for step: int in ceili(900.0 / STEP):
		agent.update(STEP, START, 180.0, _world)
		if agent.activity != previous:
			walks += int(agent.activity == Activity.WALK)
			grazes += int(agent.activity == Activity.GRAZE)
			previous = agent.activity

	assert_gt(walks, 50)
	assert_almost_eq(float(grazes) / walks, _settings.graze_chance, 0.15)


func test_sheep_bleats_now_and_then() -> void:
	var agent: FlockAgent = FlockAgent.new(11, _settings)
	var bleat_times: Array[float] = []

	for step: int in ceili(300.0 / STEP):
		agent.update(STEP, START, 0.0, _world)
		if agent.take_bleat():
			bleat_times.append(step * STEP)

	assert_gt(bleat_times.size(), 300.0 / _settings.bleat_interval_max - 2.0)
	assert_lt(bleat_times.size(), 300.0 / _settings.bleat_interval_min + 2.0)
	for index: int in range(1, bleat_times.size()):
		var gap: float = bleat_times[index] - bleat_times[index - 1]
		assert_gte(gap, _settings.bleat_interval_min - STEP)
		assert_lte(gap, _settings.bleat_interval_max + STEP)


func test_bleat_wish_is_cleared_by_asking() -> void:
	var agent: FlockAgent = FlockAgent.new(11, _settings)
	_run_until(agent, func() -> bool: return agent.take_bleat(), 60.0)

	assert_false(agent.take_bleat())


func test_walk_targets_are_always_on_free_ground() -> void:
	# A sheep in a corner: most directions lead out of the field.
	var corner: Vector2 = Vector2(60.0, 60.0)
	var agent: FlockAgent = FlockAgent.new(13, _settings)
	var walks: int = 0

	for step: int in ceili(600.0 / STEP):
		var before: FlockAgent.Activity = agent.activity
		agent.update(STEP, corner, 180.0, _world)
		if agent.activity == Activity.WALK and before != Activity.WALK:
			walks += 1
			assert_true(_world.is_free.call(agent.target), "target %s" % agent.target)

	assert_gt(walks, 20)


func test_stray_sheep_heads_back_to_the_flock() -> void:
	# The flock is far to the right.
	_world.center = START + Vector2(900.0, 0.0)
	var toward: int = 0
	var walks: int = 0

	for agent_seed: int in 60:
		var agent: FlockAgent = FlockAgent.new(agent_seed, _settings)
		_run_until(agent, func() -> bool: return agent.activity == Activity.WALK, 5.0)
		if agent.activity == Activity.WALK:
			walks += 1
			toward += int(agent.target.x > START.x)

	assert_gt(float(toward) / walks, 0.9)


func test_sheep_near_the_flock_wanders_in_all_directions() -> void:
	var right: int = 0
	var walks: int = 0

	for agent_seed: int in 80:
		var agent: FlockAgent = FlockAgent.new(agent_seed, _settings)
		_run_until(agent, func() -> bool: return agent.activity == Activity.WALK, 5.0)
		if agent.activity == Activity.WALK:
			walks += 1
			right += int(agent.target.x > START.x)

	assert_almost_eq(float(right) / walks, 0.5, 0.2)


func test_sheep_leans_toward_where_the_others_walk() -> void:
	_world.heading = Vector2.RIGHT
	_settings.alignment_weight = 1.5
	var right: int = 0
	var walks: int = 0

	for agent_seed: int in 80:
		var agent: FlockAgent = FlockAgent.new(agent_seed, _settings)
		_run_until(agent, func() -> bool: return agent.activity == Activity.WALK, 5.0)
		if agent.activity == Activity.WALK:
			walks += 1
			right += int(agent.target.x > START.x)

	assert_gt(float(right) / walks, 0.8)


func test_walking_sheep_keeps_apart_from_a_neighbour_in_its_way() -> void:
	var agent: FlockAgent = FlockAgent.new(3, _settings)
	_run_until(agent, func() -> bool: return agent.activity == Activity.WALK, 5.0)
	var straight: Vector2 = agent.update(STEP, START, 180.0, _world)

	# Somebody stands close by, a little to the side of the way.
	var side: Vector2 = straight.orthogonal()
	_world.neighbours = [START + straight * 35.0 + side * 10.0]
	var around: Vector2 = agent.update(STEP, START, 180.0, _world)

	assert_lt(around.dot(side), -0.2, "it swerves to the other side")
	assert_almost_eq(around.length(), 1.0, 0.001)


# --- Bell ------------------------------------------------------------------------


func test_bell_makes_the_sheep_walk_to_where_it_rang() -> void:
	var agent: FlockAgent = FlockAgent.new(3, _settings)
	var bell: Vector2 = START + Vector2(300.0, 0.0)

	agent.start_bell(bell)
	var input: Vector2 = agent.update(STEP, START, 0.0, _world)

	assert_eq(agent.activity, Activity.BELL)
	assert_eq(agent.get_phase(), GameEnums.SheepPhase.BELL)
	assert_almost_eq(input, Vector2.RIGHT, 0.001)


func test_bell_interrupts_grazing() -> void:
	var agent: FlockAgent = FlockAgent.new(5, _settings)
	_run_until(agent, func() -> bool: return agent.activity == Activity.GRAZE, 120.0)

	agent.start_bell(START + Vector2(300.0, 0.0))

	assert_false(agent.is_grazing())


func test_sheep_stops_a_little_before_the_bell() -> void:
	var agent: FlockAgent = FlockAgent.new(3, _settings)
	var bell: Vector2 = START + Vector2(300.0, 0.0)
	agent.start_bell(bell)

	var near: Vector2 = bell - Vector2(_settings.bell_stop_distance - 5.0, 0.0)

	assert_eq(agent.update(STEP, near, 180.0, _world), Vector2.ZERO)
	assert_eq(agent.activity, Activity.BELL, "it waits there while the bell holds it")


func test_sheep_returns_to_normal_when_the_bell_time_is_over() -> void:
	var agent: FlockAgent = FlockAgent.new(3, _settings)
	agent.start_bell(START + Vector2(300.0, 0.0))

	for step: int in ceili(_settings.bell_follow_time / STEP) + 2:
		agent.update(STEP, START, 0.0, _world)

	assert_eq(agent.activity, Activity.PAUSE)
	assert_eq(agent.get_phase(), GameEnums.SheepPhase.WANDER)


## Runs the agent standing at the start until [param done] or the time is up.
func _run_until(agent: FlockAgent, done: Callable, seconds: float) -> void:
	for step: int in ceili(seconds / STEP):
		if done.call():
			return
		agent.update(STEP, START, 180.0, _world)


## The agent's activity changes over [param seconds], with their targets.
func _record_activities(agent: FlockAgent, seconds: float) -> Array:
	var record: Array = []
	var previous: int = -1
	for step: int in ceili(seconds / STEP):
		agent.update(STEP, START, 180.0, _world)
		if agent.activity != previous:
			previous = agent.activity
			record.append([step, agent.activity, agent.target])
	return record

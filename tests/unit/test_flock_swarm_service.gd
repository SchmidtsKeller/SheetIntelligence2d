extends TestCase
## The flock in the real arena: ten sheep that stay where they belong, come
## to the bell, die when they are killed, and look the same on the guest.

const ARENA_SCENE: PackedScene = preload("res://systems/arena/arena.tscn")
const ROUND_SEED: int = 20261114
## Physics ticks per simulated second, as in the game.
const TICKS_PER_SECOND: int = 60
## How much faster than real time the flock is simulated on its own.
const FAST: float = 30.0
## With a guest, snapshots have to keep their rhythm of 20 per simulated
## second, which limits the speed-up to what the frame rate allows.
const FAST_WITH_GUEST: float = 4.0

var _arena: Arena
var _session: GameSession
var _swarm: FlockSwarmService
var _flock_size: int = 0


func before_each() -> void:
	_flock_size = Services.config.flock_size
	_arena = add_child_autofree(ARENA_SCENE.instantiate())
	var network: StubNetworkService = add_child_autofree(StubNetworkService.new())
	_session = add_child_autofree(GameSession.new())
	_session.scene_flow = add_child_autofree(SceneFlowController.new())
	_session.bind_network(network)
	_swarm = add_child_autofree(FlockSwarmService.new())
	_swarm.arena = _arena
	_swarm.setup(_session, Services.perks)
	_session.host()


func after_each() -> void:
	_set_speed(1.0)
	_swarm.despawn_flock()
	_session.leave()
	await wait_frames(2)


# --- Spawning --------------------------------------------------------------------


func test_flock_has_ten_sheep_in_the_arena() -> void:
	watch_signals(_swarm)

	_swarm.spawn_flock(ROUND_SEED)

	assert_eq(_swarm.get_living_count(), 10, "GDD §5: flock size")
	assert_eq(_swarm.get_living_sheep_ids().size(), _flock_size)
	assert_signal_emit_count(_swarm, &"sheep_spawned", _flock_size)
	for sheep_id: int in _swarm.get_living_sheep_ids():
		var body: Node2D = _swarm.get_sheep_body(sheep_id)
		assert_is(body, SheepBody)
		assert_eq(body.get_parent(), _arena.get_entities_layer(), "in the y-sorted layer")
		assert_true(_swarm.is_sheep_alive(sheep_id))
		assert_eq(_swarm.get_sheep_id(body), sheep_id)


func test_flock_takes_every_slot_of_the_round_but_the_monsters() -> void:
	var slot_count: int = _flock_size + 1
	var monster_slot: int = RoundCast.monster_slot(ROUND_SEED, slot_count)
	var seeds: PackedInt64Array = RoundCast.visual_seeds(ROUND_SEED, slot_count)
	var positions: Array[Vector2] = _arena.get_spawn_layout(ROUND_SEED, slot_count).sheep_positions

	_swarm.spawn_flock(ROUND_SEED)

	var flock_seeds: Array[int] = []
	var flock_positions: Array[Vector2] = []
	for sheep_id: int in _swarm.get_living_sheep_ids():
		var body: SheepBody = _swarm.get_sheep_body(sheep_id)
		flock_seeds.append(body.get_visual_seed())
		flock_positions.append(body.position)
	for slot: int in slot_count:
		if slot == monster_slot:
			assert_does_not_have(flock_seeds, seeds[slot], "the Monster's look is not in the flock")
			assert_does_not_have(flock_positions, positions[slot], "and its place is free")
		else:
			assert_has(flock_seeds, seeds[slot])
			assert_has(flock_positions, positions[slot])


func test_same_round_seed_gives_the_same_flock() -> void:
	_swarm.spawn_flock(ROUND_SEED)
	var first: Array = _looks_and_places()

	_swarm.spawn_flock(ROUND_SEED)
	await wait_frames(2)
	var again: Array = _looks_and_places()

	_swarm.spawn_flock(ROUND_SEED + 1)
	await wait_frames(2)
	var other: Array = _looks_and_places()

	assert_eq(again, first)
	assert_ne(other, first)
	assert_eq(_swarm.get_living_count(), _flock_size, "a new flock replaces the old one")


func test_despawning_removes_every_sheep() -> void:
	_swarm.spawn_flock(ROUND_SEED)

	_swarm.despawn_flock()

	assert_eq(_swarm.get_living_count(), 0)
	assert_eq(_swarm.get_living_sheep_ids(), [])
	assert_null(_swarm.get_sheep_body(1))


func test_flock_needs_a_running_session() -> void:
	_session.leave()
	expect_error("only the host of a running session spawns the flock")

	_swarm.spawn_flock(ROUND_SEED)

	assert_eq(_swarm.get_living_count(), 0)


# --- A whole round ---------------------------------------------------------------


func test_flock_behaves_for_a_whole_round() -> void:
	# 180 simulated seconds (GDD §5: round duration) in the real arena.
	_swarm.spawn_flock(ROUND_SEED)
	var play_area: Rect2 = _arena.get_play_area()
	var footprints: Array[PackedVector2Array] = _arena.get_obstacle_footprints()
	var ids: Array[int] = _swarm.get_living_sheep_ids()
	var travelled: Dictionary[int, float] = {}
	var previous: Dictionary[int, Vector2] = {}
	var has_grazed: Dictionary[int, bool] = {}
	var has_walked: Dictionary[int, bool] = {}
	var problems: PackedStringArray = []
	var smallest_spread: float = INF
	var largest_spread: float = 0.0
	for sheep_id: int in ids:
		travelled[sheep_id] = 0.0
		previous[sheep_id] = (_swarm.get_sheep_body(sheep_id) as Node2D).global_position

	_set_speed(FAST)
	for tick: int in roundi(Services.config.round_duration * TICKS_PER_SECOND):
		await get_tree().physics_frame
		if tick % 6 != 0:
			continue
		for sheep_id: int in ids:
			var body: SheepBody = _swarm.get_sheep_body(sheep_id)
			var position: Vector2 = body.global_position
			travelled[sheep_id] += position.distance_to(previous[sheep_id])
			previous[sheep_id] = position
			has_grazed[sheep_id] = has_grazed.get(sheep_id, false) or body.is_grazing()
			has_walked[sheep_id] = has_walked.get(sheep_id, false) or body.get_speed() > 100.0
			if not play_area.has_point(position):
				problems.append("sheep %d left the field at %s (tick %d)" % [sheep_id, position, tick])
			for footprint: PackedVector2Array in footprints:
				if Geometry2D.is_point_in_polygon(position, footprint):
					problems.append("sheep %d is inside an obstacle at %s" % [sheep_id, position])
		var spread: float = _mean_distance_between(previous.values())
		smallest_spread = minf(smallest_spread, spread)
		largest_spread = maxf(largest_spread, spread)
	_set_speed(1.0)

	assert_eq(problems, PackedStringArray(), "no sheep leaves the field or enters an obstacle")
	for sheep_id: int in ids:
		assert_gt(travelled[sheep_id], 1500.0, "sheep %d keeps moving, it is not stuck" % sheep_id)
		assert_true(has_walked.get(sheep_id, false), "sheep %d walks at walking speed" % sheep_id)
		assert_true(has_grazed.get(sheep_id, false), "sheep %d grazes" % sheep_id)
	assert_gt(smallest_spread, 70.0, "the flock never collapses into one clump")
	assert_lt(largest_spread, 1200.0, "and it never scatters over the whole field")
	assert_eq(_swarm.get_living_count(), _flock_size, "nobody dies of wandering")


func test_phase_changes_are_announced() -> void:
	_swarm.spawn_flock(ROUND_SEED)
	watch_signals(_swarm)

	await _simulate(20.0)

	var phases: Dictionary[int, bool] = {}
	for index: int in get_signal_emit_count(_swarm, &"sheep_phase_changed"):
		phases[get_signal_arguments(_swarm, &"sheep_phase_changed", index)[1]] = true
	assert_true(phases.has(GameEnums.SheepPhase.WANDER))
	assert_true(phases.has(GameEnums.SheepPhase.GRAZE), "within 20 s somebody grazes")


func test_sheep_bleat_from_time_to_time() -> void:
	_swarm.spawn_flock(ROUND_SEED)
	var bleats: Array[int] = [0]
	for sheep_id: int in _swarm.get_living_sheep_ids():
		(_swarm.get_sheep_body(sheep_id) as SheepBody).bleated.connect(
			func() -> void: bleats[0] += 1
		)

	await _simulate(30.0)

	# Ten sheep, each bleating every 8 to 25 s.
	assert_gt(bleats[0], 5)
	assert_lt(bleats[0], 45)


# --- Bell ------------------------------------------------------------------------


func test_bell_calls_exactly_the_sheep_within_its_radius() -> void:
	_swarm.spawn_flock(ROUND_SEED)
	await _simulate(3.0)
	var origin: Vector2 = _flock_center()
	var radius: float = 260.0
	var inside: Array[int] = []
	var outside: Array[int] = []
	for sheep_id: int in _swarm.get_living_sheep_ids():
		var position: Vector2 = (_swarm.get_sheep_body(sheep_id) as Node2D).global_position
		if position.distance_to(origin) <= radius:
			inside.append(sheep_id)
		else:
			outside.append(sheep_id)
	watch_signals(_swarm)

	_swarm.ring_bell(origin, radius)

	assert_gt(inside.size(), 0, "the test needs sheep inside the radius")
	assert_gt(outside.size(), 0, "and outside of it")
	for sheep_id: int in inside:
		assert_eq(_swarm.get_agent(sheep_id).activity, FlockAgent.Activity.BELL, "sheep %d" % sheep_id)
		assert_eq(_swarm.get_agent(sheep_id).target, origin)
	for sheep_id: int in outside:
		assert_ne(_swarm.get_agent(sheep_id).activity, FlockAgent.Activity.BELL, "sheep %d" % sheep_id)
	assert_signal_emitted_with(_swarm, &"bell_rung", [origin, radius])


func test_called_sheep_gather_and_then_go_back_to_normal() -> void:
	_swarm.spawn_flock(ROUND_SEED)
	await _simulate(2.0)
	# Somewhere a little off the flock, with the default radius of the bell.
	var origin: Vector2 = _flock_center() + Vector2(160.0, 0.0)
	var radius: float = Services.config.bell_radius
	var called: Array[int] = []
	var distance_before: float = 0.0
	for sheep_id: int in _swarm.get_living_sheep_ids():
		var position: Vector2 = (_swarm.get_sheep_body(sheep_id) as Node2D).global_position
		if position.distance_to(origin) <= radius:
			called.append(sheep_id)
			distance_before += position.distance_to(origin)

	_swarm.ring_bell(origin, radius)
	await _simulate(Services.config.bell_follow_time - 0.5)

	var distance_after: float = 0.0
	for sheep_id: int in called:
		distance_after += (
			(_swarm.get_sheep_body(sheep_id) as Node2D).global_position.distance_to(origin)
		)
	assert_gt(called.size(), 3)
	assert_lt(distance_after / called.size(), distance_before / called.size(), "they came closer")
	assert_lt(distance_after / called.size(), Services.config.bell_stop_distance + 90.0)

	await _simulate(1.5)
	for sheep_id: int in called:
		assert_ne(_swarm.get_agent(sheep_id).activity, FlockAgent.Activity.BELL)


# --- Death -----------------------------------------------------------------------


func test_killed_sheep_leaves_the_flock() -> void:
	_swarm.spawn_flock(ROUND_SEED)
	var victim: int = _swarm.get_living_sheep_ids()[3]
	var body: SheepBody = _swarm.get_sheep_body(victim)
	watch_signals(_swarm)

	assert_true(_swarm.kill_sheep(victim, GameEnums.DeathCause.EATEN))

	assert_eq(_swarm.get_living_count(), _flock_size - 1)
	assert_does_not_have(_swarm.get_living_sheep_ids(), victim)
	assert_false(_swarm.is_sheep_alive(victim))
	assert_null(_swarm.get_agent(victim), "a dead sheep has no mind")
	assert_signal_emitted_with(
		_swarm, &"sheep_died", [victim, GameEnums.DeathCause.EATEN, body.global_position]
	)
	assert_signal_emitted_with(_swarm, &"living_count_changed", [_flock_size - 1])


func test_sheep_dies_only_once_but_a_shot_body_can_still_be_eaten() -> void:
	_swarm.spawn_flock(ROUND_SEED)
	var victim: int = _swarm.get_living_sheep_ids()[0]
	_swarm.kill_sheep(victim, GameEnums.DeathCause.SHOT)
	watch_signals(_swarm)

	assert_false(_swarm.kill_sheep(victim, GameEnums.DeathCause.SHOT), "it is already dead")
	assert_true(_swarm.kill_sheep(victim, GameEnums.DeathCause.EATEN), "its body is still there")
	assert_false(_swarm.kill_sheep(victim, GameEnums.DeathCause.EATEN), "now it is gone")

	assert_signal_not_emitted(_swarm, &"sheep_died", "the sheep was not alive any more")
	assert_eq(_swarm.get_living_count(), _flock_size - 1)


func test_shot_from_the_firearm_kills_the_sheep_it_hits() -> void:
	# The flock together with the real firearm (#14).
	_swarm.spawn_flock(ROUND_SEED)
	var combat: SessionCombatService = add_child_autofree(SessionCombatService.new())
	combat.session = _session
	combat.swarm = _swarm
	var sheepherder: Node2D = Node2D.new()
	_arena.get_entities_layer().add_child(sheepherder)
	combat.begin_round(sheepherder, null)
	# The physics world has to know the sheep before a bullet can hit one.
	await _simulate(0.2, 1.0)
	# The sheep with the most room around it, so nothing else is in the way.
	var victim: int = -1
	var most_room: float = 0.0
	for sheep_id: int in _swarm.get_living_sheep_ids():
		var here: Vector2 = (_swarm.get_sheep_body(sheep_id) as Node2D).global_position
		var room: float = INF
		for other_id: int in _swarm.get_living_sheep_ids():
			if other_id != sheep_id:
				var there: Vector2 = (_swarm.get_sheep_body(other_id) as Node2D).global_position
				room = minf(room, here.distance_to(there))
		if room > most_room:
			most_room = room
			victim = sheep_id
	var picture: Node2D = _swarm.get_sheep_body(victim).get_node(^"Facing")
	watch_signals(combat)
	watch_signals(_swarm)

	# A bullet hits a sheep where it is shown.
	var origin: Vector2 = picture.global_position + Vector2(-50.0, 0.0)
	assert_true(combat.request_shot(origin, Vector2.RIGHT))

	assert_false(_swarm.is_sheep_alive(victim), "the sheep that was aimed at is dead")
	assert_eq(_swarm.get_living_count(), _flock_size - 1, "and only that one")
	assert_eq(
		(_swarm.get_sheep_body(victim) as SheepBody).get_state(),
		SheepBody.State.CORPSE,
		"its body stays on the field"
	)
	assert_signal_emit_count(_swarm, &"sheep_died", 1)
	assert_signal_emitted(combat, &"shot_fired")
	assert_eq(
		get_signal_arguments(combat, &"shot_fired", 0)[2],
		CombatService.ShotResult.HIT_SHEEP,
		"the firearm reports a hit sheep"
	)
	sheepherder.queue_free()


func test_unknown_sheep_cannot_be_killed() -> void:
	_swarm.spawn_flock(ROUND_SEED)

	assert_false(_swarm.kill_sheep(999, GameEnums.DeathCause.SHOT))
	assert_false(_swarm.is_sheep_alive(999))
	assert_eq(_swarm.get_sheep_id(_arena), -1)


func test_nearest_living_sheep() -> void:
	_swarm.spawn_flock(ROUND_SEED)
	var ids: Array[int] = _swarm.get_living_sheep_ids()
	var position: Vector2 = (_swarm.get_sheep_body(ids[2]) as Node2D).global_position

	assert_eq(_swarm.find_nearest_living_sheep(position, 48.0), ids[2])
	assert_eq(_swarm.find_nearest_living_sheep(position + Vector2(5000.0, 0.0), 48.0), -1)

	_swarm.kill_sheep(ids[2], GameEnums.DeathCause.SHOT)
	assert_ne(_swarm.find_nearest_living_sheep(position, 5000.0), ids[2], "dead sheep do not count")


# --- Neighbours ------------------------------------------------------------------


func test_registered_neighbour_counts_as_one_of_the_flock() -> void:
	# The Monster's sheep registers like this: the flock must neither avoid
	# nor ignore it.
	_swarm.spawn_flock(ROUND_SEED)
	var monster: Node2D = add_child_autofree(Node2D.new())
	monster.global_position = _flock_center() + Vector2(2000.0, 0.0)
	await _simulate(0.1)
	var center_without: Vector2 = _swarm.get_world().center

	_swarm.register_neighbour(monster)
	await _simulate(0.1)

	var world: FlockWorld = _swarm.get_world()
	assert_gt(world.center.x, center_without.x + 100.0, "the flock's middle includes it")
	assert_has(world.neighbours, monster.global_position, "and every sheep sees it")
	assert_eq(world.neighbours.size(), _flock_size, "nine other sheep and the neighbour")

	_swarm.unregister_neighbour(monster)
	await _simulate(0.1)
	assert_eq(_swarm.get_world().neighbours.size(), _flock_size - 1)


# --- The guest sees the same flock -----------------------------------------------


func test_guest_sees_the_same_sheep_in_the_same_places() -> void:
	var pair: Dictionary = _create_pair()
	var host_swarm: FlockSwarmService = pair["host_swarm"]
	var guest_swarm: FlockSwarmService = pair["guest_swarm"]

	host_swarm.spawn_flock(ROUND_SEED)

	assert_eq(guest_swarm.get_living_sheep_ids(), host_swarm.get_living_sheep_ids())
	for sheep_id: int in host_swarm.get_living_sheep_ids():
		var on_host: SheepBody = host_swarm.get_sheep_body(sheep_id)
		var on_guest: SheepBody = guest_swarm.get_sheep_body(sheep_id)
		assert_eq(on_guest.get_visual_seed(), on_host.get_visual_seed(), "sheep %d" % sheep_id)
		assert_eq(on_guest.position, on_host.position)
	assert_null(guest_swarm.get_agent(1), "only the host thinks for the sheep")
	host_swarm.despawn_flock()


func test_guest_sheep_follow_the_hosts_sheep() -> void:
	var pair: Dictionary = _create_pair()
	var host_swarm: FlockSwarmService = pair["host_swarm"]
	var guest_swarm: FlockSwarmService = pair["guest_swarm"]
	host_swarm.spawn_flock(ROUND_SEED)
	var start: Dictionary[int, Vector2] = {}
	for sheep_id: int in host_swarm.get_living_sheep_ids():
		start[sheep_id] = (host_swarm.get_sheep_body(sheep_id) as Node2D).global_position

	await _simulate(8.0, FAST_WITH_GUEST)

	var moved: int = 0
	for sheep_id: int in host_swarm.get_living_sheep_ids():
		var on_host: Vector2 = (host_swarm.get_sheep_body(sheep_id) as Node2D).global_position
		var on_guest: Vector2 = (guest_swarm.get_sheep_body(sheep_id) as Node2D).global_position
		moved += int(on_host.distance_to(start[sheep_id]) > 40.0)
		# The guest shows the sheep a moment in the past: at most 0.25 s of walking.
		assert_lt(on_guest.distance_to(on_host), 50.0, "sheep %d" % sheep_id)
	assert_gt(moved, 4, "most sheep have walked somewhere by now")
	host_swarm.despawn_flock()


func test_grazing_death_bleats_and_the_bell_reach_the_guest() -> void:
	var pair: Dictionary = _create_pair()
	var host_swarm: FlockSwarmService = pair["host_swarm"]
	var guest_swarm: FlockSwarmService = pair["guest_swarm"]
	host_swarm.spawn_flock(ROUND_SEED)
	var ids: Array[int] = host_swarm.get_living_sheep_ids()
	var guest_bleats: Array[int] = [0]
	for sheep_id: int in ids:
		(guest_swarm.get_sheep_body(sheep_id) as SheepBody).bleated.connect(
			func() -> void: guest_bleats[0] += 1
		)

	# Grazing: wait until a sheep has been grazing on the host for a moment.
	var grazer: int = -1
	for attempt: int in 600:
		await _simulate(0.1, FAST_WITH_GUEST)
		for sheep_id: int in ids:
			var agent: FlockAgent = host_swarm.get_agent(sheep_id)
			if agent.is_grazing() and agent.time_left > 1.0 and agent.time_left < 2.5:
				grazer = sheep_id
		if grazer != -1:
			break
	assert_ne(grazer, -1, "a sheep grazes on the host")
	var guest_grazer: SheepBody = guest_swarm.get_sheep_body(grazer)
	assert_eq(guest_grazer.get_state(), SheepBody.State.GRAZE, "and is shown grazing on the guest")

	# Bleats: ten sheep, so the next one is never far away.
	for attempt: int in 300:
		if guest_bleats[0] > 0:
			break
		await _simulate(0.1, FAST_WITH_GUEST)
	assert_gt(guest_bleats[0], 0, "bleats arrive as well")

	# Death.
	watch_signals(guest_swarm)
	assert_false(guest_swarm.kill_sheep(ids[0], GameEnums.DeathCause.SHOT), "the guest decides nothing")
	host_swarm.kill_sheep(ids[0], GameEnums.DeathCause.SHOT)
	assert_false(guest_swarm.is_sheep_alive(ids[0]))
	assert_eq(guest_swarm.get_living_count(), _flock_size - 1)
	assert_signal_emit_count(guest_swarm, &"sheep_died", 1)

	# The bell, rung on the guest: the host's sheep answer.
	var origin: Vector2 = (host_swarm.get_sheep_body(ids[1]) as Node2D).global_position
	guest_swarm.ring_bell(origin, 300.0)
	assert_eq(host_swarm.get_agent(ids[1]).activity, FlockAgent.Activity.BELL)
	assert_signal_emitted_with(guest_swarm, &"bell_rung", [origin, 300.0])
	host_swarm.despawn_flock()


func test_guest_knows_the_phase_of_every_sheep() -> void:
	var pair: Dictionary = _create_pair()
	var host_swarm: FlockSwarmService = pair["host_swarm"]
	var guest_swarm: FlockSwarmService = pair["guest_swarm"]
	host_swarm.spawn_flock(ROUND_SEED)
	watch_signals(guest_swarm)

	await _simulate(15.0, FAST_WITH_GUEST)

	assert_gt(
		get_signal_emit_count(guest_swarm, &"sheep_phase_changed"),
		_flock_size,
		"the guest hears of phase changes"
	)
	for sheep_id: int in host_swarm.get_living_sheep_ids():
		assert_eq(
			guest_swarm.get_sheep_phase(sheep_id),
			host_swarm.get_agent(sheep_id).get_phase(),
			"sheep %d" % sheep_id
		)
	host_swarm.despawn_flock()


func test_guest_sheep_move_smoothly_over_a_bad_connection() -> void:
	var pair: Dictionary = _create_pair()
	var host_swarm: FlockSwarmService = pair["host_swarm"]
	var guest_swarm: FlockSwarmService = pair["guest_swarm"]
	var guest_messenger: NetMessenger = (pair["pair"] as SessionPair).guest.messenger
	guest_messenger.sim_latency = 0.06
	guest_messenger.sim_jitter = 0.04
	guest_messenger.sim_loss = 0.15
	host_swarm.spawn_flock(ROUND_SEED)
	# The spawns take their time over this line.
	var arrival_deadline_msec: int = Time.get_ticks_msec() + 2000
	while guest_swarm.get_living_count() < _flock_size and Time.get_ticks_msec() < arrival_deadline_msec:
		await get_tree().process_frame
	var ids: Array[int] = guest_swarm.get_living_sheep_ids()
	assert_eq(ids.size(), _flock_size, "the flock arrives, if a little late")
	var speed: float = Services.perks.get_stat(StatIds.SHEEP_MOVE_SPEED)
	var shown: Dictionary[int, Vector2] = {}
	for sheep_id: int in ids:
		shown[sheep_id] = (guest_swarm.get_sheep_body(sheep_id) as Node2D).global_position
	var travelled: float = 0.0
	var jumps: int = 0
	var largest_gap: float = 0.0

	# In real time: what counts is how far a sheep moves from frame to frame.
	var until_msec: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until_msec:
		await get_tree().process_frame
		var delta: float = get_process_delta_time()
		for sheep_id: int in ids:
			var now: Vector2 = (guest_swarm.get_sheep_body(sheep_id) as Node2D).global_position
			var step: float = now.distance_to(shown[sheep_id])
			travelled += step
			# Twice its walking speed, plus the small correction after a gap.
			jumps += int(step > speed * delta * 2.0 + 12.0)
			shown[sheep_id] = now
			var on_host: Vector2 = (host_swarm.get_sheep_body(sheep_id) as Node2D).global_position
			largest_gap = maxf(largest_gap, now.distance_to(on_host))

	assert_gt(travelled, 500.0, "the guest's sheep walk")
	assert_eq(jumps, 0, "without jumping")
	# A quarter of a second behind at most: interpolation delay plus the line.
	assert_lt(largest_gap, speed * 0.3 + 20.0, "and stay close to where they really are")
	host_swarm.despawn_flock()


func test_every_sheep_is_shown_through_the_same_delay() -> void:
	# Uniform presentation: on the host, a sheep it simulates is drawn where
	# the guest draws it, not where its simulation already is.
	var pair: Dictionary = _create_pair()
	var host_swarm: FlockSwarmService = pair["host_swarm"]
	var guest_swarm: FlockSwarmService = pair["guest_swarm"]
	host_swarm.spawn_flock(ROUND_SEED)

	# Find a sheep in the middle of a walk. This runs in real time: what is
	# compared is where two devices draw a sheep in the very same frame.
	var walker: int = -1
	for attempt: int in 150:
		await _simulate(0.1, 1.0)
		for sheep_id: int in host_swarm.get_living_sheep_ids():
			var body: SheepBody = host_swarm.get_sheep_body(sheep_id)
			if body.get_speed() > 170.0 and host_swarm.get_agent(sheep_id).time_left > 0.5:
				walker = sheep_id
		if walker != -1:
			break
	assert_ne(walker, -1, "a sheep walks at full speed")
	var on_host: SheepBody = host_swarm.get_sheep_body(walker)
	var host_picture: Node2D = on_host.get_node(^"Facing")
	var guest_picture: Node2D = guest_swarm.get_sheep_body(walker).get_node(^"Facing")

	assert_gt(
		host_picture.global_position.distance_to(on_host.global_position),
		6.0,
		"the picture trails the simulation"
	)
	assert_lt(
		host_picture.global_position.distance_to(guest_picture.global_position),
		12.0,
		"host and guest draw the sheep in the same place"
	)
	assert_eq(on_host.get_state(), SheepBody.State.WALK)
	host_swarm.despawn_flock()


# --- Helpers ---------------------------------------------------------------------


## Lets [param seconds] of game time pass, [param factor] times faster than
## real time.
func _simulate(seconds: float, factor: float = FAST) -> void:
	_set_speed(factor)
	for tick: int in maxi(roundi(seconds * TICKS_PER_SECOND), 1):
		await get_tree().physics_frame
	_set_speed(1.0)
	# One ordinary frame, so that pictures are up to date as well.
	await get_tree().process_frame


## Runs the game [param factor] times faster. The time scale alone would only
## make every physics step longer; with more steps per second each step stays
## as long as in the game.
static func _set_speed(factor: float) -> void:
	Engine.time_scale = factor
	Engine.physics_ticks_per_second = roundi(TICKS_PER_SECOND * factor)
	Engine.max_physics_steps_per_frame = maxi(8, ceili(factor * 2.0))


func _flock_center() -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var ids: Array[int] = _swarm.get_living_sheep_ids()
	for sheep_id: int in ids:
		sum += (_swarm.get_sheep_body(sheep_id) as Node2D).global_position
	return sum / ids.size()


func _looks_and_places() -> Array:
	var result: Array = []
	for sheep_id: int in _swarm.get_living_sheep_ids():
		var body: SheepBody = _swarm.get_sheep_body(sheep_id)
		result.append([body.get_visual_seed(), body.position])
	return result


static func _mean_distance_between(positions: Array) -> float:
	var sum: float = 0.0
	var pairs: int = 0
	for first: int in positions.size():
		for second: int in range(first + 1, positions.size()):
			sum += (positions[first] as Vector2).distance_to(positions[second])
			pairs += 1
	return sum / pairs if pairs > 0 else 0.0


## A host and a guest, each with its own arena and its own flock service. The
## guest's arena lives in its own viewport, so the two worlds do not collide.
func _create_pair() -> Dictionary:
	var pair: SessionPair = SessionPair.create(self)
	# The guest's session runs first in every frame. Both devices share one
	# process here; this way the guest's clock has already reached the frame in
	# which the host sends a snapshot, as on a real second device.
	move_child(pair.guest, pair.host.get_index())
	var guest_viewport: SubViewport = add_child_autofree(SubViewport.new())
	var guest_arena: Arena = ARENA_SCENE.instantiate()
	guest_viewport.add_child(guest_arena)
	var host_swarm: FlockSwarmService = add_child_autofree(FlockSwarmService.new())
	var guest_swarm: FlockSwarmService = add_child_autofree(FlockSwarmService.new())
	host_swarm.arena = _arena
	guest_swarm.arena = guest_arena
	host_swarm.setup(pair.host, Services.perks)
	guest_swarm.setup(pair.guest, Services.perks)
	pair.connect_both()
	return {"pair": pair, "host_swarm": host_swarm, "guest_swarm": guest_swarm}

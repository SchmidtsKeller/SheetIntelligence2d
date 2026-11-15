extends TestCase
## The messenger delivers events exactly once and in order, and lets
## snapshots get lost.

const HOST_ID: int = SessionPair.HOST_ID
const GUEST_ID: int = SessionPair.GUEST_ID

const WORLD_EVENT: StringName = &"test.world_event"
const REQUEST: StringName = &"test.request"

var _host: NetMessenger
var _guest: NetMessenger
## What each side handled: [code][event_id, payload, sender_id][/code].
var _host_log: Array[Array] = []
var _guest_log: Array[Array] = []


func before_each() -> void:
	_host_log.clear()
	_guest_log.clear()
	_host = _create_messenger(_host_log)
	_guest = _create_messenger(_guest_log)
	_host.configure(HOST_ID, GUEST_ID, true)
	_guest.configure(GUEST_ID, HOST_ID, false)
	SessionPair.link(_host, _guest)


func test_broadcast_is_handled_here_at_once_and_on_the_other_device() -> void:
	assert_true(_host.broadcast(WORLD_EVENT, [42, "bang", Vector2(1.0, 2.0)]))

	assert_eq(_host_log, [[WORLD_EVENT, [42, "bang", Vector2(1.0, 2.0)], HOST_ID]])
	assert_eq(_guest_log, [[WORLD_EVENT, [42, "bang", Vector2(1.0, 2.0)], HOST_ID]])


func test_request_from_the_guest_reaches_only_the_host() -> void:
	assert_true(_guest.send_to_host(REQUEST, ["shoot"]))

	assert_eq(_host_log, [[REQUEST, ["shoot"], GUEST_ID]])
	assert_eq(_guest_log, [])


func test_request_from_the_host_is_handled_locally() -> void:
	assert_true(_host.send_to_host(REQUEST, ["shoot"]))

	assert_eq(_host_log, [[REQUEST, ["shoot"], HOST_ID]])
	assert_eq(_guest_log, [], "nothing travels: the host is already there")


func test_send_to_remote_skips_this_device() -> void:
	_host.send_to_remote(REQUEST, [1])

	assert_eq(_host_log, [])
	assert_eq(_guest_log.size(), 1)


func test_guest_may_not_send_a_host_only_event() -> void:
	expect_error("only the host may send")

	assert_false(_guest.broadcast(WORLD_EVENT, []))

	assert_eq(_host_log, [])
	assert_eq(_guest_log, [])


func test_forged_host_only_event_is_ignored_by_the_host() -> void:
	# A faulty guest sends it anyway, bypassing its own check.
	_host.receive(true, [0, WORLD_EVENT, ["forged"]], GUEST_ID)

	assert_eq(_host_log, [])


func test_unregistered_event_cannot_be_sent() -> void:
	expect_error("is not registered")

	assert_false(_host.broadcast(&"test.unknown", []))


func test_events_arrive_in_the_order_they_were_sent() -> void:
	for number: int in 20:
		_host.broadcast(WORLD_EVENT, [number])

	assert_eq(_numbers_of(_guest_log), range(20))


func test_events_arrive_exactly_once_and_in_order_on_a_bad_connection() -> void:
	# 50 ms delay plus up to 100 ms jitter: later events overtake earlier ones.
	_guest.sim_latency = 0.05
	_guest.sim_jitter = 0.1
	for number: int in 60:
		_host.broadcast(WORLD_EVENT, [number])
		_guest.advance(0.004)

	assert_lt(_guest_log.size(), 60, "some events are still on their way")
	for step: int in 40:
		_guest.advance(0.01)

	assert_eq(_numbers_of(_guest_log), range(60))


func test_event_sent_while_another_is_still_being_handed_over_keeps_the_order() -> void:
	# The link delivers at once: the guest asks back while the host's first
	# event is still on its way out, and the host answers inside that request.
	var ask_back: Callable = func(payload: Array, _sender_id: int) -> void:
		if payload == [0]:
			_guest.send_to_host(REQUEST, ["asked back"])
	var answer: Callable = func(payload: Array, _sender_id: int) -> void:
		if payload == ["asked back"]:
			_host.broadcast(WORLD_EVENT, [1])
	_guest.subscribe(WORLD_EVENT, ask_back)
	_host.subscribe(REQUEST, answer)

	_host.broadcast(WORLD_EVENT, [0])
	for number: int in range(2, 6):
		_host.broadcast(WORLD_EVENT, [number])
	_guest.send_to_host(REQUEST, ["later"])

	assert_eq(_numbers_of(_guest_log), range(6), "the answer and all later events arrive")
	assert_eq(_numbers_of(_host_log), [0, "asked back", 1, 2, 3, 4, 5, "later"])


func test_event_that_overtook_another_waits_for_it() -> void:
	_host.receive(true, [1, REQUEST, ["second"]], GUEST_ID)
	assert_eq(_host_log, [], "the first one is still missing")

	_host.receive(true, [0, REQUEST, ["first"]], GUEST_ID)

	assert_eq(_host_log, [[REQUEST, ["first"], GUEST_ID], [REQUEST, ["second"], GUEST_ID]])


func test_duplicated_event_is_handled_once() -> void:
	_host.receive(true, [0, REQUEST, ["once"]], GUEST_ID)
	_host.receive(true, [0, REQUEST, ["once"]], GUEST_ID)

	assert_eq(_host_log.size(), 1)


func test_events_are_never_lost_even_when_every_snapshot_is() -> void:
	_guest.sim_loss = 1.0
	watch_signals(_guest)

	_host.broadcast(WORLD_EVENT, [1])
	_host.send_snapshot(1, [0.0])
	_guest.advance(0.01)

	assert_eq(_guest_log.size(), 1)
	assert_signal_not_emitted(_guest, &"snapshot_received")


func test_snapshot_reaches_the_other_device() -> void:
	watch_signals(_guest)

	_host.send_snapshot(7, [1.5, 2.5])

	assert_signal_emitted_with(_guest, &"snapshot_received", [7, [1.5, 2.5], HOST_ID])


func test_outdated_snapshot_is_dropped() -> void:
	watch_signals(_guest)

	_host.send_snapshot(5, ["new"])
	_host.send_snapshot(4, ["old"])
	_host.send_snapshot(5, ["duplicate"])

	assert_signal_emit_count(_guest, &"snapshot_received", 1)


func test_about_half_the_snapshots_survive_fifty_percent_loss() -> void:
	_guest.sim_loss = 0.5
	watch_signals(_guest)

	for tick: int in 400:
		_host.send_snapshot(tick, [])
	_guest.advance(0.01)

	var arrived: int = get_signal_emit_count(_guest, &"snapshot_received")
	assert_gt(arrived, 140)
	assert_lt(arrived, 260)


func test_offline_broadcast_is_handled_locally_and_sends_nothing() -> void:
	var transmitted: Array[bool] = []
	_host.configure(HOST_ID, 0, true)
	_host.transmitter = func(reliable: bool, _message: Array) -> void: transmitted.append(reliable)

	_host.broadcast(WORLD_EVENT, [1])
	_host.send_snapshot(1, [])

	assert_eq(_host_log.size(), 1)
	assert_eq(transmitted, [])
	assert_false(_host.has_remote())


func test_reset_starts_the_sequence_again_on_both_sides() -> void:
	_host.broadcast(WORLD_EVENT, [1])
	_host.broadcast(WORLD_EVENT, [2])

	_host.reset()
	_guest.reset()
	_host.broadcast(WORLD_EVENT, [3])

	assert_eq(_numbers_of(_guest_log), [1, 2, 3])


func test_events_that_arrive_before_the_session_are_handled_once_it_starts() -> void:
	_guest.configure(GUEST_ID, 0, false)
	_host.broadcast(WORLD_EVENT, [1])
	_host.broadcast(WORLD_EVENT, [2])
	_host.send_snapshot(1, ["dropped"])
	assert_eq(_guest_log, [], "nothing is handled before the session starts")

	# As the session starts it.
	_guest.reset()
	_guest.configure(GUEST_ID, HOST_ID, false)
	_guest.receive_early_events()
	_host.broadcast(WORLD_EVENT, [3])

	assert_eq(_numbers_of(_guest_log), [1, 2, 3])


func test_early_events_of_a_session_that_never_started_are_forgotten() -> void:
	_guest.configure(GUEST_ID, 0, false)
	_host.broadcast(WORLD_EVENT, [1])

	# The attempt ends, as the session does it.
	_guest.configure(1, 0, true)
	_guest.configure(GUEST_ID, HOST_ID, false)
	_guest.receive_early_events()

	assert_eq(_guest_log, [])


func test_early_events_count_only_from_the_device_the_session_is_with() -> void:
	_guest.configure(GUEST_ID, 0, false)
	_guest.receive(true, [0, WORLD_EVENT, [9]], 7)
	_host.broadcast(WORLD_EVENT, [1])

	_guest.configure(GUEST_ID, HOST_ID, false)
	_guest.receive_early_events()

	assert_eq(_numbers_of(_guest_log), [1])


func test_subscribers_get_only_their_event() -> void:
	var seen: Array[Array] = []
	var handler: Callable = func(payload: Array, _sender_id: int) -> void: seen.append(payload)
	_guest.subscribe(WORLD_EVENT, handler)

	_host.broadcast(WORLD_EVENT, ["mine"])
	_host.send_to_remote(REQUEST, ["not mine"])
	_guest.unsubscribe(WORLD_EVENT, handler)
	_host.broadcast(WORLD_EVENT, ["after unsubscribing"])

	assert_eq(seen, [["mine"]])


func test_event_ids_survive_the_trip_as_names() -> void:
	# Over a real connection a StringName arrives as a String.
	_guest.receive(true, [0, String(WORLD_EVENT), []], HOST_ID)

	assert_eq(_guest_log.size(), 1)
	assert_eq(typeof(_guest_log[0][0]), TYPE_STRING_NAME)


func _create_messenger(received: Array[Array]) -> NetMessenger:
	var messenger: NetMessenger = add_child_autofree(NetMessenger.new())
	# Tests move time themselves.
	messenger.set_process(false)
	messenger.register_event(WORLD_EVENT, NetMessenger.SenderRule.HOST_ONLY)
	messenger.register_event(REQUEST, NetMessenger.SenderRule.ANYONE)
	messenger.event_received.connect(
		func(event_id: StringName, payload: Array, sender_id: int) -> void:
			received.append([event_id, payload, sender_id])
	)
	return messenger


static func _numbers_of(received: Array[Array]) -> Array:
	var numbers: Array = []
	for entry: Array in received:
		numbers.append(entry[1][0])
	return numbers

extends TestCase
## The desktop dev transport, over real sockets on this computer.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const ConnectionState = NetworkService.ConnectionState
# gdlint: ignore=constant-name
const DisconnectReason = NetworkService.DisconnectReason

## How long a connection on this computer may take.
const TIMEOUT_FRAMES: int = 300
## Random ports to try before giving up on finding a free one.
const PORT_PROBES: int = 50

var _host: EnetNetworkService
var _guest: EnetNetworkService
## Each side is a branch of the scene tree with its own multiplayer API, the
## way two instances of the game each have their own.
var _host_side: Node
var _guest_side: Node
var _port: int = 0


func before_each() -> void:
	_host_side = add_child_autofree(Node.new())
	_guest_side = add_child_autofree(Node.new())
	get_tree().set_multiplayer(SceneMultiplayer.new(), _host_side.get_path())
	get_tree().set_multiplayer(SceneMultiplayer.new(), _guest_side.get_path())
	_host = EnetNetworkService.new()
	_guest = EnetNetworkService.new()
	_host_side.add_child(_host)
	_guest_side.add_child(_guest)
	_port = _free_port()


func after_each() -> void:
	_host.close_session()
	_guest.close_session()
	# The connections are closed one frame after their session ended.
	await wait_frames(2)
	get_tree().set_multiplayer(null, _host_side.get_path())
	get_tree().set_multiplayer(null, _guest_side.get_path())


func test_enet_is_available_on_desktop() -> void:
	assert_true(EnetNetworkService.is_available())


func test_starts_disconnected() -> void:
	assert_eq(_host.get_connection_state(), ConnectionState.DISCONNECTED)
	assert_eq(_host.get_local_peer_id(), 0)
	assert_eq(_host.get_remote_peer_id(), 0)
	assert_null(_host.get_multiplayer_peer())
	assert_true(_host.is_host(), "without a session this device is the authority")
	assert_false(_host.is_offline())
	assert_false(_host.requires_pairing_codes())


func test_host_waits_for_a_guest() -> void:
	assert_eq(_host.host_session({"port": _port}), OK)

	assert_eq(_host.get_connection_state(), ConnectionState.CONNECTING)
	assert_true(_host.is_host())
	assert_not_null(_host.get_multiplayer_peer())
	assert_eq(_host.host_session({"port": _port}), ERR_ALREADY_IN_USE, "one session at a time")


func test_two_instances_connect() -> void:
	watch_signals(_host)
	watch_signals(_guest)

	await _connect_both()

	assert_eq(_host.get_connection_state(), ConnectionState.CONNECTED)
	assert_eq(_guest.get_connection_state(), ConnectionState.CONNECTED)
	assert_true(_host.is_host())
	assert_false(_guest.is_host())
	assert_eq(_host.get_local_peer_id(), 1, "the host is always peer 1")
	assert_ne(_guest.get_local_peer_id(), 1)
	assert_eq(_host.get_remote_peer_id(), _guest.get_local_peer_id())
	assert_eq(_guest.get_remote_peer_id(), 1)
	assert_signal_emit_count(_host, &"session_started", 1)
	assert_signal_emit_count(_guest, &"session_started", 1)


func test_guest_leaving_ends_the_hosts_session() -> void:
	await _connect_both()
	watch_signals(_host)

	_guest.close_session()
	await _wait_until(
		func() -> bool: return _host.get_connection_state() == ConnectionState.DISCONNECTED
	)

	assert_eq(_host.get_connection_state(), ConnectionState.DISCONNECTED)
	assert_eq(get_signal_arguments(_host, &"session_ended")[0], DisconnectReason.REMOTE_CLOSE)
	assert_null(_host.get_multiplayer_peer())


func test_host_leaving_ends_the_guests_session() -> void:
	await _connect_both()
	watch_signals(_guest)

	_host.close_session()
	await _wait_until(
		func() -> bool: return _guest.get_connection_state() == ConnectionState.DISCONNECTED
	)

	assert_eq(_guest.get_connection_state(), ConnectionState.DISCONNECTED)
	var arguments: Array = get_signal_arguments(_guest, &"session_ended")
	assert_eq(arguments[0], DisconnectReason.REMOTE_CLOSE)
	assert_ne(arguments[1], "", "there is a message for the player")


func test_closing_reports_a_local_close() -> void:
	await _connect_both()
	watch_signals(_guest)

	_guest.close_session()

	assert_eq(get_signal_arguments(_guest, &"session_ended")[0], DisconnectReason.LOCAL_CLOSE)
	assert_eq(_guest.get_local_peer_id(), 0)


func test_joining_without_a_host_times_out() -> void:
	_guest.connect_timeout = 0.3
	watch_signals(_guest)

	assert_eq(_guest.join_session({"address": "127.0.0.1", "port": _port}), OK)
	await _wait_until(
		func() -> bool: return _guest.get_connection_state() == ConnectionState.DISCONNECTED
	)

	assert_eq(_guest.get_connection_state(), ConnectionState.DISCONNECTED)
	var reason: DisconnectReason = get_signal_arguments(_guest, &"session_ended")[0]
	assert_true(
		reason == DisconnectReason.TIMED_OUT or reason == DisconnectReason.CONNECTION_FAILED,
		"the attempt fails with a reason"
	)


func test_host_can_host_again_after_a_session() -> void:
	await _connect_both()
	_guest.close_session()
	await _wait_until(
		func() -> bool: return _host.get_connection_state() == ConnectionState.DISCONNECTED
	)

	assert_eq(_host.host_session({"port": _port + 1}), OK)

	assert_eq(_host.get_connection_state(), ConnectionState.CONNECTING)


func test_messages_cross_the_real_connection_in_order() -> void:
	# The whole stack over sockets: messenger, RPC, multiplayer API, ENet.
	var host_messenger: NetMessenger = _create_messenger(_host_side)
	var guest_messenger: NetMessenger = _create_messenger(_guest_side)
	var received_by_guest: Array = []
	var received_by_host: Array = []
	guest_messenger.subscribe(
		&"test.number",
		func(payload: Array, _sender_id: int) -> void: received_by_guest.append(payload[0])
	)
	host_messenger.subscribe(
		&"test.request",
		func(payload: Array, _sender_id: int) -> void: received_by_host.append(payload[0])
	)

	await _connect_both()
	host_messenger.configure(_host.get_local_peer_id(), _host.get_remote_peer_id(), true)
	guest_messenger.configure(_guest.get_local_peer_id(), _guest.get_remote_peer_id(), false)

	for number: int in 25:
		host_messenger.send_to_remote(&"test.number", [number])
		guest_messenger.send_to_host(&"test.request", [number])
	await _wait_until(
		func() -> bool: return received_by_guest.size() >= 25 and received_by_host.size() >= 25
	)

	assert_eq(received_by_guest, range(25), "host to guest: exactly once and in order")
	assert_eq(received_by_host, range(25), "guest to host: exactly once and in order")


func test_snapshots_cross_the_real_connection() -> void:
	var host_messenger: NetMessenger = _create_messenger(_host_side)
	var guest_messenger: NetMessenger = _create_messenger(_guest_side)
	watch_signals(guest_messenger)

	await _connect_both()
	host_messenger.configure(_host.get_local_peer_id(), _host.get_remote_peer_id(), true)
	guest_messenger.configure(_guest.get_local_peer_id(), _guest.get_remote_peer_id(), false)
	host_messenger.send_snapshot(1, [12.5, [1, 100.0, 200.0, 0.5]])
	await _wait_until(
		func() -> bool: return get_signal_emit_count(guest_messenger, &"snapshot_received") > 0
	)

	assert_signal_emitted_with(
		guest_messenger,
		&"snapshot_received",
		[1, [12.5, [1, 100.0, 200.0, 0.5]], _host.get_local_peer_id()]
	)


func test_a_connection_never_holds_snapshots_back() -> void:
	await _connect_both()
	# The setting reaches the other device as a message of its own.
	await wait_frames(5)

	assert_eq(_throttle_deceleration(_host), 0, "the host sends every snapshot")
	assert_eq(_throttle_deceleration(_guest), 0, "the guest sends every snapshot")


func _connect_both() -> void:
	assert_eq(_host.host_session({"port": _port}), OK, "host on port %d" % _port)
	assert_eq(_guest.join_session({"address": "127.0.0.1", "port": _port}), OK)
	await _wait_until(
		func() -> bool:
			return (
				_host.get_connection_state() == ConnectionState.CONNECTED
				and _guest.get_connection_state() == ConnectionState.CONNECTED
			)
	)


func _wait_until(condition: Callable) -> void:
	for frame: int in TIMEOUT_FRAMES:
		if condition.call():
			return
		await get_tree().process_frame


## How fast ENet closes its packet throttle on the connection of
## [param service]. While the throttle is closed ENet drops snapshots before
## it sends them; 0 means it never closes.
static func _throttle_deceleration(service: EnetNetworkService) -> int:
	var connection: Object = service.get_multiplayer_peer().call(
		&"get_peer", service.get_remote_peer_id()
	)
	var statistic: int = ClassDB.class_get_integer_constant(
		&"ENetPacketPeer", &"PEER_PACKET_THROTTLE_DECELERATION"
	)
	return int(connection.call(&"get_statistic", statistic))


static func _create_messenger(parent: Node) -> NetMessenger:
	var messenger: NetMessenger = NetMessenger.new()
	messenger.name = "Messenger"
	parent.add_child(messenger)
	messenger.register_event(&"test.number", NetMessenger.SenderRule.HOST_ONLY)
	messenger.register_event(&"test.request", NetMessenger.SenderRule.ANYONE)
	return messenger


## A random port, away from the default, that this computer lets the test bind,
## together with the next one (a test hosts twice). Windows reserves whole port
## blocks, e.g. for Hyper-V, and binding inside one fails.
static func _free_port() -> int:
	var port: int = 0
	for _probe: int in PORT_PROBES:
		port = 30000 + randi() % 20000
		if _can_bind(port) and _can_bind(port + 1):
			return port
	return port


static func _can_bind(port: int) -> bool:
	var socket: PacketPeerUDP = PacketPeerUDP.new()
	var bound: bool = socket.bind(port, "127.0.0.1") == OK
	socket.close()
	return bound

class_name GameSession
extends Node
## The layer between the connection and the game (see docs/networking.md).
##
## A session is the time two devices are connected, or one device plays
## offline. It answers the questions every gameplay system has: am I the
## host, who plays which role, which screen are we both on. It also owns the
## building blocks for replication: [member messenger] (events and
## snapshots), [member state] (host-owned values) and [member entities]
## (spawning and transforms).
##
## The session only talks to the [NetworkService] contract, so it works the
## same over the offline loopback, the desktop dev transport and WebRTC.

## A session is up: both devices are connected, or the offline session started.
signal session_started

## The session is over. [param message] says why, in words for the player.
signal session_ended(reason: NetworkService.DisconnectReason, message: String)

## The roles were assigned or swapped. Emitted on both devices.
signal roles_changed

## Both devices have loaded [param screen] and may start using it.
signal screen_entered(screen: SceneFlowController.Screen)

const KEY_HOST_ROLE: StringName = &"session.host_role"

const EVENT_SCREEN: StringName = &"session.screen"
const EVENT_SCREEN_READY: StringName = &"session.screen_ready"
const EVENT_SCREEN_ENTERED: StringName = &"session.screen_entered"

## Events and snapshots between the two devices.
var messenger: NetMessenger
## Values the host owns and both devices see.
var state: SyncedState
## The replicated entities.
var entities: NetEntityRegistry

## The scene flow used for screen changes. Defaults to the autoload.
var scene_flow: SceneFlowController:
	get:
		if scene_flow == null and is_inside_tree():
			scene_flow = get_node_or_null(^"/root/SceneFlow") as SceneFlowController
		return scene_flow

## Why the last session ended, for the lobby to show. Empty if none ended yet.
var last_end_message: String = ""

var _network: NetworkService
var _active: bool = false
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

## The screen change in progress; 0 when both devices are settled.
var _transition_id: int = 0
var _transition_screen: SceneFlowController.Screen = SceneFlowController.Screen.NONE
var _ready_peers: Array[int] = []
var _next_transition_id: int = 1


func _init() -> void:
	messenger = NetMessenger.new()
	messenger.name = "Messenger"
	add_child(messenger)
	state = SyncedState.new()
	state.name = "State"
	add_child(state)
	entities = NetEntityRegistry.new()
	entities.name = "Entities"
	add_child(entities)

	state.setup(messenger)
	entities.setup(messenger)
	state.value_changed.connect(_on_state_changed)
	messenger.register_event(EVENT_SCREEN, NetMessenger.SenderRule.HOST_ONLY)
	messenger.register_event(EVENT_SCREEN_READY, NetMessenger.SenderRule.ANYONE)
	messenger.register_event(EVENT_SCREEN_ENTERED, NetMessenger.SenderRule.HOST_ONLY)
	messenger.subscribe(EVENT_SCREEN, _on_screen_event)
	messenger.subscribe(EVENT_SCREEN_READY, _on_screen_ready_event)
	messenger.subscribe(EVENT_SCREEN_ENTERED, _on_screen_entered_event)
	_random.randomize()


## Reads the replication settings from the game configuration.
func configure(config: GameConfig) -> void:
	entities.tick_rate = config.net_tick_rate
	entities.interpolation_delay = config.net_interpolation_delay
	entities.max_extrapolation = config.net_max_extrapolation


## Connects the session to a transport. A running session is ended first.
func bind_network(network: NetworkService) -> void:
	if _network == network:
		return
	if _network != null:
		_network.session_started.disconnect(_on_network_session_started)
		_network.session_ended.disconnect(_on_network_session_ended)
		if _active:
			_end(NetworkService.DisconnectReason.LOCAL_CLOSE, "The connection was replaced.")
	_network = network
	if _network != null:
		_network.session_started.connect(_on_network_session_started)
		_network.session_ended.connect(_on_network_session_ended)


# --- Connection ----------------------------------------------------------------


## Starts a session as the host. See [method NetworkService.host_session].
func host(options: Dictionary = {}) -> Error:
	return _network.host_session(options)


## Joins a session as the guest. See [method NetworkService.join_session].
func join(options: Dictionary = {}) -> Error:
	return _network.join_session(options)


## Leaves the session.
func leave() -> void:
	_network.close_session()


## Whether a session is up.
func is_active() -> bool:
	return _active


## Whether this device is the host. Also [code]true[/code] offline and
## without a session, so single-device scenes behave as the authority.
func is_host() -> bool:
	return _network == null or _network.is_host()


## Whether a second device takes part (false offline).
func has_remote_player() -> bool:
	return _active and _network.get_remote_peer_id() != 0


func get_local_peer_id() -> int:
	return _network.get_local_peer_id() if _active else 0


func get_remote_peer_id() -> int:
	return _network.get_remote_peer_id() if _active else 0


func get_connection_state() -> NetworkService.ConnectionState:
	if _network == null:
		return NetworkService.ConnectionState.DISCONNECTED
	return _network.get_connection_state()


# --- Roles ---------------------------------------------------------------------


## The role of the player on this device.
func get_local_role() -> GameEnums.Role:
	var host_role: GameEnums.Role = _get_host_role()
	return host_role if is_host() else GameEnums.opposite_role(host_role)


## The role of the player on the other device.
func get_remote_role() -> GameEnums.Role:
	return GameEnums.opposite_role(get_local_role())


## The role of the player with [param peer_id].
func get_role_of(peer_id: int) -> GameEnums.Role:
	if peer_id == 0 or not _active:
		return GameEnums.Role.NONE
	return get_local_role() if peer_id == get_local_peer_id() else get_remote_role()


## Gives the host [param host_role] and the guest the other role. Host only.
func assign_roles(host_role: GameEnums.Role) -> bool:
	if host_role == GameEnums.Role.NONE:
		return false
	return state.set_value(KEY_HOST_ROLE, host_role)


## Assigns the roles at random, as for the first round (GDD §2.3). Host only.
func assign_random_roles() -> bool:
	var host_is_sheepherder: bool = _random.randi() % 2 == 0
	return assign_roles(
		GameEnums.Role.SHEEPHERDER if host_is_sheepherder else GameEnums.Role.MONSTER
	)


## Swaps the roles, as after every round (GDD §2.3). Host only.
func swap_roles() -> bool:
	return assign_roles(GameEnums.opposite_role(_get_host_role()))


# --- Screens -------------------------------------------------------------------


## Takes both devices to [param screen]. Host only. Both load the scene, each
## reports when it is ready, and only then [signal screen_entered] is emitted
## on both, so neither starts ahead of the other.
func request_screen(screen: SceneFlowController.Screen) -> bool:
	if not _active or not is_host():
		push_error("GameSession: only the host of a running session can change the screen.")
		return false
	if scene_flow != null and not scene_flow.can_go_to(screen):
		push_error(
			(
				"GameSession: the scene flow does not allow %s."
				% SceneFlowController.screen_name(screen)
			)
		)
		return false
	var transition_id: int = _next_transition_id
	_next_transition_id += 1
	return messenger.broadcast(EVENT_SCREEN, [screen, transition_id])


## Whether a screen change is still waiting for a device to get ready.
func is_changing_screen() -> bool:
	return _transition_id != 0


# --- Internals -----------------------------------------------------------------


func _get_host_role() -> GameEnums.Role:
	return state.get_value(KEY_HOST_ROLE, GameEnums.Role.NONE)


func _on_network_session_started() -> void:
	messenger.reset()
	messenger.configure(
		_network.get_local_peer_id(), _network.get_remote_peer_id(), _network.is_host()
	)
	state.clear()
	entities.clear_local()
	_reset_transition()
	_active = true
	last_end_message = ""
	if _network.is_host():
		assign_random_roles()
		state.send_all()
	session_started.emit()


func _on_network_session_ended(reason: NetworkService.DisconnectReason, message: String) -> void:
	_end(reason, message)


func _end(reason: NetworkService.DisconnectReason, message: String) -> void:
	var was_active: bool = _active
	_active = false
	last_end_message = message
	messenger.configure(1, 0, true)
	messenger.reset()
	entities.clear_local()
	state.clear()
	_reset_transition()
	if was_active:
		_return_to_lobby()
	session_ended.emit(reason, message)


## A round cannot go on without the other player.
func _return_to_lobby() -> void:
	if scene_flow == null:
		return
	var screen: SceneFlowController.Screen = scene_flow.current_screen
	if screen == SceneFlowController.Screen.ROUND or screen == SceneFlowController.Screen.RESULTS:
		scene_flow.go_to(SceneFlowController.Screen.LOBBY)


func _on_state_changed(key: StringName, _value: Variant) -> void:
	if key == KEY_HOST_ROLE:
		roles_changed.emit()


func _on_screen_event(payload: Array, _sender_id: int) -> void:
	var screen: SceneFlowController.Screen = payload[0]
	_transition_id = payload[1]
	_transition_screen = screen
	_ready_peers.clear()
	if scene_flow != null:
		scene_flow.go_to(screen)
	_report_ready_when_loaded(_transition_id)


func _report_ready_when_loaded(transition_id: int) -> void:
	if is_inside_tree():
		# The scene tree swaps the scene at the end of the frame; one more
		# frame lets the new scene finish its own setup.
		await get_tree().process_frame
		await get_tree().process_frame
	if _active and _transition_id == transition_id:
		messenger.send_to_host(EVENT_SCREEN_READY, [transition_id])


func _on_screen_ready_event(payload: Array, sender_id: int) -> void:
	if payload[0] != _transition_id or _ready_peers.has(sender_id):
		return
	_ready_peers.append(sender_id)
	var expected: int = 2 if has_remote_player() else 1
	if _ready_peers.size() >= expected:
		messenger.broadcast(EVENT_SCREEN_ENTERED, [_transition_screen, _transition_id])


func _on_screen_entered_event(payload: Array, _sender_id: int) -> void:
	if payload[1] != _transition_id:
		return
	_reset_transition()
	screen_entered.emit(payload[0])


func _reset_transition() -> void:
	_transition_id = 0
	_transition_screen = SceneFlowController.Screen.NONE
	_ready_peers.clear()

class_name EnetNetworkService
extends NetworkService
## Desktop development transport: a direct ENet connection, by default on
## this computer only.
##
## It lets the networked game run as two desktop instances in seconds,
## without the browser pairing flow. Development only: ENet does not exist in
## Web builds, which connect through WebRTC and pairing codes instead.
##
## Options for [method host_session]: [code]port[/code], [code]lan[/code]
## (accept other computers; default only this one).
## [br]Options for [method join_session]: [code]address[/code], [code]port[/code].

const ENET_CLASS: StringName = &"ENetMultiplayerPeer"
const HOST_PEER_ID: int = 1

## A joining device gives up after this many seconds.
var connect_timeout: float = 10.0

var _peer: MultiplayerPeer
var _api: MultiplayerAPI
var _state: ConnectionState = ConnectionState.DISCONNECTED
var _is_host: bool = false
var _remote_id: int = 0
var _connecting_for: float = 0.0

# What the multiplayer API reported while it was polling the connection. A
# connection must not be replaced or closed from inside its own poll (the
# engine crashes), so the reports are acted on afterwards, in _process.
var _reported_connected_id: int = 0
var _reported_disconnect: bool = false
var _reported_failure: bool = false
## Peers of ended sessions, closed on the next frame for the same reason.
var _retired_peers: Array[MultiplayerPeer] = []


## Whether this build of the engine contains ENet (desktop yes, Web no).
static func is_available() -> bool:
	return ClassDB.class_exists(ENET_CLASS) and ClassDB.can_instantiate(ENET_CLASS)


func _process(delta: float) -> void:
	_close_retired_peers()
	if _peer == null:
		return
	_act_on_reports()
	if _peer == null:
		return
	if _state == ConnectionState.CONNECTING and not _is_host:
		_connecting_for += delta
		if _connecting_for > connect_timeout:
			_end(DisconnectReason.TIMED_OUT, "The host did not answer in time.")
	elif (
		_state == ConnectionState.CONNECTED
		and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
	):
		_end(DisconnectReason.REMOTE_CLOSE, "The connection to the other player was lost.")


func host_session(options: Dictionary = {}) -> Error:
	if _state != ConnectionState.DISCONNECTED:
		return ERR_ALREADY_IN_USE
	var peer: MultiplayerPeer = _create_peer()
	if peer == null:
		return ERR_UNAVAILABLE
	if not options.get("lan", false):
		peer.call(&"set_bind_ip", "127.0.0.1")
	var port: int = options.get("port", LaunchOptions.DEFAULT_PORT)
	# One guest at most: the game is strictly 1v1.
	var error: Error = peer.call(&"create_server", port, 1)
	if error != OK:
		return error
	_adopt(peer, true)
	return OK


func join_session(options: Dictionary = {}) -> Error:
	if _state != ConnectionState.DISCONNECTED:
		return ERR_ALREADY_IN_USE
	var peer: MultiplayerPeer = _create_peer()
	if peer == null:
		return ERR_UNAVAILABLE
	var address: String = options.get("address", LaunchOptions.DEFAULT_ADDRESS)
	var port: int = options.get("port", LaunchOptions.DEFAULT_PORT)
	var error: Error = peer.call(&"create_client", address, port)
	if error != OK:
		return error
	_adopt(peer, false)
	return OK


func close_session() -> void:
	if _state == ConnectionState.DISCONNECTED:
		return
	_end(DisconnectReason.LOCAL_CLOSE, "The session was closed.")


func get_connection_state() -> ConnectionState:
	return _state


func is_host() -> bool:
	return _is_host or _state == ConnectionState.DISCONNECTED


func is_offline() -> bool:
	return false


func get_local_peer_id() -> int:
	return _peer.get_unique_id() if _state == ConnectionState.CONNECTED else 0


func get_remote_peer_id() -> int:
	return _remote_id


func get_multiplayer_peer() -> MultiplayerPeer:
	return _peer


func requires_pairing_codes() -> bool:
	return false


func submit_pairing_code(_code: String) -> Error:
	return ERR_UNAVAILABLE


func _create_peer() -> MultiplayerPeer:
	if not is_inside_tree():
		push_error("EnetNetworkService: must be in the scene tree to open a session.")
		return null
	if not is_available():
		push_error("EnetNetworkService: this build has no ENet. Use it on desktop only.")
		return null
	# Created by name: a direct reference would not compile in a Web build.
	return ClassDB.instantiate(ENET_CLASS) as MultiplayerPeer


## Hands the peer to Godot's multiplayer API before it connects. The API has
## to see the connection being made, or it will not know the other device.
func _adopt(peer: MultiplayerPeer, as_host: bool) -> void:
	_peer = peer
	_is_host = as_host
	_remote_id = 0
	_connecting_for = 0.0
	_reported_connected_id = 0
	_reported_disconnect = false
	_reported_failure = false
	_api = multiplayer
	_api.multiplayer_peer = peer
	_api.peer_connected.connect(_on_peer_connected)
	_api.peer_disconnected.connect(_on_peer_disconnected)
	_api.connection_failed.connect(_on_connection_failed)
	_api.server_disconnected.connect(_on_server_disconnected)
	_set_state(ConnectionState.CONNECTING)


func _on_peer_connected(peer_id: int) -> void:
	# A guest only ever talks to the host.
	if _is_host or peer_id == HOST_PEER_ID:
		_reported_connected_id = peer_id


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id == _remote_id or peer_id == _reported_connected_id:
		_reported_disconnect = true


func _on_connection_failed() -> void:
	_reported_failure = true


func _on_server_disconnected() -> void:
	_reported_disconnect = true


func _act_on_reports() -> void:
	if _reported_connected_id != 0 and _state == ConnectionState.CONNECTING:
		_remote_id = _reported_connected_id
		_set_state(ConnectionState.CONNECTED)
		session_started.emit()
	_reported_connected_id = 0
	if _reported_failure:
		_reported_failure = false
		if _state != ConnectionState.DISCONNECTED:
			_end(DisconnectReason.CONNECTION_FAILED, "Could not connect. Is the host running?")
	if _reported_disconnect:
		_reported_disconnect = false
		if _state != ConnectionState.DISCONNECTED:
			_end(DisconnectReason.REMOTE_CLOSE, "The other player left the session.")


func _close_retired_peers() -> void:
	for peer: MultiplayerPeer in _retired_peers:
		peer.close()
	_retired_peers.clear()


func _end(reason: DisconnectReason, message: String) -> void:
	var peer: MultiplayerPeer = _peer
	_peer = null
	_remote_id = 0
	_is_host = false
	if _api != null:
		_api.peer_connected.disconnect(_on_peer_connected)
		_api.peer_disconnected.disconnect(_on_peer_disconnected)
		_api.connection_failed.disconnect(_on_connection_failed)
		_api.server_disconnected.disconnect(_on_server_disconnected)
		if _api.multiplayer_peer == peer:
			_api.multiplayer_peer = OfflineMultiplayerPeer.new()
		_api = null
	if peer != null:
		_retired_peers.append(peer)
	_set_state(ConnectionState.DISCONNECTED)
	session_ended.emit(reason, message)


func _set_state(state: ConnectionState) -> void:
	if state == _state:
		return
	_state = state
	connection_state_changed.emit(state)

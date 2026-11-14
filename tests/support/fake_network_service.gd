class_name FakeNetworkService
extends NetworkService
## A [NetworkService] that tests steer by hand: it connects when told to and
## ends when told to. It carries no data; see [SessionPair] for the link.

var local_id: int = 1
var remote_id: int = 0
var host: bool = true

var _state: ConnectionState = ConnectionState.DISCONNECTED


## Pretends the other device connected.
func simulate_started() -> void:
	_set_state(ConnectionState.CONNECTED)
	session_started.emit()


## Pretends the session ended, e.g. because the other device went away.
func simulate_ended(reason: DisconnectReason, message: String) -> void:
	_set_state(ConnectionState.DISCONNECTED)
	session_ended.emit(reason, message)


func host_session(_options: Dictionary = {}) -> Error:
	host = true
	_set_state(ConnectionState.CONNECTING)
	return OK


func join_session(_options: Dictionary = {}) -> Error:
	host = false
	_set_state(ConnectionState.CONNECTING)
	return OK


func close_session() -> void:
	if _state != ConnectionState.DISCONNECTED:
		simulate_ended(DisconnectReason.LOCAL_CLOSE, "The session was closed.")


func get_connection_state() -> ConnectionState:
	return _state


func is_host() -> bool:
	return host


func is_offline() -> bool:
	return false


func get_local_peer_id() -> int:
	return local_id if _state == ConnectionState.CONNECTED else 0


func get_remote_peer_id() -> int:
	return remote_id if _state == ConnectionState.CONNECTED else 0


func get_multiplayer_peer() -> MultiplayerPeer:
	return null


func requires_pairing_codes() -> bool:
	return false


func submit_pairing_code(_code: String) -> Error:
	return ERR_UNAVAILABLE


func _set_state(state: ConnectionState) -> void:
	if state == _state:
		return
	_state = state
	connection_state_changed.emit(state)

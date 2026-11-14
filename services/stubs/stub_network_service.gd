class_name StubNetworkService
extends NetworkService
## Offline [NetworkService]: a session of one.
##
## Hosting succeeds immediately with an [OfflineMultiplayerPeer], so this
## device is the authoritative host without any second device. Joining is
## impossible, because there is nobody to join.

const _OFFLINE_PEER_ID: int = 1

var _state: ConnectionState = ConnectionState.DISCONNECTED
var _peer: MultiplayerPeer


func host_session(_options: Dictionary = {}) -> Error:
	if _state != ConnectionState.DISCONNECTED:
		return ERR_ALREADY_IN_USE
	_peer = OfflineMultiplayerPeer.new()
	_set_state(ConnectionState.CONNECTED)
	session_started.emit()
	return OK


func join_session(_options: Dictionary = {}) -> Error:
	return ERR_UNAVAILABLE


func close_session() -> void:
	if _state == ConnectionState.DISCONNECTED:
		return
	_peer = null
	_set_state(ConnectionState.DISCONNECTED)
	session_ended.emit(DisconnectReason.LOCAL_CLOSE, "The session was closed.")


func get_connection_state() -> ConnectionState:
	return _state


func is_host() -> bool:
	return true


func is_offline() -> bool:
	return true


func get_local_peer_id() -> int:
	return _OFFLINE_PEER_ID if _state == ConnectionState.CONNECTED else 0


func get_remote_peer_id() -> int:
	return 0


func get_multiplayer_peer() -> MultiplayerPeer:
	return _peer


func requires_pairing_codes() -> bool:
	return false


func submit_pairing_code(_code: String) -> Error:
	return ERR_UNAVAILABLE


func _set_state(state: ConnectionState) -> void:
	if state == _state:
		return
	_state = state
	connection_state_changed.emit(state)

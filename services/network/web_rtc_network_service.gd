class_name WebRtcNetworkService
extends NetworkService
## The Web build's transport (GDD §9.4): WebRTC between two browsers in the
## same network, without any server.
##
## The devices exchange two [PairingCode]s instead of talking to a signalling
## server. The host makes an offer; the guest reads it and makes an answer;
## the host reads the answer, and the devices connect. Each code is made once
## the browser has found all of its addresses (ICE candidates), so it holds
## everything the other side needs. There are no STUN or TURN servers: both
## devices must reach each other directly in the local network.
##
## WebRTC is built into Web exports only; desktop builds use the ENet
## transport instead.

const HOST_PEER_ID: int = 1
const GUEST_PEER_ID: int = 2
## A code is made with what was found if the browser has not finished looking
## for addresses after this many seconds.
const GATHERING_TIMEOUT: float = 3.0
## The two transfer channels [NetMessenger] uses: 1 for events, 2 for snapshots.
const CHANNELS: Array[MultiplayerPeer.TransferMode] = [
	MultiplayerPeer.TRANSFER_MODE_RELIABLE,
	MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
]
const NO_PATH_HINT: String = (
	"Both devices must be in the same Wi-Fi. Some networks, such as guest Wi-Fi,"
	+ " keep devices from reaching each other."
)

## Once both codes are in, the devices give up connecting after this many seconds.
var connect_timeout: float = 30.0

var _peer: WebRTCMultiplayerPeer
var _connection: WebRTCPeerConnection
var _api: MultiplayerAPI
var _state: ConnectionState = ConnectionState.DISCONNECTED
var _is_host: bool = false
var _remote_id: int = 0
var _session_id: int = 0
var _local_type: String = ""
var _local_sdp: String = ""
var _candidates: Array = []
var _gathering_for: float = 0.0
var _code_sent: bool = false
## Whether the other side's code was applied.
var _remote_set: bool = false
## Seconds since both codes were in; negative while waiting for a code.
var _connecting_for: float = -1.0
var _pairing_problem: String = ""

# Reported while the connection was polled, acted on in _process (see
# EnetNetworkService: a connection must not be closed from inside its poll).
var _reported_connected_id: int = 0
var _reported_disconnect: bool = false
var _retired_peers: Array[MultiplayerPeer] = []


## Whether this build can use WebRTC without a plugin: only Web exports.
static func is_available() -> bool:
	return OS.has_feature("web")


func _process(delta: float) -> void:
	for peer: MultiplayerPeer in _retired_peers:
		peer.close()
	_retired_peers.clear()
	if _peer == null:
		return
	_act_on_reports()
	if _peer == null or _state != ConnectionState.CONNECTING:
		if _state == ConnectionState.CONNECTED and _connection_lost():
			_end(DisconnectReason.REMOTE_CLOSE, "The connection to the other player was lost.")
		return
	_send_code_when_gathered(delta)
	if _connection.get_connection_state() == WebRTCPeerConnection.STATE_FAILED:
		_end(DisconnectReason.CONNECTION_FAILED, "Could not connect. " + NO_PATH_HINT)
		return
	if _connecting_for >= 0.0:
		_connecting_for += delta
		if _connecting_for > connect_timeout:
			_end(DisconnectReason.TIMED_OUT, "Connecting took too long. " + NO_PATH_HINT)


func host_session(_options: Dictionary = {}) -> Error:
	if _state != ConnectionState.DISCONNECTED:
		return ERR_ALREADY_IN_USE
	var error: Error = _start(true)
	if error != OK:
		return error
	_session_id = Crypto.new().generate_random_bytes(4).decode_u32(0)
	error = _connection.create_offer()
	if error != OK:
		_end(DisconnectReason.CONNECTION_FAILED, "Could not prepare the code.")
	return error


func join_session(_options: Dictionary = {}) -> Error:
	if _state != ConnectionState.DISCONNECTED:
		return ERR_ALREADY_IN_USE
	return _start(false)


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
	return true


## The host takes one answer once its offer is out; the guest takes one offer.
func submit_pairing_code(code: String) -> Error:
	_pairing_problem = ""
	if _state != ConnectionState.CONNECTING or _remote_set or (_is_host and not _code_sent):
		return ERR_UNAVAILABLE
	var expected: PairingCode.Kind = PairingCode.Kind.ANSWER if _is_host else PairingCode.Kind.OFFER
	var pairing: PairingCode = PairingCode.decode_expected(code, expected, _session_id)
	if pairing.problem != PairingCode.Problem.NONE:
		_pairing_problem = PairingCode.describe(pairing.problem)
		return ERR_INVALID_DATA
	_remote_set = true
	if _is_host:
		# The guest made its code already; only the connection is left.
		_connecting_for = 0.0
		return _connection.set_remote_description("answer", pairing.description)
	_session_id = pairing.session_id
	return _connection.set_remote_description("offer", pairing.description)


func get_pairing_problem() -> String:
	return _pairing_problem


func _start(as_host: bool) -> Error:
	if not is_inside_tree():
		push_error("WebRtcNetworkService: must be in the scene tree to open a session.")
		return ERR_UNCONFIGURED
	var peer: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
	var error: Error = (
		peer.create_server(CHANNELS) if as_host else peer.create_client(GUEST_PEER_ID, CHANNELS)
	)
	if error != OK:
		return error
	var connection: WebRTCPeerConnection = WebRTCPeerConnection.new()
	# No STUN or TURN server: the devices meet in the local network.
	error = connection.initialize({"iceServers": []})
	if error != OK:
		return error
	connection.session_description_created.connect(_on_session_description_created)
	connection.ice_candidate_created.connect(_on_ice_candidate_created)
	error = peer.add_peer(connection, GUEST_PEER_ID if as_host else HOST_PEER_ID)
	if error != OK:
		return error
	_peer = peer
	_connection = connection
	_is_host = as_host
	_remote_id = 0
	_session_id = 0
	_local_type = ""
	_local_sdp = ""
	_candidates.clear()
	_gathering_for = 0.0
	_code_sent = false
	_remote_set = false
	_connecting_for = -1.0
	_pairing_problem = ""
	_reported_connected_id = 0
	_reported_disconnect = false
	# The multiplayer API has to see the connection being made (see the contract).
	_api = multiplayer
	_api.multiplayer_peer = peer
	_api.peer_connected.connect(_on_peer_connected)
	_api.peer_disconnected.connect(_on_peer_disconnected)
	_set_state(ConnectionState.CONNECTING)
	return OK


## [param answer] with the guest waiting for the host to start the encryption
## (DTLS), as RFC 5763 allows. By default the guest starts it as soon as it
## reaches the host, which can be long before the host has read the answer;
## Chrome keeps such early messages, Firefox does not (docs/pairing.md).
static func as_passive_answer(answer: String) -> String:
	return answer.replace("a=setup:active", "a=setup:passive")


func _on_session_description_created(type: String, sdp: String) -> void:
	if type == "answer":
		sdp = as_passive_answer(sdp)
	_local_type = type
	_local_sdp = sdp
	_connection.set_local_description(type, sdp)


func _on_ice_candidate_created(media: String, index: int, candidate: String) -> void:
	_candidates.append([media, index, candidate])


## Makes this device's code once the browser has all its addresses, or after
## [constant GATHERING_TIMEOUT].
func _send_code_when_gathered(delta: float) -> void:
	if _code_sent or _local_sdp.is_empty():
		return
	_gathering_for += delta
	var complete: bool = (
		_connection.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE
	)
	if not complete and _gathering_for < GATHERING_TIMEOUT:
		return
	if _candidates.is_empty():
		_end(DisconnectReason.CONNECTION_FAILED, "This device is not connected to a network.")
		return
	_code_sent = true
	var kind: PairingCode.Kind = PairingCode.Kind.OFFER if _is_host else PairingCode.Kind.ANSWER
	var description: String = PairingCode.with_candidates(_local_sdp, _candidates)
	pairing_code_ready.emit(PairingCode.encode(kind, _session_id, description))


func _on_peer_connected(peer_id: int) -> void:
	_reported_connected_id = peer_id


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id == _remote_id or peer_id == _reported_connected_id:
		_reported_disconnect = true


func _act_on_reports() -> void:
	if _reported_connected_id != 0 and _state == ConnectionState.CONNECTING:
		_remote_id = _reported_connected_id
		_set_state(ConnectionState.CONNECTED)
		session_started.emit()
	_reported_connected_id = 0
	if _reported_disconnect:
		_reported_disconnect = false
		if _state != ConnectionState.DISCONNECTED:
			_end(DisconnectReason.REMOTE_CLOSE, "The other player left the session.")


func _connection_lost() -> bool:
	var state: WebRTCPeerConnection.ConnectionState = _connection.get_connection_state()
	return state == WebRTCPeerConnection.STATE_FAILED or state == WebRTCPeerConnection.STATE_CLOSED


func _end(reason: DisconnectReason, message: String) -> void:
	var peer: MultiplayerPeer = _peer
	_peer = null
	_connection = null
	_remote_id = 0
	_is_host = false
	_connecting_for = -1.0
	if _api != null:
		_api.peer_connected.disconnect(_on_peer_connected)
		_api.peer_disconnected.disconnect(_on_peer_disconnected)
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

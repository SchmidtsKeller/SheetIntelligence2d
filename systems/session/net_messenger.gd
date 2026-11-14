class_name NetMessenger
extends Node
## Carries messages between the two devices of a session.
##
## There are two kinds of message, on two channels (see docs/networking.md):
## [br][b]Events[/b] are reliable and ordered: each arrives exactly once, in
## the order it was sent. They carry everything that must not be lost (shots,
## deaths, scores, spawns, role changes).
## [br][b]Snapshots[/b] are unreliable: a lost one is simply replaced by the
## next. They carry continuous state (positions) several times per second.
##
## The messenger does not know the transport. It hands messages to Godot's
## multiplayer API, which sends them over whatever peer the session uses.
## Tests replace [member transmitter] to connect two messengers directly.

## A reliable event arrived (or was dispatched locally).
signal event_received(event_id: StringName, payload: Array, sender_id: int)

## A snapshot arrived. [param tick] counts the sender's snapshots.
signal snapshot_received(tick: int, payload: Array, sender_id: int)

## Who is allowed to send an event.
enum SenderRule {
	## Only the host: world and combat events, round and match state.
	HOST_ONLY,
	## Either device: requests to the host, and what a player owns.
	ANYONE,
}

## Sends one message to the other device: [code](reliable: bool, message:
## Array) -> void[/code]. Tests point this at the other messenger's
## [method receive].
var transmitter: Callable = _transmit_rpc

## Simulated network conditions for incoming messages, to exercise the
## interpolation and the ordering. All zero means off.
var sim_latency: float = 0.0
var sim_jitter: float = 0.0
## Share of snapshots that are dropped (0..1). Events are never dropped.
var sim_loss: float = 0.0

var _local_id: int = 1
var _remote_id: int = 0
var _is_host: bool = true

var _rules: Dictionary[StringName, SenderRule] = {}
var _handlers: Dictionary[StringName, Array] = {}

var _next_send_sequence: int = 0
var _next_receive_sequence: int = 0
## Events that arrived ahead of an earlier one, by sequence number.
var _waiting_events: Dictionary[int, Array] = {}
var _latest_snapshot_tick: int = -1

var _time: float = 0.0
## Incoming messages held back by the simulated conditions:
## [code]{"at": float, "reliable": bool, "message": Array, "sender": int}[/code].
var _delayed: Array[Dictionary] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_random.seed = 20261114


func _process(delta: float) -> void:
	advance(delta)


## Tells the messenger who is who. Called by the session when it starts.
## [param remote_id] is 0 when there is no other device (offline).
func configure(local_id: int, remote_id: int, is_host: bool) -> void:
	_local_id = local_id
	_remote_id = remote_id
	_is_host = is_host


## Forgets all message state. Called when a session starts and when it ends.
func reset() -> void:
	_next_send_sequence = 0
	_next_receive_sequence = 0
	_waiting_events.clear()
	_latest_snapshot_tick = -1
	_delayed.clear()


func is_host() -> bool:
	return _is_host


func has_remote() -> bool:
	return _remote_id != 0


func get_local_id() -> int:
	return _local_id


func get_remote_id() -> int:
	return _remote_id


## Declares an event and who may send it. Every event must be registered on
## both devices before it is used.
func register_event(event_id: StringName, rule: SenderRule) -> void:
	_rules[event_id] = rule


## Calls [param handler] with [code](payload: Array, sender_id: int)[/code]
## whenever [param event_id] arrives or is dispatched locally.
func subscribe(event_id: StringName, handler: Callable) -> void:
	var handlers: Array = _handlers.get_or_add(event_id, [])
	if not handlers.has(handler):
		handlers.append(handler)


func unsubscribe(event_id: StringName, handler: Callable) -> void:
	if _handlers.has(event_id):
		_handlers[event_id].erase(handler)


## Sends an event to both devices: it is handled here immediately and on the
## other device when it arrives. This is how the host announces what happened.
func broadcast(event_id: StringName, payload: Array = []) -> bool:
	if not _may_send(event_id):
		return false
	_dispatch(event_id, payload, _local_id)
	_send_event(event_id, payload)
	return true


## Sends an event to the host. On the host itself it is handled immediately,
## so code that asks the host for something is the same on both devices.
func send_to_host(event_id: StringName, payload: Array = []) -> bool:
	if not _may_send(event_id):
		return false
	if _is_host:
		_dispatch(event_id, payload, _local_id)
	else:
		_send_event(event_id, payload)
	return true


## Sends an event to the other device only.
func send_to_remote(event_id: StringName, payload: Array = []) -> bool:
	if not _may_send(event_id):
		return false
	_send_event(event_id, payload)
	return true


## Sends a snapshot to the other device. It may get lost.
func send_snapshot(tick: int, payload: Array) -> void:
	if has_remote():
		transmitter.call(false, [tick, payload])


## Takes a message from the other device. Called by the RPCs, and by tests.
func receive(reliable: bool, message: Array, sender_id: int) -> void:
	if sim_latency <= 0.0 and sim_jitter <= 0.0 and sim_loss <= 0.0:
		_deliver(reliable, message, sender_id)
		return
	if not reliable and _random.randf() < sim_loss:
		return
	(
		_delayed
		. append(
			{
				"at": _time + sim_latency + _random.randf() * sim_jitter,
				"reliable": reliable,
				"message": message,
				"sender": sender_id,
			}
		)
	)


## Moves time forward and delivers the messages whose simulated delay is over.
func advance(delta: float) -> void:
	_time += delta
	if _delayed.is_empty():
		return
	var due: Array[Dictionary] = []
	for entry: Dictionary in _delayed:
		if entry["at"] <= _time:
			due.append(entry)
	for entry: Dictionary in due:
		_delayed.erase(entry)
		_deliver(entry["reliable"], entry["message"], entry["sender"])


func _deliver(reliable: bool, message: Array, sender_id: int) -> void:
	if reliable:
		_deliver_event(message, sender_id)
	else:
		_deliver_snapshot(message, sender_id)


## Hands events on strictly in sequence: a duplicate is dropped, an event that
## overtook an earlier one waits for it.
func _deliver_event(message: Array, sender_id: int) -> void:
	if message.size() != 3:
		push_warning("NetMessenger: ignored a malformed event message.")
		return
	var sequence: int = message[0]
	if sequence < _next_receive_sequence or _waiting_events.has(sequence):
		return
	_waiting_events[sequence] = [message[1], message[2], sender_id]
	while _waiting_events.has(_next_receive_sequence):
		var event: Array = _waiting_events[_next_receive_sequence]
		_waiting_events.erase(_next_receive_sequence)
		_next_receive_sequence += 1
		_accept_event(event[0], event[1], event[2])


func _accept_event(event_id: StringName, payload: Array, sender_id: int) -> void:
	if not _rules.has(event_id):
		push_warning("NetMessenger: ignored the unregistered event '%s'." % event_id)
		return
	# A host-only event can only come from the host, which is never this device
	# when the event arrives over the network on the host.
	if _rules[event_id] == SenderRule.HOST_ONLY and _is_host:
		push_warning("NetMessenger: ignored '%s', which only the host may send." % event_id)
		return
	_dispatch(event_id, payload, sender_id)


func _deliver_snapshot(message: Array, sender_id: int) -> void:
	if message.size() != 2:
		push_warning("NetMessenger: ignored a malformed snapshot message.")
		return
	var tick: int = message[0]
	if tick <= _latest_snapshot_tick:
		return
	_latest_snapshot_tick = tick
	snapshot_received.emit(tick, message[1], sender_id)


func _dispatch(event_id: StringName, payload: Array, sender_id: int) -> void:
	event_received.emit(event_id, payload, sender_id)
	if not _handlers.has(event_id):
		return
	for handler: Callable in _handlers[event_id].duplicate():
		handler.call(payload, sender_id)


func _may_send(event_id: StringName) -> bool:
	if not _rules.has(event_id):
		push_error("NetMessenger: the event '%s' is not registered." % event_id)
		return false
	if _rules[event_id] == SenderRule.HOST_ONLY and not _is_host:
		push_error("NetMessenger: only the host may send '%s'." % event_id)
		return false
	return true


func _send_event(event_id: StringName, payload: Array) -> void:
	if not has_remote():
		return
	transmitter.call(true, [_next_send_sequence, event_id, payload])
	_next_send_sequence += 1


func _transmit_rpc(reliable: bool, message: Array) -> void:
	if not is_inside_tree():
		return
	if reliable:
		_rpc_event.rpc_id(_remote_id, message)
	else:
		_rpc_snapshot.rpc_id(_remote_id, message)


@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_event(message: Array) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == _remote_id:
		receive(true, message, sender_id)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _rpc_snapshot(message: Array) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == _remote_id:
		receive(false, message, sender_id)

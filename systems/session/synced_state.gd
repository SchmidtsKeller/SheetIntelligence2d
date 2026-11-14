class_name SyncedState
extends Node
## A small key-value store that the host owns and both devices see.
##
## For state that changes rarely and must never diverge: roles, the round
## state, scores. The host sets a value; the guest receives it as a reliable
## event and both emit [signal value_changed]. When a guest connects, the host
## sends everything it has.
##
## Values must be plain data (numbers, strings, arrays, dictionaries).

## A value was set or changed. Emitted on both devices.
signal value_changed(key: StringName, value: Variant)

const EVENT_SET: StringName = &"state.set"
const EVENT_FULL: StringName = &"state.full"

var _messenger: NetMessenger
var _values: Dictionary[StringName, Variant] = {}


func setup(messenger: NetMessenger) -> void:
	_messenger = messenger
	messenger.register_event(EVENT_SET, NetMessenger.SenderRule.HOST_ONLY)
	messenger.register_event(EVENT_FULL, NetMessenger.SenderRule.HOST_ONLY)
	messenger.subscribe(EVENT_SET, _on_set)
	messenger.subscribe(EVENT_FULL, _on_full)


## Sets [param key] for both devices. Only the host may do this; returns
## [code]false[/code] on the guest.
func set_value(key: StringName, value: Variant) -> bool:
	return _messenger.broadcast(EVENT_SET, [key, value])


func get_value(key: StringName, default: Variant = null) -> Variant:
	return _values.get(key, default)


func has_value(key: StringName) -> bool:
	return _values.has(key)


## Sends every value to the guest. Called by the session once a guest is there.
func send_all() -> void:
	if _messenger.is_host() and _messenger.has_remote():
		_messenger.send_to_remote(EVENT_FULL, [_values.duplicate(true)])


## Forgets all values on this device. Called when a session ends.
func clear() -> void:
	_values.clear()


func _on_set(payload: Array, _sender_id: int) -> void:
	_store(payload[0], payload[1])


func _on_full(payload: Array, _sender_id: int) -> void:
	var values: Dictionary = payload[0]
	for key: Variant in values:
		_store(StringName(key), values[key])


func _store(key: StringName, value: Variant) -> void:
	if _values.has(key) and _values[key] == value:
		return
	_values[key] = value
	value_changed.emit(key, value)

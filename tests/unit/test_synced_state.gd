extends TestCase
## Synced state: the host sets a value, both devices see it.

var _host_messenger: NetMessenger
var _guest_messenger: NetMessenger
var _host: SyncedState
var _guest: SyncedState


func before_each() -> void:
	_host_messenger = add_child_autofree(NetMessenger.new())
	_guest_messenger = add_child_autofree(NetMessenger.new())
	_host_messenger.configure(SessionPair.HOST_ID, SessionPair.GUEST_ID, true)
	_guest_messenger.configure(SessionPair.GUEST_ID, SessionPair.HOST_ID, false)
	SessionPair.link(_host_messenger, _guest_messenger)
	_host = add_child_autofree(SyncedState.new())
	_guest = add_child_autofree(SyncedState.new())
	_host.setup(_host_messenger)
	_guest.setup(_guest_messenger)


func test_value_set_by_the_host_is_seen_on_both_devices() -> void:
	watch_signals(_host)
	watch_signals(_guest)

	assert_true(_host.set_value(&"round", 3))

	assert_eq(_host.get_value(&"round"), 3)
	assert_eq(_guest.get_value(&"round"), 3)
	assert_signal_emitted_with(_host, &"value_changed", [&"round", 3])
	assert_signal_emitted_with(_guest, &"value_changed", [&"round", 3])


func test_guest_cannot_set_a_value() -> void:
	expect_error("only the host may send")

	assert_false(_guest.set_value(&"round", 99))

	assert_false(_host.has_value(&"round"))
	assert_false(_guest.has_value(&"round"))


func test_missing_value_gives_the_default() -> void:
	assert_null(_guest.get_value(&"nothing"))
	assert_eq(_guest.get_value(&"nothing", 7), 7)
	assert_false(_guest.has_value(&"nothing"))


func test_setting_the_same_value_again_is_not_announced() -> void:
	_host.set_value(&"score", 1)
	watch_signals(_guest)

	_host.set_value(&"score", 1)
	assert_signal_not_emitted(_guest, &"value_changed")

	_host.set_value(&"score", 2)
	assert_signal_emit_count(_guest, &"value_changed", 1)


func test_structured_values_are_kept_intact() -> void:
	var result: Dictionary = {"outcome": 2, "points": [3, -2], "reason": "timeout"}

	_host.set_value(&"result", result)

	assert_eq(_guest.get_value(&"result"), result)


func test_guest_that_connects_later_gets_everything() -> void:
	# The host collected state before anybody was connected.
	_host_messenger.configure(SessionPair.HOST_ID, 0, true)
	_host.set_value(&"round", 2)
	_host.set_value(&"host_role", GameEnums.Role.MONSTER)
	assert_false(_guest.has_value(&"round"))

	_host_messenger.configure(SessionPair.HOST_ID, SessionPair.GUEST_ID, true)
	_host.send_all()

	assert_eq(_guest.get_value(&"round"), 2)
	assert_eq(_guest.get_value(&"host_role"), GameEnums.Role.MONSTER)


func test_clear_forgets_the_values_of_this_device_only() -> void:
	_host.set_value(&"round", 2)

	_guest.clear()

	assert_false(_guest.has_value(&"round"))
	assert_true(_host.has_value(&"round"))

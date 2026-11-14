extends TestCase
## The session: who is host, who plays which role, which screen both are on.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Role = GameEnums.Role
# gdlint: ignore=constant-name
const Screen = SceneFlowController.Screen

var _pair: SessionPair


func before_each() -> void:
	_pair = SessionPair.create(self)


func after_each() -> void:
	_pair = null


# --- Lifecycle -------------------------------------------------------------------


func test_without_a_session_this_device_is_the_authority() -> void:
	assert_false(_pair.host.is_active())
	assert_true(_pair.host.is_host())
	assert_false(_pair.host.has_remote_player())
	assert_eq(_pair.host.get_local_peer_id(), 0)
	assert_eq(_pair.host.get_local_role(), Role.NONE)


func test_session_starts_on_both_devices() -> void:
	watch_signals(_pair.host)
	watch_signals(_pair.guest)

	_pair.connect_both()

	assert_true(_pair.host.is_active())
	assert_true(_pair.guest.is_active())
	assert_true(_pair.host.is_host())
	assert_false(_pair.guest.is_host())
	assert_true(_pair.host.has_remote_player())
	assert_eq(_pair.host.get_local_peer_id(), SessionPair.HOST_ID)
	assert_eq(_pair.host.get_remote_peer_id(), SessionPair.GUEST_ID)
	assert_eq(_pair.guest.get_local_peer_id(), SessionPair.GUEST_ID)
	assert_eq(_pair.guest.get_remote_peer_id(), SessionPair.HOST_ID)
	assert_signal_emit_count(_pair.host, &"session_started", 1)
	assert_signal_emit_count(_pair.guest, &"session_started", 1)


func test_connection_state_follows_the_transport() -> void:
	assert_eq(_pair.guest.get_connection_state(), NetworkService.ConnectionState.DISCONNECTED)

	_pair.guest.join()
	assert_eq(_pair.guest.get_connection_state(), NetworkService.ConnectionState.CONNECTING)

	_pair.connect_both()
	assert_eq(_pair.guest.get_connection_state(), NetworkService.ConnectionState.CONNECTED)


func test_losing_the_other_player_ends_the_session_with_a_message() -> void:
	_pair.connect_both()
	watch_signals(_pair.guest)

	_pair.guest_network.simulate_ended(
		NetworkService.DisconnectReason.REMOTE_CLOSE, "The other player left the session."
	)

	assert_false(_pair.guest.is_active())
	assert_eq(_pair.guest.last_end_message, "The other player left the session.")
	assert_eq(_pair.guest.get_local_role(), Role.NONE, "session state is gone")
	assert_signal_emitted_with(
		_pair.guest,
		&"session_ended",
		[NetworkService.DisconnectReason.REMOTE_CLOSE, "The other player left the session."]
	)


func test_losing_the_other_player_during_a_round_returns_to_the_lobby() -> void:
	_pair.connect_both()
	_pair.guest_flow.go_to(Screen.ROUND)

	_pair.guest_network.simulate_ended(NetworkService.DisconnectReason.REMOTE_CLOSE, "Gone.")

	assert_eq(_pair.guest_flow.current_screen, Screen.LOBBY)


func test_losing_the_other_player_in_the_lobby_stays_in_the_lobby() -> void:
	_pair.connect_both()
	_pair.guest_flow.go_to(Screen.LOBBY)
	var scenes_before: int = _pair.guest_scenes.size()

	_pair.guest_network.simulate_ended(NetworkService.DisconnectReason.REMOTE_CLOSE, "Gone.")

	assert_eq(_pair.guest_flow.current_screen, Screen.LOBBY)
	assert_eq(_pair.guest_scenes.size(), scenes_before, "no scene was reloaded")


func test_failed_connection_attempt_is_reported_without_a_session() -> void:
	watch_signals(_pair.guest)
	_pair.guest.join()

	_pair.guest_network.simulate_ended(
		NetworkService.DisconnectReason.TIMED_OUT, "The host did not answer in time."
	)

	assert_false(_pair.guest.is_active())
	assert_eq(_pair.guest.last_end_message, "The host did not answer in time.")
	assert_signal_emit_count(_pair.guest, &"session_ended", 1)


func test_leaving_ends_the_session() -> void:
	_pair.connect_both()

	_pair.host.leave()

	assert_false(_pair.host.is_active())


func test_entities_are_removed_when_the_session_ends() -> void:
	_pair.connect_both()
	_register_entity_kind(_pair.host)
	_register_entity_kind(_pair.guest)
	_pair.host.entities.spawn(&"thing", SessionPair.HOST_ID)
	assert_eq(_pair.guest.entities.get_entity_ids().size(), 1)

	_pair.guest_network.simulate_ended(NetworkService.DisconnectReason.REMOTE_CLOSE, "Gone.")

	assert_eq(_pair.guest.entities.get_entity_ids(), [])


func test_a_new_session_starts_clean() -> void:
	_pair.connect_both()
	_pair.host.state.set_value(&"leftover", 1)
	_pair.host_network.simulate_ended(NetworkService.DisconnectReason.REMOTE_CLOSE, "Gone.")
	_pair.guest_network.simulate_ended(NetworkService.DisconnectReason.REMOTE_CLOSE, "Gone.")

	_pair.connect_both()

	assert_false(_pair.host.state.has_value(&"leftover"))
	assert_false(_pair.guest.state.has_value(&"leftover"))
	assert_eq(_pair.host.last_end_message, "")


func test_replacing_the_transport_ends_the_running_session() -> void:
	_pair.connect_both()
	watch_signals(_pair.host)
	var other_network: FakeNetworkService = add_child_autofree(FakeNetworkService.new())

	_pair.host.bind_network(other_network)

	assert_false(_pair.host.is_active())
	assert_signal_emit_count(_pair.host, &"session_ended", 1)


func test_offline_session_is_a_session_of_one() -> void:
	var session: GameSession = add_child_autofree(GameSession.new())
	var network: StubNetworkService = add_child_autofree(StubNetworkService.new())
	session.scene_flow = _pair.host_flow
	session.bind_network(network)

	assert_eq(session.host(), OK)

	assert_true(session.is_active())
	assert_true(session.is_host())
	assert_false(session.has_remote_player())
	assert_ne(session.get_local_role(), Role.NONE, "the lone player still has a role")
	session.leave()


# --- Roles -----------------------------------------------------------------------


func test_roles_are_assigned_when_the_session_starts() -> void:
	watch_signals(_pair.guest)

	_pair.connect_both()

	var host_role: GameEnums.Role = _pair.host.get_local_role()
	assert_ne(host_role, Role.NONE)
	assert_eq(_pair.guest.get_local_role(), GameEnums.opposite_role(host_role))
	assert_eq(_pair.guest.get_remote_role(), host_role, "the guest knows the host's role")
	assert_eq(_pair.host.get_remote_role(), _pair.guest.get_local_role())
	assert_signal_emitted(_pair.guest, &"roles_changed")


func test_first_round_roles_are_random() -> void:
	# GDD §2.3: roles are assigned at random for round 1.
	_pair.connect_both()
	var seen: Dictionary[GameEnums.Role, bool] = {}

	for attempt: int in 60:
		_pair.host.assign_random_roles()
		seen[_pair.host.get_local_role()] = true

	assert_true(seen.has(Role.SHEEPHERDER), "the host is sometimes the Sheepherder")
	assert_true(seen.has(Role.MONSTER), "and sometimes the Monster")


func test_host_assigns_roles_for_both_devices() -> void:
	_pair.connect_both()

	assert_true(_pair.host.assign_roles(Role.MONSTER))

	assert_eq(_pair.host.get_local_role(), Role.MONSTER)
	assert_eq(_pair.guest.get_local_role(), Role.SHEEPHERDER)


func test_roles_swap_on_request() -> void:
	_pair.connect_both()
	_pair.host.assign_roles(Role.SHEEPHERDER)
	watch_signals(_pair.host)
	watch_signals(_pair.guest)

	assert_true(_pair.host.swap_roles())

	assert_eq(_pair.host.get_local_role(), Role.MONSTER)
	assert_eq(_pair.guest.get_local_role(), Role.SHEEPHERDER)
	assert_signal_emit_count(_pair.host, &"roles_changed", 1)
	assert_signal_emit_count(_pair.guest, &"roles_changed", 1)


func test_roles_alternate_over_a_match() -> void:
	_pair.connect_both()
	_pair.host.assign_roles(Role.SHEEPHERDER)
	var host_roles: Array[GameEnums.Role] = [_pair.host.get_local_role()]

	for round_number: int in 4:
		_pair.host.swap_roles()
		host_roles.append(_pair.host.get_local_role())

	assert_eq(
		host_roles,
		[Role.SHEEPHERDER, Role.MONSTER, Role.SHEEPHERDER, Role.MONSTER, Role.SHEEPHERDER]
	)


func test_guest_cannot_change_the_roles() -> void:
	_pair.connect_both()
	var host_role: GameEnums.Role = _pair.host.get_local_role()
	expect_error("only the host may send")

	assert_false(_pair.guest.swap_roles())

	assert_eq(_pair.host.get_local_role(), host_role)


func test_no_role_cannot_be_assigned() -> void:
	_pair.connect_both()

	assert_false(_pair.host.assign_roles(Role.NONE))


func test_role_of_a_peer() -> void:
	_pair.connect_both()
	_pair.host.assign_roles(Role.MONSTER)

	assert_eq(_pair.host.get_role_of(SessionPair.HOST_ID), Role.MONSTER)
	assert_eq(_pair.host.get_role_of(SessionPair.GUEST_ID), Role.SHEEPHERDER)
	assert_eq(_pair.guest.get_role_of(SessionPair.HOST_ID), Role.MONSTER)
	assert_eq(_pair.host.get_role_of(0), Role.NONE)


# --- Screens ---------------------------------------------------------------------


func test_host_takes_both_devices_to_a_screen() -> void:
	_pair.connect_both()
	_pair.host_flow.go_to(Screen.LOBBY)
	_pair.guest_flow.go_to(Screen.LOBBY)

	assert_true(_pair.host.request_screen(Screen.ROUND))

	assert_eq(_pair.host_flow.current_screen, Screen.ROUND)
	assert_eq(_pair.guest_flow.current_screen, Screen.ROUND)
	assert_eq(_pair.guest_scenes[-1], "res://ui/screens/round_screen.tscn")
	await wait_frames(3)


func test_screen_is_entered_only_when_both_devices_are_ready() -> void:
	_pair.connect_both()
	watch_signals(_pair.host)
	watch_signals(_pair.guest)

	_pair.host.request_screen(Screen.ROUND)

	assert_true(_pair.host.is_changing_screen())
	assert_signal_not_emitted(_pair.host, &"screen_entered", "nobody has reported ready yet")

	await wait_frames(3)

	assert_false(_pair.host.is_changing_screen())
	assert_false(_pair.guest.is_changing_screen())
	assert_signal_emitted_with(_pair.host, &"screen_entered", [Screen.ROUND])
	assert_signal_emitted_with(_pair.guest, &"screen_entered", [Screen.ROUND])
	assert_signal_emit_count(_pair.host, &"screen_entered", 1)
	assert_signal_emit_count(_pair.guest, &"screen_entered", 1)


func test_host_waits_for_a_slow_guest() -> void:
	_pair.connect_both()
	watch_signals(_pair.host)
	# The guest's messages take half a second.
	_pair.host.messenger.sim_latency = 0.5
	_pair.host.messenger.set_process(false)

	_pair.host.request_screen(Screen.ROUND)
	await wait_frames(3)

	assert_signal_not_emitted(_pair.host, &"screen_entered", "the guest's report has not arrived")
	assert_true(_pair.host.is_changing_screen())

	_pair.host.messenger.advance(0.6)

	assert_signal_emitted_with(_pair.host, &"screen_entered", [Screen.ROUND])


func test_guest_cannot_change_the_screen() -> void:
	_pair.connect_both()
	expect_error("only the host of a running session can change the screen")

	assert_false(_pair.guest.request_screen(Screen.ROUND))

	assert_eq(_pair.host_scenes.size(), 0)


func test_screen_cannot_be_changed_without_a_session() -> void:
	expect_error("only the host of a running session can change the screen")

	assert_false(_pair.host.request_screen(Screen.ROUND))


func test_screen_change_respects_the_scene_flow() -> void:
	_pair.connect_both()
	_pair.host_flow.go_to(Screen.BOOT)
	expect_error("the scene flow does not allow Results")

	assert_false(_pair.host.request_screen(Screen.RESULTS))

	assert_eq(_pair.host_flow.current_screen, Screen.BOOT)


func test_offline_screen_change_needs_nobody_else() -> void:
	var session: GameSession = add_child_autofree(GameSession.new())
	var network: StubNetworkService = add_child_autofree(StubNetworkService.new())
	session.scene_flow = _pair.host_flow
	session.bind_network(network)
	session.host()
	watch_signals(session)

	session.request_screen(Screen.ROUND)
	await wait_frames(3)

	assert_signal_emitted_with(session, &"screen_entered", [Screen.ROUND])
	session.leave()


# --- Settings --------------------------------------------------------------------


func test_replication_settings_come_from_the_config() -> void:
	var config: GameConfig = GameConfig.new()
	config.net_tick_rate = 30
	config.net_interpolation_delay = 0.15
	config.net_max_extrapolation = 0.05

	_pair.host.configure(config)

	assert_eq(_pair.host.entities.tick_rate, 30)
	assert_eq(_pair.host.entities.interpolation_delay, 0.15)
	assert_eq(_pair.host.entities.max_extrapolation, 0.05)


func test_application_session_is_registered_and_configured() -> void:
	var session: GameSession = Services.session

	assert_eq(str(session.get_path()), "/root/Services/GameSession")
	assert_eq(str(session.messenger.get_path()), "/root/Services/GameSession/Messenger")
	assert_eq(session.entities.tick_rate, Services.config.net_tick_rate)
	assert_false(session.is_active(), "nothing connects by itself")


static func _register_entity_kind(session: GameSession) -> void:
	session.entities.register_kind(
		&"thing",
		func(_entity_id: int, _owner_id: int, _data: Dictionary) -> Node: return Node2D.new()
	)

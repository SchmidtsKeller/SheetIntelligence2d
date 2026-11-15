extends TestCase
## Every stub satisfies its contract and behaves as the contract describes.

# --- All stubs -----------------------------------------------------------------


func test_bootstrap_registers_an_implementation_for_every_contract() -> void:
	var registry: ServiceRegistry = add_child_autofree(ServiceRegistry.new())

	ServiceBootstrap.register_defaults(registry, GameConfig.new())

	assert_is(registry.resolve(InputService), DeviceInputService, "input is real by now")
	assert_is(registry.resolve(NetworkService), StubNetworkService)
	assert_is(registry.resolve(SwarmService), FlockSwarmService, "and so is the flock")
	assert_is(registry.resolve(CombatService), SessionCombatService, "combat is real by now")
	assert_is(registry.resolve(PerkService), SessionPerkService, "perks are real by now")
	assert_is(registry.resolve(AudioService), SpatialAudioService, "and so is audio")
	registry.clear()


func test_contracts_are_abstract_and_stubs_are_not() -> void:
	for contract: Script in ServiceBootstrap.core_contracts():
		assert_true(contract.is_abstract(), "%s is abstract" % contract.get_global_name())
	for stub: Script in [
		StubInputService,
		StubNetworkService,
		StubSwarmService,
		StubCombatService,
		StubPerkService,
		StubAudioService,
	]:
		assert_false(stub.is_abstract(), "%s can be instantiated" % stub.get_global_name())


func test_contracts_extend_node() -> void:
	for contract: Script in ServiceBootstrap.core_contracts():
		assert_eq(
			contract.get_instance_base_type(),
			&"Node",
			"%s extends Node" % contract.get_global_name()
		)


# --- Input ---------------------------------------------------------------------


func test_input_stub_reports_the_simulated_vectors() -> void:
	var input: StubInputService = autofree(StubInputService.new())

	input.move_vector = Vector2(3.0, 4.0)
	input.aim_direction = Vector2(0.0, -5.0)

	assert_almost_eq(
		input.get_move_vector().length(), 1.0, 0.0001, "movement is limited to length 1"
	)
	assert_eq(input.get_aim_direction(Vector2.ZERO), Vector2.UP, "aim is a unit vector")


func test_input_stub_never_reports_a_zero_aim() -> void:
	var input: StubInputService = autofree(StubInputService.new())

	input.aim_direction = Vector2.ZERO

	assert_eq(input.get_aim_direction(Vector2.ZERO), Vector2.RIGHT)


func test_input_stub_only_reports_actions_of_the_current_role() -> void:
	var input: StubInputService = autofree(StubInputService.new())
	watch_signals(input)
	input.set_role(GameEnums.Role.SHEEPHERDER)

	assert_true(input.simulate_press(InputActions.SHOOT))
	assert_false(input.simulate_press(InputActions.EAT), "eat is a Monster action")

	assert_true(input.is_action_held(InputActions.SHOOT))
	assert_false(input.is_action_held(InputActions.EAT))
	assert_signal_emit_count(input, &"action_pressed", 1)
	assert_signal_emitted_with(input, &"action_pressed", [InputActions.SHOOT])


func test_input_stub_releases_held_actions_when_the_role_changes() -> void:
	var input: StubInputService = autofree(StubInputService.new())
	input.set_role(GameEnums.Role.MONSTER)
	input.simulate_press(InputActions.SPRINT)
	watch_signals(input)

	input.set_role(GameEnums.Role.SHEEPHERDER)

	assert_false(input.is_action_held(InputActions.SPRINT))
	assert_signal_emitted_with(input, &"action_released", [InputActions.SPRINT])
	assert_signal_emitted_with(input, &"role_changed", [GameEnums.Role.SHEEPHERDER])
	assert_eq(input.get_role(), GameEnums.Role.SHEEPHERDER)


func test_input_stub_goes_quiet_while_gameplay_is_disabled() -> void:
	var input: StubInputService = autofree(StubInputService.new())
	input.set_role(GameEnums.Role.MONSTER)
	input.move_vector = Vector2.RIGHT
	input.simulate_press(InputActions.GRAZE)
	watch_signals(input)

	input.set_gameplay_enabled(false)

	assert_false(input.is_gameplay_enabled())
	assert_eq(input.get_move_vector(), Vector2.ZERO)
	assert_false(input.is_action_held(InputActions.GRAZE))
	assert_signal_emitted_with(input, &"action_released", [InputActions.GRAZE])
	assert_false(input.simulate_press(InputActions.BLEAT))

	input.set_gameplay_enabled(true)
	assert_eq(input.get_move_vector(), Vector2.RIGHT)


func test_input_stub_locks_stay_until_the_last_source_lets_go() -> void:
	var input: StubInputService = autofree(StubInputService.new())
	input.move_vector = Vector2.LEFT

	input.add_lock(InputActions.MOVE, &"eating")
	input.add_lock(InputActions.MOVE, &"grazing")
	assert_true(input.is_locked(InputActions.MOVE))
	assert_eq(input.get_move_vector(), Vector2.ZERO)

	input.remove_lock(InputActions.MOVE, &"eating")
	assert_true(input.is_locked(InputActions.MOVE), "grazing still locks movement")

	input.remove_lock(InputActions.MOVE, &"grazing")
	assert_false(input.is_locked(InputActions.MOVE))
	assert_eq(input.get_move_vector(), Vector2.LEFT)


func test_input_stub_lock_releases_and_blocks_an_action() -> void:
	var input: StubInputService = autofree(StubInputService.new())
	input.set_role(GameEnums.Role.MONSTER)
	input.simulate_press(InputActions.SPRINT)

	input.add_lock(InputActions.SPRINT, &"eating")

	assert_false(input.is_action_held(InputActions.SPRINT))
	assert_false(input.simulate_press(InputActions.SPRINT))


func test_input_stub_clear_locks_removes_everything_of_one_source() -> void:
	var input: StubInputService = autofree(StubInputService.new())
	input.add_lock(InputActions.MOVE, &"eating")
	input.add_lock(InputActions.SPRINT, &"eating")
	input.add_lock(InputActions.MOVE, &"menu")

	input.clear_locks(&"eating")

	assert_false(input.is_locked(InputActions.SPRINT))
	assert_true(input.is_locked(InputActions.MOVE), "the menu lock is still there")


func test_input_stub_scheme_override() -> void:
	var input: StubInputService = autofree(StubInputService.new())
	watch_signals(input)

	input.set_scheme_override(InputService.Scheme.TOUCH)
	assert_eq(input.get_scheme(), InputService.Scheme.TOUCH)
	assert_signal_emitted_with(input, &"scheme_changed", [InputService.Scheme.TOUCH])

	input.clear_scheme_override()
	assert_eq(input.get_scheme(), InputService.Scheme.KEYBOARD_MOUSE)


# --- Network -------------------------------------------------------------------


func test_network_stub_starts_disconnected() -> void:
	var network: StubNetworkService = autofree(StubNetworkService.new())

	assert_eq(network.get_connection_state(), NetworkService.ConnectionState.DISCONNECTED)
	assert_eq(network.get_local_peer_id(), 0)
	assert_null(network.get_multiplayer_peer())
	assert_true(network.is_offline())
	assert_false(network.requires_pairing_codes())


func test_network_stub_hosts_an_offline_session() -> void:
	var network: StubNetworkService = autofree(StubNetworkService.new())
	watch_signals(network)

	assert_eq(network.host_session(), OK)

	assert_eq(network.get_connection_state(), NetworkService.ConnectionState.CONNECTED)
	assert_true(network.is_host())
	assert_eq(network.get_local_peer_id(), 1)
	assert_eq(network.get_remote_peer_id(), 0, "nobody else is in an offline session")
	assert_is(network.get_multiplayer_peer(), OfflineMultiplayerPeer)
	assert_signal_emitted_with(
		network, &"connection_state_changed", [NetworkService.ConnectionState.CONNECTED]
	)
	assert_signal_emit_count(network, &"session_started", 1)
	assert_eq(network.host_session(), ERR_ALREADY_IN_USE, "a second session cannot be started")


func test_network_stub_cannot_join_anyone() -> void:
	var network: StubNetworkService = autofree(StubNetworkService.new())

	assert_eq(network.join_session(), ERR_UNAVAILABLE)
	assert_eq(network.submit_pairing_code("anything"), ERR_UNAVAILABLE)
	assert_eq(network.get_connection_state(), NetworkService.ConnectionState.DISCONNECTED)


func test_network_stub_closes_its_session() -> void:
	var network: StubNetworkService = autofree(StubNetworkService.new())
	network.host_session()
	watch_signals(network)

	network.close_session()

	assert_eq(network.get_connection_state(), NetworkService.ConnectionState.DISCONNECTED)
	assert_null(network.get_multiplayer_peer())
	assert_eq(
		get_signal_arguments(network, &"session_ended")[0],
		NetworkService.DisconnectReason.LOCAL_CLOSE
	)

	network.close_session()
	assert_signal_emit_count(network, &"session_ended", 1, "closing twice ends the session once")


# --- Swarm ---------------------------------------------------------------------


func test_swarm_stub_is_an_empty_flock() -> void:
	var swarm: StubSwarmService = autofree(StubSwarmService.new())

	swarm.spawn_flock(1234)

	assert_eq(swarm.get_living_count(), 0)
	assert_eq(swarm.get_living_sheep_ids(), [])
	assert_false(swarm.is_sheep_alive(0))
	assert_null(swarm.get_sheep_body(0))
	assert_eq(swarm.find_nearest_living_sheep(Vector2.ZERO, 1000.0), -1)
	assert_false(swarm.kill_sheep(0, GameEnums.DeathCause.EATEN))


func test_swarm_stub_announces_the_bell() -> void:
	var swarm: StubSwarmService = autofree(StubSwarmService.new())
	watch_signals(swarm)

	swarm.ring_bell(Vector2(10.0, 20.0), 400.0)

	assert_signal_emitted_with(swarm, &"bell_rung", [Vector2(10.0, 20.0), 400.0])


func test_swarm_stub_keeps_track_of_neighbours() -> void:
	var swarm: StubSwarmService = autofree(StubSwarmService.new())
	var monster: Node2D = autofree(Node2D.new())

	swarm.register_neighbour(monster)
	swarm.register_neighbour(monster)
	assert_eq(swarm.get_neighbours(), [monster], "a neighbour is registered once")
	assert_eq(swarm.get_sheep_id(monster), -1, "a neighbour is not an NPC sheep")

	swarm.unregister_neighbour(monster)
	assert_eq(swarm.get_neighbours(), [])


# --- Combat --------------------------------------------------------------------


func test_combat_stub_answers_for_a_fresh_round() -> void:
	var combat: StubCombatService = autofree(StubCombatService.new(GameConfig.new()))

	assert_eq(combat.get_ammo(), 3)
	assert_eq(combat.get_ammo_capacity(), 3)
	assert_false(combat.is_reloading())
	assert_eq(combat.get_reload_progress(), 1.0)
	assert_false(combat.is_ammo_depleted())
	assert_eq(combat.get_shot_sheep_count(), 0)
	assert_eq(combat.get_eaten_count(), 0)
	assert_eq(combat.get_monster_form(), GameEnums.MonsterForm.SHEEP)
	assert_false(combat.can_kill_sheepherder())
	assert_true(combat.is_monster_killable())
	assert_false(combat.is_eating())
	assert_eq(combat.get_eat_cooldown_remaining(), 0.0)


func test_combat_stub_refuses_every_request() -> void:
	var combat: StubCombatService = autofree(StubCombatService.new(GameConfig.new()))
	watch_signals(combat)
	combat.begin_round(null, null)

	assert_false(combat.can_shoot())
	assert_false(combat.request_shot(Vector2.ZERO, Vector2.RIGHT))
	assert_false(combat.can_eat())
	assert_false(combat.request_eat())

	assert_signal_not_emitted(combat, &"shot_fired")
	assert_signal_not_emitted(combat, &"eat_started")
	assert_eq(combat.get_ammo(), 3, "a refused shot costs no bullet")


func test_combat_stub_follows_the_round_lifecycle() -> void:
	var combat: StubCombatService = autofree(StubCombatService.new(GameConfig.new()))
	watch_signals(combat)

	combat.begin_round(null, null)
	assert_true(combat.is_round_active())
	assert_signal_emitted_with(combat, &"ammo_changed", [3, 3])

	combat.end_round()
	assert_false(combat.is_round_active())


func test_combat_stub_reads_ammo_from_the_config() -> void:
	var config: GameConfig = GameConfig.new()
	config.firearm_ammo = 7

	var combat: StubCombatService = autofree(StubCombatService.new(config))

	assert_eq(combat.get_ammo_capacity(), 7)


# --- Perks ---------------------------------------------------------------------


func test_perk_stub_returns_the_plain_config_value_of_every_stat() -> void:
	var config: GameConfig = GameConfig.new()
	var perks: StubPerkService = autofree(StubPerkService.new(config))

	for stat: StringName in StatIds.all():
		assert_eq(perks.get_stat(stat), config.get_number(stat), "effective value of '%s'" % stat)
		assert_eq(perks.get_base_stat(stat), config.get_number(stat), "base value of '%s'" % stat)


func test_perk_stub_follows_changes_to_the_config() -> void:
	var config: GameConfig = GameConfig.new()
	var perks: StubPerkService = autofree(StubPerkService.new(config))

	config.bell_radius = 123.0

	assert_eq(perks.get_stat(StatIds.BELL_RADIUS), 123.0)


func test_perk_stub_rounds_integer_stats() -> void:
	var perks: StubPerkService = autofree(StubPerkService.new(GameConfig.new()))

	assert_eq(perks.get_stat_int(StatIds.FIREARM_AMMO), 3)
	assert_eq(typeof(perks.get_stat_int(StatIds.FIREARM_AMMO)), TYPE_INT)


func test_perk_stub_fails_loudly_for_an_unknown_stat() -> void:
	var perks: StubPerkService = autofree(StubPerkService.new(GameConfig.new()))
	expect_error("no numeric value named 'no_such_stat'")

	assert_eq(perks.get_stat(&"no_such_stat"), 0.0)


func test_perk_stub_ignores_modifiers() -> void:
	var perks: StubPerkService = autofree(StubPerkService.new(GameConfig.new()))

	var first: int = perks.add_modifier(
		StatIds.FIREARM_AMMO, PerkService.ModifierOp.ADD, 1.0, PerkIds.SPARE_BULLET
	)
	var second: int = perks.add_modifier(
		StatIds.EAT_DURATION, PerkService.ModifierOp.MULTIPLY, 0.5, PerkIds.FASTER_CONSUMPTION, 3.0
	)

	assert_ne(first, second, "every modifier gets its own handle")
	assert_eq(perks.get_stat(StatIds.FIREARM_AMMO), 3.0)
	assert_eq(perks.get_stat(StatIds.EAT_DURATION), 1.0)
	perks.remove_modifier(first)
	perks.remove_modifiers_from(PerkIds.FASTER_CONSUMPTION)


func test_perk_stub_accepts_only_perks_from_the_role_pool() -> void:
	var perks: StubPerkService = autofree(StubPerkService.new(GameConfig.new()))
	watch_signals(perks)

	assert_true(perks.select_perk(GameEnums.Role.SHEEPHERDER, PerkIds.SPARE_BULLET))
	assert_false(
		perks.select_perk(GameEnums.Role.SHEEPHERDER, PerkIds.INVISIBILITY), "a Monster perk"
	)
	assert_false(perks.select_perk(GameEnums.Role.MONSTER, &"no_such_perk"))

	assert_eq(perks.get_selected_perk(GameEnums.Role.SHEEPHERDER), PerkIds.SPARE_BULLET)
	assert_eq(perks.get_selected_perk(GameEnums.Role.MONSTER), PerkIds.NONE)
	assert_signal_emit_count(perks, &"perk_selected", 1)
	assert_eq(
		perks.get_available_perks(GameEnums.Role.MONSTER),
		[PerkIds.FASTER_CONSUMPTION, PerkIds.INVISIBILITY, PerkIds.ALLIED_BAT]
	)


func test_perk_stub_locks_and_clears_the_selection() -> void:
	var perks: StubPerkService = autofree(StubPerkService.new(GameConfig.new()))
	perks.select_perk(GameEnums.Role.MONSTER, PerkIds.ALLIED_BAT)

	perks.lock_selection()
	assert_true(perks.is_selection_locked())
	assert_false(
		perks.select_perk(GameEnums.Role.MONSTER, PerkIds.INVISIBILITY), "locked at round start"
	)
	assert_eq(perks.get_selected_perk(GameEnums.Role.MONSTER), PerkIds.ALLIED_BAT)

	perks.clear_selection()
	assert_false(perks.is_selection_locked())
	assert_eq(perks.get_selected_perk(GameEnums.Role.MONSTER), PerkIds.NONE)


func test_perk_stub_has_no_active_perks() -> void:
	var perks: StubPerkService = autofree(StubPerkService.new(GameConfig.new()))
	perks.select_perk(GameEnums.Role.MONSTER, PerkIds.INVISIBILITY)

	assert_false(perks.activate_perk(GameEnums.Role.MONSTER))
	assert_false(perks.is_perk_active(GameEnums.Role.MONSTER))
	assert_eq(perks.get_perk_cooldown_remaining(GameEnums.Role.MONSTER), 0.0)
	assert_eq(perks.get_perk_charge(GameEnums.Role.MONSTER), 0.0)


# --- Audio ---------------------------------------------------------------------


func test_audio_stub_records_what_was_played() -> void:
	var audio: StubAudioService = autofree(StubAudioService.new(GameConfig.new()))
	watch_signals(audio)

	audio.play_event(AudioEvents.BELL, Vector2(5.0, 6.0))
	audio.play_ui(&"click")

	assert_eq(audio.played.size(), 2)
	assert_eq(
		audio.played[0],
		{"event": AudioEvents.BELL, "position": Vector2(5.0, 6.0), "positional": true}
	)
	assert_eq(audio.played[1]["positional"], false)
	assert_signal_emitted_with(audio, &"event_played", [AudioEvents.BELL, Vector2(5.0, 6.0)])


func test_audio_stub_hearing_ranges_follow_the_design_document() -> void:
	var audio: StubAudioService = autofree(StubAudioService.new(GameConfig.new()))

	assert_eq(audio.get_hearing_range(AudioEvents.GRASS_MOVE), 400.0, "quiet")
	assert_eq(audio.get_hearing_range(AudioEvents.BLEAT), 800.0, "loud")
	assert_eq(audio.get_hearing_range(AudioEvents.EAT), 800.0, "loud")
	assert_eq(audio.get_hearing_range(AudioEvents.DOG_BARK), 800.0, "loud")
	assert_eq(audio.get_hearing_range(AudioEvents.BELL), INF, "whole map")
	assert_eq(audio.get_hearing_range(AudioEvents.GUNSHOT), INF, "whole map")


func test_audio_stub_manages_emitters() -> void:
	var audio: StubAudioService = autofree(StubAudioService.new(GameConfig.new()))
	var sheep: Node2D = autofree(Node2D.new())

	var first: int = audio.start_emitter(AudioEvents.GRASS_MOVE, sheep)
	var second: int = audio.start_emitter(AudioEvents.GRASS_MOVE, sheep)
	assert_ne(first, second)
	assert_eq(audio.get_emitter_count(), 2)

	audio.set_emitter_playing(first, false)
	audio.stop_emitter(first)
	assert_eq(audio.get_emitter_count(), 1)

	audio.stop_all()
	assert_eq(audio.get_emitter_count(), 0)


func test_audio_stub_listener_and_volume() -> void:
	var audio: StubAudioService = autofree(StubAudioService.new(GameConfig.new()))
	var player: Node2D = autofree(Node2D.new())

	assert_null(audio.get_listener())
	audio.set_listener(player)
	assert_eq(audio.get_listener(), player)

	assert_eq(audio.get_bus_volume(AudioService.BUS_EFFECTS), 1.0)
	audio.set_bus_volume(AudioService.BUS_EFFECTS, 0.25)
	assert_eq(audio.get_bus_volume(AudioService.BUS_EFFECTS), 0.25)
	audio.set_bus_volume(AudioService.BUS_UI, 7.0)
	assert_eq(audio.get_bus_volume(AudioService.BUS_UI), 1.0, "volume is clamped to 0..1")

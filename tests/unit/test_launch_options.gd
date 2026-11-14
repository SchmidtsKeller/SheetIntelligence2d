extends TestCase
## Development options from the command line.


func test_no_arguments_start_nothing() -> void:
	var options: LaunchOptions = LaunchOptions.parse([])

	assert_eq(options.mode, LaunchOptions.Mode.NONE)
	assert_false(options.wants_session())
	assert_eq(options.port, LaunchOptions.DEFAULT_PORT)
	assert_eq(options.address, "127.0.0.1")
	assert_false(options.lan)
	assert_eq(options.sim_latency, 0.0)


func test_host() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--host"])

	assert_eq(options.mode, LaunchOptions.Mode.HOST)
	assert_true(options.wants_session())


func test_join_defaults_to_this_computer() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--join"])

	assert_eq(options.mode, LaunchOptions.Mode.JOIN)
	assert_eq(options.address, "127.0.0.1")


func test_join_another_computer_on_another_port() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--join=192.168.0.20", "--port=4000"])

	assert_eq(options.address, "192.168.0.20")
	assert_eq(options.port, 4000)
	assert_eq(
		options.get_session_options(), {"address": "192.168.0.20", "port": 4000, "lan": false}
	)


func test_host_for_the_local_network() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--host", "--lan"])

	assert_true(options.lan)
	assert_eq(options.get_session_options()["lan"], true)


func test_simulated_conditions_are_given_in_milliseconds_and_percent() -> void:
	var options: LaunchOptions = LaunchOptions.parse(
		["--net-latency=80", "--net-jitter=30", "--net-loss=5"]
	)

	assert_almost_eq(options.sim_latency, 0.08)
	assert_almost_eq(options.sim_jitter, 0.03)
	assert_almost_eq(options.sim_loss, 0.05)


func test_nonsense_values_are_kept_in_range() -> void:
	var options: LaunchOptions = LaunchOptions.parse(
		["--net-latency=-5", "--net-loss=250", "--port=abc"]
	)

	assert_eq(options.sim_latency, 0.0)
	assert_eq(options.sim_loss, 1.0)
	assert_eq(options.port, LaunchOptions.DEFAULT_PORT)


func test_perks_are_given_by_id() -> void:
	assert_eq(LaunchOptions.parse([]).perks, [])
	var options: LaunchOptions = LaunchOptions.parse(
		["--perk=wide_flashlight, invisibility", "--perk=spare_bullet", "--perk="]
	)

	assert_eq(options.perks, [PerkIds.WIDE_FLASHLIGHT, PerkIds.INVISIBILITY, PerkIds.SPARE_BULLET])
	assert_false(options.wants_session(), "a perk alone connects nothing")


func test_arguments_of_other_tools_are_ignored() -> void:
	var options: LaunchOptions = LaunchOptions.parse(["--filter=session", "--quiet"])

	assert_false(options.wants_session())


func test_start_session_hosts_and_applies_the_simulation() -> void:
	var pair: SessionPair = SessionPair.create(self)
	var options: LaunchOptions = LaunchOptions.parse(["--host", "--net-latency=40"])

	assert_eq(options.start_session(pair.host), OK)

	assert_eq(pair.host.get_connection_state(), NetworkService.ConnectionState.CONNECTING)
	assert_almost_eq(pair.host.messenger.sim_latency, 0.04)


func test_start_session_joins() -> void:
	var pair: SessionPair = SessionPair.create(self)

	assert_eq(LaunchOptions.parse(["--join"]).start_session(pair.guest), OK)

	assert_eq(pair.guest.get_connection_state(), NetworkService.ConnectionState.CONNECTING)
	assert_false(pair.guest_network.host)


func test_start_session_does_nothing_without_a_flag() -> void:
	var pair: SessionPair = SessionPair.create(self)

	assert_eq(LaunchOptions.parse([]).start_session(pair.host), OK)

	assert_eq(pair.host.get_connection_state(), NetworkService.ConnectionState.DISCONNECTED)

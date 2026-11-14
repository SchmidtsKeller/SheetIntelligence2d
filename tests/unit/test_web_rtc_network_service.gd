extends TestCase
## The WebRTC transport outside a browser. WebRTC itself only exists in Web
## exports, so connecting is checked in the browser (docs/pairing.md); here
## only what holds everywhere.


func test_it_is_the_web_builds_transport_only() -> void:
	assert_false(WebRtcNetworkService.is_available(), "desktop builds use ENet")
	var network: NetworkService = autofree(
		ServiceBootstrap.create_network_service(GameConfig.new())
	)
	assert_is(network, StubNetworkService)


func test_it_pairs_with_codes_and_takes_none_without_a_session() -> void:
	var network: WebRtcNetworkService = autofree(WebRtcNetworkService.new())

	assert_true(network.requires_pairing_codes())
	assert_false(network.is_offline())
	assert_eq(network.get_connection_state(), NetworkService.ConnectionState.DISCONNECTED)
	assert_true(network.is_host(), "without a session this device is the authority")
	assert_eq(network.submit_pairing_code("ANYTHING"), ERR_UNAVAILABLE)
	assert_eq(network.get_pairing_problem(), "")
	assert_eq(network.get_local_peer_id(), 0)
	assert_null(network.get_multiplayer_peer())
	network.close_session()


func test_its_channels_are_the_ones_the_messenger_uses() -> void:
	# NetMessenger: channel 1 reliable events, channel 2 unreliable ordered snapshots.
	assert_eq(
		WebRtcNetworkService.CHANNELS,
		[MultiplayerPeer.TRANSFER_MODE_RELIABLE, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED]
	)


func test_the_guest_answers_as_the_side_that_waits_for_the_encryption() -> void:
	var answer: String = "v=0\r\nm=application 9 UDP/DTLS/SCTP\r\na=setup:active\r\n"

	var passive: String = WebRtcNetworkService.as_passive_answer(answer)

	assert_eq(passive, answer.replace("active", "passive"))
	assert_eq(WebRtcNetworkService.as_passive_answer(passive), passive)

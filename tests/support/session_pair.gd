class_name SessionPair
extends RefCounted
## Two sessions, a host and a guest, wired to each other inside one process.
##
## Messages go straight from one messenger to the other, so a test sees both
## sides of a connection without sockets. Each session gets its own scene flow
## that records scene changes instead of performing them.

const HOST_ID: int = 1
const GUEST_ID: int = 2

var host: GameSession
var guest: GameSession
var host_network: FakeNetworkService
var guest_network: FakeNetworkService
var host_flow: SceneFlowController
var guest_flow: SceneFlowController

## The scenes each side was asked to load, in order.
var host_scenes: PackedStringArray = []
var guest_scenes: PackedStringArray = []


## Builds both sides below [param test], which frees them when the test ends.
static func create(test: TestCase) -> SessionPair:
	var pair: SessionPair = SessionPair.new()
	pair.host_network = test.add_child_autofree(FakeNetworkService.new())
	pair.guest_network = test.add_child_autofree(FakeNetworkService.new())
	pair.host_network.local_id = HOST_ID
	pair.host_network.remote_id = GUEST_ID
	pair.guest_network.local_id = GUEST_ID
	pair.guest_network.remote_id = HOST_ID
	pair.guest_network.host = false

	pair.host_flow = test.add_child_autofree(SceneFlowController.new())
	pair.guest_flow = test.add_child_autofree(SceneFlowController.new())
	pair.host_flow.scene_changer = func(path: String) -> Error:
		pair.host_scenes.append(path)
		return OK
	pair.guest_flow.scene_changer = func(path: String) -> Error:
		pair.guest_scenes.append(path)
		return OK

	pair.host = test.add_child_autofree(GameSession.new())
	pair.guest = test.add_child_autofree(GameSession.new())
	pair.host.scene_flow = pair.host_flow
	pair.guest.scene_flow = pair.guest_flow
	pair.host.bind_network(pair.host_network)
	pair.guest.bind_network(pair.guest_network)
	link(pair.host.messenger, pair.guest.messenger)
	return pair


## Sends what [param host_messenger] transmits to [param guest_messenger] and
## the other way round.
static func link(host_messenger: NetMessenger, guest_messenger: NetMessenger) -> void:
	host_messenger.transmitter = func(reliable: bool, message: Array) -> void:
		guest_messenger.receive(reliable, message.duplicate(true), HOST_ID)
	guest_messenger.transmitter = func(reliable: bool, message: Array) -> void:
		host_messenger.receive(reliable, message.duplicate(true), GUEST_ID)


## Brings the session up on both sides, guest first. Over WebRTC the host can
## also start first (docs/networking.md, rules for transports).
func connect_both() -> void:
	guest_network.simulate_started()
	host_network.simulate_started()

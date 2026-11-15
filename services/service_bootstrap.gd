@abstract class_name ServiceBootstrap
extends RefCounted
## The composition root: the one place that decides which implementation
## fulfils which contract.
##
## Until a real implementation is merged, its contract is served by a stub
## from `services/stubs/`. A task that delivers a real implementation changes
## exactly one line here.


## The six core contracts every build must provide (GDD §9.2).
static func core_contracts() -> Array[Script]:
	return [
		InputService,
		NetworkService,
		SwarmService,
		CombatService,
		PerkService,
		AudioService,
	]


## Registers the default implementation of every core contract in
## [param registry]. [param config] is the game configuration the services
## read their numbers from.
static func register_defaults(registry: ServiceRegistry, config: GameConfig) -> void:
	registry.register(InputService, DeviceInputService.new())
	registry.register(NetworkService, create_network_service(config))
	registry.register(CombatService, SessionCombatService.new())
	var perks: SessionPerkService = SessionPerkService.new(config, PerkCatalog.load_default())
	perks.launch_perks = LaunchOptions.from_command_line().perks
	registry.register(PerkService, perks)
	registry.register(AudioService, SpatialAudioService.new(config))

	var session: GameSession = GameSession.new()
	session.configure(config)
	registry.register(GameSession, session)
	session.bind_network(registry.resolve(NetworkService) as NetworkService)
	perks.setup(session)

	# The flock replicates through the session, so it comes after it.
	var swarm: FlockSwarmService = FlockSwarmService.new()
	registry.register(SwarmService, swarm)
	swarm.setup(session, registry.resolve(PerkService) as PerkService)

	# The match runs on the session and on the services above.
	var match_flow: MatchFlow = MatchFlow.new()
	registry.register(MatchFlow, match_flow)
	match_flow.setup(session)

	# The sounds of the game's flow follow the session and the match.
	var cues: GameSoundCues = GameSoundCues.new()
	registry.register(GameSoundCues, cues)
	cues.setup(session, match_flow)


## The transport for this run: WebRTC with pairing codes in the Web build; on
## desktop the dev transport when the command line asks to host or join a
## session, otherwise the offline loopback.
static func create_network_service(config: GameConfig) -> NetworkService:
	if WebRtcNetworkService.is_available():
		return WebRtcNetworkService.new()
	var options: LaunchOptions = LaunchOptions.from_command_line()
	if options.wants_session() and can_connect_by_address():
		return _create_enet(config)
	return StubNetworkService.new()


## Whether this build connects two instances by address (the desktop's ENet),
## as the desktop lobby's Host and Join do.
static func can_connect_by_address() -> bool:
	return not OS.has_feature("web") and EnetNetworkService.is_available()


## Registers the desktop transport in [param registry] in place of the offline
## one, so that the lobby can host or join (#99), and returns it. Until then,
## the offline transport stays: a sandbox scene or a test that starts a session
## of its own does not open a port. Returns the registered transport if it
## already connects by address, and [code]null[/code] where none can.
static func use_address_transport(registry: ServiceRegistry, config: GameConfig) -> NetworkService:
	var current: NetworkService = registry.try_resolve(NetworkService) as NetworkService
	if current is EnetNetworkService:
		return current
	if not can_connect_by_address():
		return null
	var enet: EnetNetworkService = _create_enet(config)
	var previous: Node = registry.replace(NetworkService, enet)
	if previous != null:
		previous.queue_free()
	return enet


static func _create_enet(config: GameConfig) -> EnetNetworkService:
	var enet: EnetNetworkService = EnetNetworkService.new()
	enet.connect_timeout = config.net_connect_timeout
	return enet


## The core contracts that have no implementation in [param registry].
static func find_missing(registry: ServiceRegistry) -> Array[Script]:
	var missing: Array[Script] = []
	for contract: Script in core_contracts():
		if not registry.has_service(contract):
			missing.append(contract)
	return missing

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
	registry.register(AudioService, StubAudioService.new(config))

	var session: GameSession = GameSession.new()
	session.configure(config)
	registry.register(GameSession, session)
	session.bind_network(registry.resolve(NetworkService) as NetworkService)
	perks.setup(session)

	# The flock replicates through the session, so it comes after it.
	var swarm: FlockSwarmService = FlockSwarmService.new()
	registry.register(SwarmService, swarm)
	swarm.setup(session, registry.resolve(PerkService) as PerkService)


## The transport for this run: the desktop dev transport when the command
## line asks to host or join a session, otherwise the offline loopback.
static func create_network_service(config: GameConfig) -> NetworkService:
	var options: LaunchOptions = LaunchOptions.from_command_line()
	if options.wants_session() and not OS.has_feature("web") and EnetNetworkService.is_available():
		var enet: EnetNetworkService = EnetNetworkService.new()
		enet.connect_timeout = config.net_connect_timeout
		return enet
	return StubNetworkService.new()


## The core contracts that have no implementation in [param registry].
static func find_missing(registry: ServiceRegistry) -> Array[Script]:
	var missing: Array[Script] = []
	for contract: Script in core_contracts():
		if not registry.has_service(contract):
			missing.append(contract)
	return missing

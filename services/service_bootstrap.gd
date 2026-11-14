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
	registry.register(NetworkService, StubNetworkService.new())
	registry.register(SwarmService, StubSwarmService.new())
	registry.register(CombatService, StubCombatService.new(config))
	registry.register(PerkService, StubPerkService.new(config))
	registry.register(AudioService, StubAudioService.new(config))


## The core contracts that have no implementation in [param registry].
static func find_missing(registry: ServiceRegistry) -> Array[Script]:
	var missing: Array[Script] = []
	for contract: Script in core_contracts():
		if not registry.has_service(contract):
			missing.append(contract)
	return missing

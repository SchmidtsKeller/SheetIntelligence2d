extends TestCase
## The service registry registers, resolves, replaces and fails loudly.


## A second implementation of the input contract, to swap against the stub.
class OtherInputService:
	extends StubInputService


var _registry: ServiceRegistry


func before_each() -> void:
	_registry = add_child_autofree(ServiceRegistry.new())
	_registry.fail_hard = false


func after_each() -> void:
	_registry.clear()


func test_register_then_resolve_returns_the_implementation() -> void:
	var input: StubInputService = StubInputService.new()

	assert_true(_registry.register(InputService, input))

	assert_eq(_registry.resolve(InputService), input)
	assert_true(_registry.has_service(InputService))
	assert_eq(_registry.last_error, "")


func test_registered_implementation_becomes_a_child_named_after_its_contract() -> void:
	var input: StubInputService = StubInputService.new()

	_registry.register(InputService, input)

	assert_eq(input.get_parent(), _registry)
	assert_eq(input.name, &"InputService", "the node path must not depend on the implementation")


func test_implementation_that_already_has_a_parent_is_left_where_it_is() -> void:
	var holder: Node = add_child_autofree(Node.new())
	var input: StubInputService = StubInputService.new()
	holder.add_child(input)

	_registry.register(InputService, input)

	assert_eq(input.get_parent(), holder)
	assert_eq(_registry.resolve(InputService), input)
	_registry.unregister(InputService)


func test_missing_service_is_reported() -> void:
	assert_null(_registry.resolve(InputService))

	assert_has(_registry.last_error, "No service registered for InputService")


func test_missing_service_fails_loudly_by_default() -> void:
	_registry.fail_hard = true
	expect_error("No service registered for InputService")

	assert_null(_registry.resolve(InputService))


func test_try_resolve_and_has_service_are_quiet_about_a_missing_service() -> void:
	assert_null(_registry.try_resolve(InputService))
	assert_false(_registry.has_service(InputService))

	assert_eq(_registry.last_error, "")


func test_registering_a_contract_twice_is_refused() -> void:
	var first: StubInputService = StubInputService.new()
	var second: OtherInputService = autofree(OtherInputService.new())
	_registry.register(InputService, first)

	assert_false(_registry.register(InputService, second))

	assert_eq(_registry.resolve(InputService), first, "the first implementation stays")
	assert_has(_registry.last_error, "already registered")


func test_implementation_must_extend_the_contract() -> void:
	var audio: StubAudioService = autofree(StubAudioService.new())

	assert_false(_registry.register(InputService, audio))

	assert_false(_registry.has_service(InputService))
	assert_has(_registry.last_error, "does not extend the contract InputService")


func test_null_implementation_is_refused() -> void:
	assert_false(_registry.register(InputService, null))

	assert_has(_registry.last_error, "null")


func test_replace_swaps_the_implementation_and_returns_the_previous_one() -> void:
	var first: StubInputService = autofree(StubInputService.new())
	var second: OtherInputService = OtherInputService.new()
	_registry.register(InputService, first)

	var previous: Node = _registry.replace(InputService, second)

	assert_eq(previous, first)
	assert_eq(_registry.resolve(InputService), second)
	assert_null(first.get_parent(), "the previous implementation leaves the registry")
	assert_true(is_instance_valid(first), "the previous implementation is not freed")


func test_replace_can_put_the_previous_implementation_back() -> void:
	var original: StubInputService = StubInputService.new()
	var temporary: OtherInputService = autofree(OtherInputService.new())
	_registry.register(InputService, original)

	var previous: Node = _registry.replace(InputService, temporary)
	_registry.replace(InputService, previous)

	assert_eq(_registry.resolve(InputService), original)
	assert_eq(original.get_parent(), _registry)


func test_replace_registers_when_the_contract_has_no_implementation() -> void:
	var input: StubInputService = StubInputService.new()

	assert_null(_registry.replace(InputService, input))

	assert_eq(_registry.resolve(InputService), input)


func test_replace_refuses_a_wrong_implementation_and_keeps_the_current_one() -> void:
	var input: StubInputService = StubInputService.new()
	var audio: StubAudioService = autofree(StubAudioService.new())
	_registry.register(InputService, input)

	assert_null(_registry.replace(InputService, audio))

	assert_eq(_registry.resolve(InputService), input)


func test_unregister_removes_and_returns_the_implementation() -> void:
	var input: StubInputService = autofree(StubInputService.new())
	_registry.register(InputService, input)

	assert_eq(_registry.unregister(InputService), input)

	assert_false(_registry.has_service(InputService))
	assert_null(input.get_parent())
	assert_null(_registry.unregister(InputService), "nothing left to unregister")


func test_contracts_are_kept_apart() -> void:
	var input: StubInputService = StubInputService.new()
	var audio: StubAudioService = StubAudioService.new()

	_registry.register(InputService, input)
	_registry.register(AudioService, audio)

	assert_eq(_registry.resolve(InputService), input)
	assert_eq(_registry.resolve(AudioService), audio)
	assert_eq(_registry.get_contracts().size(), 2)
	assert_has(_registry.get_contracts(), InputService)
	assert_has(_registry.get_contracts(), AudioService)


func test_clear_frees_all_implementations() -> void:
	var input: StubInputService = StubInputService.new()
	_registry.register(InputService, input)

	_registry.clear()

	assert_false(_registry.has_service(InputService))
	assert_false(is_instance_valid(input))


func test_changes_are_announced() -> void:
	watch_signals(_registry)
	var first: StubInputService = autofree(StubInputService.new())
	var second: OtherInputService = autofree(OtherInputService.new())

	_registry.register(InputService, first)
	assert_signal_emitted_with(_registry, &"service_registered", [InputService, first])

	_registry.replace(InputService, second)
	assert_signal_emitted_with(_registry, &"service_replaced", [InputService, second, first])

	_registry.unregister(InputService)
	assert_signal_emitted_with(_registry, &"service_unregistered", [InputService, second])


# --- The application's registry ------------------------------------------------


func test_application_registry_serves_every_core_contract() -> void:
	for contract: Script in ServiceBootstrap.core_contracts():
		assert_true(Services.has_service(contract), "%s is registered" % contract.get_global_name())
		assert_is(Services.resolve(contract), contract)
	assert_eq(ServiceBootstrap.find_missing(Services), [])


func test_application_registry_has_typed_accessors() -> void:
	assert_eq(Services.input, Services.resolve(InputService))
	assert_eq(Services.network, Services.resolve(NetworkService))
	assert_eq(Services.swarm, Services.resolve(SwarmService))
	assert_eq(Services.combat, Services.resolve(CombatService))
	assert_eq(Services.perks, Services.resolve(PerkService))
	assert_eq(Services.audio, Services.resolve(AudioService))


func test_application_services_have_the_same_node_path_on_every_device() -> void:
	assert_eq(str(Services.network.get_path()), "/root/Services/NetworkService")
	assert_eq(str(Services.swarm.get_path()), "/root/Services/SwarmService")
	assert_eq(str(Services.combat.get_path()), "/root/Services/CombatService")


func test_application_service_can_be_swapped_for_a_test_and_restored() -> void:
	var fake: OtherInputService = OtherInputService.new()

	var original: Node = Services.replace(InputService, fake)
	assert_eq(Services.input, fake)

	Services.replace(InputService, original)
	fake.free()
	assert_eq(Services.input, original)


func test_find_missing_names_the_contracts_without_implementation() -> void:
	_registry.register(InputService, StubInputService.new())

	var missing: Array[Script] = ServiceBootstrap.find_missing(_registry)

	assert_eq(missing.size(), 5)
	assert_does_not_have(missing, InputService)
	assert_has(missing, NetworkService)

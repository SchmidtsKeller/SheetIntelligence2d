class_name ServiceRegistry
extends Node
## A service locator: maps a contract (an abstract class from `abstractions/`)
## to the implementation that currently fulfils it.
##
## Gameplay code asks for a contract and never names a concrete service class,
## so implementations can be swapped per platform and in tests.
##
## Registered implementations become children of the registry, named after
## their contract. Their node path is therefore the same on both devices no
## matter which implementation is in use, which is what RPCs need.
##
## The application's instance is the autoload [code]Services[/code]. Tests
## create their own instances.

## An implementation was registered for a contract that had none.
signal service_registered(contract: Script, implementation: Node)

## The implementation of a contract was swapped.
signal service_replaced(contract: Script, implementation: Node, previous: Node)

## A contract lost its implementation.
signal service_unregistered(contract: Script, previous: Node)

## When [code]true[/code] (the default), misuse is reported with
## [method @GlobalScope.push_error] and stops execution in debug builds. Tests
## that provoke misuse on purpose switch this off and read [member last_error].
var fail_hard: bool = true

## The message of the most recent misuse, or an empty string.
var last_error: String = ""

var _services: Dictionary[Script, Node] = {}


## Registers [param implementation] for [param contract]. Fails if the
## contract already has an implementation (use [method replace]) or if
## [param implementation] does not extend [param contract].
func register(contract: Script, implementation: Node) -> bool:
	if not _is_valid_pair(contract, implementation):
		return false
	if _services.has(contract):
		_fail("%s is already registered. Use replace() to swap the implementation." % _name_of(contract))
		return false
	_adopt(contract, implementation)
	service_registered.emit(contract, implementation)
	return true


## Makes [param implementation] the service for [param contract] and returns
## the previous implementation, or [code]null[/code] if there was none. The
## previous one is removed from the registry but not freed: the caller owns it
## and can put it back later (tests) or free it.
func replace(contract: Script, implementation: Node) -> Node:
	if not _is_valid_pair(contract, implementation):
		return null
	var previous: Node = _release(contract)
	_adopt(contract, implementation)
	if previous == null:
		service_registered.emit(contract, implementation)
	else:
		service_replaced.emit(contract, implementation, previous)
	return previous


## The implementation of [param contract]. A missing service is a programming
## error and fails loudly; use [method try_resolve] or [method has_service]
## where a service is truly optional.
func resolve(contract: Script) -> Node:
	var implementation: Node = _services.get(contract)
	if implementation == null:
		_fail("No service registered for %s." % _name_of(contract))
	return implementation


## The implementation of [param contract], or [code]null[/code] without complaint.
func try_resolve(contract: Script) -> Node:
	return _services.get(contract)


## Whether [param contract] has an implementation.
func has_service(contract: Script) -> bool:
	return _services.has(contract)


## Removes the implementation of [param contract] and returns it without
## freeing it, or [code]null[/code] if there was none.
func unregister(contract: Script) -> Node:
	var previous: Node = _release(contract)
	if previous != null:
		service_unregistered.emit(contract, previous)
	return previous


## All contracts that currently have an implementation.
func get_contracts() -> Array[Script]:
	var contracts: Array[Script] = []
	contracts.assign(_services.keys())
	return contracts


## Removes and frees every registered implementation.
func clear() -> void:
	for contract: Script in get_contracts():
		var previous: Node = unregister(contract)
		if previous != null:
			previous.free()


func _is_valid_pair(contract: Script, implementation: Node) -> bool:
	if contract == null:
		_fail("Cannot register a service without a contract.")
		return false
	if implementation == null:
		_fail("Cannot register null as %s." % _name_of(contract))
		return false
	if not is_instance_of(implementation, contract):
		_fail("%s does not extend the contract %s." % [_describe(implementation), _name_of(contract)])
		return false
	return true


func _adopt(contract: Script, implementation: Node) -> void:
	_services[contract] = implementation
	if implementation.get_parent() == null:
		implementation.name = _name_of(contract)
		add_child(implementation)


func _release(contract: Script) -> Node:
	var previous: Node = _services.get(contract)
	if previous == null:
		return null
	_services.erase(contract)
	if previous.get_parent() == self:
		remove_child(previous)
	return previous


func _fail(message: String) -> void:
	last_error = message
	if fail_hard:
		push_error("ServiceRegistry: " + message)
		assert(false, "ServiceRegistry: " + message)


static func _name_of(contract: Script) -> String:
	var global_name: StringName = contract.get_global_name()
	if not global_name.is_empty():
		return String(global_name)
	var file_name: String = contract.resource_path.get_file().get_basename().to_pascal_case()
	return file_name if not file_name.is_empty() else "UnnamedContract"


static func _describe(implementation: Node) -> String:
	var script: Script = implementation.get_script()
	if script != null:
		return _name_of(script)
	return implementation.get_class()

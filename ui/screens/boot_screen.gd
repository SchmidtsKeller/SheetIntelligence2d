extends Control
## The boot screen: the application's entry point.
##
## Checks that every core service contract has an implementation, then hands
## over to the lobby. A build with a missing service stops here with a
## readable message instead of failing somewhere in the middle of a round.

@onready var _title: Label = %Title
@onready var _status: Label = %Status


func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name", "")
	var missing: Array[Script] = ServiceBootstrap.find_missing(Services)
	if not missing.is_empty():
		_status.text = "Cannot start: no implementation for %s." % _names_of(missing)
		push_error("Boot: " + _status.text)
		return
	_status.text = "Starting …"
	# The scene tree must not be changed while it is still setting up this scene.
	_enter_lobby.call_deferred()


func _enter_lobby() -> void:
	SceneFlow.go_to(SceneFlowController.Screen.LOBBY)


static func _names_of(contracts: Array[Script]) -> String:
	var names: PackedStringArray = []
	for contract: Script in contracts:
		names.append(String(contract.get_global_name()))
	return ", ".join(names)

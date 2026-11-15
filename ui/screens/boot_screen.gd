extends Control
## The boot screen: the application's entry point.
##
## Checks that every core service contract has an implementation, then hands
## over to the lobby. A build with a missing service stops here with a
## readable message instead of failing somewhere in the middle of a round.
##
## In the Web build, [code]?sound-check[/code] in the page's address opens the
## sound check instead of the lobby (docs/audio.md).

const SOUND_CHECK_SCENE: String = "res://systems/audio/sandbox/sound_check.tscn"
const SOUND_CHECK_PARAMETER: String = "sound-check"

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
	if _wants_sound_check():
		get_tree().change_scene_to_file.call_deferred(SOUND_CHECK_SCENE)
		return
	# Development: host or join right away when the command line asks for it.
	var error: Error = LaunchOptions.from_command_line().start_session(Services.session)
	if error != OK:
		push_error("Boot: could not start the session (%s)." % error_string(error))
	# The scene tree must not be changed while it is still setting up this scene.
	_enter_lobby.call_deferred()


func _enter_lobby() -> void:
	SceneFlow.go_to(SceneFlowController.Screen.LOBBY)


static func _wants_sound_check() -> bool:
	if not OS.has_feature("web"):
		return false
	var script: String = "new URLSearchParams(location.search).has('%s')" % SOUND_CHECK_PARAMETER
	# A JavaScript boolean arrives as a number.
	return bool(JavaScriptBridge.eval(script))


static func _names_of(contracts: Array[Script]) -> String:
	var names: PackedStringArray = []
	for contract: Script in contracts:
		names.append(String(contract.get_global_name()))
	return ", ".join(names)

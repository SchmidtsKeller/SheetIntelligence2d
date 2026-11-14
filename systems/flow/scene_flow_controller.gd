class_name SceneFlowController
extends Node
## The scene flow: which screen the application shows and where it may go next.
##
## [codeblock lang=text]
## boot → lobby → round → results ─┬→ round   (next round)
##                  │              └→ lobby   (match over)
##                  └→ lobby                  (disconnect)
## [/codeblock]
##
## The application's instance is the autoload [code]SceneFlow[/code]. Each
## screen is a scene; later tasks replace the placeholder scenes by setting
## [member screen_scenes].

enum Screen {
	## A scene outside the flow, e.g. a sandbox started on its own. Any screen
	## can be entered from here.
	NONE,
	BOOT,
	LOBBY,
	ROUND,
	RESULTS,
}

## The allowed transitions: screen → screens that may follow it.
const TRANSITIONS: Dictionary[Screen, Array] = {
	Screen.BOOT: [Screen.LOBBY],
	Screen.LOBBY: [Screen.ROUND],
	Screen.ROUND: [Screen.RESULTS, Screen.LOBBY],
	Screen.RESULTS: [Screen.ROUND, Screen.LOBBY],
}

## A transition was accepted and the scene change is about to happen.
signal screen_changing(from: Screen, to: Screen)

## The current screen changed.
signal screen_changed(screen: Screen)

## The scene shown for each screen.
var screen_scenes: Dictionary[Screen, String] = {
	Screen.BOOT: "res://ui/screens/boot_screen.tscn",
	Screen.LOBBY: "res://ui/screens/lobby_screen.tscn",
	Screen.ROUND: "res://ui/screens/round_screen.tscn",
	Screen.RESULTS: "res://ui/screens/results_screen.tscn",
}

## The screen the application is on. Before the first transition this is the
## screen of the scene the application was started with.
var current_screen: Screen:
	get:
		_detect_start_screen()
		return _current_screen

## Performs the scene change: takes a scene path, returns an [enum Error].
## Tests replace it to follow the flow without loading scenes.
var scene_changer: Callable = _change_scene

var _current_screen: Screen = Screen.NONE
var _start_screen_detected: bool = false


## Whether the flow allows going from the current screen to [param screen].
func can_go_to(screen: Screen) -> bool:
	return can_transition(current_screen, screen)


## Goes to [param screen]. Returns [code]false[/code] and changes nothing if
## the flow does not allow it or the scene cannot be loaded.
func go_to(screen: Screen) -> bool:
	if not can_go_to(screen):
		push_error(
			(
				"SceneFlow: cannot go from %s to %s."
				% [screen_name(current_screen), screen_name(screen)]
			)
		)
		return false
	var error: Error = scene_changer.call(screen_scenes[screen])
	if error != OK:
		push_error(
			(
				"SceneFlow: could not load the scene of %s (%s)."
				% [screen_name(screen), error_string(error)]
			)
		)
		return false
	var previous: Screen = current_screen
	print_verbose("SceneFlow: %s → %s" % [screen_name(previous), screen_name(screen)])
	screen_changing.emit(previous, screen)
	_start_screen_detected = true
	_current_screen = screen
	screen_changed.emit(screen)
	return true


## The screens that may follow the current one.
func get_next_screens() -> Array[Screen]:
	return next_screens_of(current_screen)


## Whether the flow allows going from [param from] to [param to].
static func can_transition(from: Screen, to: Screen) -> bool:
	if to == Screen.NONE:
		return false
	if from == Screen.NONE:
		return true
	return next_screens_of(from).has(to)


## The screens that may follow [param screen].
static func next_screens_of(screen: Screen) -> Array[Screen]:
	var next: Array[Screen] = []
	if screen == Screen.NONE:
		next.assign([Screen.BOOT, Screen.LOBBY, Screen.ROUND, Screen.RESULTS])
	else:
		next.assign(TRANSITIONS.get(screen, []))
	return next


## Readable name of [param screen] for UI and logs.
static func screen_name(screen: Screen) -> String:
	return (Screen.find_key(screen) as String).capitalize()


func _detect_start_screen() -> void:
	if _start_screen_detected or not is_inside_tree():
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		# Autoloads are ready before the first scene exists; try again later.
		return
	_start_screen_detected = true
	_current_screen = _screen_of_scene_path(scene.scene_file_path)


func _screen_of_scene_path(path: String) -> Screen:
	if path.is_empty():
		return Screen.NONE
	var wanted: String = _resolved(path)
	for screen: Screen in screen_scenes:
		if _resolved(screen_scenes[screen]) == wanted:
			return screen
	return Screen.NONE


func _change_scene(path: String) -> Error:
	return get_tree().change_scene_to_file(path)


static func _resolved(path: String) -> String:
	if path.begins_with("uid://"):
		return ResourceUID.ensure_path(path)
	return path

extends Node
## Automated check of the session framework with two real instances.
##
## Start one instance with [code]--host[/code] and one with [code]--join[/code]
## (see `tools/test_two_instances.sh`). Each runs the same scripted scenario
## against the other, prints what it observed, and exits with code 0 if
## everything held:
## [br]- both connect by themselves and get opposite roles; a swap reaches both
## [br]- each moves its own box; the other sees it move smoothly
## [br]- 30 numbered events arrive exactly once and in order, in both directions
## [br]- the host takes both to the Round screen, with the ready handshake
## [br]- the host leaves; the guest returns to the lobby with a message
##
## The network flags [code]--net-latency[/code], [code]--net-jitter[/code] and
## [code]--net-loss[/code] apply, so the same check runs on a bad connection.

const EVENT_COUNT: StringName = &"selfcheck.count"
const EVENTS_TO_SEND: int = 30
const EVENT_INTERVAL: float = 0.1
const BOX_SPEED: float = 200.0
const CIRCLE_RADIUS: float = 100.0
const SWAP_AT: float = 1.5
const CHANGE_SCREEN_AT: float = 4.0
const LEAVE_AFTER_ENTERING: float = 1.0
const GIVE_UP_AFTER: float = 25.0

var _session: GameSession
var _label: String = "?"
## Which side this instance plays. Asked from the command line, because
## without a session every device counts as the host.
var _hosting: bool = false
var _total_time: float = 0.0
var _session_time: float = -1.0
var _finished: bool = false

var _own_box: Node2D
var _own_box_center: Vector2
var _remote_box: Node2D
var _remote_previous: Vector2
var _remote_travelled: float = 0.0
var _remote_observed_for: float = 0.0
var _remote_jumps: int = 0

var _events_sent: int = 0
var _events_received: Array[int] = []
var _roles_changed_count: int = 0
var _role_before_swap: GameEnums.Role = GameEnums.Role.NONE
var _swapped: bool = false
var _screen_requested: bool = false
var _entered_round_at: float = -1.0
var _left: bool = false
var _end_reason: int = -1
var _end_message: String = ""


func _ready() -> void:
	# Survive the scene changes this check causes.
	reparent.call_deferred(get_tree().root)
	Engine.max_fps = 60
	_session = Services.session
	_session.entities.register_kind(NetDemoBox.KIND, NetDemoBox.build)
	_session.entities.entity_spawned.connect(_on_entity_spawned)
	_session.messenger.register_event(EVENT_COUNT, NetMessenger.SenderRule.ANYONE)
	_session.messenger.subscribe(EVENT_COUNT, _on_count)
	_session.session_started.connect(_on_session_started)
	_session.session_ended.connect(_on_session_ended)
	_session.roles_changed.connect(func() -> void: _roles_changed_count += 1)
	_session.screen_entered.connect(_on_screen_entered)

	var options: LaunchOptions = LaunchOptions.from_command_line()
	_hosting = options.mode == LaunchOptions.Mode.HOST
	_label = "host" if _hosting else "guest"
	if not options.wants_session():
		_finish(["start this scene with -- --host or -- --join"])
		return
	var error: Error = options.start_session(_session)
	if error != OK:
		_finish(["could not start the session: %s" % error_string(error)])


func _process(delta: float) -> void:
	if _finished:
		return
	_total_time += delta
	if _total_time > GIVE_UP_AFTER:
		_finish(_problems() + ["gave up after %s s" % GIVE_UP_AFTER])
		return
	if _session_time < 0.0:
		return
	_session_time += delta
	_move_own_box()
	_watch_remote_box(delta)
	_send_events()
	if _hosting and _session.is_active():
		_direct_the_scenario()


func _on_session_started() -> void:
	_session_time = 0.0
	if not _hosting:
		return
	var host_id: int = _session.get_local_peer_id()
	var guest_id: int = _session.get_remote_peer_id()
	_session.entities.spawn(NetDemoBox.KIND, host_id, {"x": 400.0, "y": 360.0, "color": "orange"})
	_session.entities.spawn(NetDemoBox.KIND, guest_id, {"x": 880.0, "y": 360.0, "color": "blue"})


func _on_entity_spawned(entity_id: int, entity: Node) -> void:
	if _session.entities.is_local_authority(entity_id):
		_own_box = entity as Node2D
		_own_box_center = _own_box.position
	else:
		_remote_box = entity as Node2D
		_remote_previous = _remote_box.position


func _move_own_box() -> void:
	if not is_instance_valid(_own_box):
		return
	var angle: float = _session_time * BOX_SPEED / CIRCLE_RADIUS
	_own_box.position = _own_box_center + Vector2.from_angle(angle) * CIRCLE_RADIUS
	_own_box.rotation = angle


func _watch_remote_box(delta: float) -> void:
	if not is_instance_valid(_remote_box) or delta <= 0.0:
		return
	var step: float = _remote_box.position.distance_to(_remote_previous)
	_remote_previous = _remote_box.position
	# The first second covers the jump onto the circle and the buffer filling.
	if _session_time < 1.0:
		return
	_remote_observed_for += delta
	_remote_travelled += step
	# A box that moves at 200 px/s never covers 3 times that in one frame
	# unless the picture stuttered.
	if step > 8.0 and step / delta > BOX_SPEED * 3.0:
		_remote_jumps += 1


func _send_events() -> void:
	while _events_sent < EVENTS_TO_SEND and _session_time >= _events_sent * EVENT_INTERVAL:
		_session.messenger.send_to_remote(EVENT_COUNT, [_events_sent])
		_events_sent += 1


func _on_count(payload: Array, _sender_id: int) -> void:
	_events_received.append(payload[0])


func _direct_the_scenario() -> void:
	if not _swapped and _session_time >= SWAP_AT:
		_swapped = true
		_role_before_swap = _session.get_local_role()
		_session.swap_roles()
	if not _screen_requested and _session_time >= CHANGE_SCREEN_AT:
		_screen_requested = true
		_session.request_screen(SceneFlowController.Screen.ROUND)
	if not _left and _entered_round_at >= 0.0:
		if _session_time - _entered_round_at >= LEAVE_AFTER_ENTERING:
			_left = true
			var problems: Array[String] = _problems()
			_session.leave()
			_finish(problems)


func _on_screen_entered(screen: SceneFlowController.Screen) -> void:
	if screen == SceneFlowController.Screen.ROUND:
		_entered_round_at = _session_time


func _on_session_ended(reason: NetworkService.DisconnectReason, message: String) -> void:
	_end_reason = reason
	_end_message = message
	if _hosting:
		return
	# Guest: the host went away. One frame later the lobby must be showing.
	await get_tree().process_frame
	await get_tree().process_frame
	var problems: Array[String] = _problems()
	if _end_reason != NetworkService.DisconnectReason.REMOTE_CLOSE:
		problems.append("the session ended with reason %d, not a remote close" % _end_reason)
	if _end_message.is_empty():
		problems.append("no message says why the session ended")
	if SceneFlow.current_screen != SceneFlowController.Screen.LOBBY:
		problems.append(
			"not back in the lobby but on %s" % SceneFlowController.screen_name(SceneFlow.current_screen)
		)
	_finish(problems)


## Everything that did not hold so far.
func _problems() -> Array[String]:
	var problems: Array[String] = []
	if _session_time < 0.0:
		problems.append("the session never started")
		return problems
	if _roles_changed_count < 2:
		problems.append("saw %d role changes, expected the assignment and the swap" % _roles_changed_count)
	if _session.is_active() and _session.get_local_role() == GameEnums.Role.NONE:
		problems.append("no role")
	if _hosting and _session.get_local_role() == _role_before_swap:
		problems.append("the swap did not change the host's role")
	var expected_events: Array[int] = []
	expected_events.assign(range(EVENTS_TO_SEND))
	if _events_received != expected_events:
		problems.append("events arrived as %s" % [_events_received])
	if _remote_jumps > 0:
		problems.append("the other box jumped %d times" % _remote_jumps)
	var expected_distance: float = BOX_SPEED * _remote_observed_for
	if _remote_observed_for < 1.0 or _remote_travelled < expected_distance * 0.7:
		problems.append(
			"the other box travelled %d px in %.1f s, expected about %d"
			% [_remote_travelled, _remote_observed_for, expected_distance]
		)
	if _entered_round_at < 0.0:
		problems.append("the Round screen was never entered")
	return problems


func _finish(problems: Array[String]) -> void:
	if _finished:
		return
	_finished = true
	print(
		"SELFCHECK %s: roles changed %d times, role now %s, %d of %d events in order, "
		% [
			_label,
			_roles_changed_count,
			GameEnums.role_name(_session.get_local_role()),
			_events_received.size(),
			EVENTS_TO_SEND,
		]
		+ "other box travelled %d px in %.1f s with %d jumps, round entered: %s, end: '%s'"
		% [_remote_travelled, _remote_observed_for, _remote_jumps, _entered_round_at >= 0.0, _end_message]
	)
	for problem: String in problems:
		print("SELFCHECK %s PROBLEM: %s" % [_label, problem])
	print("SELFCHECK %s: %s" % [_label, "PASS" if problems.is_empty() else "FAIL"])
	# Give the connection a moment to say goodbye before the process ends.
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if problems.is_empty() else 1)

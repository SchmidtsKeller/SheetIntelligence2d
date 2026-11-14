extends Control
## Network demo: two instances connect, each moves its own box, and both see
## both boxes. Shows roles, a role swap, events, a synchronized screen change
## and what happens when the other instance goes away.
##
## [codeblock lang=text]
## godot --path . res://systems/session/demo/net_demo.tscn -- --host
## godot --path . res://systems/session/demo/net_demo.tscn -- --join
## [/codeblock]
##
## Without a flag the demo runs as an offline session of one. Add
## [code]--net-latency=80 --net-jitter=40 --net-loss=10[/code] to see the
## interpolation work on a bad connection.

const EVENT_HELLO: StringName = &"demo.hello"
const MOVE_SPEED: float = 240.0
const TURN_SPEED: float = 3.0

var _session: GameSession
var _own_box_id: int = -1
var _hellos_sent: int = 0
var _hellos_received: int = 0

@onready var _world: Node2D = %World
@onready var _status: Label = %Status
@onready var _log: RichTextLabel = %Log
@onready var _swap_button: Button = %SwapRoles
@onready var _round_button: Button = %GoToRound


func _ready() -> void:
	_session = Services.session
	_session.entities.spawn_root = _world
	_session.entities.register_kind(NetDemoBox.KIND, NetDemoBox.build)
	_session.entities.entity_spawned.connect(_on_entity_spawned)
	_session.messenger.register_event(EVENT_HELLO, NetMessenger.SenderRule.ANYONE)
	_session.messenger.subscribe(EVENT_HELLO, _on_hello)
	_session.session_started.connect(_on_session_started)
	_session.session_ended.connect(_on_session_ended)
	_session.roles_changed.connect(_on_roles_changed)

	_swap_button.pressed.connect(_session.swap_roles)
	_round_button.pressed.connect(_session.request_screen.bind(SceneFlowController.Screen.ROUND))
	(%SayHello as Button).pressed.connect(_say_hello)
	(%Leave as Button).pressed.connect(_session.leave)

	if _session.is_active():
		_on_session_started()
	else:
		var options: LaunchOptions = LaunchOptions.from_command_line()
		var error: Error = options.start_session(_session) if options.wants_session() else _session.host()
		_write("Starting: %s" % error_string(error))


func _exit_tree() -> void:
	_session.messenger.unsubscribe(EVENT_HELLO, _on_hello)


func _process(delta: float) -> void:
	_move_own_box(delta)
	_status.text = _describe()
	_swap_button.disabled = not (_session.is_active() and _session.is_host())
	_round_button.disabled = _swap_button.disabled


## The demo reads the keyboard directly: it shows the network layer, and the
## input service that characters use is a separate task.
func _move_own_box(delta: float) -> void:
	var box: Node2D = _session.entities.get_entity(_own_box_id) as Node2D
	if box == null:
		return
	var direction: Vector2 = Input.get_vector(
		InputActions.MOVE_LEFT,
		InputActions.MOVE_RIGHT,
		InputActions.MOVE_UP,
		InputActions.MOVE_DOWN
	)
	box.position += direction * MOVE_SPEED * delta
	if not direction.is_zero_approx():
		box.rotation = rotate_toward(box.rotation, direction.angle(), TURN_SPEED * delta * 2.0)


func _on_session_started() -> void:
	_write("Session started as %s." % ("host" if _session.is_host() else "guest"))
	if not _session.is_host():
		return
	# The host decides which entities exist: one box for each player.
	var guest_id: int = _session.get_remote_peer_id()
	var host_id: int = _session.get_local_peer_id()
	_session.entities.spawn(NetDemoBox.KIND, host_id, {"x": 400.0, "y": 360.0, "color": "orange"})
	if guest_id != 0:
		_session.entities.spawn(
			NetDemoBox.KIND, guest_id, {"x": 880.0, "y": 360.0, "color": "deepskyblue"}
		)


func _on_entity_spawned(entity_id: int, _entity: Node) -> void:
	if _session.entities.is_local_authority(entity_id) and _own_box_id == -1:
		_own_box_id = entity_id
	_write("Entity %d spawned (%s)." % [
		entity_id, "mine" if _session.entities.is_local_authority(entity_id) else "theirs"
	])


func _on_session_ended(_reason: NetworkService.DisconnectReason, message: String) -> void:
	_own_box_id = -1
	_write("Session ended: %s" % message)


func _on_roles_changed() -> void:
	_write("Roles: I am the %s." % GameEnums.role_name(_session.get_local_role()))


func _say_hello() -> void:
	_hellos_sent += 1
	_session.messenger.send_to_remote(EVENT_HELLO, [_hellos_sent])


func _on_hello(payload: Array, _sender_id: int) -> void:
	_hellos_received += 1
	_write("Hello number %d arrived." % payload[0])


func _describe() -> String:
	if not _session.is_active():
		var waiting: bool = (
			_session.get_connection_state() == NetworkService.ConnectionState.CONNECTING
		)
		return "Waiting for the other instance …" if waiting else "No session."
	return "%s  |  peer %d, other peer %d  |  role: %s  |  entities: %d  |  hellos: %d sent, %d received" % [
		"HOST" if _session.is_host() else "GUEST",
		_session.get_local_peer_id(),
		_session.get_remote_peer_id(),
		GameEnums.role_name(_session.get_local_role()),
		_session.entities.get_entity_ids().size(),
		_hellos_sent,
		_hellos_received,
	]


func _write(line: String) -> void:
	_log.append_text(line + "\n")

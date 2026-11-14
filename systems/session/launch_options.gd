class_name LaunchOptions
extends RefCounted
## Development options from the command line (everything after [code]--[/code]).
##
## [codeblock lang=text]
## godot --path . -- --host                 # host a session on this computer
## godot --path . -- --join                 # join the session on this computer
## godot --path . -- --join=192.168.0.20    # join a session on another computer
## [/codeblock]
##
## [code]--port=<number>[/code] changes the port (default 24565).
## [br][code]--lan[/code] lets a host accept other computers (default: only
## this computer).
## [br][code]--net-latency=<ms>[/code], [code]--net-jitter=<ms>[/code] and
## [code]--net-loss=<percent>[/code] simulate a bad connection for incoming
## messages.
##
## The Web build ignores these: it only connects through pairing codes.

enum Mode {
	## No flag given: nothing connects by itself.
	NONE,
	HOST,
	JOIN,
}

const DEFAULT_PORT: int = 24565
const DEFAULT_ADDRESS: String = "127.0.0.1"

var mode: Mode = Mode.NONE
var address: String = DEFAULT_ADDRESS
var port: int = DEFAULT_PORT
var lan: bool = false
## Simulated one-way delay of incoming messages, in seconds.
var sim_latency: float = 0.0
## Simulated extra delay, random per message, in seconds.
var sim_jitter: float = 0.0
## Simulated share of lost snapshots, 0..1.
var sim_loss: float = 0.0


## The options this instance of the game was started with.
static func from_command_line() -> LaunchOptions:
	return parse(OS.get_cmdline_user_args())


## Reads the options from [param arguments]. Unknown arguments are ignored;
## they may belong to another tool, such as the test runner.
static func parse(arguments: PackedStringArray) -> LaunchOptions:
	var options: LaunchOptions = LaunchOptions.new()
	for argument: String in arguments:
		var name: String = argument.get_slice("=", 0)
		var value: String = argument.get_slice("=", 1) if argument.contains("=") else ""
		match name:
			"--host":
				options.mode = Mode.HOST
			"--join":
				options.mode = Mode.JOIN
				if not value.is_empty():
					options.address = value
			"--port":
				if value.is_valid_int():
					options.port = value.to_int()
			"--lan":
				options.lan = true
			"--net-latency":
				options.sim_latency = maxf(value.to_float(), 0.0) / 1000.0
			"--net-jitter":
				options.sim_jitter = maxf(value.to_float(), 0.0) / 1000.0
			"--net-loss":
				options.sim_loss = clampf(value.to_float() / 100.0, 0.0, 1.0)
	return options


## Whether the instance should connect over the desktop dev transport.
func wants_session() -> bool:
	return mode != Mode.NONE


## The options for [method NetworkService.host_session] and
## [method NetworkService.join_session].
func get_session_options() -> Dictionary:
	return {"address": address, "port": port, "lan": lan}


## Hosts or joins as the command line asked. Returns [constant OK] when
## nothing was asked for.
func start_session(session: GameSession) -> Error:
	session.messenger.sim_latency = sim_latency
	session.messenger.sim_jitter = sim_jitter
	session.messenger.sim_loss = sim_loss
	match mode:
		Mode.HOST:
			return session.host(get_session_options())
		Mode.JOIN:
			return session.join(get_session_options())
		_:
			return OK

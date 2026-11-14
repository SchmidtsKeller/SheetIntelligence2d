extends SceneTree
## A small static file server for the exported Web build. Development only.
##
## [codeblock lang=text]
## godot --headless --path . --script res://tools/serve_web.gd
## godot --headless --path . --script res://tools/serve_web.gd -- --port=9000 --dir=build/web --lan
## [/codeblock]
##
## Serves `build/web` at http://localhost:8060 by default. The only requirement
## is Godot itself. [code]--lan[/code] also accepts connections from other
## devices in the network; note that browsers allow camera and clipboard only
## on https:// and on localhost, so pairing cannot be tested this way.

const DEFAULT_PORT: int = 8060
const DEFAULT_DIRECTORY: String = "build/web"
const REQUEST_TIMEOUT_MSEC: int = 5000
const MAX_REQUEST_BYTES: int = 16 * 1024

const MIME_TYPES: Dictionary[String, String] = {
	"html": "text/html; charset=utf-8",
	"js": "text/javascript; charset=utf-8",
	"css": "text/css; charset=utf-8",
	"json": "application/json",
	"wasm": "application/wasm",
	"pck": "application/octet-stream",
	"png": "image/png",
	"jpg": "image/jpeg",
	"svg": "image/svg+xml",
	"ico": "image/x-icon",
	"webmanifest": "application/manifest+json",
	"txt": "text/plain; charset=utf-8",
}

var _server: TCPServer = TCPServer.new()
var _root: String = ""
## Open connections: [code]{"peer": StreamPeerTCP, "buffer": PackedByteArray, "since": int}[/code].
var _connections: Array[Dictionary] = []


func _initialize() -> void:
	var port: int = DEFAULT_PORT
	var directory: String = DEFAULT_DIRECTORY
	var bind_address: String = "127.0.0.1"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
		elif argument.begins_with("--dir="):
			directory = argument.trim_prefix("--dir=")
		elif argument == "--lan":
			bind_address = "*"
		else:
			print("Unknown option: %s" % argument)

	_root = ProjectSettings.globalize_path("res://").path_join(directory).simplify_path()
	if directory.is_absolute_path():
		_root = directory.simplify_path()
	if not FileAccess.file_exists(_root.path_join("index.html")):
		printerr("No index.html in %s. Export the Web build first: tools/export_web" % _root)
		quit(1)
		return

	var error: Error = _server.listen(port, bind_address)
	if error != OK:
		printerr(
			(
				"Cannot listen on port %d (%s). Is another server running?"
				% [port, error_string(error)]
			)
		)
		quit(1)
		return

	print("Serving %s" % _root)
	print("  http://localhost:%d" % port)
	if bind_address == "*":
		for address: String in IP.get_local_addresses():
			if (
				address.count(".") == 3
				and not address.begins_with("127.")
				and not address.begins_with("169.254.")
			):
				print(
					(
						"  http://%s:%d   (other devices; no camera or clipboard without HTTPS)"
						% [address, port]
					)
				)
	print("Press Ctrl+C to stop.")


func _process(_delta: float) -> bool:
	while _server.is_connection_available():
		(
			_connections
			. append(
				{
					"peer": _server.take_connection(),
					"buffer": PackedByteArray(),
					"since": Time.get_ticks_msec(),
				}
			)
		)
	for connection: Dictionary in _connections.duplicate():
		if _advance(connection):
			(connection["peer"] as StreamPeerTCP).disconnect_from_host()
			_connections.erase(connection)
	OS.delay_msec(2)
	return false


## Reads what has arrived on [param connection] and answers once the request
## head is complete. Returns [code]true[/code] when the connection is done.
func _advance(connection: Dictionary) -> bool:
	var peer: StreamPeerTCP = connection["peer"]
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return true
	if Time.get_ticks_msec() - (connection["since"] as int) > REQUEST_TIMEOUT_MSEC:
		return true

	var available: int = peer.get_available_bytes()
	if available > 0:
		var chunk: Array = peer.get_data(available)
		var buffer: PackedByteArray = connection["buffer"]
		buffer.append_array(chunk[1])
		connection["buffer"] = buffer
	var request: String = (connection["buffer"] as PackedByteArray).get_string_from_utf8()
	if not request.contains("\r\n\r\n"):
		return (connection["buffer"] as PackedByteArray).size() > MAX_REQUEST_BYTES

	_respond(peer, request.get_slice("\r\n", 0))
	return true


func _respond(peer: StreamPeerTCP, request_line: String) -> void:
	var parts: PackedStringArray = request_line.split(" ")
	if parts.size() < 2 or (parts[0] != "GET" and parts[0] != "HEAD"):
		_send(
			peer,
			405,
			"Method Not Allowed",
			"text/plain; charset=utf-8",
			"Only GET and HEAD are supported.".to_utf8_buffer(),
			true
		)
		return

	var url_path: String = parts[1].get_slice("?", 0).get_slice("#", 0).uri_decode()
	var file_path: String = _root.path_join(url_path).simplify_path()
	if url_path.ends_with("/"):
		file_path = file_path.path_join("index.html")
	# simplify_path() resolves "..", so a path outside the root is an escape attempt.
	if file_path != _root and not file_path.begins_with(_root + "/"):
		_send(
			peer, 403, "Forbidden", "text/plain; charset=utf-8", "Forbidden.".to_utf8_buffer(), true
		)
		return
	if not FileAccess.file_exists(file_path):
		print("404  %s" % url_path)
		_send(
			peer, 404, "Not Found", "text/plain; charset=utf-8", "Not found.".to_utf8_buffer(), true
		)
		return

	var mime_type: String = MIME_TYPES.get(
		file_path.get_extension().to_lower(), "application/octet-stream"
	)
	print("200  %s" % url_path)
	_send(peer, 200, "OK", mime_type, FileAccess.get_file_as_bytes(file_path), parts[0] == "GET")


func _send(
	peer: StreamPeerTCP,
	status: int,
	reason: String,
	mime_type: String,
	body: PackedByteArray,
	with_body: bool
) -> void:
	var head: String = (
		"\r\n"
		. join(
			[
				"HTTP/1.1 %d %s" % [status, reason],
				"Content-Type: %s" % mime_type,
				"Content-Length: %d" % body.size(),
				# Always serve the latest export.
				"Cache-Control: no-store",
				"Connection: close",
				"",
				"",
			]
		)
	)
	peer.put_data(head.to_utf8_buffer())
	if with_body:
		peer.put_data(body)

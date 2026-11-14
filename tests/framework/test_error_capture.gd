class_name TestErrorCapture
extends Logger
## Collects the errors the engine reports while a test runs.
##
## Script errors and [method @GlobalScope.push_error] calls do not stop a
## headless run, so without this a broken test could pass unnoticed. The
## runner registers one instance with [method OS.add_logger] and asks it for
## the errors after every test. Warnings are ignored.

var _errors: PackedStringArray = []
var _mutex: Mutex = Mutex.new()


# The engine may log from any thread.
func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace],
) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var text: String = rationale if not rationale.is_empty() else code
	_mutex.lock()
	_errors.append("%s (%s:%d in %s)" % [text, file, line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


## Returns the errors collected since the last call and forgets them.
func take() -> PackedStringArray:
	_mutex.lock()
	var errors: PackedStringArray = _errors.duplicate()
	_errors.clear()
	_mutex.unlock()
	return errors

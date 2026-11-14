extends Node
## Runs all unit tests and quits with exit code 0 (all passed) or 1.
##
## [codeblock lang=text]
## godot --headless --path . res://tests/test_runner.tscn
## godot --headless --path . res://tests/test_runner.tscn -- --filter=registry
## [/codeblock]
##
## Finds every [code]test_*.gd[/code] below `res://tests/` (except this
## framework), runs each [code]test_*[/code] method of each [TestCase], and
## prints one line per test plus a summary.
##
## Options after [code]--[/code]:
## [br][code]--filter=<text>[/code] runs only tests whose file path or method
## name contains the text.
## [br][code]--quiet[/code] prints only failures and the summary.
##
## The project must have been imported once (`godot --headless --path .
## --import`), because scripts find each other's [code]class_name[/code]
## through the import cache. `tools/run_tests` does both steps.

# Preloaded instead of referenced by class name, so that this script still
# loads, and can say what is wrong, when the import cache is missing.
const TestCaseBase = preload("res://tests/framework/test_case.gd")
const ErrorCapture = preload("res://tests/framework/test_error_capture.gd")

const TEST_ROOT: String = "res://tests"
const FRAMEWORK_DIR: String = "res://tests/framework"
const TEST_FILE_PREFIX: String = "test_"
const TEST_METHOD_PREFIX: String = "test_"
## A test that runs longer than this is considered hung and aborts the run.
const TEST_TIMEOUT_SECONDS: float = 30.0

var _filter: String = ""
var _quiet: bool = false
var _capture: ErrorCapture = ErrorCapture.new()

var _test_count: int = 0
var _failed_count: int = 0
var _assert_count: int = 0
var _failed_tests: PackedStringArray = []

var _running_test: String = ""
var _running_since_msec: int = 0


func _ready() -> void:
	if not _is_project_imported():
		print("The project has not been imported yet, so scripts cannot find each other's classes.")
		print("Run this once, then start the tests again:  godot --headless --path . --import")
		print("RESULT: FAILED")
		get_tree().quit(1)
		return
	_parse_arguments()
	# Let the scene tree finish starting up before the first test runs.
	_run.call_deferred()


## Whether the import cache knows the project's global classes.
func _is_project_imported() -> bool:
	for global_class: Dictionary in ProjectSettings.get_global_class_list():
		if global_class["class"] == &"TestCase":
			return true
	return false


func _process(_delta: float) -> void:
	if _running_test.is_empty():
		return
	if Time.get_ticks_msec() - _running_since_msec > TEST_TIMEOUT_SECONDS * 1000.0:
		print("\nTIMEOUT  %s did not finish within %s s. Aborting the test run." % [_running_test, TEST_TIMEOUT_SECONDS])
		get_tree().quit(1)


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--filter="):
			_filter = argument.trim_prefix("--filter=").to_lower()
		elif argument == "--quiet":
			_quiet = true
		else:
			print("Unknown test option: %s" % argument)


func _run() -> void:
	var started_msec: int = Time.get_ticks_msec()
	OS.add_logger(_capture)
	for path: String in _find_test_files(TEST_ROOT):
		await _run_file(path)
	OS.remove_logger(_capture)
	_print_summary(Time.get_ticks_msec() - started_msec)
	get_tree().quit(0 if _failed_count == 0 and _test_count > 0 else 1)


func _find_test_files(directory: String) -> PackedStringArray:
	var files: PackedStringArray = []
	if directory == FRAMEWORK_DIR:
		return files
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return files
	for file: String in dir.get_files():
		if file.begins_with(TEST_FILE_PREFIX) and file.ends_with(".gd"):
			files.append(directory.path_join(file))
	for sub_directory: String in dir.get_directories():
		files.append_array(_find_test_files(directory.path_join(sub_directory)))
	files.sort()
	return files


func _run_file(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		_record_file_failure(path, "the script could not be loaded")
		return
	var instance: Variant = script.new()
	if not instance is TestCaseBase:
		if instance is Object and not instance is RefCounted:
			(instance as Object).free()
		_record_file_failure(path, "the script does not extend TestCase")
		return
	var test_case: TestCaseBase = instance

	var methods: PackedStringArray = _test_methods_of(script, path)
	if methods.is_empty():
		test_case.free()
		return

	if not _quiet:
		print("\n%s" % path.trim_prefix("res://"))
	add_child(test_case)
	_capture.take()
	await test_case.before_all()
	for method: String in methods:
		await _run_test(test_case, path, method)
	await test_case.after_all()
	var leftover_errors: PackedStringArray = _capture.take()
	if not leftover_errors.is_empty():
		_record_file_failure(path, "engine error outside a test: %s" % "; ".join(leftover_errors))
	remove_child(test_case)
	test_case.free()


func _test_methods_of(script: GDScript, path: String) -> PackedStringArray:
	var methods: PackedStringArray = []
	var file_matches: bool = _filter.is_empty() or path.to_lower().contains(_filter)
	for info: Dictionary in script.get_script_method_list():
		var method: String = info["name"]
		if not method.begins_with(TEST_METHOD_PREFIX) or methods.has(method):
			continue
		if file_matches or method.to_lower().contains(_filter):
			methods.append(method)
	return methods


func _run_test(test_case: TestCaseBase, path: String, method: String) -> void:
	_running_test = "%s::%s" % [path.trim_prefix("res://"), method]
	_running_since_msec = Time.get_ticks_msec()

	test_case._begin_test()
	await test_case.before_each()
	await test_case.call(method)
	await test_case.after_each()
	var failures: PackedStringArray = test_case._end_test(_capture.take())

	_test_count += 1
	_assert_count += test_case._get_assert_count()
	if failures.is_empty():
		if not _quiet:
			var expected_errors: int = test_case._get_expected_error_count()
			var note: String = "  (the engine error above was expected)" if expected_errors > 0 else ""
			print("  PASS  %s%s" % [method, note])
	else:
		_failed_count += 1
		_failed_tests.append(_running_test)
		print("  FAIL  %s" % (method if not _quiet else _running_test))
		for failure: String in failures:
			print("          %s" % failure)
	_running_test = ""


func _record_file_failure(path: String, problem: String) -> void:
	_test_count += 1
	_failed_count += 1
	_failed_tests.append(path.trim_prefix("res://"))
	print("\n%s\n  FAIL  %s" % [path.trim_prefix("res://"), problem])


func _print_summary(duration_msec: int) -> void:
	print("\n----------------------------------------")
	if _test_count == 0:
		print("No tests found%s." % ("" if _filter.is_empty() else " for filter '%s'" % _filter))
	for failed_test: String in _failed_tests:
		print("FAILED  %s" % failed_test)
	print(
		"%d tests, %d passed, %d failed, %d assertions, %.2f s"
		% [_test_count, _test_count - _failed_count, _failed_count, _assert_count, duration_msec / 1000.0]
	)
	print("RESULT: %s" % ("PASSED" if _failed_count == 0 and _test_count > 0 else "FAILED"))

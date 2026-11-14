class_name TestCase
extends Node
## Base class of all unit tests.
##
## A test file is a script named [code]test_*.gd[/code] below `res://tests/`
## that extends this class. Every method whose name starts with
## [code]test_[/code] is one test. The runner adds the test case to the scene
## tree, so tests may add child nodes and await frames.
##
## A failed assertion does not stop the test; it is recorded and the test goes
## on. A test also fails if it makes no assertion at all, or if the engine
## reports an error that was not announced with [method expect_error].

var _failures: PackedStringArray = []
var _assert_count: int = 0
var _expected_errors: PackedStringArray = []
var _to_free: Array[Object] = []
var _signal_log: Dictionary[int, Dictionary] = {}

# --- Hooks (override as needed; may await) -----------------------------------


## Runs once before the first test of this file.
func before_all() -> void:
	pass


## Runs once after the last test of this file.
func after_all() -> void:
	pass


## Runs before every test.
func before_each() -> void:
	pass


## Runs after every test.
func after_each() -> void:
	pass


# --- Assertions --------------------------------------------------------------


func assert_true(condition: bool, message: String = "") -> bool:
	return _check(condition, "expected true but got false", message)


func assert_false(condition: bool, message: String = "") -> bool:
	return _check(not condition, "expected false but got true", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	return _check(
		_equal(actual, expected),
		"expected %s but got %s" % [_show(expected), _show(actual)],
		message
	)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> bool:
	return _check(
		not _equal(actual, unexpected), "expected anything but %s" % _show(unexpected), message
	)


## Compares two numbers, or two vectors component-wise, within [param tolerance].
func assert_almost_eq(
	actual: Variant, expected: Variant, tolerance: float = 0.0001, message: String = ""
) -> bool:
	return _check(
		_almost_equal(actual, expected, tolerance),
		"expected %s (±%s) but got %s" % [_show(expected), tolerance, _show(actual)],
		message,
	)


func assert_gt(actual: Variant, limit: Variant, message: String = "") -> bool:
	return _check(
		actual > limit,
		"expected a value greater than %s but got %s" % [_show(limit), _show(actual)],
		message
	)


func assert_gte(actual: Variant, limit: Variant, message: String = "") -> bool:
	return _check(
		actual >= limit,
		"expected a value of at least %s but got %s" % [_show(limit), _show(actual)],
		message
	)


func assert_lt(actual: Variant, limit: Variant, message: String = "") -> bool:
	return _check(
		actual < limit,
		"expected a value less than %s but got %s" % [_show(limit), _show(actual)],
		message
	)


func assert_lte(actual: Variant, limit: Variant, message: String = "") -> bool:
	return _check(
		actual <= limit,
		"expected a value of at most %s but got %s" % [_show(limit), _show(actual)],
		message
	)


func assert_null(value: Variant, message: String = "") -> bool:
	return _check(value == null, "expected null but got %s" % _show(value), message)


func assert_not_null(value: Variant, message: String = "") -> bool:
	return _check(value != null, "expected a value but got null", message)


## Passes if [param container] (array, dictionary or string) contains [param value].
func assert_has(container: Variant, value: Variant, message: String = "") -> bool:
	return _check(
		value in container, "expected %s to contain %s" % [_show(container), _show(value)], message
	)


func assert_does_not_have(container: Variant, value: Variant, message: String = "") -> bool:
	return _check(
		not (value in container),
		"expected %s not to contain %s" % [_show(container), _show(value)],
		message
	)


## Passes if [param value] is an instance of [param type] (a script, a native
## class such as [code]Node[/code], or a [enum Variant.Type]).
func assert_is(value: Variant, type: Variant, message: String = "") -> bool:
	return _check(
		is_instance_of(value, type),
		"%s is not an instance of %s" % [_show(value), _show_type(type)],
		message
	)


## Records a failure unconditionally.
func fail_test(message: String) -> void:
	_check(false, "failed", message)


## Counts as an assertion that passed, for tests whose point is that nothing
## went wrong.
func pass_test() -> void:
	_assert_count += 1


# --- Engine errors -----------------------------------------------------------


## Announces that the code under test will report an engine error whose text
## contains [param text_part]. Without this, any error fails the test. The
## test also fails if the announced error does not occur.
func expect_error(text_part: String) -> void:
	_expected_errors.append(text_part)


# --- Signals -----------------------------------------------------------------


## Starts recording every signal [param emitter] emits, for the signal assertions.
func watch_signals(emitter: Object) -> void:
	var id: int = emitter.get_instance_id()
	if _signal_log.has(id):
		return
	var emissions: Dictionary[StringName, Array] = {}
	_signal_log[id] = emissions
	for info: Dictionary in emitter.get_signal_list():
		var signal_name: StringName = info["name"]
		emissions[signal_name] = []
		emitter.connect(
			signal_name, func(...arguments: Array) -> void: emissions[signal_name].append(arguments)
		)


func assert_signal_emitted(emitter: Object, signal_name: StringName, message: String = "") -> bool:
	return _check(
		get_signal_emit_count(emitter, signal_name) > 0,
		"expected signal '%s' to be emitted" % signal_name,
		message
	)


func assert_signal_not_emitted(
	emitter: Object, signal_name: StringName, message: String = ""
) -> bool:
	var count: int = get_signal_emit_count(emitter, signal_name)
	return _check(
		count == 0,
		(
			"expected signal '%s' not to be emitted, but it was emitted %d time(s)"
			% [signal_name, count]
		),
		message
	)


func assert_signal_emit_count(
	emitter: Object, signal_name: StringName, expected: int, message: String = ""
) -> bool:
	var count: int = get_signal_emit_count(emitter, signal_name)
	return _check(
		count == expected,
		(
			"expected signal '%s' to be emitted %d time(s) but it was emitted %d time(s)"
			% [signal_name, expected, count]
		),
		message
	)


## Passes if the most recent emission of [param signal_name] carried
## [param arguments].
func assert_signal_emitted_with(
	emitter: Object, signal_name: StringName, arguments: Array, message: String = ""
) -> bool:
	var emissions: Array = _emissions_of(emitter, signal_name)
	if emissions.is_empty():
		return _check(
			false,
			(
				"expected signal '%s' to be emitted with %s but it was not emitted"
				% [signal_name, _show(arguments)]
			),
			message
		)
	var last: Array = emissions.back()
	return _check(
		_equal(last, arguments),
		"expected signal '%s' with %s but got %s" % [signal_name, _show(arguments), _show(last)],
		message
	)


## How often [param emitter] emitted [param signal_name] since it is watched.
func get_signal_emit_count(emitter: Object, signal_name: StringName) -> int:
	return _emissions_of(emitter, signal_name).size()


## The arguments of emission number [param index] (0 = first, -1 = latest).
func get_signal_arguments(emitter: Object, signal_name: StringName, index: int = -1) -> Array:
	var emissions: Array = _emissions_of(emitter, signal_name)
	if emissions.is_empty():
		return []
	return emissions[index]


# --- Object lifetime ---------------------------------------------------------


## Frees [param object] when the test ends. Returns [param object] for chaining.
func autofree(object: Variant) -> Variant:
	_to_free.append(object)
	return object


## Adds [param node] below this test case and frees it when the test ends.
func add_child_autofree(node: Variant) -> Variant:
	add_child(node)
	return autofree(node)


# --- Time --------------------------------------------------------------------


## Waits for [param count] process frames.
func wait_frames(count: int = 1) -> void:
	for _i: int in count:
		await get_tree().process_frame


## Waits for [param seconds] of game time.
func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --- Runner interface (not for tests) ----------------------------------------


func _begin_test() -> void:
	_failures.clear()
	_assert_count = 0
	_expected_errors.clear()
	_signal_log.clear()


## Ends the test and returns its failures. [param engine_errors] are the
## errors the engine reported while the test ran.
func _end_test(engine_errors: PackedStringArray) -> PackedStringArray:
	for object: Object in _to_free:
		if is_instance_valid(object) and not object is RefCounted:
			object.free()
	_to_free.clear()

	var matched: Dictionary[String, bool] = {}
	for error: String in engine_errors:
		var announced: bool = false
		for text_part: String in _expected_errors:
			if error.contains(text_part):
				matched[text_part] = true
				announced = true
		if not announced:
			_failures.append("unexpected engine error: %s" % error)
	for text_part: String in _expected_errors:
		if not matched.has(text_part):
			_failures.append(
				"expected an engine error containing '%s', but none occurred" % text_part
			)

	if _failures.is_empty() and _assert_count == 0:
		_failures.append("the test made no assertions")
	return _failures.duplicate()


func _get_assert_count() -> int:
	return _assert_count


func _get_expected_error_count() -> int:
	return _expected_errors.size()


func _check(passed: bool, problem: String, message: String) -> bool:
	_assert_count += 1
	if not passed:
		_failures.append(problem if message.is_empty() else "%s: %s" % [message, problem])
	return passed


func _emissions_of(emitter: Object, signal_name: StringName) -> Array:
	var id: int = emitter.get_instance_id()
	if not _signal_log.has(id):
		_failures.append(
			"signals of %s are not watched; call watch_signals() first" % _show(emitter)
		)
		return []
	var emissions: Dictionary = _signal_log[id]
	if not emissions.has(signal_name):
		_failures.append("%s has no signal '%s'" % [_show(emitter), signal_name])
		return []
	return emissions[signal_name]


static func _equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		# 1 and 1.0 are equal; a String and a StringName with the same text too.
		var numbers: bool = (a is int or a is float) and (b is int or b is float)
		var texts: bool = (a is String or a is StringName) and (b is String or b is StringName)
		if not numbers and not texts:
			return false
	return a == b


static func _almost_equal(a: Variant, b: Variant, tolerance: float) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) <= tolerance
	if a is Vector2 and b is Vector2:
		var difference: Vector2 = a - b
		return absf(difference.x) <= tolerance and absf(difference.y) <= tolerance
	return false


static func _show(value: Variant) -> String:
	if value is String or value is StringName:
		return '"%s"' % value
	if value is Object and value != null:
		var script: Script = (value as Object).get_script()
		if script != null and not script.get_global_name().is_empty():
			return "<%s>" % script.get_global_name()
	return str(value)


static func _show_type(type: Variant) -> String:
	if type is Script and not (type as Script).get_global_name().is_empty():
		return String((type as Script).get_global_name())
	if type is int:
		return type_string(type)
	return str(type)

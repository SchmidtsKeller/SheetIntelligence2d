class_name PairingBrowser
extends RefCounted
## The browser side of pairing ([code]web/pairing.js[/code]): QR codes, the
## camera scanner and the clipboard, shown as HTML over the game.
##
## Only the Web build has it; elsewhere [method is_available] is
## [code]false[/code] and the methods do nothing. Tests replace it with a fake.

## The player scanned, pasted or typed a code.
signal code_entered(code: String)
## The camera or the text field was closed without a code.
signal cancelled
## The camera could not be used; [param message] says why, for the player.
signal failed(message: String)
## Copying is over: [param copied] says whether the code is on the clipboard;
## otherwise the player was shown it to copy by hand.
signal copy_finished(copied: bool)

const INTERFACE: String = "SheepPairing"

var _api: JavaScriptObject
## Kept, or JavaScript can no longer call it.
var _callback: JavaScriptObject


func _init() -> void:
	if not OS.has_feature("web"):
		return
	_api = JavaScriptBridge.get_interface(INTERFACE)
	if _api != null:
		_callback = JavaScriptBridge.create_callback(_on_result)


## Whether the browser side is there.
func is_available() -> bool:
	return _api != null


## The modules of a QR code for [param text], one row of [code]0[/code] and
## [code]1[/code] per entry; empty if there is none.
func qr_rows(text: String) -> PackedStringArray:
	if _api == null:
		return PackedStringArray()
	return str(_api.call(&"qrMatrix", text, "L")).split("\n", false)


## Opens the camera to read the other device's code.
func scan() -> void:
	if _api != null:
		_api.call(&"scan", _callback)


## Opens a field to paste or type a code into.
func enter(title: String) -> void:
	if _api != null:
		_api.call(&"enter", title, _callback)


## Puts [param text] on the clipboard, or shows it to copy by hand.
func copy(text: String) -> void:
	if _api != null:
		_api.call(&"copy", text, _callback)


## Closes the camera or a field that is open.
func close() -> void:
	if _api != null:
		_api.call(&"close")


func _on_result(arguments: Array) -> void:
	var value: String = str(arguments[1]) if arguments.size() > 1 else ""
	match str(arguments[0]):
		"code":
			code_entered.emit(value)
		"cancel":
			cancelled.emit()
		"error":
			failed.emit(value)
		"copied":
			copy_finished.emit(true)
		"closed":
			copy_finished.emit(false)

extends Node2D
## Input sandbox: shows what the [InputService] reports and steers a
## placeholder character with nothing but that.
##
## Run this scene on its own (F6). Use the buttons to switch the role, to
## switch gameplay input on and off and to force the touch controls, and
## check that keyboard and mouse and the touch controls steer the character
## in exactly the same way. On a desktop, forced touch controls can be
## operated with the mouse.

const TURN_SPEED: float = 12.0
const ARENA: Rect2 = Rect2(60.0, 140.0, 1160.0, 520.0)
const ALL_ABILITIES: Array[StringName] = [
	InputActions.SHOOT,
	InputActions.BELL,
	InputActions.GRAZE,
	InputActions.BLEAT,
	InputActions.EAT,
	InputActions.SPRINT,
	InputActions.PERK,
]

var _input: InputService
var _move_speed: float = 180.0
## Recent action signals, newest first.
var _events: PackedStringArray = []

@onready var _character: Node2D = %Character
@onready var _readout: Label = %Readout
@onready var _role_button: Button = %RoleButton
@onready var _gameplay_button: Button = %GameplayButton
@onready var _scheme_button: Button = %SchemeButton
@onready var _lock_button: Button = %LockButton


func _ready() -> void:
	_input = Services.input
	_move_speed = Services.perks.get_stat(StatIds.HERDER_MOVE_SPEED)
	_input.action_pressed.connect(_on_action.bind("pressed"))
	_input.action_released.connect(_on_action.bind("released"))
	_role_button.pressed.connect(_next_role)
	_gameplay_button.pressed.connect(_toggle_gameplay)
	_scheme_button.pressed.connect(_next_scheme)
	_lock_button.pressed.connect(_toggle_move_lock)
	_input.set_gameplay_enabled(true)
	_input.set_role(GameEnums.Role.SHEEPHERDER)


func _exit_tree() -> void:
	_input.clear_locks(&"sandbox")
	_input.clear_scheme_override()
	_input.set_role(GameEnums.Role.NONE)


func _physics_process(delta: float) -> void:
	# Everything the character does comes from the input service.
	var move: Vector2 = _input.get_move_vector()
	var speed: float = _move_speed
	if _input.is_action_held(InputActions.SPRINT):
		speed *= 1.5
	if _input.is_action_held(InputActions.GRAZE):
		speed = 0.0
	_character.position += move * speed * delta
	_character.position = _character.position.clamp(ARENA.position, ARENA.end)
	var facing: Vector2 = _facing(move)
	_character.rotation = lerp_angle(_character.rotation, facing.angle(), TURN_SPEED * delta)


func _process(_delta: float) -> void:
	_readout.text = _describe()
	_role_button.text = "Role: %s" % GameEnums.role_name(_input.get_role())
	_gameplay_button.text = "Gameplay input: %s" % ("on" if _input.is_gameplay_enabled() else "off")
	_scheme_button.text = "Controls: %s" % _scheme_name(_input.get_scheme())
	_lock_button.text = (
		"Movement: %s" % ("locked" if _input.is_locked(InputActions.MOVE) else "free")
	)
	queue_redraw()


func _draw() -> void:
	draw_rect(ARENA, Color(0.16, 0.25, 0.16))
	draw_rect(ARENA, Color(0.5, 0.6, 0.5), false, 2.0)
	# The aim, as the Sheepherder's flashlight would point.
	if InputActions.role_aims(_input.get_role()):
		var aim: Vector2 = _input.get_aim_direction(_character.global_position)
		draw_line(_character.position, _character.position + aim * 160.0, Color.YELLOW, 3.0)


## The Sheepherder faces where they aim, the Monster where it walks.
func _facing(move: Vector2) -> Vector2:
	if InputActions.role_aims(_input.get_role()):
		return _input.get_aim_direction(_character.global_position)
	if move.is_zero_approx():
		return Vector2.from_angle(_character.rotation)
	return move


func _on_action(action: StringName, what: String) -> void:
	_events.insert(0, "%s %s" % [action, what])
	if _events.size() > 6:
		_events.resize(6)


func _next_role() -> void:
	match _input.get_role():
		GameEnums.Role.SHEEPHERDER:
			_input.set_role(GameEnums.Role.MONSTER)
		GameEnums.Role.MONSTER:
			_input.set_role(GameEnums.Role.NONE)
		_:
			_input.set_role(GameEnums.Role.SHEEPHERDER)


func _toggle_gameplay() -> void:
	_input.set_gameplay_enabled(not _input.is_gameplay_enabled())


func _next_scheme() -> void:
	if _input.get_scheme() == InputService.Scheme.TOUCH:
		_input.set_scheme_override(InputService.Scheme.KEYBOARD_MOUSE)
	else:
		_input.set_scheme_override(InputService.Scheme.TOUCH)


func _toggle_move_lock() -> void:
	if _input.is_locked(InputActions.MOVE):
		_input.remove_lock(InputActions.MOVE, &"sandbox")
	else:
		_input.add_lock(InputActions.MOVE, &"sandbox")


func _describe() -> String:
	var move: Vector2 = _input.get_move_vector()
	var aim: Vector2 = _input.get_aim_direction(_character.global_position)
	var held: PackedStringArray = []
	for action: StringName in ALL_ABILITIES:
		if _input.is_action_held(action):
			held.append(action)
	return (
		"move (%.2f, %.2f) length %.2f    aim (%.2f, %.2f)    held: %s\nlast: %s"
		% [
			move.x,
			move.y,
			move.length(),
			aim.x,
			aim.y,
			", ".join(held) if not held.is_empty() else "nothing",
			"  |  ".join(_events) if not _events.is_empty() else "no action yet",
		]
	)


static func _scheme_name(scheme: InputService.Scheme) -> String:
	return "touch" if scheme == InputService.Scheme.TOUCH else "keyboard and mouse"

class_name BotInput
extends StubInputService
## The controls of a character that a bot plays (offline, see [RoundStage]).
##
## The bot moves the stick and presses the buttons here, and only that
## character listens to it. It is never [code]Services.input[/code]: the
## player's keys do not reach the bot's character, and the bot cannot press
## anything for the player. It gates actions by role and by the gameplay
## switch exactly like the player's input does.

## The spawn data key that marks a character as a bot's.
const DATA_KEY: String = "bot"


func _init(role: GameEnums.Role = GameEnums.Role.NONE) -> void:
	super()
	set_role(role)


## Whether [param data], the spawn data of a character, makes it a bot's.
static func is_bot_data(data: Dictionary) -> bool:
	return data.get(DATA_KEY, false)


## Presses [param action] if it is not held yet. Returns whether it is held.
func hold(action: StringName) -> bool:
	if is_action_held(action):
		return true
	return simulate_press(action)


## Lets go of [param action] if it is held.
func let_go(action: StringName) -> void:
	if is_action_held(action):
		simulate_release(action)


## Presses and releases [param action] at once. Returns whether it was
## reported.
func tap(action: StringName) -> bool:
	var reported: bool = simulate_press(action)
	simulate_release(action)
	return reported


## Lets go of everything: no movement, no button held.
func release_all() -> void:
	move_vector = Vector2.ZERO
	for action: StringName in InputActions.HOLD_ACTIONS:
		let_go(action)

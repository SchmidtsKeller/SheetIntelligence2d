extends TestCase
## An offline match against the computer (#57): the round screen on one
## device, with a bot playing the character the player does not play.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Phase = MatchFlow.Phase
# gdlint: ignore=constant-name
const Role = GameEnums.Role

const ROUND_SCENE: String = "res://ui/screens/round_screen.tscn"
## The longest a bot may take for what a test waits for, in physics steps.
const PATIENCE: int = 240

var _flow: MatchFlow
var _session: GameSession
var _scene_flow: SceneFlowController
var _screen: Node2D
var _time: float = 0.0
## The player's controls, which the test presses.
var _player: StubInputService
var _original_input: Node
var _original_config: Dictionary[StringName, float] = {}


func before_each() -> void:
	_session = Services.session
	_flow = Services.match_flow
	if _session.is_active():
		_session.leave()
	_scene_flow = add_child_autofree(SceneFlowController.new())
	_scene_flow.scene_changer = func(_path: String) -> Error: return OK
	_session.scene_flow = _scene_flow
	_time = 50.0
	_flow.clock = func() -> float: return _time
	_player = StubInputService.new()
	_original_input = Services.replace(InputService, _player)


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	_session.leave()
	_session.scene_flow = null
	_flow.clock = MatchFlow.system_clock
	_flow.first_host_role = Role.NONE
	Services.replace(InputService, _original_input)
	_player.free()
	for stat: StringName in _original_config:
		Services.config.set(stat, _original_config[stat])
	_original_config.clear()
	await wait_frames(2)


# --- Who plays what --------------------------------------------------------------


func test_a_bot_plays_the_sheepherder_against_the_players_monster() -> void:
	await _play_as(Role.MONSTER)
	var stage: RoundStage = _stage()
	var herder: Sheepherder = stage.get_sheepherder()
	var monster: Monster = stage.get_monster()

	assert_true(_session.is_offline())
	assert_true(herder.is_bot)
	assert_true(herder.controlled_locally, "the bot's character is simulated here")
	assert_is(herder.input, BotInput)
	assert_false(herder.get_camera().enabled, "the bot has no camera")
	assert_is(stage.get_bot(), SheepherderBot)
	assert_false(monster.is_bot)
	assert_eq(monster.input, _player)
	assert_true(monster.get_camera().is_current(), "the camera is the player's")


func test_a_bot_plays_the_monster_against_the_players_sheepherder() -> void:
	await _play_as(Role.SHEEPHERDER)
	var stage: RoundStage = _stage()
	var monster: Monster = stage.get_monster()
	var herder: Sheepherder = stage.get_sheepherder()

	assert_true(monster.is_bot)
	assert_true(monster.controlled_locally)
	assert_is(monster.input, BotInput)
	assert_null(monster.get_camera(), "the bot has no camera")
	assert_is(stage.get_bot(), MonsterBot)
	assert_false(herder.is_bot)
	assert_eq(herder.input, _player)
	assert_true(herder.get_camera().is_current(), "the camera is the player's")


func test_the_bot_monster_is_shown_like_the_flock() -> void:
	await _play_as(Role.SHEEPHERDER)
	var body: SheepBody = _stage().get_monster().get_body()
	var sheep: SheepBody = Services.swarm.get_sheep_body(Services.swarm.get_living_sheep_ids()[0])
	var monster_sync: SheepNetSync = body.get_node(^"NetSync")
	var sheep_sync: SheepNetSync = sheep.get_node(^"NetSync")

	# Simulated on this device like the flock, so drawn through the same delay:
	# its picture does not follow its moves sooner than a sheep's does.
	assert_eq(monster_sync.live_on_owner, sheep_sync.live_on_owner)
	assert_true(body.presented_externally)
	assert_eq(body.presented_externally, sheep.presented_externally)


func test_the_player_plays_the_other_role_in_the_next_round() -> void:
	await _play_as(Role.MONSTER)
	_pass(Services.config.round_countdown_duration)
	_pass(Services.config.round_duration)
	_pass(Services.config.round_resolved_duration)
	await wait_frames(4)
	_screen.free()
	_flow.request_next_round()
	_screen = _open_round_screen()
	await wait_frames(3)

	assert_eq(_session.get_local_role(), Role.SHEEPHERDER)
	assert_true(_stage().get_monster().is_bot, "the bot took the Monster")
	assert_false(_stage().get_sheepherder().is_bot)


# --- The bot plays fair ----------------------------------------------------------


func test_the_players_keys_never_reach_the_bot() -> void:
	await _play_as(Role.MONSTER)
	var herder: Sheepherder = _stage().get_sheepherder()
	_pass(Services.config.round_countdown_duration)
	watch_signals(Services.combat)
	_player.set_role(Role.SHEEPHERDER)

	_player.simulate_press(InputActions.SHOOT)
	_player.simulate_press(InputActions.BELL)

	assert_signal_not_emitted(Services.combat, &"shot_fired")
	assert_true(herder.can_ring_bell(), "the bell was not rung")


func test_the_bot_waits_for_the_countdown() -> void:
	await _play_as(Role.MONSTER)
	var herder: Sheepherder = _stage().get_sheepherder()
	var bot_input: BotInput = herder.input
	var start: Vector2 = herder.global_position

	await _steps(30)

	assert_eq(_flow.get_phase(), Phase.COUNTDOWN)
	assert_false(bot_input.is_gameplay_enabled())
	assert_eq(herder.global_position, start, "the bot stood still")

	_pass(Services.config.round_countdown_duration)
	await _steps(2)

	assert_true(bot_input.is_gameplay_enabled())


# --- The bot Monster -------------------------------------------------------------


func test_the_bot_monster_eats_where_the_sheepherder_cannot_see() -> void:
	_tune(StatIds.BOT_MONSTER_REST_MIN, 0.0)
	_tune(StatIds.BOT_MONSTER_REST_MAX, 0.0)
	await _play_as(Role.SHEEPHERDER)
	var stage: RoundStage = _stage()
	var body: SheepBody = stage.get_monster().get_body()
	# The player's Sheepherder looks away, in their corner, far from the flock.
	var herder: Vector2 = stage.get_sheepherder().global_position
	_player.aim_direction = body.global_position.direction_to(herder)
	var prey: SheepBody = _nearest_sheep_to(body)
	prey.global_position = body.global_position + Vector2(60.0, 0.0)
	_pass(Services.config.round_countdown_duration)

	var eaten: bool = await _wait_until(
		func() -> bool: return Services.combat.get_eaten_count() > 0
	)

	assert_true(eaten, "the bot Monster ate a sheep")
	assert_eq(Services.swarm.get_living_count(), Services.config.flock_size - 1)


func test_the_bot_monster_does_not_eat_in_the_light() -> void:
	_tune(StatIds.BOT_MONSTER_REST_MIN, 0.0)
	_tune(StatIds.BOT_MONSTER_REST_MAX, 0.0)
	await _play_as(Role.SHEEPHERDER)
	var stage: RoundStage = _stage()
	var herder: Sheepherder = stage.get_sheepherder()
	var body: SheepBody = stage.get_monster().get_body()
	# The Sheepherder stands next to the Monster and shines the light on it.
	herder.global_position = _clear_spot_next_to(stage.get_arena(), body.global_position)
	_player.aim_direction = herder.global_position.direction_to(body.global_position)
	_nearest_sheep_to(body).global_position = body.global_position + Vector2(60.0, 0.0)
	_pass(Services.config.round_countdown_duration)

	await _steps(PATIENCE / 2)

	assert_eq(Services.combat.get_eaten_count(), 0)
	assert_false(body.is_devouring())


# --- The bot Sheepherder ---------------------------------------------------------


func test_the_bot_sheepherder_shoots_a_sheep_it_sees_eating() -> void:
	await _play_as(Role.MONSTER)
	var stage: RoundStage = _stage()
	var herder: Sheepherder = stage.get_sheepherder()
	var body: SheepBody = stage.get_monster().get_body()
	_pass(Services.config.round_countdown_duration)
	await _steps(2)
	# The player's Monster eats right in the bot's light.
	var ahead: Vector2 = herder.get_aim_direction()
	body.global_position = herder.global_position + ahead * 160.0
	_nearest_sheep_to(body).global_position = body.global_position + ahead * 40.0
	await _steps(2)
	watch_signals(Services.combat)
	assert_true(Services.combat.request_eat(), "the Monster eats")

	var shot: bool = await _wait_until(func() -> bool: return not body.is_alive())

	assert_true(shot, "the bot shot the Monster")
	assert_signal_emitted(Services.combat, &"monster_shot")


func test_the_bot_sheepherder_goes_to_look_where_it_heard_eating() -> void:
	await _play_as(Role.MONSTER)
	var herder: Sheepherder = _stage().get_sheepherder()
	var bot: SheepherderBot = _stage().get_bot()
	_pass(Services.config.round_countdown_duration)
	await _steps(2)

	Services.audio.play_event(AudioEvents.EAT, herder.global_position + Vector2(500.0, 0.0))
	var reacted: bool = await _wait_until(
		func() -> bool: return bot.get_mode() == SheepherderBot.Mode.INVESTIGATE
	)

	assert_true(reacted, "it goes to look")


func test_the_bot_sheepherder_does_not_hear_eating_far_away() -> void:
	await _play_as(Role.MONSTER)
	var herder: Sheepherder = _stage().get_sheepherder()
	var bot: SheepherderBot = _stage().get_bot()
	_pass(Services.config.round_countdown_duration)
	await _steps(2)
	var hearing: float = Services.audio.get_hearing_range(AudioEvents.EAT)

	var far: Vector2 = herder.global_position + Vector2(hearing + 50.0, 0.0)
	Services.audio.play_event(AudioEvents.EAT, far)
	await _steps(60)

	assert_ne(bot.get_mode(), SheepherderBot.Mode.INVESTIGATE)


# --- Helpers ---------------------------------------------------------------------


## Opens the round screen offline with this player in [param role].
func _play_as(role: Role) -> void:
	_flow.first_host_role = role
	_screen = _open_round_screen()
	await wait_frames(3)


func _open_round_screen() -> Node2D:
	var screen: Node2D = (load(ROUND_SCENE) as PackedScene).instantiate()
	add_child(screen)
	return screen


func _stage() -> RoundStage:
	return _screen.call(&"get_stage")


func _pass(seconds: float) -> void:
	_time += seconds
	_flow.tick()


func _steps(count: int) -> void:
	for step: int in count:
		await get_tree().physics_frame


## Waits up to [constant PATIENCE] physics steps for [param condition].
func _wait_until(condition: Callable) -> bool:
	for step: int in PATIENCE:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


## Sets a config value for this test only.
func _tune(stat: StringName, value: float) -> void:
	if not _original_config.has(stat):
		_original_config[stat] = Services.config.get_number(stat)
	Services.config.set(stat, value)


func _nearest_sheep_to(body: SheepBody) -> SheepBody:
	var sheep_id: int = Services.swarm.find_nearest_living_sheep(body.global_position, 100000.0)
	return Services.swarm.get_sheep_body(sheep_id) as SheepBody


## A place 120 px from [param from] with nothing between the two.
func _clear_spot_next_to(arena: Arena, from: Vector2) -> Vector2:
	for step: int in 8:
		var direction: Vector2 = Vector2.DOWN.rotated(step * TAU / 8.0)
		var clear: bool = true
		for distance: float in [40.0, 80.0, 120.0]:
			clear = clear and arena.is_free(from + direction * distance, 40.0)
		if clear:
			return from + direction * 120.0
	return from + Vector2(0.0, 120.0)

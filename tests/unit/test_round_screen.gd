extends TestCase
## The round screen on one device: the match flow, the stage with the real
## flock and the real combat rules, and the results screen at the end.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Phase = MatchFlow.Phase
# gdlint: ignore=constant-name
const Screen = SceneFlowController.Screen
# gdlint: ignore=constant-name
const ResultsScreen = preload("res://ui/screens/results_screen.gd")

const ROUND_SCENE: String = "res://ui/screens/round_screen.tscn"
const RESULTS_SCENE: String = "res://ui/screens/results_screen.tscn"

var _flow: MatchFlow
var _session: GameSession
var _scene_flow: SceneFlowController
var _loaded_scenes: PackedStringArray = []
var _screen: Node2D
var _time: float = 0.0


func before_each() -> void:
	_session = Services.session
	_flow = Services.match_flow
	if _session.is_active():
		_session.leave()
	# The session changes screens through a flow that only takes notes.
	_loaded_scenes.clear()
	_scene_flow = add_child_autofree(SceneFlowController.new())
	_scene_flow.scene_changer = func(path: String) -> Error:
		_loaded_scenes.append(path)
		return OK
	_session.scene_flow = _scene_flow
	_time = 50.0
	_flow.clock = func() -> float: return _time
	# This device plays the Monster first; nobody plays the Sheepherder.
	_flow.first_host_role = GameEnums.Role.MONSTER
	_screen = _open_round_screen()
	await wait_frames(2)


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	_session.leave()
	_session.scene_flow = null
	_flow.clock = MatchFlow.system_clock
	_flow.first_host_role = GameEnums.Role.NONE
	await wait_frames(2)


# --- A round ---------------------------------------------------------------------


func test_the_screen_starts_a_match_with_everybody_in_place() -> void:
	var stage: RoundStage = _stage()

	assert_true(_session.is_active(), "an offline session")
	assert_eq(_flow.get_phase(), Phase.COUNTDOWN)
	assert_eq(_flow.get_round_number(), 1)
	assert_true(stage.is_cast_ready())
	assert_eq(Services.swarm.get_living_count(), Services.config.flock_size)
	var role: GameEnums.Role = _session.get_local_role()
	assert_ne(role, GameEnums.Role.NONE)
	assert_eq(Services.input.get_role(), role)
	assert_eq(stage.get_vision().role, role)
	var is_monster: bool = role == GameEnums.Role.MONSTER
	assert_eq(stage.get_monster().controlled_locally, is_monster)
	assert_eq(stage.get_sheepherder().controlled_locally, not is_monster)
	var own: Node2D = stage.get_monster().get_body() if is_monster else stage.get_sheepherder()
	assert_eq(stage.get_vision().viewer, own)
	assert_eq(Services.combat.get_ammo(), Services.config.firearm_ammo, "a full magazine")
	assert_true(Services.perks.is_selection_locked())


func test_the_sheepherder_starts_in_their_corner_far_from_the_flock() -> void:
	var stage: RoundStage = _stage()
	var arena: Arena = stage.get_arena()
	var herder: Sheepherder = stage.get_sheepherder()
	var monster: SheepBody = stage.get_monster().get_body()

	assert_true(arena.get_sheepherder_spawn_area().has_point(herder.global_position))
	assert_true(arena.get_flock_spawn_area().has_point(monster.global_position))
	# Nobody can act in the countdown; the flock must be out of the flashlight
	# so a Monster that stands still is not seen doing so.
	assert_gt(
		herder.global_position.distance_to(monster.global_position),
		Services.config.flashlight_cone_length
	)


func test_nobody_can_act_before_the_countdown_is_over() -> void:
	assert_false(Services.input.is_gameplay_enabled())
	assert_eq(_screen.call(&"get_banner_text"), "3")
	assert_true((_screen.call(&"get_status_text") as String).begins_with("Round 1 of 5"))
	assert_true((_screen.call(&"get_status_text") as String).ends_with("3:00"))

	_pass(Services.config.round_countdown_duration)

	assert_eq(_flow.get_phase(), Phase.ACTIVE)
	assert_true(Services.input.is_gameplay_enabled())
	assert_eq(_screen.call(&"get_banner_text"), "")

	_pass(59.5)

	assert_true((_screen.call(&"get_status_text") as String).ends_with("2:01"))


func test_shooting_the_monster_ends_the_round_for_the_sheepherder() -> void:
	var stage: RoundStage = _stage()
	_pass(Services.config.round_countdown_duration)
	var herder: Sheepherder = stage.get_sheepherder()
	var body: SheepBody = stage.get_monster().get_body()
	# A clear line of fire, wherever the round put the two.
	body.global_position = _clear_spot_next_to(stage.get_arena(), herder.global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var aim: Vector2 = herder.global_position.direction_to(body.global_position)
	assert_true(Services.combat.request_shot(herder.global_position, aim))
	_pass(0.016)

	assert_eq(_flow.get_phase(), Phase.RESOLVED)
	var result: RoundResult = _flow.get_last_result()
	assert_eq(result.outcome, GameEnums.RoundOutcome.SHEEPHERDER_WIN)
	assert_eq(result.reason, GameEnums.RoundEndReason.MONSTER_SHOT)
	assert_eq(result.get_sheepherder_points(), 10)
	assert_false(Services.input.is_gameplay_enabled())
	assert_false(Services.combat.can_shoot(), "the round is over for the combat service")
	assert_eq(
		_screen.call(&"get_banner_text"), "The Sheepherder wins the round\nThe Monster was shot."
	)


func test_an_eaten_sheep_counts_for_the_monster_at_the_timeout() -> void:
	var stage: RoundStage = _stage()
	_pass(Services.config.round_countdown_duration)
	var body: SheepBody = stage.get_monster().get_body()
	var sheep_id: int = Services.swarm.find_nearest_living_sheep(body.global_position, 100000.0)
	var sheep: SheepBody = Services.swarm.get_sheep_body(sheep_id)
	body.global_position = sheep.global_position + Vector2(40.0, 0.0)

	assert_true(Services.combat.request_eat())
	_pass(Services.config.round_duration)

	var result: RoundResult = _flow.get_last_result()
	assert_eq(result.reason, GameEnums.RoundEndReason.TIMEOUT)
	assert_eq(result.outcome, GameEnums.RoundOutcome.SHEEPHERDER_WIN)
	assert_eq(result.get_monster_points(), 1)
	assert_eq(result.get_sheepherder_points(), 9)
	assert_eq(result.eaten_sheep, 1)
	assert_eq(result.surviving_sheep, 9)


# --- From round to round ---------------------------------------------------------


func test_after_the_round_the_results_screen_follows() -> void:
	_pass(Services.config.round_countdown_duration)
	_pass(Services.config.round_duration)
	assert_eq(_flow.get_phase(), Phase.RESOLVED)

	_pass(Services.config.round_resolved_duration)
	await wait_frames(4)

	assert_eq(_flow.get_phase(), Phase.RESULTS)
	assert_eq(_loaded_scenes, PackedStringArray([RESULTS_SCENE]))
	assert_false(Services.perks.is_selection_locked())


func test_the_next_round_has_a_new_stage_and_the_other_role() -> void:
	var first_role: GameEnums.Role = _session.get_local_role()
	var first_monster: Monster = _stage().get_monster()
	await _finish_round()

	assert_true(_flow.request_next_round())
	_screen.free()
	_screen = _open_round_screen()
	await wait_frames(4)

	var stage: RoundStage = _stage()
	assert_eq(_flow.get_round_number(), 2)
	assert_eq(_flow.get_phase(), Phase.COUNTDOWN)
	assert_eq(_session.get_local_role(), GameEnums.opposite_role(first_role))
	assert_eq(Services.input.get_role(), _session.get_local_role())
	assert_true(stage.is_cast_ready())
	assert_false(is_instance_valid(first_monster), "the old round is gone")
	assert_eq(Services.swarm.get_living_count(), Services.config.flock_size)
	assert_eq(stage.get_arena().get_decals_layer().get_child_count(), 0, "clean ground")
	assert_eq(Services.combat.get_eaten_count(), 0)


func test_leaving_the_round_cleans_up() -> void:
	_pass(Services.config.round_countdown_duration)

	_screen.free()
	await wait_frames(2)

	assert_eq(Services.input.get_role(), GameEnums.Role.NONE)
	assert_eq(Services.swarm.get_living_count(), 0)
	assert_eq(_session.entities.get_entity_ids().size(), 0)
	assert_false(Services.combat.can_shoot())


func test_the_end_of_the_session_ends_the_match() -> void:
	_pass(Services.config.round_countdown_duration)

	_session.leave()

	assert_eq(_flow.get_phase(), Phase.IDLE)
	assert_true(Services.input.is_gameplay_enabled())
	assert_false(Services.perks.is_selection_locked())
	assert_eq(_session.entities.get_entity_ids().size(), 0)


# --- The results screen ----------------------------------------------------------


func test_the_results_screen_shows_the_round_and_the_standing() -> void:
	var role: GameEnums.Role = _session.get_local_role()
	await _finish_round()
	_screen.free()

	var results: Control = add_child_autofree((load(RESULTS_SCENE) as PackedScene).instantiate())
	var text: String = results.call(&"get_text")

	assert_true(text.contains("Round 1 of 5"), text)
	assert_true(text.contains("The Sheepherder wins the round"), text)
	assert_true(text.contains("Time ran out: 10 to 0 points."), text)
	var herder: String = "you" if role == GameEnums.Role.SHEEPHERDER else "opponent"
	assert_true(text.contains("Sheepherder (%s): 10 points." % herder), text)
	assert_true(text.contains("10 sheep survived (+10), 0 shot (+0)."), text)
	var wins: String = "you 1, opponent 0" if herder == "you" else "you 0, opponent 1"
	assert_true(text.contains("Round wins: %s, draws 0." % wins), text)
	assert_false(text.contains("the match"), "the match goes on")


func test_the_results_screen_starts_the_next_round() -> void:
	await _finish_round()
	_screen.free()
	var results: Control = add_child_autofree((load(RESULTS_SCENE) as PackedScene).instantiate())
	_loaded_scenes.clear()

	var next: Button = _button(results, "Next round")
	assert_true(next.visible)
	assert_false(_button(results, "Rematch").visible)
	assert_true(_button(results, "Back to lobby").visible)
	next.pressed.emit()

	assert_eq(_loaded_scenes, PackedStringArray([ROUND_SCENE]))


func test_the_results_screen_leads_back_to_the_lobby() -> void:
	await _finish_round()
	_screen.free()
	var results: Control = add_child_autofree((load(RESULTS_SCENE) as PackedScene).instantiate())
	_loaded_scenes.clear()

	_button(results, "Back to lobby").pressed.emit()
	await wait_frames(4)

	assert_eq(_loaded_scenes, PackedStringArray(["res://ui/screens/lobby_screen.tscn"]))
	assert_eq(_flow.get_phase(), Phase.IDLE)
	assert_true((results.call(&"get_text") as String).contains("No round was played"))


func test_the_results_screen_names_the_winner_of_the_match() -> void:
	var score: MatchScore = MatchScore.new(3)
	var host_wins: RoundResult = RoundResult.new()
	host_wins.outcome = GameEnums.RoundOutcome.SHEEPHERDER_WIN
	var draw: RoundResult = RoundResult.new()
	draw.outcome = GameEnums.RoundOutcome.DRAW
	score.record_round(host_wins, GameEnums.Role.SHEEPHERDER)
	score.record_round(draw, GameEnums.Role.MONSTER)
	assert_eq(ResultsScreen.describe_match(score, MatchScore.Player.HOST), "")

	score.record_round(draw, GameEnums.Role.SHEEPHERDER)

	assert_eq(
		ResultsScreen.describe_match(score, MatchScore.Player.HOST), "You win the match, 1 to 0."
	)
	assert_eq(
		ResultsScreen.describe_match(score, MatchScore.Player.GUEST), "You lose the match, 0 to 1."
	)
	assert_eq(
		ResultsScreen.describe_standing(score, MatchScore.Player.GUEST),
		"Round wins: you 0, opponent 1, draws 2.\nPoints in all rounds: you 0, opponent 0."
	)


func test_the_results_screen_names_a_drawn_match() -> void:
	var score: MatchScore = MatchScore.new(1)
	var draw: RoundResult = RoundResult.new()
	draw.outcome = GameEnums.RoundOutcome.DRAW
	score.record_round(draw, GameEnums.Role.MONSTER)

	assert_eq(
		ResultsScreen.describe_match(score, MatchScore.Player.GUEST), "The match is a draw, 0 to 0."
	)


func test_the_results_screen_explains_both_scores() -> void:
	var rules: RoundRules = RoundRules.new(RoundSettings.from_config(GameConfig.new()))
	for _i: int in 3:
		rules.report_sheep_eaten()
	rules.report_sheep_shot()
	rules.report_body_eaten()
	rules.advance(180.0)

	assert_eq(
		ResultsScreen.describe_sheepherder(rules.get_result(), "you"),
		"Sheepherder (you): 4 points. 6 sheep survived (+6), 1 shot (-2)."
	)
	assert_eq(
		ResultsScreen.describe_monster(rules.get_result(), "opponent"),
		"Monster (opponent): 3 points. 3 sheep eaten alive (+3), 1 shot sheep eaten (+0)."
	)


func test_the_timer_is_shown_in_minutes_and_seconds() -> void:
	assert_eq(_screen.call(&"format_time", 180.0), "3:00")
	assert_eq(_screen.call(&"format_time", 179.2), "3:00")
	assert_eq(_screen.call(&"format_time", 61.0), "1:01")
	assert_eq(_screen.call(&"format_time", 0.4), "0:01")
	assert_eq(_screen.call(&"format_time", 0.0), "0:00")
	assert_eq(_screen.call(&"format_time", -3.0), "0:00")


# --- Helpers ---------------------------------------------------------------------


func _open_round_screen() -> Node2D:
	var screen: Node2D = (load(ROUND_SCENE) as PackedScene).instantiate()
	add_child(screen)
	return screen


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


func _stage() -> RoundStage:
	return _screen.call(&"get_stage")


func _pass(seconds: float) -> void:
	_time += seconds
	_flow.tick()


## Lets the round run out and waits for the results.
func _finish_round() -> void:
	_pass(Services.config.round_countdown_duration)
	_pass(Services.config.round_duration)
	_pass(Services.config.round_resolved_duration)
	await wait_frames(4)


func _button(screen: Control, text: String) -> Button:
	for node: Node in screen.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null

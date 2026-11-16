extends Node
## A whole offline match of bot against bot, to see the bots play (#57).
##
## The player's character gets a bot as well: the player's input is replaced
## by a [BotInput], and a bot steers whatever character this device plays. The
## match runs faster than real time and prints every round:
##
## [codeblock lang=text]
## godot --headless --path . res://systems/bots/check/bot_match_check.tscn
## godot --headless --path . res://systems/bots/check/bot_match_check.tscn -- --speed=8 --matches=3
## [/codeblock]
##
## It exits with code 0 if every match was played to its end and the bots did
## something in it: at least one sheep eaten and one shot fired. A round in
## which the Sheepherder used up every bullet says so, and how it ended: the
## bot's Monster is unleashed then (#108).

const ROUND_SCENE: String = "res://ui/screens/round_screen.tscn"
const DEFAULT_SPEED: float = 6.0
## Real seconds a match may take before the check gives up, per round.
const GIVE_UP_PER_ROUND: float = 120.0

var _speed: float = DEFAULT_SPEED
var _matches_wanted: int = 1
var _matches_played: int = 0
var _rounds: int = 0
var _eaten: int = 0
var _shots: int = 0
var _out_of_bullets: bool = false
var _real_time: float = 0.0
## Game time, which runs [member _speed] times faster; the match's clock.
var _game_time: float = 0.0
var _local_bot: Node
var _finished: bool = false
var _problems: Array[String] = []


func _ready() -> void:
	# Survive the scene changes of the match.
	reparent.call_deferred(get_tree().root)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--speed="):
			_speed = maxf(argument.get_slice("=", 1).to_float(), 1.0)
		elif argument.begins_with("--matches="):
			_matches_wanted = maxi(argument.get_slice("=", 1).to_int(), 1)
	# Faster, but in the same steps as a real match: 1/60 s of game time each.
	Engine.time_scale = _speed
	Engine.physics_ticks_per_second = roundi(60.0 * _speed)
	Engine.max_physics_steps_per_frame = ceili(_speed) * 8
	var device_input: Node = Services.replace(InputService, BotInput.new())
	if device_input != null:
		device_input.queue_free()
	var flow: MatchFlow = Services.match_flow
	# The round timer counts game time, so a round is as long as in a real match.
	flow.clock = func() -> float: return _game_time
	flow.round_resolved.connect(_on_round_resolved)
	flow.match_finished.connect(_on_match_finished)
	Services.combat.shot_fired.connect(_on_shot_fired)
	Services.combat.ammo_depleted.connect(_on_ammo_depleted)
	_start_match.call_deferred()


func _process(delta: float) -> void:
	if _finished:
		return
	_real_time += delta / Engine.time_scale
	_game_time += delta
	var rounds_total: int = Services.match_flow.get_rounds_total()
	if _real_time > GIVE_UP_PER_ROUND * rounds_total * _matches_wanted:
		_problems.append("gave up after %d s" % _real_time)
		_finish()
		return
	_give_the_player_a_bot()
	var flow: MatchFlow = Services.match_flow
	var on_results: bool = SceneFlow.current_screen == SceneFlowController.Screen.RESULTS
	if on_results and flow.get_phase() == MatchFlow.Phase.RESULTS and not flow.is_match_over():
		flow.request_next_round()


## The character this device plays gets a bot, like the other one has.
func _give_the_player_a_bot() -> void:
	var screen: Node = get_tree().current_scene
	if screen == null or not screen.has_method(&"get_stage"):
		return
	var stage: RoundStage = screen.call(&"get_stage")
	if stage == null or not stage.is_cast_ready():
		return
	if is_instance_valid(_local_bot) and _local_bot.get_parent() == stage:
		return
	var monster: Monster = stage.get_monster()
	var herder: Sheepherder = stage.get_sheepherder()
	var bot_seed: int = Services.match_flow.get_round_seed() + 1
	if monster.is_bot:
		_local_bot = SheepherderBot.new(herder, bot_seed)
	else:
		_local_bot = MonsterBot.new(monster, herder, bot_seed)
	stage.add_child(_local_bot)


func _on_shot_fired(_from: Vector2, _to: Vector2, _result: CombatService.ShotResult) -> void:
	_shots += 1


func _on_ammo_depleted() -> void:
	_out_of_bullets = true


func _start_match() -> void:
	SceneFlow.go_to(SceneFlowController.Screen.ROUND)


func _on_round_resolved(result: RoundResult) -> void:
	_rounds += 1
	_eaten += result.eaten_sheep + result.eaten_bodies
	var bullets: String = ", out of bullets" if _out_of_bullets else ""
	_out_of_bullets = false
	print(
		(
			"BOTCHECK round %d: %s, %s | eaten %d (+%d bodies), shot %d, alive %d, %d s left%s"
			% [
				_rounds,
				result.get_headline(),
				result.get_reason_text(),
				result.eaten_sheep,
				result.eaten_bodies,
				result.shot_sheep,
				result.surviving_sheep,
				result.time_left,
				bullets,
			]
		)
	)


func _on_match_finished(outcome: MatchScore.Outcome) -> void:
	_matches_played += 1
	print("BOTCHECK match %d over: %s" % [_matches_played, MatchScore.Outcome.find_key(outcome)])
	if _matches_played >= _matches_wanted:
		_finish()
	else:
		_rematch_when_on_results.call_deferred()


func _rematch_when_on_results() -> void:
	while SceneFlow.current_screen != SceneFlowController.Screen.RESULTS:
		await get_tree().process_frame
	Services.match_flow.request_rematch()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _matches_played < _matches_wanted:
		_problems.append("%d of %d matches finished" % [_matches_played, _matches_wanted])
	if _eaten == 0:
		_problems.append("the bot Monster never ate")
	if _shots == 0:
		_problems.append("the bot Sheepherder never shot")
	print(
		(
			"BOTCHECK: %d rounds, %d eaten, %d shots, %.0f s real time at %.0fx"
			% [_rounds, _eaten, _shots, _real_time, _speed]
		)
	)
	for problem: String in _problems:
		print("BOTCHECK PROBLEM: %s" % problem)
	print("BOTCHECK: %s" % ("PASS" if _problems.is_empty() else "FAIL"))
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Services.match_flow.clock = MatchFlow.system_clock
	get_tree().quit(0 if _problems.is_empty() else 1)

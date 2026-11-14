extends Node
## Automated check of the companion perks with two real instances.
##
## Start one instance with [code]--host[/code] and one with [code]--join[/code],
## both with [code]--perk=shepherd_dog,allied_bat[/code] (see
## `tools/test_two_instances.sh companions`). Both run the Monster sandbox: the
## host is the Sheepherder with the dog, the guest the Monster with the bat.
## Each prints what it observed and exits with code 0 if everything held:
## [br]- the dog is there on both devices and stays near the Sheepherder
## [br]- the Monster eats a sheep near the dog: both devices hear the dog bark,
## and the host's dog faces the Monster
## [br]- the Monster sends the bat: both devices shrink the flashlight cone when
## it arrives, restore it after the disruption, and start the cooldown
##
## The network flags apply, so the same check runs on a bad connection.

const SANDBOX_SCENE: String = "res://entities/monster/sandbox/monster_sandbox.tscn"
const GIVE_UP_AFTER: float = 60.0
## The bat's shrink factor on the cone (GDD §4.2).
const SHRUNK: float = 1.0 - 0.42
## How long the dog has to settle next to the Sheepherder before it is measured.
const SETTLE_TIME: float = 3.0
## How close the Monster walks up to the sheep it eats.
const CLOSE_ENOUGH: float = 30.0
const PRESS_INTERVAL: float = 0.25
## Allowance for the guest's picture of the dog, which lags behind.
const SHOWN_LAG: float = 40.0

var _session: GameSession
var _input: StubInputService
var _sandbox: Node2D
var _hosting: bool = false
var _label: String = "?"
var _finished: bool = false
var _total_time: float = 0.0
var _round_time: float = 0.0
var _since_press: float = 0.0
var _dog: ShepherdDog
var _dog_far_after_settling: float = 0.0
var _barks: int = 0
var _faced_monster: bool = false
var _eaten: bool = false
var _bat_sent: bool = false
var _bat_seen: bool = false
var _shrunk_at: float = -1.0
var _restored_at: float = -1.0
var _cooldown_seen: float = 0.0


func _ready() -> void:
	Engine.max_fps = 60
	_session = Services.session
	var options: LaunchOptions = LaunchOptions.from_command_line()
	_hosting = options.mode == LaunchOptions.Mode.HOST
	_label = "host" if _hosting else "guest"
	if not options.wants_session():
		_finish(["start this scene with -- --host or -- --join"])
		return
	if not options.perks.has(PerkIds.SHEPHERD_DOG) or not options.perks.has(PerkIds.ALLIED_BAT):
		_finish(["start this scene with -- --perk=shepherd_dog,allied_bat"])
		return
	# The players are scripts: no device steers this instance.
	_input = StubInputService.new()
	_input.name = "ScriptedInput"
	var device_input: Node = Services.replace(InputService, _input)
	if device_input != null:
		device_input.queue_free()
	# Eaten is what the host decided, not what was asked for.
	Services.combat.eat_started.connect(
		func(_target: CombatService.EatTarget, _id: int, _duration: float) -> void: _eaten = true
	)
	_session.session_ended.connect(
		func(_reason: NetworkService.DisconnectReason, message: String) -> void:
			_finish_with("the session ended: " + message)
	)
	_sandbox = (load(SANDBOX_SCENE) as PackedScene).instantiate()
	add_child(_sandbox)


func _process(delta: float) -> void:
	if _finished:
		return
	_total_time += delta
	if _total_time > GIVE_UP_AFTER:
		_finish_with("gave up after %d s" % GIVE_UP_AFTER)
		return
	var monster: Monster = _sandbox.call(&"get_monster")
	var herder: Sheepherder = _sandbox.call(&"get_sheepherder")
	if monster == null or herder == null:
		return
	_round_time += delta
	_since_press += delta
	_watch_the_dog(herder)
	_watch_the_cone()
	_watch_the_bat()
	if not _hosting:
		_play_the_monster(monster, herder)
	if _restored_at >= 0.0 and _cooldown_seen > 0.0:
		_finish(_problems())


# --- What both devices see -------------------------------------------------------


func _watch_the_dog(herder: Sheepherder) -> void:
	if _dog == null:
		for companion: Node in get_tree().get_nodes_in_group(Groups.COMPANIONS):
			if companion is ShepherdDog:
				_dog = companion
				_dog.barked.connect(_on_barked)
		return
	if not is_instance_valid(_dog) or _round_time < SETTLE_TIME or _eaten:
		return
	var distance: float = _dog.global_position.distance_to(herder.global_position)
	_dog_far_after_settling = maxf(_dog_far_after_settling, distance)


func _on_barked() -> void:
	_barks += 1
	if not _hosting:
		return
	var monster: Monster = _sandbox.call(&"get_monster")
	var toward: float = (monster.get_body().global_position - _dog.global_position).angle()
	_faced_monster = absf(angle_difference(_dog.rotation, toward)) < 0.2


func _watch_the_cone() -> void:
	var angle: float = Services.perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG)
	var length: float = Services.perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH)
	var config: GameConfig = Services.config
	var shrunk: bool = (
		is_equal_approx(angle, config.flashlight_cone_angle_deg * SHRUNK)
		and is_equal_approx(length, config.flashlight_cone_length * SHRUNK)
	)
	if shrunk and _shrunk_at < 0.0:
		_shrunk_at = _round_time
	elif not shrunk and _shrunk_at >= 0.0 and _restored_at < 0.0:
		_restored_at = _round_time
	if _restored_at >= 0.0:
		_cooldown_seen = Services.perks.get_perk_cooldown_remaining(GameEnums.Role.MONSTER)


func _watch_the_bat() -> void:
	for companion: Node in get_tree().get_nodes_in_group(Groups.COMPANIONS):
		if companion is AlliedBat:
			_bat_seen = true


# --- The Monster's player (guest) ------------------------------------------------


## Eats the sheep nearest the Sheepherder, so the dog is close by; then sends
## the bat.
func _play_the_monster(monster: Monster, herder: Sheepherder) -> void:
	var combat: CombatService = Services.combat
	if _round_time < SETTLE_TIME or combat.is_eating():
		_input.move_vector = Vector2.ZERO
		return
	if _eaten:
		_input.move_vector = Vector2.ZERO
		if not _bat_sent and combat.get_eat_cooldown_remaining() <= 0.0:
			_bat_sent = _press(InputActions.PERK)
		return
	var sheep_id: int = Services.swarm.find_nearest_living_sheep(herder.global_position, 100000.0)
	if sheep_id < 0:
		return
	var body: SheepBody = monster.get_body()
	var target: Vector2 = Services.swarm.get_sheep_body(sheep_id).global_position
	var away: float = body.global_position.distance_to(target)
	var direction: Vector2 = body.global_position.direction_to(target)
	_input.move_vector = direction if away > CLOSE_ENOUGH else Vector2.ZERO
	if combat.can_eat():
		_press(InputActions.EAT)


func _press(action: StringName) -> bool:
	if _since_press < PRESS_INTERVAL:
		return false
	_since_press = 0.0
	var pressed: bool = _input.simulate_press(action)
	_input.simulate_release(action)
	return pressed


# --- Result ----------------------------------------------------------------------


func _problems() -> Array[String]:
	var problems: Array[String] = []
	var config: GameConfig = Services.config
	var near_enough: float = (
		config.dog_follow_distance_max + ShepherdDog.ARRIVE_DISTANCE + SHOWN_LAG
	)
	if _dog == null:
		problems.append("no dog")
	elif _dog_far_after_settling > near_enough:
		problems.append("the dog strayed %d px from the Sheepherder" % _dog_far_after_settling)
	if _barks == 0:
		problems.append("the dog never barked")
	if _hosting and not _faced_monster:
		problems.append("the dog did not face the Monster when it barked")
	if not _bat_seen:
		problems.append("no bat")
	if _shrunk_at < 0.0:
		problems.append("the cone never shrank")
	elif _restored_at < 0.0:
		problems.append("the cone never recovered")
	elif absf(_restored_at - _shrunk_at - config.bat_disruption_duration) > 0.5:
		problems.append("the cone was shrunk for %.1f s" % (_restored_at - _shrunk_at))
	if _restored_at >= 0.0 and _cooldown_seen < config.bat_cooldown - 1.0:
		problems.append("the bat's cooldown was %.1f s after it left" % _cooldown_seen)
	return problems


## Finishes with what was seen so far and [param last_problem].
func _finish_with(last_problem: String) -> void:
	var problems: Array[String] = _problems()
	problems.append(last_problem)
	_finish(problems)


func _finish(problems: Array[String]) -> void:
	if _finished:
		return
	_finished = true
	print(
		(
			(
				"SELFCHECK %s: role %s, dog seen %s and at most %d px from the Sheepherder, "
				% [
					_label,
					GameEnums.role_name(_session.get_local_role()),
					_dog != null,
					_dog_far_after_settling,
				]
			)
			+ (
				"%d barks, bat seen %s, cone shrunk for %.1f s, cooldown %.1f s, after %.1f s"
				% [
					_barks,
					_bat_seen,
					_restored_at - _shrunk_at if _restored_at >= 0.0 else -1.0,
					_cooldown_seen,
					_total_time,
				]
			)
		)
	)
	for problem: String in problems:
		print("SELFCHECK %s PROBLEM: %s" % [_label, problem])
	print("SELFCHECK %s: %s" % [_label, "PASS" if problems.is_empty() else "FAIL"])
	# Give the other instance time to see the end as well.
	await get_tree().create_timer(1.5).timeout
	get_tree().quit(0 if problems.is_empty() else 1)

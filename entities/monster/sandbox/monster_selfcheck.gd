extends Node
## Automated check of the Monster with two real instances.
##
## Start one instance with [code]--host[/code] and one with [code]--join[/code]
## (see `tools/test_two_instances.sh monster`). Both run the Monster sandbox
## with scripted players: the host is the Sheepherder, the guest the Monster.
## Each prints what it observed and exits with code 0 if everything held:
## [br]- the Monster walks, sprints, grazes and bleats; the Sheepherder's device
## shows all of it, without jumps
## [br]- the Monster eats sheep of the flock; both devices count the same, see
## the blood and the same flock
## [br]- the kill is unlocked and the spider appears, on both devices
## [br]- the Sheepherder's bullet does nothing to the spider
## [br]- the spider kills the Sheepherder
##
## To keep the check short, both instances play with a short attack cooldown
## and low thresholds. The network flags [code]--net-latency[/code],
## [code]--net-jitter[/code] and [code]--net-loss[/code] apply, so the same
## check runs on a bad connection.

const SANDBOX_SCENE: String = "res://entities/monster/sandbox/monster_sandbox.tscn"
const GIVE_UP_AFTER: float = 90.0
const FINISH_AFTER_THE_KILL: float = 1.0
const FAR: float = 100000.0

# The Monster's script, in seconds since the round began on its device.
const WALK_FROM: float = 0.5
const SPRINT_FROM: float = 2.0
const REST_FROM: float = 3.0
const GRAZE_FROM: float = 3.2
const GRAZE_UNTIL: float = 4.2
const BLEAT_AT: float = 4.4
const HUNT_FROM: float = 4.8
## How close the Monster walks up to what it wants to eat.
const CLOSE_ENOUGH: float = 30.0
## Where the spider waits for the Sheepherder's bullet.
const WAIT_DISTANCE: float = 130.0
const WAIT_FOR_THE_SHOT: float = 10.0
const PRESS_INTERVAL: float = 0.25
const STUCK_CHECK_INTERVAL: float = 1.0
const STUCK_DISTANCE: float = 10.0
const SIDESTEP_TIME: float = 0.6
const SIDESTEP_ANGLE: float = 1.2

# What the Sheepherder's device measures on the Monster it is shown.
const SETTLE_TIME: float = 0.5
const SPEED_WINDOW: float = 0.3
const SHOT_RANGE: float = 200.0
const STILL_FOR: float = 0.4

# The shortened round.
const EAT_COOLDOWN: float = 0.5
const KILL_THRESHOLD: int = 2
const SPIDER_THRESHOLD: int = 4
const RELOAD_TIME: float = 0.5

var _session: GameSession
var _input: StubInputService
var _sandbox: Node2D
var _label: String = "?"
var _hosting: bool = false
var _finished: bool = false
var _total_time: float = 0.0
var _round_time: float = 0.0
var _body: SheepBody

# Seen on both devices.
var _states_seen: Dictionary[int, bool] = {}
var _bleats: int = 0
var _kill_unlocked: bool = false
var _spider_hits: int = 0
var _shots: int = 0
var _herder_killed_at: float = -1.0

# The Monster's own device.
var _walk_top_speed: float = 0.0
var _sprint_top_speed: float = 0.0
var _lowest_stamina: float = INF
var _grazing: bool = false
var _bleated: bool = false
var _since_press: float = 0.0
var _stuck_timer: float = 0.0
var _stuck_reference: Vector2
var _sidestep_left: float = 0.0
var _sidestep_sign: float = 1.0
var _waited_for_shot: float = 0.0
var _shot_was_awaited: bool = false

# The Sheepherder's device.
var _copy_previous: Vector2
var _copy_travelled: float = 0.0
var _copy_jumps: int = 0
var _copy_top_speed: float = 0.0
## Where the Monster was shown during the last [constant SPEED_WINDOW]
## seconds: [code][time, position][/code] per frame, oldest first.
var _trail: Array[Array] = []
var _copy_still_for: float = 0.0


func _ready() -> void:
	Engine.max_fps = 60
	_session = Services.session
	var options: LaunchOptions = LaunchOptions.from_command_line()
	_hosting = options.mode == LaunchOptions.Mode.HOST
	_label = "host" if _hosting else "guest"
	if not options.wants_session():
		_finish_with([], "start this scene with -- --host or -- --join")
		return

	var config: GameConfig = Services.config
	config.eat_cooldown = EAT_COOLDOWN
	config.herder_kill_threshold = KILL_THRESHOLD
	config.spider_evolution_threshold = SPIDER_THRESHOLD
	config.firearm_reload_time = RELOAD_TIME

	# The players are scripts: no device steers this instance.
	_input = StubInputService.new()
	_input.name = "ScriptedInput"
	var device_input: Node = Services.replace(InputService, _input)
	if device_input != null:
		device_input.queue_free()

	var combat: CombatService = Services.combat
	combat.shot_fired.connect(_on_shot_fired)
	combat.sheepherder_kill_unlocked.connect(func() -> void: _kill_unlocked = true)
	combat.sheepherder_killed.connect(_on_sheepherder_killed)
	_session.session_ended.connect(_on_session_ended)

	# The sandbox starts the session the command line asks for.
	_sandbox = (load(SANDBOX_SCENE) as PackedScene).instantiate()
	add_child(_sandbox)


func _process(delta: float) -> void:
	if _finished:
		return
	_total_time += delta
	if _total_time > GIVE_UP_AFTER:
		_finish_with(_problems(), "gave up after %d s" % GIVE_UP_AFTER)
		return
	var monster: Monster = _sandbox.call(&"get_monster")
	var herder: Sheepherder = _sandbox.call(&"get_sheepherder")
	if monster == null or herder == null:
		return
	if _body != monster.get_body():
		_body = monster.get_body()
		_body.bleated.connect(func() -> void: _bleats += 1)
		_copy_previous = _shown_position()
		_trail.clear()
	_round_time += delta
	_states_seen[_body.get_state()] = true
	if _hosting:
		_watch_the_monster(delta)
		_play_the_sheepherder(herder, delta)
	else:
		_play_the_monster(monster, herder, delta)
	if _herder_killed_at >= 0.0 and _round_time - _herder_killed_at >= FINISH_AFTER_THE_KILL:
		_finish(_problems())


# --- The Monster's player (guest) ------------------------------------------------


func _play_the_monster(monster: Monster, herder: Sheepherder, delta: float) -> void:
	_since_press += delta
	if _round_time < HUNT_FROM:
		_mimic_a_sheep(monster)
	elif Services.combat.get_monster_form() != GameEnums.MonsterForm.SPIDER:
		_hunt(delta)
	elif herder.is_alive():
		_go_for_the_sheepherder(herder, delta)
	else:
		_input.move_vector = Vector2.ZERO


## Walks, sprints, grazes and bleats, as a player does to pass as a sheep.
func _mimic_a_sheep(monster: Monster) -> void:
	var speed: float = _body.velocity.length()
	if _round_time < WALK_FROM:
		return
	if _round_time < SPRINT_FROM:
		_input.move_vector = Vector2.RIGHT
		_walk_top_speed = maxf(_walk_top_speed, speed)
	elif _round_time < REST_FROM:
		if not _input.is_action_held(InputActions.SPRINT):
			_input.simulate_press(InputActions.SPRINT)
			return
		_input.move_vector = Vector2.LEFT
		_sprint_top_speed = maxf(_sprint_top_speed, speed)
		_lowest_stamina = minf(_lowest_stamina, monster.get_stamina())
	elif _round_time < GRAZE_FROM:
		_input.simulate_release(InputActions.SPRINT)
		_input.move_vector = Vector2.ZERO
	elif _round_time < GRAZE_UNTIL:
		if not _grazing:
			_grazing = true
			_input.simulate_press(InputActions.GRAZE)
	elif _grazing:
		_grazing = false
		_input.simulate_release(InputActions.GRAZE)
	elif _round_time >= BLEAT_AT and not _bleated:
		_bleated = true
		_input.simulate_press(InputActions.BLEAT)
		_input.simulate_release(InputActions.BLEAT)


## Walks to the nearest sheep and eats it, until the spider appears.
func _hunt(delta: float) -> void:
	var combat: CombatService = Services.combat
	if combat.is_eating():
		_input.move_vector = Vector2.ZERO
		return
	var from: Vector2 = _body.global_position
	var sheep_id: int = Services.swarm.find_nearest_edible_sheep(from, FAR)
	if sheep_id < 0:
		_input.move_vector = Vector2.ZERO
		return
	_walk_towards(Services.swarm.get_sheep_body(sheep_id).global_position, CLOSE_ENOUGH, delta)
	if combat.can_eat():
		_press_eat()


## The spider walks up to the Sheepherder, lets them shoot, and kills them.
func _go_for_the_sheepherder(herder: Sheepherder, delta: float) -> void:
	var combat: CombatService = Services.combat
	var shot_at: bool = _spider_hits > 0 or combat.is_ammo_depleted()
	if not shot_at and _waited_for_shot < WAIT_FOR_THE_SHOT:
		_walk_towards(herder.global_position, WAIT_DISTANCE, delta)
		if _body.global_position.distance_to(herder.global_position) <= WAIT_DISTANCE:
			_waited_for_shot += delta
		return
	_shot_was_awaited = true
	_walk_towards(herder.global_position, CLOSE_ENOUGH, delta)
	if combat.can_eat():
		_press_eat()


## Steers towards [param target] until it is [param stop_at] away. Something in
## the way is walked around.
func _walk_towards(target: Vector2, stop_at: float, delta: float) -> void:
	var from: Vector2 = _body.global_position
	if from.distance_to(target) <= stop_at:
		_input.move_vector = Vector2.ZERO
		_stuck_timer = 0.0
		_stuck_reference = from
		return
	var direction: Vector2 = from.direction_to(target)
	_stuck_timer += delta
	if _stuck_timer >= STUCK_CHECK_INTERVAL:
		if from.distance_to(_stuck_reference) < STUCK_DISTANCE:
			_sidestep_left = SIDESTEP_TIME
			_sidestep_sign = -_sidestep_sign
		_stuck_timer = 0.0
		_stuck_reference = from
	if _sidestep_left > 0.0:
		_sidestep_left -= delta
		direction = direction.rotated(SIDESTEP_ANGLE * _sidestep_sign)
	_input.move_vector = direction


func _press_eat() -> void:
	if _since_press < PRESS_INTERVAL:
		return
	_since_press = 0.0
	_input.simulate_press(InputActions.EAT)
	_input.simulate_release(InputActions.EAT)


# --- The Sheepherder's player (host) ---------------------------------------------


## Stands, keeps the Monster in the light, and shoots at the spider once it
## has come close and stands still.
func _play_the_sheepherder(herder: Sheepherder, delta: float) -> void:
	_since_press += delta
	if not herder.is_alive():
		return
	var from: Vector2 = herder.global_position
	var target: Vector2 = _body.global_position
	_input.aim_direction = from.direction_to(target)
	var combat: CombatService = Services.combat
	if (
		combat.get_monster_form() == GameEnums.MonsterForm.SPIDER
		and _spider_hits == 0
		and combat.can_shoot()
		and from.distance_to(target) <= SHOT_RANGE
		and _copy_still_for >= STILL_FOR
		and _since_press >= PRESS_INTERVAL
	):
		_since_press = 0.0
		_input.simulate_press(InputActions.SHOOT)
		_input.simulate_release(InputActions.SHOOT)


## Measures how the Monster of the other device is shown here.
func _watch_the_monster(delta: float) -> void:
	var shown: Vector2 = _shown_position()
	var step: float = shown.distance_to(_copy_previous)
	_copy_previous = shown
	_copy_still_for = _copy_still_for + delta if step < 0.5 else 0.0
	if _round_time < SETTLE_TIME or delta <= 0.0:
		return
	_copy_travelled += step
	# Nothing the Monster does covers three times the spider's speed in one
	# frame unless the picture stuttered.
	var fastest: float = Services.config.get_number(StatIds.SPIDER_MOVE_SPEED)
	if step > 12.0 and step / delta > fastest * 3.0:
		_copy_jumps += 1
	# The speed over the last moments, not over one frame: a late snapshot
	# moves the picture a little faster or slower for a frame or two.
	if Services.combat.get_monster_form() != GameEnums.MonsterForm.SHEEP:
		_trail.clear()
		return
	_trail.append([_round_time, shown])
	while _round_time - (_trail[0][0] as float) > SPEED_WINDOW:
		_trail.pop_front()
	var span: float = _round_time - (_trail[0][0] as float)
	if span >= SPEED_WINDOW * 0.9:
		_copy_top_speed = maxf(_copy_top_speed, shown.distance_to(_trail[0][1] as Vector2) / span)


## Where the Monster's sheep is drawn on this device.
func _shown_position() -> Vector2:
	return (_body.get_node(^"Facing") as Node2D).global_position


# --- What happened ---------------------------------------------------------------


func _on_shot_fired(_origin: Vector2, _end: Vector2, result: CombatService.ShotResult) -> void:
	_shots += 1
	if result == CombatService.ShotResult.HIT_SPIDER:
		_spider_hits += 1


func _on_sheepherder_killed(_position: Vector2) -> void:
	_herder_killed_at = _round_time


func _on_session_ended(_reason: NetworkService.DisconnectReason, message: String) -> void:
	_finish_with(_problems(), "the session ended before the check did: '%s'" % message)


## Everything that did not hold so far.
func _problems() -> Array[String]:
	var problems: Array[String] = []
	var monster: Monster = _sandbox.call(&"get_monster")
	var herder: Sheepherder = _sandbox.call(&"get_sheepherder")
	if monster == null or herder == null:
		problems.append("the round never began: no Monster or no Sheepherder")
		return problems
	var combat: CombatService = Services.combat
	var config: GameConfig = Services.config
	var role: GameEnums.Role = GameEnums.Role.SHEEPHERDER if _hosting else GameEnums.Role.MONSTER
	if _session.get_local_role() != role or Services.input.get_role() != role:
		problems.append("plays the %s" % GameEnums.role_name(_session.get_local_role()))
	if monster.controlled_locally == _hosting or herder.controlled_locally != _hosting:
		problems.append("the wrong device steers the Monster or the Sheepherder")

	for state: SheepBody.State in [
		SheepBody.State.WALK, SheepBody.State.GRAZE, SheepBody.State.DEVOUR
	]:
		if not _states_seen.has(state):
			problems.append("never saw the Monster %s" % SheepBody.State.find_key(state))
	if _bleats < 1:
		problems.append("never heard the Monster bleat")

	if combat.get_eaten_count() != SPIDER_THRESHOLD:
		problems.append("%d sheep eaten, not %d" % [combat.get_eaten_count(), SPIDER_THRESHOLD])
	if not _kill_unlocked:
		problems.append("the kill on the Sheepherder was never unlocked")
	if combat.get_monster_form() != GameEnums.MonsterForm.SPIDER:
		problems.append("the Monster is no spider")
	elif _body.get_node_or_null(^"Facing/Spider") == null:
		problems.append("the spider is not drawn")
	if combat.is_monster_killable():
		problems.append("the Monster can still be killed")
	if _spider_hits < 1:
		problems.append("no bullet hit the spider (%d shots)" % _shots)
	if _herder_killed_at < 0.0 or herder.is_alive():
		problems.append("the Sheepherder was not killed")

	var dead: int = combat.get_eaten_alive_count() + combat.get_shot_sheep_count()
	if Services.swarm.get_living_count() != config.flock_size - dead:
		problems.append(
			(
				"%d sheep alive, expected %d"
				% [Services.swarm.get_living_count(), config.flock_size - dead]
			)
		)
	if _blood_count() < dead:
		problems.append("%d blood decals for %d killed sheep" % [_blood_count(), dead])

	if _hosting:
		problems.append_array(_problems_with_the_shown_monster())
	else:
		problems.append_array(_problems_with_the_own_monster())
	return problems


func _problems_with_the_own_monster() -> Array[String]:
	var problems: Array[String] = []
	var config: GameConfig = Services.config
	var walk: float = config.get_number(StatIds.MONSTER_MOVE_SPEED)
	var sprint: float = config.get_number(StatIds.MONSTER_SPRINT_SPEED)
	if _walk_top_speed < walk * 0.95 or _walk_top_speed > walk * 1.02:
		problems.append("walked at %d px/s, not %d" % [_walk_top_speed, walk])
	if _sprint_top_speed < sprint * 0.95 or _sprint_top_speed > sprint * 1.02:
		problems.append("sprinted at %d px/s, not %d" % [_sprint_top_speed, sprint])
	if _lowest_stamina >= config.get_number(StatIds.MONSTER_SPRINT_STAMINA):
		problems.append("sprinting cost no stamina")
	if not _shot_was_awaited:
		problems.append("the spider never got to the Sheepherder")
	return problems


func _problems_with_the_shown_monster() -> Array[String]:
	var problems: Array[String] = []
	var config: GameConfig = Services.config
	var walk: float = config.get_number(StatIds.MONSTER_MOVE_SPEED)
	var sprint: float = config.get_number(StatIds.MONSTER_SPRINT_SPEED)
	if _copy_jumps > 0:
		problems.append("the Monster jumped %d times" % _copy_jumps)
	if _copy_travelled < walk:
		problems.append("the Monster travelled only %d px" % _copy_travelled)
	# The sprint lasts a second: a window of it shows well above walking speed.
	if _copy_top_speed < lerpf(walk, sprint, 0.5) or _copy_top_speed > sprint * 1.15:
		problems.append("the Monster was shown at up to %d px/s as a sheep" % _copy_top_speed)
	var vision: VisionTarget = _body.get_node_or_null(^"VisionTarget") as VisionTarget
	if vision == null or not is_equal_approx(vision.radius, SpiderVisual.RADIUS):
		problems.append("the spider is lit like a sheep")
	return problems


func _blood_count() -> int:
	var arena: Arena = _sandbox.call(&"get_arena")
	return arena.get_decals_layer().get_child_count()


func _finish_with(problems: Array[String], last_problem: String) -> void:
	if _finished:
		return
	problems.append(last_problem)
	_finish(problems)


func _finish(problems: Array[String]) -> void:
	if _finished:
		return
	_finished = true
	var combat: CombatService = Services.combat
	var states: PackedStringArray = []
	for state: int in _states_seen:
		states.append(SheepBody.State.find_key(state))
	print(
		(
			(
				"SELFCHECK %s: role %s, Monster seen %s, %d bleats, %d eaten, form %s, "
				% [
					_label,
					GameEnums.role_name(_session.get_local_role()),
					", ".join(states),
					_bleats,
					combat.get_eaten_count(),
					GameEnums.MonsterForm.find_key(combat.get_monster_form()),
				]
			)
			+ (
				"%d shots, %d on the spider, Sheepherder killed: %s, %d sheep alive, after %.1f s"
				% [
					_shots,
					_spider_hits,
					_herder_killed_at >= 0.0,
					Services.swarm.get_living_count(),
					_total_time,
				]
			)
		)
	)
	if _hosting:
		print(
			(
				"SELFCHECK host: the Monster travelled %d px with %d jumps, up to %d px/s as a sheep"
				% [_copy_travelled, _copy_jumps, _copy_top_speed]
			)
		)
	else:
		print(
			(
				"SELFCHECK guest: walked at %d px/s, sprinted at %d px/s, stamina down to %.1f s"
				% [_walk_top_speed, _sprint_top_speed, _lowest_stamina]
			)
		)
	for problem: String in problems:
		print("SELFCHECK %s PROBLEM: %s" % [_label, problem])
	print("SELFCHECK %s: %s" % [_label, "PASS" if problems.is_empty() else "FAIL"])
	# Give the other instance time to see the end as well.
	await get_tree().create_timer(1.5).timeout
	get_tree().quit(0 if problems.is_empty() else 1)

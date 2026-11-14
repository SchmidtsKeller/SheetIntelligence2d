class_name SheepherderBot
extends Node
## Plays the Sheepherder in an offline match (see [RoundStage]).
##
## It knows only what a player in the Sheepherder's place could know: where
## the flock started, what its flashlight lights, and the sounds it hears
## (see [BotSenses]). It never asks which sheep is the Monster. Instead it
## keeps a suspicion for every sheep it watches:
## [br]- a sheep it sees eating is as good as caught;
## [br]- a sheep it sees run faster than the flock grows suspicious;
## [br]- the sheep it finds next to where it heard eating grows suspicious.
## [br]It shoots the most suspicious one it can see once it is sure enough,
## after a reaction time and with a small error. Meanwhile it keeps near the
## flock, sweeps its light over it, rings the bell now and then, goes to look
## where it heard eating, and runs from the spider.
##
## It only moves the stick, aims and presses buttons on the Sheepherder's
## [BotInput], and only while the player may act too.

enum Mode {
	## Keeps near the flock and sweeps its light over it.
	WATCH,
	## Goes to look where it heard eating.
	INVESTIGATE,
	## Aims at a suspect and shoots.
	AIM,
	## Runs from the spider.
	FLEE,
}

## Suspicion of a sheep that was seen eating.
const CAUGHT: float = 2.0
## A sheep runs faster than the flock above this share of the walking speed.
const RUNNING_SHARE: float = 1.15
## How fast the light turns toward where the bot wants it, in radians per
## second: it sweeps, it does not jump.
const AIM_TURN_RATE: float = 3.0
## How far off it hears where a sound came from, as a share of the distance:
## an ear tells the direction and roughly how far, not the exact spot.
const HEARING_ERROR: float = 0.3
## The least it is off, however close the sound.
const HEARING_ERROR_MIN: float = 40.0
## How long it remembers where it heard eating.
const NOISE_MEMORY: float = 8.0
## How close it walks up to where it heard eating.
const INVESTIGATE_DISTANCE: float = 140.0
## Within this distance a suspect that may kill it is shot sooner.
const DANGER_DISTANCE: float = 170.0
## Share of the shooting suspicion that is enough when in danger.
const DANGER_SHARE: float = 0.5

var _herder: Sheepherder
var _input: BotInput
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _steering: BotSteering = BotSteering.new()
var _mode: Mode = Mode.WATCH
## Per sheep-like body, by instance id: where it was last seen, and how
## suspicious it is.
var _last_seen: Dictionary[int, Vector2] = {}
var _suspicion: Dictionary[int, float] = {}
## Eating it heard: [code][position, seconds left, already blamed][/code].
var _noises: Array[Array] = []
var _spider_at: Vector2 = Vector2.INF
var _suspect: SheepBody
var _aimed_for: float = 0.0
var _aim: Vector2 = Vector2.UP
var _look_at: Vector2 = Vector2.INF
var _sweep_left: float = 0.0
var _bell_left: float = 0.0


## A bot for [param herder], whose input must be a [BotInput].
## [param bot_seed] makes its decisions repeatable.
func _init(herder: Sheepherder, bot_seed: int) -> void:
	name = "SheepherderBot"
	_herder = herder
	_input = herder.input as BotInput
	_random.seed = bot_seed


func _ready() -> void:
	# Before the Sheepherder reads the input in the same step.
	process_physics_priority = -2
	Services.audio.event_played.connect(_on_sound)
	Services.combat.monster_form_changed.connect(_on_monster_form_changed)
	_bell_left = Services.perks.get_stat(StatIds.BOT_HERDER_BELL_INTERVAL)
	# It watched the flock arrive.
	for body: SheepBody in BotSenses.living_sheep_like(get_tree()):
		_last_seen[body.get_instance_id()] = body.global_position
	_aim = _herder.get_aim_direction()


func _exit_tree() -> void:
	Services.audio.event_played.disconnect(_on_sound)
	Services.combat.monster_form_changed.disconnect(_on_monster_form_changed)


func get_mode() -> Mode:
	return _mode


## How suspicious [param body] is to the bot; 0 for a body it never suspected.
func get_suspicion(body: Node) -> float:
	return _suspicion.get(body.get_instance_id(), 0.0)


## The sheep it is aiming at; [code]null[/code] while it is not.
func get_suspect() -> SheepBody:
	return _suspect if _mode == Mode.AIM and is_instance_valid(_suspect) else null


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_herder) or _input == null:
		return
	_input.set_gameplay_enabled(Services.input.is_gameplay_enabled())
	if not _input.is_gameplay_enabled() or not _herder.is_alive():
		_input.release_all()
		return
	var seen: Array[SheepBody] = _perceive(delta)
	_forget(delta)
	_choose_mode(seen)
	match _mode:
		Mode.WATCH:
			_watch(delta)
		Mode.INVESTIGATE:
			_investigate(delta)
		Mode.AIM:
			_aim_and_shoot(delta)
		Mode.FLEE:
			_flee(delta)
	_turn_light(delta)
	_ring_bell(delta)


# --- Seeing and hearing ----------------------------------------------------------


## Looks at every sheep in its light. Returns the ones it sees.
func _perceive(delta: float) -> Array[SheepBody]:
	var perks: PerkService = Services.perks
	var running: float = perks.get_stat(StatIds.MONSTER_MOVE_SPEED) * RUNNING_SHARE
	var seen: Array[SheepBody] = []
	var living: Dictionary[int, bool] = {}
	for body: SheepBody in BotSenses.living_sheep_like(get_tree()):
		var id: int = body.get_instance_id()
		living[id] = true
		if not BotSenses.herder_sees(_herder, body):
			continue
		seen.append(body)
		_last_seen[id] = body.global_position
		if body.is_devouring():
			_suspicion[id] = maxf(_suspicion.get(id, 0.0), CAUGHT)
		elif body.get_speed() > running:
			_raise(id, perks.get_stat(StatIds.BOT_HERDER_SPRINT_SUSPICION) * delta)
		if body.get_node_or_null(^"Facing/Spider") != null:
			_spider_at = body.global_position
	for id: int in _last_seen.keys():
		if not living.has(id):
			_last_seen.erase(id)
			_suspicion.erase(id)
	_blame_noises(seen)
	return seen


## The sheep seen nearest to eating it heard is suspected, once per meal.
func _blame_noises(seen: Array[SheepBody]) -> void:
	var perks: PerkService = Services.perks
	var radius: float = perks.get_stat(StatIds.BOT_HERDER_BLOOD_RADIUS)
	for noise: Array in _noises:
		if noise[2]:
			continue
		var nearest: SheepBody = null
		var nearest_distance: float = radius
		for body: SheepBody in seen:
			var distance: float = body.global_position.distance_to(noise[0])
			if distance <= nearest_distance:
				nearest = body
				nearest_distance = distance
		if nearest != null:
			noise[2] = true
			_raise(nearest.get_instance_id(), perks.get_stat(StatIds.BOT_HERDER_BLOOD_SUSPICION))


func _raise(id: int, amount: float) -> void:
	_suspicion[id] = _suspicion.get(id, 0.0) + amount


func _forget(delta: float) -> void:
	var decay: float = Services.perks.get_stat(StatIds.BOT_HERDER_SUSPICION_DECAY) * delta
	for id: int in _suspicion.keys():
		_suspicion[id] = maxf(_suspicion[id] - decay, 0.0)
	var heard: Array[Array] = []
	for noise: Array in _noises:
		noise[1] -= delta
		if noise[1] > 0.0:
			heard.append(noise)
	_noises = heard


func _on_sound(event_id: StringName, world_position: Vector2) -> void:
	if not is_instance_valid(_herder):
		return
	var hearing: float = Services.audio.get_hearing_range(event_id)
	if _herder.global_position.distance_to(world_position) > hearing:
		return
	match event_id:
		AudioEvents.EAT:
			_noises.append([_heard_at(world_position), NOISE_MEMORY, false])
		AudioEvents.SPIDER_SCREECH:
			_spider_at = world_position


## Where it last heard eating, once it had the time to react to it;
## [constant Vector2.INF] if it heard none it still remembers.
func _latest_noise() -> Vector2:
	var reaction: float = Services.perks.get_stat(StatIds.BOT_HERDER_REACTION_TIME)
	for index: int in range(_noises.size() - 1, -1, -1):
		var noise: Array = _noises[index]
		if NOISE_MEMORY - (noise[1] as float) >= reaction:
			return noise[0]
	return Vector2.INF


## Where it thinks a sound at [param source] came from.
func _heard_at(source: Vector2) -> Vector2:
	var distance: float = _herder.global_position.distance_to(source)
	var error: float = maxf(distance * HEARING_ERROR, HEARING_ERROR_MIN)
	return source + Vector2.from_angle(_random.randf() * TAU) * _random.randf() * error


func _on_monster_form_changed(form: GameEnums.MonsterForm) -> void:
	if form != GameEnums.MonsterForm.SPIDER:
		_spider_at = Vector2.INF


# --- Deciding --------------------------------------------------------------------


func _choose_mode(seen: Array[SheepBody]) -> void:
	if _spider_at != Vector2.INF:
		_switch_to(Mode.FLEE)
		return
	var suspect: SheepBody = _find_suspect(seen)
	if suspect != null and Services.combat.can_shoot():
		if suspect != _suspect:
			_aimed_for = 0.0
		_suspect = suspect
		_switch_to(Mode.AIM)
		return
	_suspect = null
	if _latest_noise() != Vector2.INF:
		_switch_to(Mode.INVESTIGATE)
		return
	_switch_to(Mode.WATCH)


## The most suspicious sheep in sight that is suspicious enough to shoot.
func _find_suspect(seen: Array[SheepBody]) -> SheepBody:
	var perks: PerkService = Services.perks
	var enough: float = perks.get_stat(StatIds.BOT_HERDER_SHOOT_SUSPICION)
	var in_danger: bool = Services.combat.can_kill_sheepherder()
	var best: SheepBody = null
	var best_suspicion: float = 0.0
	for body: SheepBody in seen:
		var suspicion: float = get_suspicion(body)
		var needed: float = enough
		var near: float = body.global_position.distance_to(_herder.global_position)
		if in_danger and near <= DANGER_DISTANCE:
			needed = enough * DANGER_SHARE
		if suspicion >= needed and suspicion > best_suspicion:
			best = body
			best_suspicion = suspicion
	return best


func _switch_to(mode: Mode) -> void:
	if mode == _mode:
		return
	_mode = mode
	_aimed_for = 0.0
	_sweep_left = 0.0
	_steering.reset(_herder.global_position)


# --- Acting ----------------------------------------------------------------------


## Near the flock, but not in it, with the light going from sheep to sheep.
func _watch(delta: float) -> void:
	var here: Vector2 = _herder.global_position
	var flock: Vector2 = _flock_center()
	var keep: float = Services.perks.get_stat(StatIds.BOT_HERDER_FLOCK_DISTANCE)
	var distance: float = here.distance_to(flock)
	if distance > keep * 1.25:
		_input.move_vector = _steering.toward(here, flock, delta, keep)
	elif distance < keep * 0.6:
		_input.move_vector = _steering.away_from(here, flock, delta)
	else:
		_input.move_vector = Vector2.ZERO
	_sweep_left -= delta
	if _sweep_left <= 0.0 or _look_at == Vector2.INF:
		_sweep_left = Services.perks.get_stat(StatIds.BOT_HERDER_SWEEP_INTERVAL)
		_look_at = _next_sheep_to_look_at(flock)


func _investigate(delta: float) -> void:
	var noise: Vector2 = _latest_noise()
	_look_at = noise
	_input.move_vector = _steering.toward(
		_herder.global_position, noise, delta, INVESTIGATE_DISTANCE
	)


func _aim_and_shoot(delta: float) -> void:
	_input.move_vector = Vector2.ZERO
	var target: Vector2 = _shown_position(_suspect)
	_look_at = target
	_aimed_for += delta
	var reaction: float = Services.perks.get_stat(StatIds.BOT_HERDER_REACTION_TIME)
	if _aimed_for < reaction or not Services.combat.can_shoot():
		return
	var error: float = deg_to_rad(Services.perks.get_stat(StatIds.BOT_HERDER_AIM_ERROR_DEG))
	_aim = _herder.global_position.direction_to(target).rotated(_random.randf_range(-error, error))
	_input.aim_direction = _aim
	_input.tap(InputActions.SHOOT)
	_aimed_for = 0.0
	# The shot tells whether it was the Monster; either way this one is done.
	_suspicion.erase(_suspect.get_instance_id())


func _flee(delta: float) -> void:
	_look_at = _spider_at
	_input.move_vector = _steering.away_from(_herder.global_position, _spider_at, delta)


## Turns the light toward where the bot wants to look, at a hand's speed.
func _turn_light(delta: float) -> void:
	if _look_at != Vector2.INF and not _look_at.is_equal_approx(_herder.global_position):
		var wanted: Vector2 = _herder.global_position.direction_to(_look_at)
		var most: float = AIM_TURN_RATE * delta
		var turn: float = clampf(_aim.angle_to(wanted), -most, most)
		_aim = _aim.rotated(turn)
	_input.aim_direction = _aim


func _ring_bell(delta: float) -> void:
	_bell_left -= delta
	if _bell_left > 0.0 or _mode != Mode.WATCH or not _herder.can_ring_bell():
		return
	_bell_left = Services.perks.get_stat(StatIds.BOT_HERDER_BELL_INTERVAL)
	_input.tap(InputActions.BELL)


# --- Memory ----------------------------------------------------------------------


## Where it thinks the flock is: the middle of where it last saw each sheep.
func _flock_center() -> Vector2:
	if _last_seen.is_empty():
		return _herder.global_position
	var sum: Vector2 = Vector2.ZERO
	for id: int in _last_seen:
		sum += _last_seen[id]
	return sum / _last_seen.size()


## The next sheep to light: the most suspicious, or else any it remembers.
func _next_sheep_to_look_at(flock: Vector2) -> Vector2:
	if _last_seen.is_empty():
		return flock
	var ids: Array[int] = []
	ids.assign(_last_seen.keys())
	var pick: int = ids[_random.randi_range(0, ids.size() - 1)]
	for id: int in ids:
		if _suspicion.get(id, 0.0) > _suspicion.get(pick, 0.0):
			pick = id
	return _last_seen[pick]


static func _shown_position(body: SheepBody) -> Vector2:
	var target: VisionTarget = body.get_node_or_null(^"VisionTarget") as VisionTarget
	return target.get_center() if target != null else body.global_position

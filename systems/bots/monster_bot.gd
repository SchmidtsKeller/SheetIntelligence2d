class_name MonsterBot
extends Node
## Plays the Monster in an offline match (see [RoundStage]).
##
## It hides with the very mind an NPC sheep has, a [FlockAgent]: it walks,
## pauses, grazes, bleats and answers the bell like the flock, so nothing but
## its hunting gives it away. Now and then, when the attack is ready and the
## Sheepherder's light is nowhere near, it walks to a sheep and eats it. Once
## it may kill the Sheepherder, it goes for them when they come close; as the
## spider it goes for them wherever they are.
##
## It only moves the stick and presses buttons on the Monster's [BotInput],
## and only while the player may act too.

enum Mode {
	## Behaves like a sheep of the flock.
	HIDE,
	## Walks to a sheep to eat it.
	HUNT,
	## Goes for the Sheepherder.
	ATTACK,
	## Walks away from where it just ate.
	LEAVE,
}

## How long the bot waits between two presses of the same button.
const PRESS_INTERVAL: float = 0.2
## How close it walks up to what it wants to eat (center to center).
const STRIKE_DISTANCE: float = 30.0
## How long it walks away from a meal before it behaves like a sheep again.
const LEAVE_TIME: float = 2.0
## It does not start eating where the light may reach it before the meal is
## over: within the light's length and this much beside the cone's edge.
const LIGHT_MARGIN_DEG: float = 60.0
## How far beside the light the Sheepherder can swing it during a meal.
const SWING_MARGIN_DEG: float = 100.0

var _monster: Monster
var _herder: Sheepherder
var _input: BotInput
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _agent: FlockAgent
var _world: FlockWorld = FlockWorld.new()
var _steering: BotSteering = BotSteering.new()
var _mode: Mode = Mode.HIDE
var _prey: SheepBody
var _hunted_for: float = 0.0
var _rest_left: float = 0.0
var _since_press: float = PRESS_INTERVAL
var _leave_left: float = 0.0
var _meal_at: Vector2 = Vector2.ZERO


## A bot for [param monster], whose input must be a [BotInput], against
## [param herder]. [param bot_seed] makes its decisions repeatable.
func _init(monster: Monster, herder: Sheepherder, bot_seed: int) -> void:
	name = "MonsterBot"
	_monster = monster
	_herder = herder
	_input = monster.input as BotInput
	_random.seed = bot_seed
	var flock: FlockSwarmService = Services.swarm as FlockSwarmService
	if flock != null:
		_agent = FlockAgent.new(_random.randi(), flock.get_settings())


func _ready() -> void:
	# Before the Monster and its driver read the input in the same step.
	process_physics_priority = -2
	Services.swarm.bell_rung.connect(_on_bell_rung)
	Services.combat.eat_started.connect(_on_eat_started)
	_rest_left = _rest_time()


func _exit_tree() -> void:
	Services.swarm.bell_rung.disconnect(_on_bell_rung)
	Services.combat.eat_started.disconnect(_on_eat_started)


func get_mode() -> Mode:
	return _mode


## The sheep it is hunting; [code]null[/code] while it is not.
func get_prey() -> SheepBody:
	return _prey if _mode == Mode.HUNT and is_instance_valid(_prey) else null


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_monster) or _input == null:
		return
	var body: SheepBody = _monster.get_body()
	# The bot plays when the player may: in the round, not in its countdown.
	_input.set_gameplay_enabled(Services.input.is_gameplay_enabled())
	if not _input.is_gameplay_enabled() or not body.is_alive():
		_input.release_all()
		return
	_since_press += delta
	_rest_left -= delta
	var combat: CombatService = Services.combat
	if combat.is_eating():
		_input.release_all()
		return
	_choose_mode(body)
	match _mode:
		Mode.HIDE:
			_hide(body, delta)
		Mode.HUNT:
			_hunt(body, delta)
		Mode.ATTACK:
			_attack(body, delta)
		Mode.LEAVE:
			_leave(body, delta)


# --- Deciding --------------------------------------------------------------------


func _choose_mode(body: SheepBody) -> void:
	var combat: CombatService = Services.combat
	var herder_alive: bool = is_instance_valid(_herder) and _herder.is_alive()
	if herder_alive and combat.can_kill_sheepherder():
		var spider: bool = combat.get_monster_form() == GameEnums.MonsterForm.SPIDER
		var distance: float = body.global_position.distance_to(_herder.global_position)
		var reach: float = Services.perks.get_stat(StatIds.BOT_MONSTER_ATTACK_RANGE)
		if spider or distance <= reach or (_mode == Mode.ATTACK and distance <= reach * 1.6):
			_switch_to(Mode.ATTACK)
			return
	if _mode == Mode.ATTACK:
		_switch_to(Mode.HIDE)
	if _mode == Mode.LEAVE and _leave_left <= 0.0:
		_switch_to(Mode.HIDE)
	if _mode == Mode.HUNT and not _may_go_on_hunting(body):
		_switch_to(Mode.HIDE)
	if _mode == Mode.HIDE and _rest_left <= 0.0 and combat.get_eat_cooldown_remaining() <= 0.0:
		_prey = _find_prey(body)
		if _prey != null:
			_hunted_for = 0.0
			_switch_to(Mode.HUNT)


func _switch_to(mode: Mode) -> void:
	if mode == _mode:
		return
	_mode = mode
	_input.release_all()
	_steering.reset(_monster.get_body().global_position)
	if mode != Mode.HUNT:
		_prey = null


## The nearest sheep it can eat unseen: the Sheepherder is not close to
## either of them, the light is not about to fall on the Monster, and the
## light cannot reach the sheep before a meal there is over.
func _find_prey(body: SheepBody) -> SheepBody:
	if _is_watched(body.global_position) or _light_may_reach(body.global_position):
		return null
	var perks: PerkService = Services.perks
	var hunt_range: float = perks.get_stat(StatIds.BOT_MONSTER_HUNT_RANGE)
	var nearest: SheepBody = null
	var nearest_distance: float = INF
	for sheep_id: int in Services.swarm.get_living_sheep_ids():
		var sheep: SheepBody = Services.swarm.get_sheep_body(sheep_id) as SheepBody
		if sheep == null:
			continue
		var distance: float = body.global_position.distance_to(sheep.global_position)
		if distance > hunt_range or distance >= nearest_distance:
			continue
		if _is_watched(sheep.global_position) or _within_light_reach(sheep.global_position):
			continue
		nearest = sheep
		nearest_distance = distance
	return nearest


func _may_go_on_hunting(body: SheepBody) -> bool:
	if not is_instance_valid(_prey) or not _prey.is_alive():
		return false
	if _hunted_for > Services.perks.get_stat(StatIds.BOT_MONSTER_HUNT_TIME):
		return false
	if BotSenses.herder_sees(_herder, body) or BotSenses.herder_sees(_herder, _prey):
		return false
	var safe: float = Services.perks.get_stat(StatIds.BOT_MONSTER_SAFE_DISTANCE)
	return not _is_near_herder(body.global_position, safe * 0.6)


## Whether the Sheepherder's light may fall on [param point] soon: it is
## within the light's length and not far beside where the light points.
func _light_may_reach(point: Vector2) -> bool:
	if not is_instance_valid(_herder) or not _herder.is_alive():
		return false
	var cone: FlashlightCone = _herder.get_flashlight_cone()
	var offset: Vector2 = point - cone.origin
	if offset.length() > cone.length * 1.1:
		return false
	var beside: float = rad_to_deg(absf(cone.direction.angle_to(offset))) - cone.angle_deg / 2.0
	return beside <= LIGHT_MARGIN_DEG


## Whether the Sheepherder could turn their light onto [param point] before a
## meal there is over: it is within the light's length, no obstacle is in the
## way, and it is not so far behind the light that it cannot swing round in
## time.
func _within_light_reach(point: Vector2) -> bool:
	if not is_instance_valid(_herder) or not _herder.is_alive():
		return false
	var cone: FlashlightCone = _herder.get_flashlight_cone()
	var offset: Vector2 = point - cone.origin
	# A Sheepherder walking this way brings the light closer during the meal.
	var meal: float = Services.perks.get_stat(StatIds.EAT_DURATION)
	var approach: float = maxf(_herder.velocity.dot(offset.normalized()), 0.0) * meal
	if offset.length() > cone.length * 1.1 + STRIKE_DISTANCE + approach:
		return false
	var beside: float = rad_to_deg(absf(cone.direction.angle_to(offset))) - cone.angle_deg / 2.0
	if beside > SWING_MARGIN_DEG:
		return false
	return WorldQueries.has_line_of_sight(_herder.get_world_2d(), cone.origin, point)


## Whether the Sheepherder is close enough to [param point] to notice.
func _is_watched(point: Vector2) -> bool:
	return _is_near_herder(point, Services.perks.get_stat(StatIds.BOT_MONSTER_SAFE_DISTANCE))


func _is_near_herder(point: Vector2, distance: float) -> bool:
	if not is_instance_valid(_herder) or not _herder.is_alive():
		return false
	return point.distance_to(_herder.global_position) < distance


func _rest_time() -> float:
	var perks: PerkService = Services.perks
	return _random.randf_range(
		perks.get_stat(StatIds.BOT_MONSTER_REST_MIN), perks.get_stat(StatIds.BOT_MONSTER_REST_MAX)
	)


# --- Acting ----------------------------------------------------------------------


## Like an NPC sheep: the flock's own mind decides.
func _hide(body: SheepBody, delta: float) -> void:
	if _agent == null:
		_input.move_vector = Vector2.ZERO
		return
	_update_world(body)
	_input.move_vector = _agent.update(delta, body.global_position, body.get_speed(), _world)
	if _agent.is_grazing():
		_input.hold(InputActions.GRAZE)
	else:
		_input.let_go(InputActions.GRAZE)
	if _agent.take_bleat():
		_input.tap(InputActions.BLEAT)


func _hunt(body: SheepBody, delta: float) -> void:
	_hunted_for += delta
	var target: Vector2 = _prey.global_position
	_input.move_vector = _steering.toward(body.global_position, target, delta, STRIKE_DISTANCE)
	# A meal cannot be broken off: none where the light can come by meanwhile.
	if not _within_light_reach(body.global_position):
		_try_to_eat()


## Away from the meal and from the Sheepherder, at a sheep's pace.
func _leave(body: SheepBody, delta: float) -> void:
	_leave_left -= delta
	var danger: Vector2 = _meal_at
	if is_instance_valid(_herder) and _herder.is_alive():
		danger = (_meal_at + _herder.global_position) / 2.0
	_input.move_vector = _steering.away_from(body.global_position, danger, delta)


func _attack(body: SheepBody, delta: float) -> void:
	if Services.combat.get_monster_form() == GameEnums.MonsterForm.SHEEP:
		_input.hold(InputActions.SPRINT)
	var target: Vector2 = _herder.global_position
	_input.move_vector = _steering.toward(body.global_position, target, delta, STRIKE_DISTANCE)
	_try_to_eat()


func _try_to_eat() -> void:
	if _since_press >= PRESS_INTERVAL and Services.combat.can_eat():
		_since_press = 0.0
		_input.tap(InputActions.EAT)


## The flock as its mind sees it: the swarm's picture, with every other sheep
## as a neighbour.
func _update_world(body: SheepBody) -> void:
	var flock: FlockSwarmService = Services.swarm as FlockSwarmService
	var shared: FlockWorld = flock.get_world()
	_world.play_area = shared.play_area
	_world.footprints = shared.footprints
	_world.is_free = shared.is_free
	_world.center = shared.center
	_world.heading = shared.heading
	var neighbours: PackedVector2Array = []
	for sheep_id: int in Services.swarm.get_living_sheep_ids():
		var sheep: Node2D = Services.swarm.get_sheep_body(sheep_id)
		if sheep != null and sheep != body:
			neighbours.append(sheep.global_position)
	_world.neighbours = neighbours


# --- Events ----------------------------------------------------------------------


## Like the flock: a sheep within the bell's reach walks to it.
func _on_bell_rung(origin: Vector2, radius: float) -> void:
	var body: SheepBody = _monster.get_body() if is_instance_valid(_monster) else null
	if body == null or _agent == null:
		return
	if body.global_position.distance_to(origin) <= radius:
		_switch_to(Mode.HIDE)
		_agent.start_bell(origin)


func _on_eat_started(_target: CombatService.EatTarget, _target_id: int, _duration: float) -> void:
	_rest_left = _rest_time()
	if _mode == Mode.HUNT:
		_meal_at = _monster.get_body().global_position
		_leave_left = LEAVE_TIME
		_switch_to(Mode.LEAVE)

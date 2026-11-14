class_name Monster
extends Node2D
## What makes one sheep the Monster (GDD §3.2): the sprint, the attack and
## the spider it turns into.
##
## The Monster's body is the sheep scene every NPC sheep uses, spawned through
## the session's entity registry as [constant KIND] and replicated by a
## [SheepNetSync] like theirs. This node sits in that body and is all that
## sets it apart. It draws nothing and changes nothing about the sheep, so on
## the Sheepherder's device the Monster's sheep is built, shown and heard
## exactly like the others ("No Built-in Tell").
##
## On the device of the Monster's player the sheep is steered from
## [InputService]: a [SheepPlayerDriver] moves it, grazes and bleats, and this
## node adds the sprint, the attack and the perk button. The attack is asked of
## [CombatService], whose host decides it; what it reports is shown here on
## both devices: the eating, the spider form and the Monster's death.

const KIND: StringName = &"monster"
const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
## The name of this node in the Monster's body.
const NODE_NAME: String = "Monster"

## The Monster's device to the other one: the Monster bleats.
## [code][entity_id][/code]
const EVENT_BLEAT: StringName = &"monster.bleat"

## The entity id in the session, or -1 outside the registry (tests).
var entity_id: int = -1
## Whether this device steers the Monster.
var controlled_locally: bool = true
## Whether a bot plays the Monster (offline): it is steered on this device, but
## through its own [member input] and without a camera.
var is_bot: bool = false
## The controls the Monster listens to when it is steered on this device.
## Defaults to [code]Services.input[/code], the player's; a bot's Monster has a
## [BotInput].
var input: InputService:
	get:
		return input if input != null else Services.input
## The session that carries the Monster's events. Defaults to
## [code]Services.session[/code].
var session: GameSession:
	get:
		if session == null:
			session = Services.session
		return session

var _body: SheepBody
var _form: GameEnums.MonsterForm = GameEnums.MonsterForm.SHEEP
var _stamina: MonsterStamina = MonsterStamina.new()
var _driver: SheepPlayerDriver
var _camera: Camera2D
## The flock the body was registered with as a neighbour.
var _swarm: SwarmService
## The perk service the body was registered with as the Monster's character.
var _perks: PerkService
## How far the sheep reaches for the vision system, to restore it after the
## spider.
var _sheep_radius: float = 0.0


## Registers the Monster's kind with [param for_session], on both devices and
## before the host spawns it. The Monster lives where the sheep live: in the
## entity layer of the arena, or where [param parent_provider] says.
static func register(for_session: GameSession, parent_provider: Callable = Callable()) -> void:
	var parent: Callable = parent_provider
	if not parent.is_valid():
		parent = Monster.find_entities_layer.bind(for_session)
	for_session.entities.register_kind(KIND, Monster.build.bind(for_session), parent)


## Factory for [method NetEntityRegistry.register_kind]: a sheep body with the
## look of [code]data["seed"][/code] at [code]data["x"], data["y"][/code], and
## the Monster in it.
static func build(
	new_entity_id: int, owner_id: int, data: Dictionary, for_session: GameSession = null
) -> Node:
	var body: SheepBody = SHEEP_SCENE.instantiate()
	body.set_visual_seed(data.get("seed", 0))
	body.position = Vector2(data.get("x", 0.0), data.get("y", 0.0))
	var bot: bool = BotInput.is_bot_data(data)
	var sync: SheepNetSync = SheepNetSync.new()
	sync.name = "NetSync"
	# Its own player sees the Monster follow the input; everyone else sees it
	# through the same delay as every sheep. A bot's Monster has no player of
	# its own, so it is shown like the flock everywhere.
	sync.live_on_owner = not bot
	body.add_child(sync)
	var monster: Monster = Monster.new()
	monster.name = NODE_NAME
	monster.entity_id = new_entity_id
	if for_session != null:
		monster.session = for_session
	monster.controlled_locally = owner_id == monster.session.messenger.get_local_id()
	if bot:
		monster.is_bot = true
		monster.input = BotInput.new(GameEnums.Role.MONSTER)
	body.add_child(monster)
	return body


## What to spawn the round's Monster with: the look and the place of the slot
## the flock left free for it (see [RoundCast]).
static func spawn_data(round_seed: int, arena: Arena) -> Dictionary:
	var slot_count: int = Services.perks.get_stat_int(StatIds.FLOCK_SIZE) + 1
	var slot: int = RoundCast.monster_slot(round_seed, slot_count)
	var start: Vector2 = arena.get_spawn_layout(round_seed, slot_count).sheep_positions[slot]
	return {
		"seed": RoundCast.visual_seeds(round_seed, slot_count)[slot],
		"x": start.x,
		"y": start.y,
	}


## The Monster in [param body], or [code]null[/code] if it is an ordinary sheep.
static func of(body: Node) -> Monster:
	return body.get_node_or_null(NODE_NAME) as Monster if body != null else null


## Where the sheep live: the y-sorted entity layer of the arena in the scene
## tree of [param for_session]; [code]null[/code] without an arena.
static func find_entities_layer(for_session: GameSession) -> Node:
	if not for_session.is_inside_tree():
		return null
	var arena: Arena = for_session.get_tree().get_first_node_in_group(Groups.ARENA) as Arena
	return arena.get_entities_layer() if arena != null else null


func _ready() -> void:
	_body = get_parent() as SheepBody
	if _body == null:
		push_error("Monster must be the child of a SheepBody.")
		return
	# Before the body, so the speed for this physics step is set when it moves.
	process_physics_priority = -1
	_stamina.reset(Services.perks.get_stat(StatIds.MONSTER_SPRINT_STAMINA))
	var messenger: NetMessenger = session.messenger
	messenger.register_event(EVENT_BLEAT, NetMessenger.SenderRule.ANYONE)
	messenger.subscribe(EVENT_BLEAT, _on_bleat_event)
	var combat: CombatService = Services.combat
	combat.eat_started.connect(_on_eat_started)
	combat.monster_form_changed.connect(_on_form_changed)
	combat.monster_shot.connect(_on_monster_shot)
	# The flock treats the Monster's sheep as one of its own.
	_swarm = Services.swarm
	_swarm.register_neighbour(_body)
	# Its active perk (invisibility) acts on the sheep, on both devices.
	_perks = Services.perks
	_perks.register_character(GameEnums.Role.MONSTER, _body)
	if controlled_locally:
		_take_control()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_bot and is_instance_valid(input):
		input.free()


func _exit_tree() -> void:
	if _body == null:
		return
	# The Monster leaves the tree only to be freed, which ends its signal
	# connections by itself; what holds on to it otherwise is let go of here.
	session.messenger.unsubscribe(EVENT_BLEAT, _on_bleat_event)
	if is_instance_valid(_swarm):
		_swarm.unregister_neighbour(_body)
	if is_instance_valid(_perks):
		_perks.unregister_character(_body)


func _physics_process(delta: float) -> void:
	if not controlled_locally or _body == null or not _body.is_alive():
		return
	var perks: PerkService = Services.perks
	if _form == GameEnums.MonsterForm.SPIDER:
		_body.speed_override = perks.get_stat(StatIds.SPIDER_MOVE_SPEED)
		return
	var moving: bool = (
		not input.get_move_vector().is_zero_approx()
		and not _body.is_grazing()
		and not _body.is_devouring()
	)
	var sprinting: bool = _stamina.advance(
		delta,
		input.is_action_held(InputActions.SPRINT),
		moving,
		perks.get_stat(StatIds.MONSTER_SPRINT_STAMINA),
		perks.get_stat(StatIds.MONSTER_SPRINT_REFILL_RATE)
	)
	_body.speed_override = perks.get_stat(
		StatIds.MONSTER_SPRINT_SPEED if sprinting else StatIds.MONSTER_MOVE_SPEED
	)


# --- State -----------------------------------------------------------------------


## The sheep body the Monster hides in.
func get_body() -> SheepBody:
	return _body


## The Monster's body: the sheep disguise or the spider.
func get_form() -> GameEnums.MonsterForm:
	return _form


## Whether the Monster is sprinting right now. Only known on its own device.
func is_sprinting() -> bool:
	return _form == GameEnums.MonsterForm.SHEEP and _stamina.is_sprinting()


## Seconds of sprinting left. Only known on the Monster's own device.
func get_stamina() -> float:
	return _stamina.get_left()


## Seconds of sprinting a full stamina meter holds.
func get_stamina_capacity() -> float:
	return _stamina.get_capacity()


## How full the stamina meter is, from 0 (empty) to 1 (full).
func get_stamina_ratio() -> float:
	return _stamina.get_ratio()


## The camera that keeps the Monster centered on its player's device;
## [code]null[/code] on the other one.
func get_camera() -> Camera2D:
	return _camera


# --- The Monster's own device ----------------------------------------------------


func _take_control() -> void:
	_driver = SheepPlayerDriver.new()
	_driver.name = "Driver"
	_driver.body = _body
	_driver.input = input
	add_child(_driver)
	_body.bleated.connect(_on_own_bleat)
	input.action_pressed.connect(_on_action_pressed)
	if is_bot:
		return
	# No limits at the borders: the Monster stays in the middle of its player's
	# screen wherever it stands (GDD §3.2).
	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.make_current()
	get_viewport().size_changed.connect(_update_zoom)
	_update_zoom()


func _on_action_pressed(action: StringName) -> void:
	match action:
		InputActions.EAT:
			Services.combat.request_eat()
		InputActions.PERK:
			Services.perks.use_perk(GameEnums.Role.MONSTER)


## The other device hears the Monster bleat like any sheep.
func _on_own_bleat() -> void:
	if session.messenger.has_remote():
		session.messenger.send_to_remote(EVENT_BLEAT, [entity_id])


func _on_bleat_event(payload: Array, _sender_id: int) -> void:
	if payload[0] == entity_id and not controlled_locally:
		_body.bleat()


## Gameplay zoom: the camera shows as much world as a player may see.
func _update_zoom() -> void:
	var zoom: float = ViewRules.camera_zoom(
		get_viewport_rect().size, Services.config.get_view_max_world_size()
	)
	_camera.zoom = Vector2(zoom, zoom)


# --- Both devices: what the host decided -----------------------------------------


func _on_eat_started(_target: int, _target_id: int, duration: float) -> void:
	_body.devour(duration)


func _on_form_changed(form: GameEnums.MonsterForm) -> void:
	if form == _form:
		return
	_form = form
	var spider: bool = form == GameEnums.MonsterForm.SPIDER
	if _driver != null:
		# A spider neither grazes nor bleats.
		_driver.mimicry_enabled = not spider
	# The spider is shown and hidden by the body's vision target like the sheep
	# was (it is drawn in the same place), but it is much larger.
	var vision: VisionTarget = _body.get_node_or_null(^"VisionTarget") as VisionTarget
	if not spider:
		_body.set_visual_override(null)
		if vision != null:
			vision.radius = _sheep_radius
		return
	_body.set_grazing(false)
	var visual: SpiderVisual = SpiderVisual.new()
	visual.name = "Spider"
	visual.body = _body
	_body.set_visual_override(visual)
	if vision != null:
		_sheep_radius = vision.radius
		vision.radius = SpiderVisual.RADIUS


## A bullet ends the Monster like a sheep: it stays on the ground.
func _on_monster_shot(_position: Vector2) -> void:
	_body.kill(GameEnums.DeathCause.SHOT)

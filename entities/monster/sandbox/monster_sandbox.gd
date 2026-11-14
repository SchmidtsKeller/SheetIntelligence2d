extends Node2D
## Monster sandbox: the arena with a round's flock, the Monster and a
## Sheepherder. Run this scene on its own (F6) to play the Monster against a
## Sheepherder that only stands there.
##
## The Monster: WASD, Shift sprints, C grazes, F bleats, E eats what is within
## reach. Five eaten sheep unlock the attack on the Sheepherder, ten make the
## spider. "Dummy shoots" lets the Sheepherder fire at the Monster.
##
## With two instances (see docs/networking.md) the same scene is a round
## without rules between two players:
## [codeblock]
## godot res://entities/monster/sandbox/monster_sandbox.tscn -- --host
## godot res://entities/monster/sandbox/monster_sandbox.tscn -- --join
## [/codeblock]
## The host plays the Sheepherder and the guest the Monster; with
## [code]--monster[/code] on the host it is the other way round. Perks are
## locked for each round: give them with [code]--perk=<id>[,<id>][/code], e.g.
## [code]--perk=shepherd_dog,allied_bat[/code] for both companions (Q sends
## the bat).

const ARENA_SCENE: PackedScene = preload("res://systems/arena/arena.tscn")
const FIRST_ROUND_SEED: int = 16
## Where the Sheepherder starts: this far below the flock's spawn area.
const START_BELOW_FLOCK: float = 220.0
## The owner of the Sheepherder when nobody plays it: no device steers it.
const NOBODY: int = -1
const MONSTER_HOSTS_ARGUMENT: String = "--monster"
## With two devices, how long the host waits before each round, so the guest's
## perk choice (--perk) arrives before the selection is locked.
const PERK_CHOICE_TIME: float = 1.0

var _arena: Arena
var _session: GameSession
var _vision: VisionSystem
var _herder: Sheepherder
var _monster: Monster
var _round_seed: int = FIRST_ROUND_SEED
var _monster_hosts: bool = false
## Counts the rounds started, so a round started while another one waits for
## the perk choice is the only one that begins.
var _rounds_started: int = 0
var _status: Label
var _round_button: Button
var _shoot_button: Button


func _ready() -> void:
	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	var blood: BloodDecalSpawner = BloodDecalSpawner.new()
	blood.decals = _arena.get_decals_layer()
	add_child(blood)
	_vision = VisionSystem.new()
	_arena.get_overlays_layer().add_child(_vision)
	_build_controls()

	_session = Services.session
	Monster.register(_session)
	_session.entities.register_kind(
		Sheepherder.KIND, Sheepherder.build, Monster.find_entities_layer.bind(_session)
	)
	_session.entities.entity_spawned.connect(_on_entity_spawned)
	_session.roles_changed.connect(_apply_role)
	_session.session_started.connect(_on_session_started)

	var options: LaunchOptions = LaunchOptions.from_command_line()
	_monster_hosts = OS.get_cmdline_user_args().has(MONSTER_HOSTS_ARGUMENT)
	if _session.is_active():
		_on_session_started()
	elif options.wants_session():
		var error: Error = options.start_session(_session)
		if error != OK:
			_status.text = "Could not start the session: %s" % error_string(error)
	else:
		_session.host()


func _exit_tree() -> void:
	_session.entities.entity_spawned.disconnect(_on_entity_spawned)
	_session.roles_changed.disconnect(_apply_role)
	_session.session_started.disconnect(_on_session_started)
	Services.input.set_role(GameEnums.Role.NONE)
	Services.combat.end_round()
	_despawn_round()


func _process(_delta: float) -> void:
	if not is_instance_valid(_monster) or not is_instance_valid(_herder):
		if not _session.is_active():
			_status.text = "Waiting for the other player…"
		return
	var combat: CombatService = Services.combat
	var parts: PackedStringArray = [
		"You are the %s" % GameEnums.role_name(_session.get_local_role()),
		_describe_monster(),
		(
			"eaten %d (the kill from %d, the spider from %d)"
			% [
				combat.get_eaten_count(),
				Services.perks.get_stat_int(StatIds.HERDER_KILL_THRESHOLD),
				Services.perks.get_stat_int(StatIds.SPIDER_EVOLUTION_THRESHOLD),
			]
		),
		_describe_attack(),
		(
			"Sheepherder %s, %d of %d bullets"
			% [
				"alive" if _herder.is_alive() else "dead",
				combat.get_ammo(),
				combat.get_ammo_capacity(),
			]
		),
		"%d sheep alive" % Services.swarm.get_living_count(),
		_describe_perk(),
	]
	_status.text = " | ".join(parts)
	_shoot_button.disabled = not combat.can_shoot()


## The Monster of the current round; [code]null[/code] before it is spawned.
func get_monster() -> Monster:
	return _monster if is_instance_valid(_monster) else null


## The Sheepherder of the current round; [code]null[/code] before it is spawned.
func get_sheepherder() -> Sheepherder:
	return _herder if is_instance_valid(_herder) else null


func get_arena() -> Arena:
	return _arena


func get_vision() -> VisionSystem:
	return _vision


## Starts another round with a new flock. Host only.
func start_new_round() -> void:
	if not _session.is_active() or not _session.is_host():
		return
	_round_seed += 1
	_start_round()


## Lets the Sheepherder fire at the Monster, wherever it is. For a Sheepherder
## that nobody plays.
func shoot_at_monster() -> bool:
	if not is_instance_valid(_monster) or not is_instance_valid(_herder):
		return false
	var from: Vector2 = _herder.global_position
	return Services.combat.request_shot(
		from, from.direction_to(_monster.get_body().global_position)
	)


# --- The round -------------------------------------------------------------------


func _on_session_started() -> void:
	if not _session.is_host():
		return
	var alone: bool = not _session.has_remote_player()
	_session.assign_roles(
		GameEnums.Role.MONSTER if alone or _monster_hosts else GameEnums.Role.SHEEPHERDER
	)
	_start_round()


## Host: a new flock, a new Monster in the slot the flock leaves free, and the
## Sheepherder below the flock. Each belongs to the device of its player.
func _start_round() -> void:
	_despawn_round()
	_rounds_started += 1
	var this_round: int = _rounds_started
	if _session.has_remote_player():
		await get_tree().create_timer(PERK_CHOICE_TIME).timeout
		if this_round != _rounds_started or not _session.is_active():
			return
	# Before the characters: the magazine size and the companions follow from it.
	Services.perks.lock_selection()
	Services.swarm.spawn_flock(_round_seed)
	var local_id: int = _session.get_local_peer_id()
	var other_id: int = _session.get_remote_peer_id() if _session.has_remote_player() else NOBODY
	var local_is_monster: bool = _session.get_local_role() == GameEnums.Role.MONSTER
	var flock: Rect2 = _arena.get_flock_spawn_area()
	var start: Vector2 = Vector2(flock.get_center().x, flock.end.y + START_BELOW_FLOCK)
	_session.entities.spawn(
		Sheepherder.KIND, other_id if local_is_monster else local_id, {"x": start.x, "y": start.y}
	)
	_session.entities.spawn(
		Monster.KIND,
		local_id if local_is_monster else other_id,
		Monster.spawn_data(_round_seed, _arena)
	)


func _despawn_round() -> void:
	if not _session.is_active() or not _session.is_host():
		return
	Services.perks.clear_selection()
	Services.swarm.despawn_flock()
	if is_instance_valid(_monster):
		_session.entities.despawn(_monster.entity_id)
	if is_instance_valid(_herder):
		_session.entities.despawn(_herder.entity_id)


## Both devices: the round begins when its two characters are there.
func _on_entity_spawned(_entity_id: int, entity: Node) -> void:
	if entity is Sheepherder:
		_herder = entity
		_monster = null
	elif Monster.of(entity) != null:
		_monster = Monster.of(entity)
	else:
		return
	if _herder == null or _monster == null:
		return
	for decal: Node in _arena.get_decals_layer().get_children():
		decal.queue_free()
	Services.combat.begin_round(_herder, _monster.get_body())
	_apply_role()


## Hands the controls and the eyes of its role to this device's player.
func _apply_role() -> void:
	var role: GameEnums.Role = _session.get_local_role()
	Services.input.set_role(role)
	_vision.role = role
	if role == GameEnums.Role.SHEEPHERDER:
		_vision.viewer = get_sheepherder()
	else:
		_vision.viewer = _monster.get_body() if get_monster() != null else null
	var alone: bool = not _session.has_remote_player()
	_round_button.visible = _session.is_host()
	_shoot_button.visible = alone


# --- Status ----------------------------------------------------------------------


func _describe_monster() -> String:
	var body: SheepBody = _monster.get_body()
	if not body.is_alive():
		return "the Monster is dead"
	if _monster.get_form() == GameEnums.MonsterForm.SPIDER:
		return "the Monster is the spider"
	if not _monster.controlled_locally:
		return "the Monster is one of the sheep"
	return (
		"stamina %.1f of %.1f s%s"
		% [
			_monster.get_stamina(),
			_monster.get_stamina_capacity(),
			", sprinting" if _monster.is_sprinting() else "",
		]
	)


## The local player's perk, and the state of an active one.
func _describe_perk() -> String:
	var perks: PerkService = Services.perks
	var role: GameEnums.Role = _session.get_local_role()
	var perk_id: StringName = perks.get_selected_perk(role)
	if perk_id == PerkIds.NONE:
		return "no perk"
	if perks.is_perk_active(role):
		return "%s running (%d %%)" % [perk_id, roundi(perks.get_perk_charge(role) * 100.0)]
	if perks.get_perk_cooldown_remaining(role) > 0.0:
		return "%s again in %.1f s" % [perk_id, perks.get_perk_cooldown_remaining(role)]
	return String(perk_id)


func _describe_attack() -> String:
	var combat: CombatService = Services.combat
	if combat.is_eating():
		return "eating"
	var cooldown: float = combat.get_eat_cooldown_remaining()
	if cooldown > 0.0:
		return "attack in %.1f s" % cooldown
	return "attack ready" if combat.can_eat() else "nothing in reach"


func _build_controls() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(12.0, 12.0)
	row.add_theme_constant_override(&"separation", 8)
	layer.add_child(row)
	_round_button = _add_button(row, "New round", start_new_round)
	_shoot_button = _add_button(row, "Dummy shoots", shoot_at_monster)
	_status = Label.new()
	row.add_child(_status)


func _add_button(row: HBoxContainer, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	return button

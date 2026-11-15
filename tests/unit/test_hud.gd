extends TestCase
## The in-game HUD on the round screen (GDD §8.2, #21): each role sees its own
## elements, and they show what the game says.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Role = GameEnums.Role

const ROUND_SCENE: String = "res://ui/screens/round_screen.tscn"
const SHARED: Array[String] = ["Timer"]

var _flow: MatchFlow
var _session: GameSession
var _screen: Node2D
var _time: float = 0.0
var _player: StubInputService
var _original_input: Node
var _original_config: Dictionary[StringName, float] = {}
var _original_launch_perks: Variant = null


func before_each() -> void:
	_session = Services.session
	_flow = Services.match_flow
	if _session.is_active():
		_session.leave()
	var scene_flow: SceneFlowController = add_child_autofree(SceneFlowController.new())
	scene_flow.scene_changer = func(_path: String) -> Error: return OK
	_session.scene_flow = scene_flow
	_time = 50.0
	_flow.clock = func() -> float: return _time
	# The other character stands still: what the HUD shows is up to the test.
	RoundStage.bots_enabled = false
	_player = StubInputService.new()
	_original_input = Services.replace(InputService, _player)


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	_session.leave()
	_session.scene_flow = null
	_flow.clock = MatchFlow.system_clock
	_flow.first_host_role = Role.NONE
	RoundStage.bots_enabled = true
	Services.replace(InputService, _original_input)
	_player.free()
	for stat: StringName in _original_config:
		Services.config.set(stat, _original_config[stat])
	_original_config.clear()
	if _original_launch_perks != null:
		(Services.perks as SessionPerkService).launch_perks.assign(_original_launch_perks)
		_original_launch_perks = null
	await wait_frames(2)


# --- Who sees what ---------------------------------------------------------------


func test_the_sheepherder_sees_their_elements_and_none_of_the_monsters() -> void:
	await _play_as(Role.SHEEPHERDER)

	for element: String in SHARED + Hud.HERDER_ELEMENTS:
		assert_true(_hud().shows(element), "the Sheepherder sees %s" % element)
	for element: String in Hud.MONSTER_ELEMENTS:
		assert_false(_hud().shows(element), "the Sheepherder does not see %s" % element)


func test_the_monster_sees_their_elements_and_none_of_the_sheepherders() -> void:
	_select_perk(PerkIds.INVISIBILITY)
	await _play_as(Role.MONSTER)

	for element: String in SHARED + Hud.MONSTER_ELEMENTS:
		assert_true(_hud().shows(element), "the Monster sees %s" % element)
	for element: String in Hud.HERDER_ELEMENTS:
		assert_false(_hud().shows(element), "nothing of the Sheepherder's ammo or bell")


func test_the_hud_follows_when_the_roles_swap() -> void:
	await _play_as(Role.SHEEPHERDER)

	_session.assign_roles(Role.MONSTER)
	await wait_frames(1)

	assert_eq(_hud().get_role(), Role.MONSTER)
	assert_true(_hud().shows("Evolution"))
	assert_false(_hud().shows("Bullets"))


func test_on_a_touchscreen_the_buttons_carry_the_actions() -> void:
	await _play_as(Role.MONSTER)

	_player.set_scheme_override(InputService.Scheme.TOUCH)
	await wait_frames(1)

	for element: String in Hud.ACTION_ICONS:
		assert_false(_hud().shows(element), "no icon for %s next to its button" % element)
	assert_true(_hud().shows("Evolution"))
	assert_true(_hud().shows("Timer"))


func test_without_an_active_perk_there_is_no_perk_icon() -> void:
	_select_perk(PerkIds.FASTER_CONSUMPTION)
	await _play_as(Role.MONSTER)

	assert_false(_hud().shows("Perk"), "a passive perk has nothing to trigger")


# --- Values ----------------------------------------------------------------------


func test_the_timer_counts_down_the_round() -> void:
	await _play_as(Role.MONSTER)
	assert_eq(_text("Timer"), "3:00")

	_pass(Services.config.round_countdown_duration)
	_pass(59.5)
	await wait_frames(1)

	assert_eq(_text("Timer"), "2:01")


func test_bullets_and_reload_follow_the_firearm() -> void:
	await _play_as(Role.SHEEPHERDER)
	_pass(Services.config.round_countdown_duration)
	await wait_frames(1)
	var capacity: int = Services.combat.get_ammo_capacity()
	assert_eq(_gauge("Bullets").pips.count(true), capacity)
	assert_eq(_gauge("Reload").caption, "Ready to fire")

	var herder: Sheepherder = _stage().get_sheepherder()
	Services.combat.request_shot(herder.global_position, Vector2.UP)
	await wait_frames(2)

	assert_eq(_gauge("Bullets").pips.count(true), capacity - 1)
	assert_eq(_gauge("Bullets").caption, "%d / %d bullets" % [capacity - 1, capacity])
	assert_eq(_gauge("Reload").caption, "Reloading")
	assert_lt(_gauge("Reload").value, 1.0)
	assert_gt(_gauge("Shoot").cooldown, 0.0, "the fire icon waits for the reload")


func test_the_bell_icon_shows_its_cooldown() -> void:
	await _play_as(Role.SHEEPHERDER)
	_pass(Services.config.round_countdown_duration)
	await wait_frames(1)
	assert_eq(_gauge("Bell").cooldown, 0.0)

	assert_true(_stage().get_sheepherder().ring_bell())
	await wait_frames(2)

	assert_gt(_gauge("Bell").cooldown, 0.9)
	assert_false(_gauge("Bell").available)


func test_the_evolution_bar_and_the_sheep_count_follow_the_meals() -> void:
	await _play_as(Role.MONSTER)
	_pass(Services.config.round_countdown_duration)
	var flock: int = Services.config.flock_size
	await wait_frames(1)
	assert_eq(_text("SheepCount"), "%d sheep alive" % flock)
	assert_eq(_gauge("Evolution").value, 0.0)

	await _eat_a_sheep()

	var spider_at: int = Services.config.spider_evolution_threshold
	assert_almost_eq(_gauge("Evolution").value, 1.0 / spider_at, 0.0001)
	assert_eq(_text("SheepCount"), "%d sheep alive" % (flock - 1))
	assert_true(_gauge("Evolution").caption.begins_with("1 eaten"))
	assert_true(_gauge("Eat").active, "the Monster is eating")
	assert_eq(
		_gauge("Evolution").marks,
		[float(Services.config.herder_kill_threshold) / spider_at, 1.0] as Array[float]
	)


func test_the_bar_says_when_the_spider_is_out_of_reach() -> void:
	await _play_as(Role.MONSTER)
	_pass(Services.config.round_countdown_duration)
	var spider_at: int = Services.config.spider_evolution_threshold
	# The Sheepherder shot so many that their bodies would not make up for it:
	# killed outright here, without bodies.
	var ids: Array[int] = Services.swarm.get_living_sheep_ids()
	for index: int in Services.config.flock_size - spider_at + 1:
		Services.swarm.kill_sheep(ids[index], GameEnums.DeathCause.EATEN)
	await wait_frames(2)

	assert_true(_gauge("Evolution").caption.ends_with("the spider is out of reach"))
	assert_false(_gauge("Evolution").available)


func test_sprinting_drains_the_stamina_meter() -> void:
	await _play_as(Role.MONSTER)
	_pass(Services.config.round_countdown_duration)
	await wait_frames(1)
	assert_eq(_gauge("Stamina").value, 1.0)

	_player.move_vector = Vector2.RIGHT
	_player.simulate_press(InputActions.SPRINT)
	for step: int in 30:
		await get_tree().physics_frame
	await wait_frames(1)

	assert_lt(_gauge("Stamina").value, 1.0)
	assert_true(_gauge("Stamina").active)
	assert_true(_gauge("Sprint").active)


func test_reaching_the_kill_milestone_says_so() -> void:
	_tune(StatIds.HERDER_KILL_THRESHOLD, 1)
	await _play_as(Role.MONSTER)
	_pass(Services.config.round_countdown_duration)

	await _eat_a_sheep()

	assert_eq(_hud().get_message(), "You can kill the Sheepherder now")
	assert_true(_gauge("Evolution").active)


func test_an_empty_firearm_says_so() -> void:
	_tune(StatIds.FIREARM_AMMO, 1)
	await _play_as(Role.SHEEPHERDER)
	_pass(Services.config.round_countdown_duration)
	var herder: Sheepherder = _stage().get_sheepherder()

	Services.combat.request_shot(herder.global_position, Vector2.UP)
	await wait_frames(2)

	assert_eq(_hud().get_message(), "Out of bullets")
	assert_eq(_gauge("Reload").caption, "Out of bullets")


# --- Helpers ---------------------------------------------------------------------


func _play_as(role: Role) -> void:
	_flow.first_host_role = role
	_screen = (load(ROUND_SCENE) as PackedScene).instantiate()
	add_child(_screen)
	await wait_frames(3)


func _hud() -> Hud:
	return _screen.call(&"get_hud")


func _stage() -> RoundStage:
	return _screen.call(&"get_stage")


func _gauge(element: String) -> HudGauge:
	return _hud().get_element(element) as HudGauge


func _text(element: String) -> String:
	return (_hud().get_element(element) as Label).text


func _pass(seconds: float) -> void:
	_time += seconds
	_flow.tick()


## The player's Monster eats the nearest sheep.
func _eat_a_sheep() -> void:
	var body: SheepBody = _stage().get_monster().get_body()
	var sheep_id: int = Services.swarm.find_nearest_living_sheep(body.global_position, 100000.0)
	body.global_position = Services.swarm.get_sheep_body(sheep_id).global_position
	await get_tree().physics_frame
	assert_true(Services.combat.request_eat(), "the Monster eats")
	await wait_frames(2)


## The Monster's perk for the round. The session starts with no selection, so
## the perk service's launch perks stand in for the lobby (#20).
func _select_perk(perk_id: StringName) -> void:
	var perks: SessionPerkService = Services.perks as SessionPerkService
	_original_launch_perks = perks.launch_perks.duplicate()
	perks.launch_perks.assign([perk_id])


## Sets a config value for this test only.
func _tune(stat: StringName, value: float) -> void:
	if not _original_config.has(stat):
		_original_config[stat] = Services.config.get_number(stat)
	var current: Variant = Services.config.get(stat)
	Services.config.set(stat, int(value) if current is int else value)

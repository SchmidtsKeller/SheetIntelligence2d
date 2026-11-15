extends TestCase
## The perk service (GDD §4): the stat lookup with its modifiers, the loadout
## of both players and the active perks, decided by the host and the same on
## both devices.

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const HERDER: GameEnums.Role = GameEnums.Role.SHEEPHERDER
const MONSTER: GameEnums.Role = GameEnums.Role.MONSTER


## A combat service whose Monster form and eating can be set by the test.
class FakeCombatService:
	extends StubCombatService

	var form: GameEnums.MonsterForm = GameEnums.MonsterForm.SHEEP
	var eating: bool = false

	func get_monster_form() -> GameEnums.MonsterForm:
		return form

	func is_eating() -> bool:
		return eating

	func has_eat_blocker(source: StringName) -> bool:
		return _eat_blockers.has(source)


var _config: GameConfig = GameConfig.new()
var _session: GameSession
var _perks: SessionPerkService
var _combat: FakeCombatService
var _swarm: SandboxSwarmService
var _originals: Dictionary = {}


func before_each() -> void:
	_session = add_child_autofree(GameSession.new())
	_perks = _new_perks(_session)
	_combat = FakeCombatService.new(_config)
	_swarm = SandboxSwarmService.new()
	_originals[CombatService] = Services.replace(CombatService, _combat)
	_originals[SwarmService] = Services.replace(SwarmService, _swarm)


func after_each() -> void:
	for contract: Script in _originals:
		Services.replace(contract, _originals[contract]).free()
	_originals.clear()


# --- Stat lookup -----------------------------------------------------------------


func test_without_modifiers_every_stat_is_its_configured_value() -> void:
	for stat: StringName in StatIds.all():
		assert_eq(_perks.get_stat(stat), _config.get_number(stat), String(stat))
		assert_eq(_perks.get_base_stat(stat), _config.get_number(stat))


func test_the_last_override_counts_then_additions_then_factors() -> void:
	var stat: StringName = StatIds.FLASHLIGHT_CONE_LENGTH
	_perks.add_modifier(stat, PerkService.ModifierOp.MULTIPLY, 0.5, &"a")
	_perks.add_modifier(stat, PerkService.ModifierOp.ADD, 10.0, &"b")
	_perks.add_modifier(stat, PerkService.ModifierOp.OVERRIDE, 100.0, &"c")
	_perks.add_modifier(stat, PerkService.ModifierOp.OVERRIDE, 200.0, &"d")
	_perks.add_modifier(stat, PerkService.ModifierOp.MULTIPLY, 0.8, &"e")

	assert_almost_eq(_perks.get_stat(stat), (200.0 + 10.0) * 0.5 * 0.8)
	assert_eq(_perks.get_base_stat(stat), 350.0)
	assert_eq(_perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG), 60.0, "other stats keep theirs")


func test_modifiers_are_removed_by_handle_or_by_source() -> void:
	var stat: StringName = StatIds.BELL_RADIUS
	var first: int = _perks.add_modifier(stat, PerkService.ModifierOp.ADD, 10.0, &"a")
	var second: int = _perks.add_modifier(stat, PerkService.ModifierOp.ADD, 20.0, &"b")
	_perks.add_modifier(stat, PerkService.ModifierOp.ADD, 40.0, &"b")
	assert_ne(first, second)
	assert_eq(_perks.get_stat(stat), 470.0)

	_perks.remove_modifier(first)
	assert_eq(_perks.get_stat(stat), 460.0)
	_perks.remove_modifier(first)
	_perks.remove_modifier(12345)
	_perks.remove_modifiers_from(&"b")
	assert_eq(_perks.get_stat(stat), 400.0)


func test_a_timed_modifier_removes_itself() -> void:
	var stat: StringName = StatIds.FLASHLIGHT_CONE_ANGLE_DEG
	watch_signals(_perks)

	_perks.add_modifier(stat, PerkService.ModifierOp.MULTIPLY, 0.58, PerkIds.ALLIED_BAT, 10.0)
	assert_signal_emitted_with(_perks, &"stat_changed", [stat])
	_perks.advance(9.9)
	assert_almost_eq(_perks.get_stat(stat), 60.0 * 0.58)

	_perks.advance(0.2)
	assert_eq(_perks.get_stat(stat), 60.0)
	assert_signal_emit_count(_perks, &"stat_changed", 2)


# --- Loadout ---------------------------------------------------------------------


func test_a_player_picks_one_perk_from_their_pool() -> void:
	watch_signals(_perks)

	assert_true(_perks.select_perk(HERDER, PerkIds.WIDE_FLASHLIGHT))
	assert_true(_perks.select_perk(HERDER, PerkIds.SPARE_BULLET), "a new choice replaces it")
	assert_false(_perks.select_perk(HERDER, PerkIds.INVISIBILITY), "a Monster perk")
	assert_false(_perks.select_perk(MONSTER, &"no_such_perk"))

	assert_eq(_perks.get_selected_perk(HERDER), PerkIds.SPARE_BULLET)
	assert_eq(_perks.get_selected_perk(MONSTER), PerkIds.NONE)
	assert_signal_emitted_with(_perks, &"perk_selected", [HERDER, PerkIds.SPARE_BULLET])
	assert_eq(
		_perks.get_available_perks(MONSTER),
		[PerkIds.FASTER_CONSUMPTION, PerkIds.INVISIBILITY, PerkIds.ALLIED_BAT]
	)


func test_a_player_may_go_without_a_perk() -> void:
	_perks.select_perk(HERDER, PerkIds.SPARE_BULLET)

	assert_true(_perks.select_perk(HERDER, PerkIds.NONE))

	assert_eq(_perks.get_selected_perk(HERDER), PerkIds.NONE)


func test_each_perk_has_the_effect_the_gdd_gives_it() -> void:
	# GDD §4 and §5, by perk: the stats that change and their new values.
	var expected: Dictionary = {
		PerkIds.WIDE_FLASHLIGHT: {&"flashlight_cone_angle_deg": 90.0},
		PerkIds.LONG_FLASHLIGHT: {&"flashlight_cone_length": 429.0},
		PerkIds.FASTER_RELOAD: {&"firearm_reload_time": 2.0},
		PerkIds.SPARE_BULLET: {&"firearm_ammo": 4.0},
		PerkIds.SHEPHERD_DOG: {},
		PerkIds.FASTER_CONSUMPTION: {&"eat_duration": 0.5},
		PerkIds.INVISIBILITY: {},
		PerkIds.ALLIED_BAT: {},
	}
	for perk_id: StringName in expected:
		var role: GameEnums.Role = (
			HERDER if _perks.get_available_perks(HERDER).has(perk_id) else MONSTER
		)
		_perks.clear_selection()
		_perks.select_perk(role, perk_id)
		_perks.lock_selection()
		var changes: Dictionary = expected[perk_id]
		for stat: StringName in StatIds.all():
			var value: float = changes.get(stat, _config.get_number(stat))
			assert_eq(_perks.get_stat(stat), value, "%s: %s" % [perk_id, stat])
	_perks.clear_selection()
	assert_eq(_perks.get_stat(StatIds.EAT_DURATION), 1.0)


func test_the_selection_is_locked_for_the_round_and_cleared_after() -> void:
	_perks.select_perk(HERDER, PerkIds.LONG_FLASHLIGHT)
	_perks.select_perk(MONSTER, PerkIds.FASTER_CONSUMPTION)

	_perks.lock_selection()
	assert_true(_perks.is_selection_locked())
	assert_false(_perks.select_perk(HERDER, PerkIds.WIDE_FLASHLIGHT), "locked at round start")
	assert_eq(_perks.get_selected_perk(HERDER), PerkIds.LONG_FLASHLIGHT)
	assert_eq(_perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH), 429.0)
	assert_eq(_perks.get_stat(StatIds.EAT_DURATION), 0.5)

	_perks.clear_selection()
	assert_false(_perks.is_selection_locked())
	assert_eq(_perks.get_selected_perk(HERDER), PerkIds.NONE)
	assert_eq(_perks.get_selected_perk(MONSTER), PerkIds.NONE)
	assert_eq(_perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH), 350.0)
	assert_eq(_perks.get_stat(StatIds.EAT_DURATION), 1.0)


func test_both_devices_know_both_perks_and_apply_the_same_modifiers() -> void:
	var pair: SessionPair = _pair()
	var host: SessionPerkService = _new_perks(pair.host)
	var guest: SessionPerkService = _new_perks(pair.guest)

	assert_true(guest.select_perk(MONSTER, PerkIds.FASTER_CONSUMPTION))
	assert_true(host.select_perk(HERDER, PerkIds.LONG_FLASHLIGHT))
	host.lock_selection()

	for perks: SessionPerkService in [host, guest]:
		assert_true(perks.is_selection_locked())
		assert_eq(perks.get_selected_perk(HERDER), PerkIds.LONG_FLASHLIGHT)
		assert_eq(perks.get_selected_perk(MONSTER), PerkIds.FASTER_CONSUMPTION)
		assert_eq(perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH), 429.0, "the Monster sees it")
		assert_eq(perks.get_stat(StatIds.EAT_DURATION), 0.5)

	host.clear_selection()
	for perks: SessionPerkService in [host, guest]:
		assert_false(perks.is_selection_locked())
		assert_eq(perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH), 350.0)
		assert_eq(perks.get_stat(StatIds.EAT_DURATION), 1.0)


func test_a_player_picks_only_for_their_own_role_and_only_the_host_locks() -> void:
	var pair: SessionPair = _pair()
	var host: SessionPerkService = _new_perks(pair.host)
	var guest: SessionPerkService = _new_perks(pair.guest)

	guest.select_perk(HERDER, PerkIds.SPARE_BULLET)
	host.select_perk(MONSTER, PerkIds.INVISIBILITY)
	guest.lock_selection()

	for perks: SessionPerkService in [host, guest]:
		assert_eq(perks.get_selected_perk(HERDER), PerkIds.NONE, "the guest plays the Monster")
		assert_eq(perks.get_selected_perk(MONSTER), PerkIds.NONE, "the host plays the herder")
		assert_false(perks.is_selection_locked(), "the guest cannot lock")


func test_a_session_that_ends_takes_the_perks_back() -> void:
	var pair: SessionPair = _pair()
	var host: SessionPerkService = _new_perks(pair.host)
	var guest: SessionPerkService = _new_perks(pair.guest)
	host.select_perk(HERDER, PerkIds.WIDE_FLASHLIGHT)
	host.lock_selection()

	pair.guest_network.simulate_ended(NetworkService.DisconnectReason.REMOTE_CLOSE, "")
	pair.host_network.simulate_ended(NetworkService.DisconnectReason.REMOTE_CLOSE, "")

	for perks: SessionPerkService in [host, guest]:
		assert_false(perks.is_selection_locked())
		assert_eq(perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG), 60.0)


# --- Invisibility ----------------------------------------------------------------


func test_invisibility_hides_the_monster_and_stops_it_eating_until_it_ends() -> void:
	var monster: SheepBody = _invisibility_round()
	var target: VisionTarget = VisionTarget.of(monster)
	watch_signals(_perks)

	assert_true(_perks.activate_perk(MONSTER))

	assert_true(_perks.is_perk_active(MONSTER))
	assert_eq(_perks.get_perk_charge(MONSTER), 1.0)
	assert_true(target.cloaked)
	assert_true(_combat.has_eat_blocker(PerkIds.INVISIBILITY), "it cannot eat while invisible")
	assert_does_not_have(_swarm.get_neighbours(), monster, "not one of the flock")
	assert_signal_emitted_with(_perks, &"active_perk_state_changed", [MONSTER])
	assert_false(_perks.activate_perk(MONSTER), "already running")

	assert_true(_perks.end_perk(MONSTER))

	assert_false(_perks.is_perk_active(MONSTER))
	assert_eq(_perks.get_perk_charge(MONSTER), 0.0)
	assert_false(target.cloaked)
	assert_false(_combat.has_eat_blocker(PerkIds.INVISIBILITY))
	assert_has(_swarm.get_neighbours(), monster, "back in the flock")


func test_standing_still_the_monster_stays_invisible_for_five_seconds() -> void:
	_invisibility_round()
	_perks.activate_perk(MONSTER)

	_perks.advance(4.9)
	assert_true(_perks.is_perk_active(MONSTER))
	assert_almost_eq(_perks.get_perk_charge(MONSTER), 0.1 / 5.0)

	_perks.advance(0.2)
	assert_false(_perks.is_perk_active(MONSTER))
	assert_eq(_perks.get_perk_cooldown_remaining(MONSTER), 30.0)


func test_walking_drains_the_meter_three_times_as_fast() -> void:
	var monster: SheepBody = _invisibility_round()
	_perks.activate_perk(MONSTER)
	_walk(monster, 100.0)

	_perks.advance(1.0)
	assert_almost_eq(_perks.get_perk_charge(MONSTER), (5.0 - 3.0) / 5.0)

	_walk(monster, 0.0)
	_perks.advance(1.0)
	assert_almost_eq(_perks.get_perk_charge(MONSTER), (5.0 - 3.0 - 1.0) / 5.0, 0.0001, "standing")

	_walk(monster, 100.0)
	_perks.advance(0.34)
	assert_false(_perks.is_perk_active(MONSTER))


func test_ending_early_loses_the_rest_and_the_cooldown_starts_at_the_end() -> void:
	_invisibility_round()
	watch_signals(_perks)
	assert_true(_perks.use_perk(MONSTER), "the perk button starts it")
	_perks.advance(1.0)

	assert_true(_perks.use_perk(MONSTER), "and ends it early")

	assert_false(_perks.is_perk_active(MONSTER))
	assert_eq(_perks.get_perk_cooldown_remaining(MONSTER), 30.0, "counted from the end")
	_perks.advance(29.9)
	assert_false(_perks.use_perk(MONSTER), "on cooldown")
	assert_signal_emit_count(_perks, &"active_perk_state_changed", 2)

	_perks.advance(0.2)
	assert_eq(_perks.get_perk_cooldown_remaining(MONSTER), 0.0)
	assert_signal_emit_count(_perks, &"active_perk_state_changed", 3, "ready again")
	assert_true(_perks.activate_perk(MONSTER))
	assert_eq(_perks.get_perk_charge(MONSTER), 1.0, "with a full meter")


func test_invisibility_needs_the_perk_a_locked_round_and_a_monster_in_sheep_form() -> void:
	assert_false(_perks.activate_perk(MONSTER), "no perk")
	var monster: SheepBody = _invisibility_round()
	assert_false(_perks.activate_perk(HERDER), "the Sheepherder has no active perk")

	_combat.eating = true
	assert_false(_perks.activate_perk(MONSTER), "not while eating")
	_combat.eating = false
	_combat.form = GameEnums.MonsterForm.SPIDER
	assert_false(_perks.activate_perk(MONSTER), "not as the spider")
	_combat.form = GameEnums.MonsterForm.SHEEP
	_perks.unregister_character(monster)
	assert_false(_perks.activate_perk(MONSTER), "not without the Monster")
	_perks.register_character(MONSTER, monster)
	monster.kill(GameEnums.DeathCause.SHOT)
	assert_false(_perks.activate_perk(MONSTER), "not when dead")


func test_invisibility_ends_when_the_monster_dies() -> void:
	var monster: SheepBody = _invisibility_round()
	_perks.activate_perk(MONSTER)

	monster.kill(GameEnums.DeathCause.SHOT)
	_perks.advance(0.1)

	assert_false(_perks.is_perk_active(MONSTER))
	assert_false(VisionTarget.of(monster).cloaked)


func test_the_end_of_the_round_ends_invisibility() -> void:
	var monster: SheepBody = _invisibility_round()
	_perks.activate_perk(MONSTER)

	_perks.clear_selection()

	assert_false(_perks.is_perk_active(MONSTER))
	assert_eq(_perks.get_perk_cooldown_remaining(MONSTER), 0.0)
	assert_false(VisionTarget.of(monster).cloaked)
	assert_false(_combat.has_eat_blocker(PerkIds.INVISIBILITY))


func test_the_host_decides_invisibility_and_both_devices_show_it() -> void:
	var pair: SessionPair = _pair()
	var host: SessionPerkService = _new_perks(pair.host)
	var guest: SessionPerkService = _new_perks(pair.guest)
	# Each device has its own copy of the Monster's sheep.
	var on_host: SheepBody = _sheep(Vector2.ZERO)
	var on_guest: SheepBody = _sheep(Vector2.ZERO)
	host.register_character(MONSTER, on_host)
	guest.register_character(MONSTER, on_guest)
	guest.select_perk(MONSTER, PerkIds.INVISIBILITY)
	host.lock_selection()

	assert_false(host.activate_perk(MONSTER), "the host plays the Sheepherder")
	assert_true(guest.activate_perk(MONSTER))
	for perks: SessionPerkService in [host, guest]:
		assert_true(perks.is_perk_active(MONSTER))
	assert_true(VisionTarget.of(on_host).cloaked)
	assert_true(VisionTarget.of(on_guest).cloaked)

	guest.advance(6.0)
	assert_true(guest.is_perk_active(MONSTER), "only the host ends it")
	assert_eq(guest.get_perk_charge(MONSTER), 0.0)
	host.advance(5.1)

	for perks: SessionPerkService in [host, guest]:
		assert_false(perks.is_perk_active(MONSTER))
		assert_eq(perks.get_perk_cooldown_remaining(MONSTER), 30.0)
	assert_false(VisionTarget.of(on_guest).cloaked)


func test_bullets_still_hit_the_invisible_monster() -> void:
	var combat: SessionCombatService = SessionCombatService.new()
	combat.session = _session
	combat.swarm = _swarm
	Services.replace(CombatService, combat).free()
	_originals[PerkService] = Services.replace(PerkService, StubPerkService.new(_config))
	var herder: Node2D = add_child_autofree(Node2D.new())
	var monster: SheepBody = _invisibility_round(Vector2(200.0, 0.0))
	combat.begin_round(herder, monster)
	_perks.activate_perk(MONSTER)
	assert_true(VisionTarget.of(monster).cloaked)
	watch_signals(combat)
	await get_tree().physics_frame

	combat.request_shot(Vector2.ZERO, Vector2.RIGHT)

	assert_eq(get_signal_arguments(combat, &"shot_fired")[2], CombatService.ShotResult.HIT_MONSTER)
	combat.end_round()


# --- Launch option ---------------------------------------------------------------


func test_launch_perks_are_picked_for_every_role_this_device_plays() -> void:
	_perks.launch_perks = [PerkIds.WIDE_FLASHLIGHT, PerkIds.INVISIBILITY]

	_perks.clear_selection()
	assert_eq(_perks.get_selected_perk(HERDER), PerkIds.WIDE_FLASHLIGHT, "on its own, both")
	assert_eq(_perks.get_selected_perk(MONSTER), PerkIds.INVISIBILITY)

	_perks.lock_selection()
	_perks.clear_selection()
	assert_eq(_perks.get_selected_perk(HERDER), PerkIds.WIDE_FLASHLIGHT, "again after a round")

	var pair: SessionPair = _pair()
	var host: SessionPerkService = _new_perks(pair.host)
	var guest: SessionPerkService = _new_perks(pair.guest)
	guest.launch_perks = [PerkIds.LONG_FLASHLIGHT, PerkIds.FASTER_CONSUMPTION]
	host.clear_selection()
	assert_eq(host.get_selected_perk(MONSTER), PerkIds.FASTER_CONSUMPTION, "the guest's own")
	assert_eq(host.get_selected_perk(HERDER), PerkIds.NONE)


# --- Helpers ---------------------------------------------------------------------


func _new_perks(session: GameSession) -> SessionPerkService:
	var perks: SessionPerkService = SessionPerkService.new(_config, PerkCatalog.load_default())
	add_child_autofree(perks)
	perks.setup(session)
	# The tests decide when time passes.
	perks.set_process(false)
	return perks


## A host and a guest; the host plays the Sheepherder.
func _pair() -> SessionPair:
	var pair: SessionPair = SessionPair.create(self)
	pair.connect_both()
	pair.host.assign_roles(HERDER)
	return pair


## A locked round in which the Monster, a sheep in the flock at [param at],
## has the invisibility perk.
func _invisibility_round(at: Vector2 = Vector2.ZERO) -> SheepBody:
	var monster: SheepBody = _sheep(at)
	_swarm.register_neighbour(monster)
	_perks.register_character(MONSTER, monster)
	_perks.select_perk(MONSTER, PerkIds.INVISIBILITY)
	_perks.lock_selection()
	return monster


func _sheep(at: Vector2) -> SheepBody:
	var sheep: SheepBody = SHEEP_SCENE.instantiate()
	sheep.position = at
	add_child_autofree(sheep)
	return sheep


## Shows [param sheep] walking at [param speed], as the network shows it.
func _walk(sheep: SheepBody, speed: float) -> void:
	sheep.presented_externally = true
	sheep.present(sheep.global_position, 0.0, speed, false)

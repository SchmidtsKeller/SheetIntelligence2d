extends TestCase
## The companion perks through the perk service (GDD §4.1, §4.2): the dog for
## the whole round, the bat on the perk button.

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const STEP: float = 1.0 / 60.0
const HERDER: GameEnums.Role = GameEnums.Role.SHEEPHERDER
const MONSTER: GameEnums.Role = GameEnums.Role.MONSTER


## A combat service whose Monster form the test sets.
class FakeCombatService:
	extends StubCombatService

	var form: GameEnums.MonsterForm = GameEnums.MonsterForm.SHEEP

	func get_monster_form() -> GameEnums.MonsterForm:
		return form


var _perks: SessionPerkService
var _combat: FakeCombatService
var _session: GameSession
var _herder: Node2D
var _monster: SheepBody
var _originals: Dictionary = {}


func before_each() -> void:
	_session = add_child_autofree(GameSession.new())
	_perks = SessionPerkService.new(Services.config, PerkCatalog.load_default())
	_perks.setup(_session)
	_combat = FakeCombatService.new(Services.config)
	_originals[PerkService] = Services.replace(PerkService, _perks)
	_originals[CombatService] = Services.replace(CombatService, _combat)
	_originals[AudioService] = Services.replace(AudioService, StubAudioService.new(Services.config))
	# Ready re-enables processing, so this comes after it entered the tree.
	_perks.set_process(false)
	_herder = add_child_autofree(Node2D.new())
	_monster = SHEEP_SCENE.instantiate()
	_monster.position = Vector2(400.0, 0.0)
	add_child_autofree(_monster)


func after_each() -> void:
	for contract: Script in _originals:
		Services.replace(contract, _originals[contract]).free()
	_originals.clear()


# --- The dog ---------------------------------------------------------------------


func test_the_dog_comes_with_the_sheepherder_for_the_whole_round() -> void:
	_perks.select_perk(HERDER, PerkIds.SHEPHERD_DOG)
	_perks.lock_selection()
	await wait_frames(1)
	assert_eq(_companions(), [], "no Sheepherder yet")

	_perks.register_character(HERDER, _herder)
	await wait_frames(1)

	var dogs: Array[Node] = _companions()
	assert_eq(dogs.size(), 1)
	assert_is(dogs[0], ShepherdDog)
	assert_false(_perks.is_perk_active(HERDER), "the dog is no active perk")
	assert_false(_perks.activate_perk(HERDER), "and nothing to trigger")

	_perks.unregister_character(_herder)
	await wait_frames(1)
	assert_eq(_companions(), [], "it leaves with the Sheepherder")


func test_the_dog_goes_when_the_round_is_over() -> void:
	_perks.register_character(HERDER, _herder)
	_perks.select_perk(HERDER, PerkIds.SHEPHERD_DOG)
	_perks.lock_selection()
	await wait_frames(1)
	assert_eq(_companions().size(), 1, "the Sheepherder was there first")

	_perks.clear_selection()
	await wait_frames(1)

	assert_eq(_companions(), [])


# --- The bat ---------------------------------------------------------------------


func test_the_bat_is_sent_with_the_perk_button_and_its_cooldown_starts_when_it_leaves() -> void:
	_bat_round()

	assert_true(_perks.use_perk(MONSTER))

	var bat: AlliedBat = _bat()
	assert_not_null(bat, "it is on its way")
	assert_true(_perks.is_perk_active(MONSTER))
	assert_eq(_perks.get_perk_charge(MONSTER), 1.0, "full until it arrives")
	assert_false(_perks.end_perk(MONSTER), "it cannot be called back")
	# Without an arena it starts at the Sheepherder (the flight: test_allied_bat).
	_run_until(bat, func() -> bool: return bat.get_phase() == AlliedBat.Phase.HARASS)
	_run(bat, 2.0)
	assert_almost_eq(_perks.get_perk_charge(MONSTER), 0.8, 0.01, "counting down the 10 s")

	_run_until(bat, func() -> bool: return not _perks.is_perk_active(MONSTER))

	assert_eq(_perks.get_perk_cooldown_remaining(MONSTER), Services.config.bat_cooldown)
	assert_eq(bat.get_phase(), AlliedBat.Phase.LEAVE, "it flies away")
	assert_false(bat.is_queued_for_deletion())
	assert_false(_perks.activate_perk(MONSTER), "on cooldown")


func test_the_bat_needs_a_sheep_and_a_sheepherder() -> void:
	_bat_round()
	_combat.form = GameEnums.MonsterForm.SPIDER
	assert_false(_perks.activate_perk(MONSTER), "not as the spider")
	_combat.form = GameEnums.MonsterForm.SHEEP
	_perks.unregister_character(_herder)
	assert_false(_perks.activate_perk(MONSTER), "nobody to harass")
	_perks.register_character(HERDER, _herder)
	_monster.kill(GameEnums.DeathCause.SHOT)
	assert_false(_perks.activate_perk(MONSTER), "not when dead")


func test_a_bat_still_on_its_way_goes_with_the_round() -> void:
	_bat_round()
	_perks.use_perk(MONSTER)
	assert_not_null(_bat())

	_perks.clear_selection()

	assert_null(_bat())


# --- Helpers ---------------------------------------------------------------------


func _bat_round() -> void:
	_perks.register_character(HERDER, _herder)
	_perks.register_character(MONSTER, _monster)
	_perks.select_perk(MONSTER, PerkIds.ALLIED_BAT)
	_perks.lock_selection()


## The companions the session spawned (no arena here, so below its registry).
func _companions() -> Array[Node]:
	var found: Array[Node] = []
	for entity_id: int in _session.entities.get_entity_ids():
		var entity: Node = _session.entities.get_entity(entity_id)
		if entity.is_in_group(Groups.COMPANIONS):
			found.append(entity)
	return found


func _bat() -> AlliedBat:
	for companion: Node in _companions():
		if companion is AlliedBat:
			# The tests decide when time passes.
			companion.set_physics_process(false)
			return companion
	return null


func _run(bat: AlliedBat, seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		_step_once(bat)


## Steps until [param done] holds, for at most a minute of game time.
func _run_until(bat: AlliedBat, done: Callable) -> void:
	for _step: int in roundi(60.0 / STEP):
		if done.call():
			return
		_step_once(bat)
	fail_test("gave up waiting")


func _step_once(bat: AlliedBat) -> void:
	if is_instance_valid(bat):
		bat.advance(STEP)
	_perks.advance(STEP)

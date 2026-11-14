extends TestCase
## The Friendly Shepherd Dog (GDD §4.1): it keeps the Sheepherder company and
## barks at the Monster only while it eats a living sheep within hearing.

const STEP: float = 1.0 / 60.0

var _perks: SessionPerkService
var _combat: StubCombatService
var _audio: StubAudioService
var _session: GameSession
var _herder: Node2D
var _monster: Node2D
var _originals: Dictionary = {}


func before_each() -> void:
	_session = add_child_autofree(GameSession.new())
	_perks = SessionPerkService.new(Services.config, PerkCatalog.load_default())
	_perks.setup(_session)
	_combat = StubCombatService.new(Services.config)
	_audio = StubAudioService.new(Services.config)
	_originals[PerkService] = Services.replace(PerkService, _perks)
	# Ready re-enables processing, so this comes after it entered the tree.
	_perks.set_process(false)
	_originals[CombatService] = Services.replace(CombatService, _combat)
	_originals[AudioService] = Services.replace(AudioService, _audio)
	_herder = add_child_autofree(Node2D.new())
	_monster = add_child_autofree(Node2D.new())
	_perks.register_character(GameEnums.Role.SHEEPHERDER, _herder)
	_perks.register_character(GameEnums.Role.MONSTER, _monster)


func after_each() -> void:
	for contract: Script in _originals:
		Services.replace(contract, _originals[contract]).free()
	_originals.clear()


func test_it_passes_through_sheep_and_the_sheepherder() -> void:
	var dog: ShepherdDog = _dog(Vector2.ZERO)

	assert_eq(dog.collision_layer, PhysicsLayers.COMPANIONS)
	assert_eq(dog.collision_mask, PhysicsLayers.WORLD, "only obstacles and borders stop it")
	assert_true(dog.is_in_group(Groups.COMPANIONS))
	assert_true(dog.is_in_group(Groups.DYNAMIC_ENTITIES), "the dark hides it like the rest")
	assert_not_null(VisionTarget.of(dog))


func test_it_catches_up_with_the_sheepherder_and_stays_near() -> void:
	var dog: ShepherdDog = _dog(Vector2(900.0, 0.0))

	_run(dog, 6.0)

	# It stops a little short of the spot it picked next to the Sheepherder.
	var far: float = Services.config.dog_follow_distance_max + ShepherdDog.ARRIVE_DISTANCE
	assert_lte(dog.global_position.distance_to(_herder.global_position), far)
	_herder.global_position = Vector2(0.0, 700.0)
	_run(dog, 6.0)
	assert_lte(dog.global_position.distance_to(_herder.global_position), far, "it follows")


func test_a_stuck_dog_comes_back_to_the_sheepherder() -> void:
	var dog: ShepherdDog = _dog(Vector2(800.0, 0.0))
	# Nothing gets it moving: as if an obstacle held it.
	_perks.add_modifier(StatIds.DOG_MOVE_SPEED, PerkService.ModifierOp.OVERRIDE, 0.0, &"test")

	_run(dog, ShepherdDog.STUCK_TIME + 0.1)

	assert_eq(dog.global_position, _herder.global_position)


func test_it_barks_and_faces_the_monster_eating_a_living_sheep_nearby() -> void:
	var dog: ShepherdDog = _dog(Vector2.ZERO)
	_monster.global_position = Vector2(0.0, 500.0)
	watch_signals(dog)

	_combat.eat_started.emit(CombatService.EatTarget.SHEEP, 3, 1.0)

	assert_signal_emit_count(dog, &"barked", 1)
	assert_eq(_audio.played[0]["event"], AudioEvents.DOG_BARK)
	assert_eq(_audio.played[0]["position"], dog.global_position)
	assert_true(dog.is_alerting())
	_run(dog, 0.5)
	assert_almost_eq(dog.rotation, PI / 2.0, 0.001, "it faces the Monster")
	assert_eq(dog.global_position, Vector2.ZERO, "and stands while it does")
	_run(dog, 0.6)
	assert_false(dog.is_alerting(), "only while the Monster eats")


func test_it_ignores_a_body_eaten_or_a_monster_out_of_hearing() -> void:
	var dog: ShepherdDog = _dog(Vector2.ZERO)
	watch_signals(dog)
	_monster.global_position = Vector2(0.0, 500.0)

	_combat.eat_started.emit(CombatService.EatTarget.SHEEP_BODY, 3, 1.0)
	_monster.global_position = Vector2(0.0, Services.config.hearing_range_loud + 1.0)
	_combat.eat_started.emit(CombatService.EatTarget.SHEEP, 4, 1.0)

	assert_signal_not_emitted(dog, &"barked")
	assert_false(dog.is_alerting())
	assert_eq(_audio.played, [])


func test_a_dog_shown_from_the_host_barks_only_when_the_host_says_so() -> void:
	var dog: ShepherdDog = _dog(Vector2.ZERO, false)
	watch_signals(dog)

	_combat.eat_started.emit(CombatService.EatTarget.SHEEP, 3, 1.0)
	assert_signal_not_emitted(dog, &"barked", "the host decides")

	_session.messenger.broadcast(ShepherdDog.EVENT_BARK, [dog.entity_id])
	assert_signal_emit_count(dog, &"barked", 1)


# --- Helpers ---------------------------------------------------------------------


func _dog(at: Vector2, simulated: bool = true) -> ShepherdDog:
	var owner_id: int = _session.messenger.get_local_id() if simulated else 99
	var dog: ShepherdDog = ShepherdDog.build(7, owner_id, {"x": at.x, "y": at.y}, _session)
	add_child_autofree(dog)
	# The tests decide when time passes.
	dog.set_physics_process(false)
	return dog


func _run(dog: ShepherdDog, seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		dog.advance(STEP)

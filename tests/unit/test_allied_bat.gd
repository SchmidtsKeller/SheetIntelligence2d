extends TestCase
## The Allied Bat (GDD §4.2): it flies in from the edge nearest the
## Sheepherder, shrinks the flashlight cone while it circles them, then leaves.

const STEP: float = 1.0 / 60.0
## Cone angle and length are each about 42 % shorter (GDD §4.2, §5).
const FACTOR: float = 1.0 - 0.42

var _perks: SessionPerkService
var _audio: StubAudioService
var _session: GameSession
var _herder: Node2D
var _originals: Dictionary = {}


func before_each() -> void:
	_session = add_child_autofree(GameSession.new())
	_perks = SessionPerkService.new(Services.config, PerkCatalog.load_default())
	_perks.setup(_session)
	_audio = StubAudioService.new(Services.config)
	_originals[PerkService] = Services.replace(PerkService, _perks)
	_originals[AudioService] = Services.replace(AudioService, _audio)
	# Ready re-enables processing, so this comes after it entered the tree.
	_perks.set_process(false)
	_herder = add_child_autofree(Node2D.new())
	_perks.register_character(GameEnums.Role.SHEEPHERDER, _herder)


func after_each() -> void:
	for contract: Script in _originals:
		Services.replace(contract, _originals[contract]).free()
	_originals.clear()


func test_it_comes_in_from_the_edge_nearest_the_sheepherder() -> void:
	var bounds: Rect2 = Rect2(0.0, 0.0, 3200.0, 2400.0)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 19
	for _attempt: int in 20:
		var left: Vector2 = AlliedBat.entry_point(bounds, Vector2(300.0, 1000.0), random)
		assert_eq(left.x, 0.0)
		assert_true(left.y >= 0.0 and left.y <= 2400.0, "anywhere along that edge")
		var bottom: Vector2 = AlliedBat.entry_point(bounds, Vector2(2000.0, 2200.0), random)
		assert_eq(bottom.y, 2400.0)
		assert_true(bottom.x >= 0.0 and bottom.x <= 3200.0)


func test_the_cone_shrinks_while_the_bat_circles_the_sheepherder() -> void:
	var bat: AlliedBat = _bat(Vector2(1000.0, 0.0))
	watch_signals(bat)

	_run(bat, 2.5)

	assert_eq(bat.get_phase(), AlliedBat.Phase.HARASS)
	assert_signal_emit_count(bat, &"arrived", 1)
	assert_almost_eq(_perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG), 60.0 * FACTOR, 0.001)
	assert_almost_eq(_perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH), 350.0 * FACTOR, 0.001)
	assert_eq(_audio.played[0]["event"], AudioEvents.BAT)
	assert_almost_eq(
		bat.global_position.distance_to(_herder.global_position),
		Services.config.bat_orbit_radius,
		1.0,
		"it circles the Sheepherder"
	)

	_run(bat, Services.config.bat_disruption_duration)

	assert_eq(bat.get_phase(), AlliedBat.Phase.LEAVE)
	assert_eq(_perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG), 60.0, "the cone recovers")
	assert_eq(_perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH), 350.0)
	_run(bat, 3.0)
	assert_true(bat.is_queued_for_deletion(), "it flew away where it came from")


func test_the_bat_shrinks_a_wide_or_long_cone_just_as_much() -> void:
	_perks.select_perk(GameEnums.Role.SHEEPHERDER, PerkIds.WIDE_FLASHLIGHT)
	_perks.lock_selection()
	var bat: AlliedBat = _bat(Vector2(500.0, 0.0))

	_run(bat, 1.5)

	assert_almost_eq(_perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG), 90.0 * FACTOR, 0.001)
	assert_almost_eq(_perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH), 350.0 * FACTOR, 0.001)
	# The lit area of the 60° cone shrinks by about 80 % (GDD §4.2).
	assert_almost_eq(FACTOR * FACTOR * FACTOR, 0.2, 0.01)


func test_bullets_pass_through_the_bat() -> void:
	var bat: AlliedBat = _bat(Vector2.ZERO)

	assert_eq(bat.find_children("*", "CollisionObject2D", true, false), [])
	assert_true(bat.is_in_group(Groups.COMPANIONS))
	assert_true(bat.is_in_group(Groups.DYNAMIC_ENTITIES), "the dark hides it like the rest")
	assert_not_null(VisionTarget.of(bat))


func test_a_bat_shown_from_the_host_starts_circling_when_the_host_says_so() -> void:
	var bat: AlliedBat = _bat(Vector2(1000.0, 0.0), false)

	_run(bat, 1.0)
	assert_eq(bat.global_position, Vector2(1000.0, 0.0), "the host flies it")
	_session.messenger.broadcast(AlliedBat.EVENT_ARRIVED, [bat.entity_id])

	assert_eq(bat.get_phase(), AlliedBat.Phase.HARASS)
	assert_almost_eq(_perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG), 60.0 * FACTOR, 0.001)


# --- Helpers ---------------------------------------------------------------------


## A bat outside the entity registry: it frees itself when it is gone.
func _bat(at: Vector2, simulated: bool = true) -> AlliedBat:
	var owner_id: int = _session.messenger.get_local_id() if simulated else 99
	var bat: AlliedBat = AlliedBat.build(-1, owner_id, {"x": at.x, "y": at.y}, _session)
	add_child_autofree(bat)
	# The tests decide when time passes.
	bat.set_physics_process(false)
	return bat


func _run(bat: AlliedBat, seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		bat.advance(STEP)
		_perks.advance(STEP)

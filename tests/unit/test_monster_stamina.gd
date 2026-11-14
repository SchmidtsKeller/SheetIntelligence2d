extends TestCase
## The Monster's sprint stamina: 3 s of sprinting, refilled at half that rate
## (GDD §3.2, §5).

const STEP: float = 1.0 / 60.0

var _stamina: MonsterStamina
var _capacity: float
var _refill: float


func before_each() -> void:
	_capacity = Services.config.monster_sprint_stamina
	_refill = Services.config.monster_sprint_refill_rate
	_stamina = MonsterStamina.new(_capacity)


func test_the_numbers_are_those_of_the_design() -> void:
	assert_eq(_capacity, 3.0)
	assert_eq(_refill, 0.5)


func test_a_fresh_meter_is_full() -> void:
	assert_eq(_stamina.get_left(), 3.0)
	assert_eq(_stamina.get_capacity(), 3.0)
	assert_eq(_stamina.get_ratio(), 1.0)
	assert_false(_stamina.is_sprinting())
	assert_false(_stamina.is_exhausted())


func test_sprinting_uses_the_meter_up_in_three_seconds() -> void:
	var sprinted: float = _run(3.5, true, true)

	assert_almost_eq(sprinted, 3.0, STEP * 1.5)
	assert_false(_stamina.is_sprinting())
	assert_true(_stamina.is_exhausted())
	assert_almost_eq(_stamina.get_left(), 0.25, STEP, "it refills from the moment it is empty")


func test_an_empty_meter_refills_in_six_seconds() -> void:
	_run(3.0, true, true)
	assert_almost_eq(_stamina.get_left(), 0.0, 0.001)

	_run(5.9, false, true)
	assert_lt(_stamina.get_left(), 3.0)

	_run(0.2, false, true)
	assert_eq(_stamina.get_left(), 3.0, "and never more than full")


func test_holding_the_button_after_running_out_does_not_sprint_again() -> void:
	_run(3.5, true, true)

	var sprinted: float = _run(2.0, true, true)

	assert_eq(sprinted, 0.0, "the button has to be let go first")
	assert_almost_eq(_stamina.get_left(), 1.25, STEP * 2.0, "meanwhile the meter refills")


func test_letting_go_allows_the_next_sprint() -> void:
	_run(3.5, true, true)
	_run(1.0, false, true)

	var sprinted: float = _run(1.0, true, true)

	assert_almost_eq(sprinted, 0.75, STEP * 2.0, "what was refilled since it ran empty")


func test_standing_still_costs_nothing() -> void:
	_run(1.0, true, true)

	var sprinted: float = _run(1.0, true, false)

	assert_eq(sprinted, 0.0)
	assert_almost_eq(_stamina.get_left(), 2.5, STEP * 2.0, "it refills while standing")


func test_a_short_sprint_can_be_continued_without_letting_go() -> void:
	_run(1.0, true, true)
	_run(0.5, true, false)

	assert_gt(_run(0.5, true, true), 0.4, "the meter never ran empty")


func test_without_capacity_there_is_no_sprint() -> void:
	_stamina.reset(0.0)

	assert_false(_stamina.advance(STEP, true, true, 0.0, _refill))
	assert_eq(_stamina.get_ratio(), 0.0)


## Advances for [param seconds] in physics steps and returns how many seconds
## of them were spent sprinting.
func _run(seconds: float, held: bool, moving: bool) -> float:
	var sprinted: float = 0.0
	for step: int in roundi(seconds / STEP):
		if _stamina.advance(STEP, held, moving, _capacity, _refill):
			sprinted += STEP
	return sprinted

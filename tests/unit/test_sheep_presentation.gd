extends TestCase
## A sheep can be shown from outside: where it is drawn, and its walk and
## graze animation, then follow what it is told instead of its simulation.

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")

var _sheep: SheepBody
var _picture: Node2D


func before_each() -> void:
	_sheep = add_child_autofree(SHEEP_SCENE.instantiate())
	_sheep.global_position = Vector2(400.0, 300.0)
	_picture = _sheep.get_node(^"Facing")


func test_by_default_the_sheep_shows_itself() -> void:
	assert_true(_sheep.simulated)
	assert_false(_sheep.presented_externally)
	assert_eq(_picture.global_position, _sheep.global_position, "the picture sits on the body")


func test_shown_from_outside_the_picture_goes_where_it_is_told() -> void:
	_sheep.presented_externally = true

	_sheep.present(Vector2(380.0, 290.0), 1.2, 0.0, false)

	assert_almost_eq(_picture.global_position, Vector2(380.0, 290.0))
	assert_almost_eq(_picture.global_rotation, 1.2)
	assert_eq(_sheep.global_position, Vector2(400.0, 300.0), "the body stays where it is")


func test_shown_speed_decides_between_standing_and_walking() -> void:
	_sheep.presented_externally = true

	_sheep.present(_sheep.global_position, 0.0, 180.0, false)
	assert_eq(_sheep.get_state(), SheepBody.State.WALK)

	_sheep.present(_sheep.global_position, 0.0, 0.0, false)
	assert_eq(_sheep.get_state(), SheepBody.State.IDLE)


func test_shown_grazing_lowers_the_head() -> void:
	_sheep.presented_externally = true

	_sheep.present(_sheep.global_position, 0.0, 0.0, true)
	assert_eq(_sheep.get_state(), SheepBody.State.GRAZE)

	_sheep.present(_sheep.global_position, 0.0, 0.0, false)
	assert_eq(_sheep.get_state(), SheepBody.State.IDLE)


func test_grazing_is_shown_only_when_the_presentation_says_so() -> void:
	# The simulation already grazes; the picture follows a moment later.
	_sheep.presented_externally = true

	_sheep.set_grazing(true)

	assert_true(_sheep.is_grazing(), "the sheep grazes")
	assert_eq(_sheep.get_state(), SheepBody.State.IDLE, "but is not shown grazing yet")

	_sheep.present(_sheep.global_position, 0.0, 0.0, true)
	assert_eq(_sheep.get_state(), SheepBody.State.GRAZE)


func test_sheep_that_is_not_simulated_here_does_not_walk() -> void:
	_sheep.simulated = false
	var start: Vector2 = _sheep.global_position

	_sheep.set_move_input(Vector2.RIGHT)
	for tick: int in 20:
		await get_tree().physics_frame

	assert_eq(_sheep.global_position, start)
	assert_eq(_sheep.get_speed(), 0.0)


func test_simulated_sheep_still_walks_when_shown_from_outside() -> void:
	_sheep.presented_externally = true
	var start: Vector2 = _sheep.global_position

	_sheep.set_move_input(Vector2.RIGHT)
	for tick: int in 20:
		await get_tree().physics_frame

	assert_gt(_sheep.global_position.x, start.x + 20.0, "the body walks")
	assert_eq(_sheep.get_state(), SheepBody.State.IDLE, "nobody has shown it walking yet")
	assert_almost_eq(_picture.global_position, start, 0.01, "and the picture has not moved")


func test_dead_sheep_lies_where_it_died_not_where_it_was_last_shown() -> void:
	_sheep.presented_externally = true
	_sheep.present(Vector2(350.0, 300.0), 0.0, 180.0, false)

	_sheep.kill(GameEnums.DeathCause.SHOT)

	assert_eq(_picture.global_position, _sheep.global_position)
	_sheep.present(Vector2(0.0, 0.0), 0.0, 180.0, false)
	assert_eq(_picture.global_position, _sheep.global_position, "a dead sheep is not moved around")
	assert_eq(_sheep.get_state(), SheepBody.State.CORPSE)


func test_presentation_can_be_handed_back_to_the_sheep() -> void:
	_sheep.presented_externally = true
	_sheep.present(Vector2(350.0, 250.0), 0.0, 0.0, false)

	_sheep.presented_externally = false

	assert_eq(_picture.global_position, _sheep.global_position)


func test_net_sync_carries_grazing_and_heading() -> void:
	var owner_sheep: SheepBody = _sheep
	var owner_sync: SheepNetSync = SheepNetSync.new()
	owner_sheep.add_child(owner_sync)
	owner_sync.configure(true, 0.1)
	var remote_sheep: SheepBody = add_child_autofree(SHEEP_SCENE.instantiate())
	var remote_sync: SheepNetSync = SheepNetSync.new()
	remote_sheep.add_child(remote_sync)
	remote_sync.configure(false, 0.1)

	owner_sheep.set_grazing(true)
	for tick: int in 4:
		remote_sync.receive(tick * 0.05, owner_sync.capture(tick * 0.05))
	remote_sync.present(0.1)

	assert_false(remote_sheep.simulated, "the other device does not simulate the sheep")
	assert_true(remote_sheep.presented_externally)
	assert_true(owner_sheep.presented_externally, "the owner shows it through the buffer as well")
	assert_eq(remote_sheep.global_position, owner_sheep.global_position)
	assert_eq(remote_sheep.get_state(), SheepBody.State.GRAZE)
	assert_almost_eq(
		(remote_sheep.get_node(^"Facing") as Node2D).global_rotation, owner_sheep.get_heading()
	)


func test_net_sync_shows_walking_from_how_the_picture_moves() -> void:
	var sync: SheepNetSync = SheepNetSync.new()
	_sheep.add_child(sync)
	sync.configure(false, 0.1)

	# 180 px/s to the right, 20 snapshots per second.
	for tick: int in 10:
		sync.receive(tick * 0.05, [400.0 + 9.0 * tick, 300.0, 0.0, 0])
	sync.present(0.20)
	sync.present(0.25)

	assert_eq(_sheep.get_state(), SheepBody.State.WALK)
	assert_almost_eq(_sheep.global_position.x, 445.0, 0.01)


func test_sheep_steered_by_its_player_is_shown_live_on_that_device() -> void:
	var sync: SheepNetSync = SheepNetSync.new()
	sync.live_on_owner = true
	_sheep.add_child(sync)

	sync.configure(true, 0.1)

	assert_false(_sheep.presented_externally, "its picture follows the input at once")
	assert_true(_sheep.simulated)

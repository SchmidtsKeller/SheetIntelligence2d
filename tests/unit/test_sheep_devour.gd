extends TestCase
## What the Monster needs of the shared sheep body: eating another creature, a
## top speed of its own and a different look (GDD §3.2).

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")


# --- Eating ----------------------------------------------------------------------


func test_a_devouring_sheep_stops_and_cannot_move() -> void:
	var sheep: SheepBody = _spawn()
	sheep.set_move_input(Vector2.RIGHT)
	await _physics_frames(20)
	watch_signals(sheep)

	assert_true(sheep.devour(1.0))
	var at: Vector2 = sheep.position
	await _physics_frames(10)

	assert_eq(sheep.get_state(), SheepBody.State.DEVOUR)
	assert_signal_emitted_with(sheep, &"state_changed", [SheepBody.State.DEVOUR])
	assert_true(sheep.is_devouring())
	assert_eq(sheep.position, at, "it stopped at once and stays")
	assert_eq(sheep.get_speed(), 0.0)


func test_a_devouring_sheep_does_not_graze() -> void:
	var sheep: SheepBody = _spawn()
	sheep.devour(1.0)

	sheep.set_grazing(true)
	await _physics_frames(2)

	assert_eq(sheep.get_state(), SheepBody.State.DEVOUR)


func test_devouring_ends_by_itself() -> void:
	var sheep: SheepBody = _spawn()
	sheep.set_move_input(Vector2.RIGHT)
	sheep.devour(0.1)

	await _physics_frames(5)
	assert_true(sheep.is_devouring(), "0.1 s are six physics steps")

	await _physics_frames(20)
	assert_false(sheep.is_devouring())
	assert_eq(sheep.get_state(), SheepBody.State.WALK, "then it does what it is told again")
	assert_gt(sheep.position.x, 0.0)


func test_the_animation_lasts_as_long_as_the_meal() -> void:
	var sheep: SheepBody = _spawn()
	var animation: AnimationPlayer = sheep.get_node(^"Animation")
	var length: float = animation.get_animation(SheepBody.ANIMATION_DEVOUR).length

	sheep.devour(0.5)

	assert_eq(animation.current_animation, String(SheepBody.ANIMATION_DEVOUR))
	assert_almost_eq(animation.get_playing_speed(), length / 0.5, 0.001)


func test_a_dead_sheep_devours_nothing() -> void:
	var sheep: SheepBody = _spawn()
	sheep.kill(GameEnums.DeathCause.SHOT)

	assert_false(sheep.devour(1.0))
	assert_eq(sheep.get_state(), SheepBody.State.CORPSE)


func test_a_meal_of_no_time_is_no_meal() -> void:
	var sheep: SheepBody = _spawn()

	assert_false(sheep.devour(0.0))
	assert_eq(sheep.get_state(), SheepBody.State.IDLE)


func test_death_ends_the_meal() -> void:
	var sheep: SheepBody = _spawn()
	sheep.devour(1.0)

	sheep.kill(GameEnums.DeathCause.SHOT)
	await _physics_frames(2)

	assert_false(sheep.is_devouring())
	assert_eq(sheep.get_state(), SheepBody.State.CORPSE)


func test_a_sheep_shown_from_outside_devours_as_well() -> void:
	# The copy on the other device: not simulated, shown from the network.
	var sheep: SheepBody = _spawn()
	sheep.simulated = false
	sheep.presented_externally = true

	sheep.devour(0.1)
	sheep.present(Vector2(40.0, 0.0), 0.0, 120.0, false)
	assert_eq(sheep.get_state(), SheepBody.State.DEVOUR, "eating goes before walking")

	await _physics_frames(10)
	sheep.present(Vector2(42.0, 0.0), 0.0, 120.0, false)
	assert_eq(sheep.get_state(), SheepBody.State.WALK)


# --- Speed -----------------------------------------------------------------------


func test_a_sheep_walks_at_sheep_speed_by_default() -> void:
	var sheep: SheepBody = _spawn()

	sheep.set_move_input(Vector2.RIGHT)
	await _physics_frames(90)

	assert_eq(sheep.speed_override, -1.0)
	assert_almost_eq(sheep.get_speed(), Services.config.sheep_move_speed, 0.01)


func test_the_top_speed_can_be_overridden() -> void:
	var sheep: SheepBody = _spawn()
	sheep.speed_override = 270.0

	sheep.set_move_input(Vector2.RIGHT)
	await _physics_frames(90)
	assert_almost_eq(sheep.get_speed(), 270.0, 0.01)

	sheep.speed_override = -1.0
	await _physics_frames(90)
	assert_almost_eq(sheep.get_speed(), Services.config.sheep_move_speed, 0.01)


# --- Look ------------------------------------------------------------------------


func test_another_look_replaces_the_sheep() -> void:
	var sheep: SheepBody = _spawn()
	var facing: Node2D = sheep.get_node(^"Facing")
	var pose: Node2D = sheep.get_node(^"Facing/Pose")
	var look: Node2D = Node2D.new()

	sheep.set_visual_override(look)

	assert_eq(look.get_parent(), facing, "it is drawn where the sheep is shown")
	assert_false(pose.visible)

	sheep.set_visual_override(null)
	assert_true(pose.visible)
	assert_true(look.is_queued_for_deletion())


func test_a_new_look_replaces_the_old_one() -> void:
	var sheep: SheepBody = _spawn()
	var first: Node2D = Node2D.new()
	var second: Node2D = Node2D.new()

	sheep.set_visual_override(first)
	sheep.set_visual_override(second)

	assert_true(first.is_queued_for_deletion())
	assert_false(second.is_queued_for_deletion())
	assert_false((sheep.get_node(^"Facing/Pose") as Node2D).visible)


# --- Helpers ---------------------------------------------------------------------


func _spawn() -> SheepBody:
	return add_child_autofree(SHEEP_SCENE.instantiate())


func _physics_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame

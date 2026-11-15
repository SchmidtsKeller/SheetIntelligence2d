extends TestCase
## The arithmetic of the in-game HUD (#21).


func test_the_timer_shows_minutes_and_seconds_rounded_up() -> void:
	assert_eq(HudReadout.format_time(180.0), "3:00")
	assert_eq(HudReadout.format_time(179.2), "3:00")
	assert_eq(HudReadout.format_time(61.0), "1:01")
	assert_eq(HudReadout.format_time(0.4), "0:01")
	assert_eq(HudReadout.format_time(0.0), "0:00")
	assert_eq(HudReadout.format_time(-3.0), "0:00")


func test_a_cooldown_runs_from_one_to_zero() -> void:
	assert_eq(HudReadout.cooldown_ratio(5.0, 5.0), 1.0)
	assert_almost_eq(HudReadout.cooldown_ratio(1.25, 5.0), 0.25, 0.0001)
	assert_eq(HudReadout.cooldown_ratio(0.0, 5.0), 0.0)
	assert_eq(HudReadout.cooldown_ratio(9.0, 5.0), 1.0, "never more than full")
	assert_eq(HudReadout.cooldown_ratio(-1.0, 5.0), 0.0)
	assert_eq(HudReadout.cooldown_ratio(2.0, 0.0), 0.0, "no cooldown, nothing to show")


func test_one_pip_per_bullet_the_magazine_holds() -> void:
	assert_eq(HudReadout.bullets(2, 3), [true, true, false] as Array[bool])
	assert_eq(HudReadout.bullets(4, 4), [true, true, true, true] as Array[bool], "Spare Bullet")
	assert_eq(HudReadout.bullets(0, 3), [false, false, false] as Array[bool])
	assert_eq(HudReadout.bullets(0, 0), [] as Array[bool])


func test_the_evolution_bar_fills_toward_the_spider() -> void:
	assert_eq(HudReadout.evolution_progress(0, 10), 0.0)
	assert_eq(HudReadout.evolution_progress(5, 10), 0.5)
	assert_eq(HudReadout.evolution_progress(12, 10), 1.0)
	assert_eq(HudReadout.milestone_position(5, 10), 0.5, "the kill milestone sits halfway")


func test_bodies_of_shot_sheep_are_still_there_to_eat() -> void:
	# 6 alive, 3 shot of which 1 body was eaten, 4 eaten in all.
	assert_eq(HudReadout.sheep_left_to_eat(6, 3, 4, 3), 8)
	assert_eq(HudReadout.sheep_left_to_eat(10, 0, 0, 0), 10)
	assert_eq(HudReadout.sheep_left_to_eat(5, 2, 5, 3), 5, "both bodies eaten")


func test_the_spider_is_out_of_reach_when_too_few_sheep_are_left() -> void:
	assert_true(HudReadout.spider_reachable(4, 6, 10))
	assert_false(HudReadout.spider_reachable(4, 5, 10))
	assert_true(HudReadout.spider_reachable(10, 0, 10), "the spider is there")


func test_the_evolution_text_names_the_next_milestone() -> void:
	assert_eq(HudReadout.evolution_text(2, 5, 10, true), "2 eaten · kill at 5 · spider at 10")
	assert_eq(HudReadout.evolution_text(5, 5, 10, true), "5 eaten · kill unlocked · spider at 10")
	assert_eq(HudReadout.evolution_text(3, 5, 10, false), "3 eaten · the spider is out of reach")
	assert_eq(
		HudReadout.evolution_text(6, 5, 10, false),
		"6 eaten · kill unlocked · the spider is out of reach"
	)
	assert_eq(HudReadout.evolution_text(10, 5, 10, true), "The spider")


func test_a_cooldown_whose_length_is_unknown_is_measured_from_its_start() -> void:
	var tracker: HudReadout.CooldownTracker = HudReadout.CooldownTracker.new()

	assert_eq(tracker.ratio(0.0), 0.0)
	assert_eq(tracker.ratio(30.0), 1.0, "it just started")
	assert_eq(tracker.ratio(15.0), 0.5)
	assert_eq(tracker.ratio(0.0), 0.0, "ready")
	assert_eq(tracker.ratio(10.0), 1.0, "the next one is measured anew")

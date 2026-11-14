extends TestCase
## Every parameter of GDD §5 lives in GameConfig with the documented default.

## The parameter table of GDD §5 (plus the scoring values of §2.3 and the
## perk values from the table's notes), by GameConfig property name.
const GDD_DEFAULTS: Dictionary[StringName, Variant] = {
	# Match rules
	&"round_duration": 180.0,
	&"match_rounds": 5,
	&"flock_size": 10,
	&"herder_points_per_surviving_sheep": 1,
	&"herder_points_per_shot_sheep": -2,
	&"monster_points_per_eaten_sheep": 1,
	# Sheepherder
	&"herder_move_speed": 180.0,
	&"firearm_ammo": 3,
	&"firearm_reload_time": 4.0,
	&"flashlight_cone_angle_deg": 60.0,
	&"flashlight_cone_length": 350.0,
	&"bell_cooldown": 12.0,
	&"bell_radius": 400.0,
	# Monster
	&"monster_move_speed": 180.0,
	&"monster_sprint_speed": 270.0,
	&"monster_sprint_stamina": 3.0,
	&"monster_sprint_refill_rate": 0.5,
	&"spider_move_speed": 300.0,
	&"eat_duration": 1.0,
	&"eat_cooldown": 5.0,
	&"melee_range": 48.0,
	&"herder_kill_threshold": 5,
	&"spider_evolution_threshold": 10,
	# NPC sheep
	&"sheep_move_speed": 180.0,
	&"sheep_graze_duration_min": 3.0,
	&"sheep_graze_duration_max": 6.0,
	# Perks
	&"perk_wide_flashlight_angle_deg": 90.0,
	&"perk_long_flashlight_length": 429.0,
	&"perk_faster_reload_time": 2.0,
	&"perk_spare_bullet_ammo": 4,
	&"perk_faster_consumption_duration": 0.5,
	&"invisibility_max_duration": 5.0,
	&"invisibility_drain_still": 1.0,
	&"invisibility_drain_moving": 3.0,
	&"invisibility_cooldown": 30.0,
	&"bat_disruption_duration": 10.0,
	&"bat_cone_shrink": 0.42,
	&"bat_cooldown": 30.0,
	# Audio
	&"hearing_range_quiet": 400.0,
	&"hearing_range_loud": 800.0,
	# Arena
	&"arena_width": 3200.0,
	&"arena_height": 2400.0,
}

## Values that are project decisions rather than GDD parameters.
const PROJECT_DEFAULTS: Dictionary[StringName, Variant] = {
	&"flock_walk_time_min": 1.5,
	&"flock_walk_time_max": 4.0,
	&"flock_pause_time_min": 0.8,
	&"flock_pause_time_max": 2.5,
	&"flock_graze_chance": 0.45,
	&"flock_bleat_interval_min": 8.0,
	&"flock_bleat_interval_max": 25.0,
	&"flock_wander_distance_min": 80.0,
	&"flock_wander_distance_max": 240.0,
	&"flock_separation_radius": 72.0,
	&"flock_cohesion_radius": 280.0,
	&"flock_alignment_weight": 0.35,
	&"flock_obstacle_margin": 60.0,
	&"flock_border_margin": 70.0,
	&"flock_body_clearance": 28.0,
	&"bell_stop_distance": 110.0,
	&"bell_follow_time": 6.0,
	&"sheep_acceleration": 900.0,
	&"sheep_turn_rate_deg": 540.0,
	&"net_tick_rate": 20,
	&"net_interpolation_delay": 0.1,
	&"net_max_extrapolation": 0.1,
	&"net_connect_timeout": 10.0,
	&"view_max_world_width": 1600.0,
	&"view_max_world_height": 900.0,
}


func test_script_defaults_match_the_design_document() -> void:
	_assert_matches_gdd(GameConfig.new())


func test_shipped_config_matches_the_design_document() -> void:
	var shipped: GameConfig = load(Services.CONFIG_PATH) as GameConfig

	if assert_not_null(shipped, "the shipped config loads as a GameConfig"):
		_assert_matches_gdd(shipped)


func test_application_uses_the_shipped_config() -> void:
	assert_eq(Services.config, load(Services.CONFIG_PATH))


func test_every_config_value_is_covered_by_this_test() -> void:
	var config: GameConfig = GameConfig.new()

	for number_name: StringName in config.get_number_names():
		assert_true(
			GDD_DEFAULTS.has(number_name) or PROJECT_DEFAULTS.has(number_name),
			"'%s' has an expected default in this test" % number_name,
		)
	assert_eq(config.get_number_names().size(), GDD_DEFAULTS.size() + PROJECT_DEFAULTS.size())


func test_integer_parameters_are_stored_as_integers() -> void:
	var config: GameConfig = GameConfig.new()

	for defaults: Dictionary in [GDD_DEFAULTS, PROJECT_DEFAULTS]:
		for number_name: StringName in defaults:
			var expected_type: int = typeof(defaults[number_name])
			assert_eq(typeof(config.get(number_name)), expected_type, "type of '%s'" % number_name)


func test_stat_ids_and_config_values_are_the_same_set() -> void:
	var config: GameConfig = GameConfig.new()
	var stat_ids: Array[StringName] = StatIds.all()

	for stat: StringName in stat_ids:
		assert_true(config.has_number(stat), "stat '%s' is a GameConfig value" % stat)
	for number_name: StringName in config.get_number_names():
		assert_has(stat_ids, number_name, "config value '%s' has a StatIds constant" % number_name)
	assert_eq(stat_ids.size(), config.get_number_names().size())


func test_get_number_returns_floats_for_integers_too() -> void:
	var config: GameConfig = GameConfig.new()

	assert_eq(config.get_number(StatIds.FIREARM_AMMO), 3.0)
	assert_eq(typeof(config.get_number(StatIds.FIREARM_AMMO)), TYPE_FLOAT)
	assert_eq(config.get_number(StatIds.BELL_RADIUS), 400.0)


func test_get_number_fails_loudly_for_an_unknown_name() -> void:
	var config: GameConfig = GameConfig.new()
	expect_error("no numeric value named 'no_such_value'")

	assert_eq(config.get_number(&"no_such_value"), 0.0)
	assert_false(config.has_number(&"no_such_value"))


# --- Relations the design document states in words ------------------------------


func test_monster_moves_exactly_like_the_sheep_it_imitates() -> void:
	var config: GameConfig = GameConfig.new()

	assert_eq(config.monster_move_speed, config.sheep_move_speed)


func test_sprint_is_one_and_a_half_times_the_base_speed() -> void:
	var config: GameConfig = GameConfig.new()

	assert_almost_eq(config.monster_sprint_speed, config.monster_move_speed * 1.5)


func test_stamina_refills_from_empty_in_six_seconds() -> void:
	var config: GameConfig = GameConfig.new()

	assert_almost_eq(config.monster_sprint_stamina / config.monster_sprint_refill_rate, 6.0)


func test_spider_is_faster_than_a_sprinting_sheep() -> void:
	var config: GameConfig = GameConfig.new()

	assert_gt(config.spider_move_speed, config.monster_sprint_speed)


func test_both_flashlight_perks_light_half_as_much_area_again() -> void:
	var config: GameConfig = GameConfig.new()
	var base_area: float = _lit_area(
		config.flashlight_cone_angle_deg, config.flashlight_cone_length
	)

	var wide_area: float = _lit_area(
		config.perk_wide_flashlight_angle_deg, config.flashlight_cone_length
	)
	var long_area: float = _lit_area(
		config.flashlight_cone_angle_deg, config.perk_long_flashlight_length
	)

	assert_almost_eq(wide_area / base_area, 1.5, 0.01)
	assert_almost_eq(long_area / base_area, 1.5, 0.01)


func test_bat_cuts_the_lit_area_by_about_eighty_percent() -> void:
	var config: GameConfig = GameConfig.new()
	var remaining: float = 1.0 - config.bat_cone_shrink
	var base_area: float = _lit_area(
		config.flashlight_cone_angle_deg, config.flashlight_cone_length
	)

	var disrupted_area: float = _lit_area(
		config.flashlight_cone_angle_deg * remaining,
		config.flashlight_cone_length * remaining,
	)

	assert_almost_eq(1.0 - disrupted_area / base_area, 0.8, 0.01)


func test_perks_halve_reload_and_eating_time() -> void:
	var config: GameConfig = GameConfig.new()

	assert_almost_eq(config.perk_faster_reload_time, config.firearm_reload_time * 0.5)
	assert_almost_eq(config.perk_faster_consumption_duration, config.eat_duration * 0.5)


func test_spare_bullet_adds_exactly_one_bullet() -> void:
	var config: GameConfig = GameConfig.new()

	assert_eq(config.perk_spare_bullet_ammo, config.firearm_ammo + 1)


func test_spider_needs_the_whole_flock() -> void:
	var config: GameConfig = GameConfig.new()

	assert_eq(config.spider_evolution_threshold, config.flock_size)
	assert_lt(config.herder_kill_threshold, config.spider_evolution_threshold)


func _assert_matches_gdd(config: GameConfig) -> void:
	for number_name: StringName in GDD_DEFAULTS:
		assert_eq(
			config.get(number_name),
			GDD_DEFAULTS[number_name],
			"GDD §5 default of '%s'" % number_name
		)
	for number_name: StringName in PROJECT_DEFAULTS:
		assert_eq(
			config.get(number_name), PROJECT_DEFAULTS[number_name], "default of '%s'" % number_name
		)


## Area of a circular sector, up to a constant factor.
static func _lit_area(angle_deg: float, length: float) -> float:
	return angle_deg * length * length

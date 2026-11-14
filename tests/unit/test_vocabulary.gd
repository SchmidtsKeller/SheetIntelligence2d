extends TestCase
## The shared vocabulary (roles, perks, sound events) matches the design document.

# --- Roles ---------------------------------------------------------------------


func test_roles_are_each_others_opposite() -> void:
	assert_eq(GameEnums.opposite_role(GameEnums.Role.SHEEPHERDER), GameEnums.Role.MONSTER)
	assert_eq(GameEnums.opposite_role(GameEnums.Role.MONSTER), GameEnums.Role.SHEEPHERDER)
	assert_eq(GameEnums.opposite_role(GameEnums.Role.NONE), GameEnums.Role.NONE)


func test_role_names() -> void:
	assert_eq(GameEnums.role_name(GameEnums.Role.SHEEPHERDER), "Sheepherder")
	assert_eq(GameEnums.role_name(GameEnums.Role.MONSTER), "Monster")


func test_role_action_sets() -> void:
	assert_eq(
		InputActions.abilities_for(GameEnums.Role.SHEEPHERDER),
		[InputActions.SHOOT, InputActions.BELL]
	)
	assert_eq(
		InputActions.abilities_for(GameEnums.Role.MONSTER),
		[
			InputActions.GRAZE,
			InputActions.BLEAT,
			InputActions.EAT,
			InputActions.SPRINT,
			InputActions.PERK
		],
	)
	assert_eq(InputActions.abilities_for(GameEnums.Role.NONE), [])
	assert_true(InputActions.role_aims(GameEnums.Role.SHEEPHERDER))
	assert_false(InputActions.role_aims(GameEnums.Role.MONSTER), "the Monster has nothing to aim")


# --- Perks (GDD §4) --------------------------------------------------------------


func test_sheepherder_has_five_perks_and_the_monster_three() -> void:
	assert_eq(PerkIds.SHEEPHERDER_POOL.size(), 5)
	assert_eq(PerkIds.MONSTER_POOL.size(), 3)
	assert_eq(PerkIds.pool_for(GameEnums.Role.SHEEPHERDER), PerkIds.SHEEPHERDER_POOL)
	assert_eq(PerkIds.pool_for(GameEnums.Role.MONSTER), PerkIds.MONSTER_POOL)
	assert_eq(PerkIds.pool_for(GameEnums.Role.NONE), [])


func test_perk_pools_do_not_overlap() -> void:
	for perk_id: StringName in PerkIds.SHEEPHERDER_POOL:
		assert_does_not_have(PerkIds.MONSTER_POOL, perk_id)
		assert_true(PerkIds.is_valid_for(GameEnums.Role.SHEEPHERDER, perk_id))
		assert_false(PerkIds.is_valid_for(GameEnums.Role.MONSTER, perk_id))


func test_no_perk_is_never_a_valid_choice() -> void:
	assert_false(PerkIds.is_valid_for(GameEnums.Role.SHEEPHERDER, PerkIds.NONE))
	assert_false(PerkIds.is_valid_for(GameEnums.Role.MONSTER, PerkIds.NONE))


# --- Sound events (GDD §5, §7.2) -------------------------------------------------


func test_every_sound_event_has_a_hearing_range_class() -> void:
	assert_eq(AudioEvents.ALL.size(), 10)
	for event_id: StringName in AudioEvents.ALL:
		assert_true(AudioEvents.RANGE_CLASS.has(event_id), "'%s' has a range class" % event_id)
	assert_eq(AudioEvents.RANGE_CLASS.size(), AudioEvents.ALL.size())


func test_sound_event_ids_are_unique() -> void:
	var seen: Array[StringName] = []

	for event_id: StringName in AudioEvents.ALL:
		assert_does_not_have(seen, event_id)
		seen.append(event_id)


func test_hearing_range_classes_follow_the_design_document() -> void:
	assert_eq(AudioEvents.range_class_of(AudioEvents.GRASS_MOVE), GameEnums.HearingRange.QUIET)
	assert_eq(AudioEvents.range_class_of(AudioEvents.BLEAT), GameEnums.HearingRange.LOUD)
	assert_eq(AudioEvents.range_class_of(AudioEvents.EAT), GameEnums.HearingRange.LOUD)
	assert_eq(AudioEvents.range_class_of(AudioEvents.DOG_BARK), GameEnums.HearingRange.LOUD)
	assert_eq(AudioEvents.range_class_of(AudioEvents.BELL), GameEnums.HearingRange.WHOLE_MAP)
	assert_eq(AudioEvents.range_class_of(AudioEvents.GUNSHOT), GameEnums.HearingRange.WHOLE_MAP)


func test_unknown_sound_events_are_quiet() -> void:
	assert_eq(AudioEvents.range_class_of(&"no_such_event"), GameEnums.HearingRange.QUIET)


# --- Stats -----------------------------------------------------------------------


func test_stat_ids_are_unique() -> void:
	var seen: Array[StringName] = []

	for stat: StringName in StatIds.all():
		assert_does_not_have(seen, stat)
		seen.append(stat)
	assert_gt(seen.size(), 0)

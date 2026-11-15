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


# --- Sound events (GDD §5, §7.2) -------------------------------------------------


func test_every_sound_event_has_a_hearing_range_class() -> void:
	assert_eq(AudioEvents.ALL.size(), 11)
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


func test_hearing_range_classes_decided_in_the_audio_task() -> void:
	assert_eq(AudioEvents.range_class_of(AudioEvents.GRAZE), GameEnums.HearingRange.QUIET)
	assert_eq(AudioEvents.range_class_of(AudioEvents.HERDER_STEP), GameEnums.HearingRange.QUIET)
	assert_eq(AudioEvents.range_class_of(AudioEvents.RELOAD_CLICK), GameEnums.HearingRange.QUIET)
	assert_eq(
		AudioEvents.range_class_of(AudioEvents.SPIDER_SCREECH), GameEnums.HearingRange.WHOLE_MAP
	)
	assert_eq(AudioEvents.range_class_of(AudioEvents.BAT), GameEnums.HearingRange.LOUD)


func test_unknown_sound_events_are_quiet() -> void:
	assert_eq(AudioEvents.range_class_of(&"no_such_event"), GameEnums.HearingRange.QUIET)


# --- Stats -----------------------------------------------------------------------


func test_stat_ids_are_unique() -> void:
	var seen: Array[StringName] = []

	for stat: StringName in StatIds.all():
		assert_does_not_have(seen, stat)
		seen.append(stat)
	assert_gt(seen.size(), 0)
